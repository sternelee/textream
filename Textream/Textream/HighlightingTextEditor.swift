//
//  HighlightingTextEditor.swift
//  Textream
//
//  Created by Fatih Kadir Akın on 26.02.2026.
//

import SwiftUI
import AppKit

extension NSFont {
    var rounded: NSFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}

struct HighlightingTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .systemFont(ofSize: 16, weight: .regular)
    var isFocused: FocusState<Bool>.Binding?
    /// Range of newly dictated text to highlight with a bump effect
    var highlightRange: NSRange? = nil
    /// One-shot: set caret to this position, then nilled out
    @Binding var caretPosition: Int?
    /// Continuously reported current caret position in the editor
    @Binding var editorCaretPosition: Int
    /// Currently selected text in the editor
    @Binding var selectedText: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = font
        textView.delegate = context.coordinator
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        context.coordinator.textView = textView

        // Set initial text and apply highlighting
        textView.string = text
        context.coordinator.applyHighlighting(textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            context.coordinator.applyHighlighting(textView)
        }

        // Apply bump highlight on newly dictated range
        if let range = highlightRange, range.location + range.length <= textView.string.count {
            context.coordinator.applyBumpHighlight(textView, range: range)
        }

        // Move caret to requested position (one-shot)
        if let pos = caretPosition, pos <= textView.string.count {
            let caretRange = NSRange(location: pos, length: 0)
            textView.setSelectedRange(caretRange)
            textView.scrollRangeToVisible(caretRange)
            DispatchQueue.main.async {
                self.caretPosition = nil
            }
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HighlightingTextEditor
        weak var textView: NSTextView?

        private static let annotationPattern = try! NSRegularExpression(
            pattern: "\\[[^\\]]+\\]",
            options: []
        )

        init(_ parent: HighlightingTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            applyHighlighting(textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let range = textView.selectedRange()
            if parent.editorCaretPosition != range.location {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.editorCaretPosition = range.location
                }
            }
            // Extract selected text
            let selected = (textView.string as NSString).substring(with: range)
            if parent.selectedText != selected {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.selectedText = selected
                }
            }
        }

        private var bumpTimer: Timer?

        func applyBumpHighlight(_ textView: NSTextView, range: NSRange) {
            guard let textStorage = textView.textStorage else { return }
            guard range.length > 0, range.location + range.length <= textStorage.length else { return }

            let bumpColor = NSColor.controlAccentColor.withAlphaComponent(0.15)
            textStorage.beginEditing()
            textStorage.addAttribute(.backgroundColor, value: bumpColor, range: range)
            textStorage.endEditing()

            // Fade out after a short delay
            bumpTimer?.invalidate()
            bumpTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self, weak textView] _ in
                guard let self, let textView else { return }
                self.applyHighlighting(textView)
            }
        }

        func applyHighlighting(_ textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: textStorage.length)
            let text = textStorage.string

            // Preserve selection
            let selectedRanges = textView.selectedRanges

            textStorage.beginEditing()

            // Reset to default style
            let defaultAttributes: [NSAttributedString.Key: Any] = [
                .font: parent.font,
                .foregroundColor: NSColor.labelColor
            ]
            textStorage.setAttributes(defaultAttributes, range: fullRange)

            // Highlight [bracket] annotations with markup-aware colors
            let bracketMatches = Self.annotationPattern.matches(in: text, options: [], range: fullRange)
            for match in bracketMatches {
                let bracketText = (text as NSString).substring(with: match.range)
                let tag = ScriptMarkupParser.tag(for: bracketText)
                let tagAttrs: [NSAttributedString.Key: Any]
                if let tag = tag {
                    // Markup tag: use tag-specific styling
                    let nsColor = NSColor(tag.editorColor)
                    let nsBg = NSColor(tag.editorBackground)
                    tagAttrs = [
                        .font: NSFontManager.shared.convert(parent.font, toHaveTrait: .italicFontMask),
                        .foregroundColor: nsColor,
                        .backgroundColor: nsBg
                    ]
                } else {
                    // Regular annotation (stage direction like [smile])
                    tagAttrs = [
                        .font: NSFontManager.shared.convert(parent.font, toHaveTrait: .italicFontMask),
                        .foregroundColor: NSColor.secondaryLabelColor,
                        .backgroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.08)
                    ]
                }
                textStorage.addAttributes(tagAttrs, range: match.range)
            }

            // Highlight **bold** text
            let boldMatches = ScriptMarkupParser.boldPattern.matches(in: text, options: [], range: fullRange)
            for match in boldMatches {
                // match.range covers the full **text** including asterisks
                let boldAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFontManager.shared.convert(parent.font, toHaveTrait: .boldFontMask),
                    .foregroundColor: NSColor.labelColor
                ]
                textStorage.addAttributes(boldAttrs, range: match.range)
            }

            textStorage.endEditing()

            // Restore selection
            textView.selectedRanges = selectedRanges
        }
    }
}
