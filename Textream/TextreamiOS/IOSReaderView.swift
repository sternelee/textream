import Combine
import SwiftUI

struct IOSReaderView: View {
    @Bindable var model: IOSTeleprompterModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showQuickSettings = false
    @State private var controlsHidden = false
    @State private var hideControlsTimer: Timer?
    @State private var fullImmersion = false
    @State private var dragOffset: CGFloat = 0
    @State private var showFullImmersionHint = false
    @AppStorage("hasShownFullImmersionHint") private var hasShownFullImmersionHint = false
    @State private var pageTransitionToast: String? = nil
    @State private var pageTransitionTimer: Timer? = nil
    @State private var lastMagnification: CGFloat = 1.0
    @State private var speedIndicatorText: String? = nil
    @State private var speedIndicatorTimer: Timer? = nil
    @State private var fontSizeIndicatorText: String? = nil
    @State private var fontSizeIndicatorTimer: Timer? = nil
    @State private var currentTimeString: String = ""
    @State private var showingJumpToPage = false
    @State private var jumpToPageText = ""
    @State private var showingPractice = false
    @State private var showPhoneticTooltip = false
    @State private var selectedWordForLookup: String? = nil
    private let tickTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let width = proxy.size.width
                ScrollViewReader { scrollProxy in
                    Group {
                        if prefersWideLayout(for: width) {
                            wideLayout(width: width, proxy: scrollProxy)
                        } else {
                            compactLayout(width: width, proxy: scrollProxy)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(readerBackground.ignoresSafeArea())
                    .foregroundStyle(.white)
                    .toolbar(.hidden, for: .navigationBar)
                    .onReceive(tickTimer) { _ in
                        model.tick(deltaSeconds: 0.1)
                        let now = Date()
                        let newString = timeFormatter.string(from: now)
                        if newString != currentTimeString {
                            currentTimeString = newString
                        }
                    }
                    .onChange(of: model.currentWordIndex) { _, newValue in
                        scrollProxy.scrollTo(newValue, anchor: .center)
                    }
                    .onChange(of: model.document.currentPageIndex) { _, _ in
                        let currentPage = model.document.currentPageIndex + 1
                        let totalPages = model.document.pages.count
                        showPageTransitionToast("Page \(currentPage) of \(totalPages)")
                    }
                    .onChange(of: model.scrollSpeedWordsPerSecond) { _, newValue in
                        showSpeedIndicator("\(String(format: "%.1f", newValue)) w/s")
                    }
                    .onChange(of: model.readerFontSize) { _, newValue in
                        showFontSizeIndicator("\(Int(newValue)) pt")
                    }
                    .alert("Textream", isPresented: Binding(
                        get: { model.presentedErrorMessage != nil },
                        set: { if !$0 { model.dismissPresentedError() } }
                    )) {
                        Button("OK") { model.dismissPresentedError() }
                    } message: {
                        Text(model.presentedErrorMessage ?? "")
                    }
                    .background(ShakeDetector())
                    .onAppear {
                        startHideControlsTimer()
                    }
                    .onDisappear {
                        hideControlsTimer?.invalidate()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                        model.togglePause()
                    }
                }
            }
        }
        .sheet(isPresented: $showingPractice) {
            PracticeView(scriptText: model.document.pages.joined(separator: "\n\n"))
        }
        .sheet(isPresented: $showPhoneticTooltip) {
            if let word = selectedWordForLookup {
                PhoneticTooltipView(word: word, nativeLanguage: model.nativeLanguage, phoneticSource: model.phoneticSource)
            }
        }
    }

    private var readerBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.03, blue: 0.06),
                Color(red: 0.06, green: 0.07, blue: 0.10),
                Color(red: 0.02, green: 0.03, blue: 0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func compactLayout(width: CGFloat, proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 14) {
            if !fullImmersion {
                topBar(compact: isCompactWidth(width))
                thinProgressBar
                pageIndicatorDots
                progressSummary(compact: isCompactWidth(width))
            }
            teleprompterGrid(compact: isCompactWidth(width), maxTextWidth: width - 32)
            if !controlsHidden && !fullImmersion {
                sliderCard()
                statusCard(compact: isCompactWidth(width))
                nextPagePreview(compact: isCompactWidth(width))
                bottomControls(compact: isCompactWidth(width))
            }
        }
        .padding(.horizontal, horizontalPadding(for: width))
        .padding(.vertical, 18)
    }

    private func wideLayout(width: CGFloat, proxy: ScrollViewProxy) -> some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(spacing: 16) {
                if !fullImmersion {
                    topBar(compact: false)
                    thinProgressBar
                    pageIndicatorDots
                }
                teleprompterGrid(compact: false, maxTextWidth: min(width * 0.58, 760))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            VStack(spacing: 16) {
                if !fullImmersion {
                    progressSummary(compact: false)
                }
                if !controlsHidden && !fullImmersion {
                    sliderCard()
                    statusCard(compact: false)
                    nextPagePreview(compact: false)
                    bottomControls(compact: false)
                }
            }
            .frame(width: min(max(300, width * 0.28), 360), alignment: .top)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .frame(maxWidth: 1280, maxHeight: .infinity, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func topBar(compact: Bool) -> some View {
        if compact || horizontalSizeClass == .compact {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    closeButton
                    titleBlock(compact: compact)
                    Spacer(minLength: 0)
                    modeLabel
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        speedSizeLabel
                        timeLabel
                        Spacer(minLength: 0)
                        jumpToStartButton
                        jumpToEndButton
                        jumpToPageButton
                        bookmarkButton
                        bookmarkJumpButton
                    }
                }
            }
        } else {
            HStack(spacing: 12) {
                closeButton
                titleBlock(compact: compact)
                Spacer(minLength: 0)
                speedSizeLabel
                timeLabel
                jumpToStartButton
                jumpToEndButton
                jumpToPageButton
                bookmarkButton
                bookmarkJumpButton
                modeLabel
            }
        }
    }

    private var closeButton: some View {
        Button {
            model.stopReading()
        } label: {
            Image(systemName: "xmark")
                .font(.headline.weight(.semibold))
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func titleBlock(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.currentDocumentDisplayName)
                .font(compact ? .footnote.weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text("Page \(model.document.currentPageIndex + 1) of \(model.document.pages.count)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    private var speedSizeLabel: some View {
        Text("\(Int(model.scrollSpeedWordsPerSecond))w/s · \(Int(model.readerFontSize))pt")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.white.opacity(0.55))
            .padding(.trailing, 4)
    }

    private var timeLabel: some View {
        Group {
            if !currentTimeString.isEmpty {
                Text(currentTimeString)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.trailing, 4)
            }
        }
    }

    private var jumpToStartButton: some View {
        Button {
            model.jumpToWord(index: 0)
        } label: {
            Image(systemName: "arrow.up.to.line.compact")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.home, modifiers: [])
    }

    private var jumpToEndButton: some View {
        Button {
            model.jumpToEnd()
        } label: {
            Image(systemName: "arrow.down.to.line.compact")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.end, modifiers: [])
    }

    private var jumpToPageButton: some View {
        Button {
            showingJumpToPage = true
        } label: {
            Image(systemName: "number")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var bookmarkButton: some View {
        Button {
            model.setBookmark()
        } label: {
            Image(systemName: "bookmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var bookmarkJumpButton: some View {
        Button {
            model.jumpToBookmark()
        } label: {
            Image(systemName: model.hasBookmark() ? "bookmark.fill" : "bookmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(model.hasBookmark() ? model.highlightColorPreset.tint : .white)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(!model.hasBookmark())
    }

    private var modeLabel: some View {
        Label(model.session.mode.label, systemImage: modeSymbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(model.highlightColorPreset.softBackground)
            .foregroundStyle(model.highlightColorPreset.tint)
            .clipShape(Capsule())
    }

    private var pageIndicatorDots: some View {
        Group {
            if model.document.pages.count > 1 {
                HStack(spacing: 5) {
                    ForEach(0..<model.document.pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == model.document.currentPageIndex ? model.highlightColorPreset.tint : Color.white.opacity(0.2))
                            .frame(width: index == model.document.currentPageIndex ? 8 : 6, height: index == model.document.currentPageIndex ? 8 : 6)
                            .animation(.easeInOut(duration: 0.2), value: model.document.currentPageIndex)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
            }
        }
    }

    private var thinProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 3)
                Rectangle()
                    .fill(model.highlightColorPreset.tint)
                    .frame(width: geo.size.width * CGFloat(model.progressRatio), height: 3)
            }
        }
        .frame(height: 3)
        .clipShape(RoundedRectangle(cornerRadius: 1.5))
    }

    private func progressSummary(compact: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 120 : 140), spacing: 10)], spacing: 10) {
            summaryCapsule(title: "Progress", value: "\(Int(model.progressRatio * 100))%")
            summaryCapsule(title: "Word", value: "\(min(model.currentWordIndex + 1, max(model.currentWords.count, 1))) / \(max(model.currentWords.count, 1))")
            summaryCapsule(title: "Time", value: model.elapsedReadingTimeFormatted)
            summaryCapsule(title: "Page", value: "\(model.document.currentPageIndex + 1) / \(model.document.pages.count)")
        }
    }

    private func teleprompterGrid(compact: Bool, maxTextWidth: CGFloat) -> some View {
        ZStack {
            ScrollView {
                FlowLayout(
                    horizontalSpacing: compact ? 8 : 10,
                    verticalSpacing: CGFloat((compact ? 10 : 12) * model.readerLineSpacing),
                    maxWidth: maxTextWidth
                ) {
                    ForEach(Array(model.currentWords.enumerated()), id: \.offset) { index, word in
                        WordButtonView(
                            word: word,
                            isCurrent: index == model.currentWordIndex,
                            isPast: index < model.currentWordIndex,
                            fontSize: model.readerFontSize,
                            fontDesign: model.readerFontFamily.fontDesign,
                            highlightTint: model.highlightColorPreset.tint,
                            softBackground: model.highlightColorPreset.softBackground,
                            compact: compact,
                            onTap: { model.jumpToWord(index: index) },
                            onSpeak: { model.speakWord(word) },
                            onLookup: {
                                selectedWordForLookup = word
                                showPhoneticTooltip = true
                            },
                            phoneticEnabled: model.phoneticTooltipEnabled
                        )
                        .id(index)
                    }
                }
                .frame(maxWidth: maxTextWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(14)
            }
            .scaleEffect(x: model.mirrorModeEnabled ? -1 : 1, y: 1)

            VStack(spacing: 0) {
                topFadeGradient
                Spacer()
                bottomFadeGradient
            }
            .allowsHitTesting(false)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    quickSettingsOverlay
                }
            }
            .padding(16)

            if model.reachedEndOfScript {
                endOfScriptOverlay
            }

            if let toast = pageTransitionToast {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                                .font(.caption2)
                            Text(toast)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        Spacer()
                    }
                    Spacer()
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }

            indicatorToast(
                icon: "gauge.with.dots.needle.67percent",
                text: speedIndicatorText
            )

            indicatorToast(
                icon: "textformat.size",
                text: fontSizeIndicatorText
            )
            .alert("Jump to Page", isPresented: $showingJumpToPage) {
                TextField("Page number", text: $jumpToPageText)
                    .keyboardType(.numberPad)
                Button("Go") {
                    if let page = Int(jumpToPageText), page >= 1, page <= model.document.pages.count {
                        model.jumpToPage(page - 1)
                    }
                    jumpToPageText = ""
                }
                Button("Cancel", role: .cancel) {
                    jumpToPageText = ""
                }
            } message: {
                Text("Enter a page number between 1 and \(model.document.pages.count)")
            }

            if showFullImmersionHint {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "hand.tap.fill")
                                .font(.caption2)
                            Text("Tap to exit full screen")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        Spacer()
                    }
                    Spacer()
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded { _ in
                    model.togglePause()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    dragOffset = 0
                    let horizontal = value.translation.width
                    let vertical = value.translation.height
                    guard abs(horizontal) > abs(vertical), abs(horizontal) > 50 else { return }
                    if horizontal < 0 {
                        model.goToNextPage()
                    } else {
                        model.goToPreviousPage()
                    }
                }
        )
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    let delta = value / lastMagnification
                    lastMagnification = value
                    let newSize = model.readerFontSize * Double(delta)
                    model.readerFontSize = max(24, min(64, newSize))
                }
                .onEnded { _ in
                    lastMagnification = 1.0
                }
        )
        .onTapGesture {
            if fullImmersion {
                withAnimation(.easeInOut(duration: 0.25)) {
                    fullImmersion = false
                }
                return
            }
            if showFullImmersionHint {
                withAnimation { showFullImmersionHint = false }
            }
            if controlsHidden {
                withAnimation(.easeInOut(duration: 0.25)) {
                    controlsHidden = false
                }
                startHideControlsTimer()
            }
        }
    }

    private var topFadeGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.05, blue: 0.07).opacity(0.85),
                Color(red: 0.04, green: 0.05, blue: 0.07).opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 24)
    }

    private var bottomFadeGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.05, blue: 0.07).opacity(0),
                Color(red: 0.04, green: 0.05, blue: 0.07).opacity(0.85)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 28)
    }

    private func sliderCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Timeline")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(model.session.mode == .wordTracking ? "Drag to reposition recognition" : "Tap a word or drag the slider")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }

            Slider(
                value: Binding(
                    get: {
                        switch model.session.mode {
                        case .wordTracking:
                            return Double(model.currentWordIndex)
                        case .classic, .voiceActivated:
                            return model.session.wordProgress
                        }
                    },
                    set: { newValue in
                        switch model.session.mode {
                        case .wordTracking:
                            model.jumpToWord(index: Int(newValue))
                        case .classic, .voiceActivated:
                            model.setWordProgress(newValue)
                        }
                    }
                ),
                in: 0...Double(max(model.currentWords.count, 1))
            )
            .tint(model.highlightColorPreset.tint)

            if !model.currentWords.isEmpty {
                let idx = model.currentWordIndex
                let start = max(0, idx - 2)
                let end = min(model.currentWords.count, idx + 3)
                let prefix = model.currentWords[start..<idx].joined(separator: " ")
                let current = model.currentWords[idx]
                let suffix = model.currentWords[(idx+1)..<end].joined(separator: " ")
                HStack(spacing: 4) {
                    if !prefix.isEmpty {
                        Text(prefix)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Text(current)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(model.highlightColorPreset.tint)
                    if !suffix.isEmpty {
                        Text(suffix)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func statusCard(compact: Bool) -> some View {
        ZStack {
            VStack(alignment: .leading, spacing: 14) {
                if compact {
                    VStack(alignment: .leading, spacing: 12) {
                        waveformView
                        statusTextBlock
                    }
                } else {
                    HStack(spacing: 12) {
                        waveformView
                        statusTextBlock
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 20))

            if model.session.isPaused {
                HStack(spacing: 6) {
                    Image(systemName: "pause.circle.fill")
                        .font(.title3.weight(.semibold))
                    Text("PAUSED")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.55))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }
        }
    }

    private var statusTextBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(model.session.mode == .classic ? "Classic playback" : (model.session.isListening ? "Microphone live" : "Microphone paused"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Page \(model.document.currentPageIndex + 1) of \(model.document.pages.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.52))
            }
            if let message = model.readerStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(statusDetailLine)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.52))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func nextPagePreview(compact: Bool) -> some View {
        Group {
            if let nextIndex = model.document.nextReadablePageIndex() {
                let preview = model.document.pagePreview(at: nextIndex, wordLimit: 6, characterLimit: 44)
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                    Text("Next: \(preview)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, compact ? 0 : 4)
            }
        }
    }

    private func bottomControls(compact: Bool) -> some View {
        Group {
            if compact {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    prevButton
                    pauseButton
                    micButton
                    nextButton
                }
            } else {
                HStack(spacing: 10) {
                    prevButton
                    pauseButton
                    micButton
                    nextButton
                }
            }
        }
    }

    private var prevButton: some View {
        controlButton(title: "Prev", systemName: "backward.fill", disabled: !model.document.hasPreviousPage) {
            model.goToPreviousPage()
        }
        .keyboardShortcut(.leftArrow, modifiers: [])
    }

    private var pauseButton: some View {
        controlButton(title: model.session.isPaused ? "Resume" : "Pause", systemName: model.session.isPaused ? "play.fill" : "pause.fill") {
            model.togglePause()
        }
        .keyboardShortcut(.space, modifiers: [])
    }

    private var micButton: some View {
        controlButton(title: model.session.mode == .classic ? "Mic" : (model.session.isListening ? "Mic On" : "Mic Off"), systemName: micIcon, disabled: model.session.mode == .classic) {
            model.toggleListening()
        }
    }

    private var nextButton: some View {
        controlButton(title: "Next", systemName: "forward.fill", disabled: !model.document.hasNextPage) {
            model.goToNextPage()
        }
        .keyboardShortcut(.rightArrow, modifiers: [])
    }

    private var modeSymbol: String {
        switch model.session.mode {
        case .classic: return "text.line.first.and.arrowtriangle.forward"
        case .voiceActivated: return "waveform"
        case .wordTracking: return "mic.badge.checkmark"
        }
    }

    private var micIcon: String {
        switch model.session.mode {
        case .classic:
            return "mic.slash"
        case .voiceActivated, .wordTracking:
            return model.session.isListening ? "mic.fill" : "mic.slash.fill"
        }
    }

    private var statusDetailLine: String {
        switch model.session.mode {
        case .classic:
            return "word \(min(model.currentWordIndex + 1, max(model.currentWords.count, 1))) / \(max(model.currentWords.count, 1)) · remaining \(model.estimatedTimeRemaining)"
        case .voiceActivated:
            let level = String(format: "%.3f", model.audioMonitor.averageLevel)
            return "word \(min(model.currentWordIndex + 1, max(model.currentWords.count, 1))) / \(max(model.currentWords.count, 1)) · audio \(level) · remaining \(model.estimatedTimeRemaining)"
        case .wordTracking:
            return "chars \(model.session.recognizedCharCount) / \(max(model.currentCollapsedText.count, 1)) · locale \(model.speechLocale.label) · remaining \(model.estimatedTimeRemaining)"
        }
    }

    private var waveformView: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(model.session.audioLevels.enumerated()), id: \.offset) { index, level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(waveformColor.opacity(index.isMultiple(of: 2) ? 0.95 : 0.72))
                    .frame(width: 4, height: max(6, level * 34))
            }
        }
        .frame(width: 120, height: 38, alignment: .leading)
    }

    private func showPageTransitionToast(_ text: String) {
        pageTransitionTimer?.invalidate()
        pageTransitionToast = text
        pageTransitionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                pageTransitionToast = nil
            }
        }
    }

    private func showSpeedIndicator(_ text: String) {
        speedIndicatorTimer?.invalidate()
        speedIndicatorText = text
        speedIndicatorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                speedIndicatorText = nil
            }
        }
    }

    private func showFontSizeIndicator(_ text: String) {
        fontSizeIndicatorTimer?.invalidate()
        fontSizeIndicatorText = text
        fontSizeIndicatorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                fontSizeIndicatorText = nil
            }
        }
    }

    private func startHideControlsTimer() {
        hideControlsTimer?.invalidate()
        hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.35)) {
                controlsHidden = true
            }
        }
    }

    private var endOfScriptOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(model.highlightColorPreset.tint)
            Text("Script Complete")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text("You have reached the end of the script.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
            Button {
                model.stopReading()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left")
                    Text("Back to Editor")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(model.highlightColorPreset.tint)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(28)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var quickSettingsOverlay: some View {
        VStack {
            if showQuickSettings {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Speed: \(String(format: "%.1f", model.scrollSpeedWordsPerSecond)) w/s")
                                    .font(.caption.weight(.semibold))
                                Spacer()
                                HStack(spacing: 0) {
                                    Button {
                                        model.scrollSpeedWordsPerSecond = max(0.5, model.scrollSpeedWordsPerSecond - 0.1)
                                    } label: {
                                        Image(systemName: "minus")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 28, height: 28)
                                            .background(Color.white.opacity(0.12))
                                    }
                                    .buttonStyle(.plain)
                                    Button {
                                        model.scrollSpeedWordsPerSecond = min(6.0, model.scrollSpeedWordsPerSecond + 0.1)
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 28, height: 28)
                                            .background(Color.white.opacity(0.12))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            Slider(value: $model.scrollSpeedWordsPerSecond, in: 0.5...6.0, step: 0.1)
                                .tint(model.highlightColorPreset.tint)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Size: \(Int(model.readerFontSize)) pt")
                                .font(.caption.weight(.semibold))
                            Slider(value: $model.readerFontSize, in: 24...64, step: 1)
                                .tint(model.highlightColorPreset.tint)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Spacing: \(String(format: "%.1f", model.readerLineSpacing))x")
                                .font(.caption.weight(.semibold))
                            Slider(value: $model.readerLineSpacing, in: 0.8...2.5, step: 0.1)
                                .tint(model.highlightColorPreset.tint)
                        }
                        HStack {
                            Text("Mirror mode")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Toggle("", isOn: $model.mirrorModeEnabled)
                                .toggleStyle(.switch)
                                .scaleEffect(0.8)
                        }
                        Button {
                            withAnimation(.spring()) {
                                if fullImmersion {
                                    fullImmersion = false
                                    showQuickSettings = false
                                } else {
                                    fullImmersion = true
                                    if !hasShownFullImmersionHint {
                                        showFullImmersionHint = true
                                        hasShownFullImmersionHint = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                            withAnimation { showFullImmersionHint = false }
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: fullImmersion ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                Text(fullImmersion ? "Exit Full Screen" : "Full Screen")
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(fullImmersion ? model.highlightColorPreset.tint.opacity(0.25) : Color.white.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        Button {
                            showingPractice = true
                            withAnimation(.spring()) { showQuickSettings = false }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "mic")
                                Text("Practice")
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        Button {
                            withAnimation(.spring()) { showQuickSettings = false }
                        } label: {
                            Text("Done")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(model.highlightColorPreset.tint)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(14)
                }
                .frame(maxHeight: min(520, UIScreen.main.bounds.height * 0.65))
                .frame(width: 220)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .transition(.scale.combined(with: .opacity))
            } else {
                Button {
                    withAnimation(.spring()) { showQuickSettings = true }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var waveformColor: Color {
        if model.session.mode == .classic {
            return .white.opacity(0.35)
        }
        if model.session.mode == .voiceActivated {
            return model.audioMonitor.isSpeaking ? model.highlightColorPreset.tint : .white.opacity(0.4)
        }
        return model.session.isListening ? model.highlightColorPreset.tint : .white.opacity(0.35)
    }

    private func summaryCapsule(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func indicatorToast(icon: String, text: String?) -> some View {
        if let text = text {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.caption2)
                        Text(text)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    Spacer()
                }
                Spacer()
            }
            .transition(.opacity)
            .allowsHitTesting(false)
        }
    }

    private func controlButton(title: String, systemName: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.title3.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(disabled ? Color.white.opacity(0.04) : Color.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .scaleEffect(1.0)
            .pressEffect()
        }
        .disabled(disabled)
        .buttonStyle(.plain)
        .opacity(disabled ? 0.42 : 1)
    }

    private struct WordButtonView: View {
        let word: String
        let isCurrent: Bool
        let isPast: Bool
        let fontSize: Double
        let fontDesign: Font.Design?
        let highlightTint: Color
        let softBackground: Color
        let compact: Bool
        let onTap: () -> Void
        let onSpeak: () -> Void
        let onLookup: () -> Void
        let phoneticEnabled: Bool

        @State private var isPressed = false

        var body: some View {
            Button(action: {
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isPressed = false
                }
                onTap()
            }) {
                Text(word)
                    .font(.system(size: fontSize, weight: isCurrent ? .bold : .semibold, design: fontDesign))
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, compact ? 8 : 10)
                    .padding(.vertical, compact ? 7 : 8)
                    .background(backgroundColor)
                    .foregroundStyle(foregroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .scaleEffect(isPressed ? 1.15 : 1.0)
                    .animation(.easeOut(duration: 0.15), value: isPressed)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(action: onSpeak) {
                    Label("Speak", systemImage: "speaker.wave.2")
                }
                if phoneticEnabled {
                    Button(action: onLookup) {
                        Label("Lookup", systemImage: "text.magnifyingglass")
                    }
                }
            }
        }

        private var backgroundColor: Color {
            if isPast { return .white.opacity(0.08) }
            if isCurrent { return softBackground }
            return .clear
        }

        private var foregroundColor: Color {
            if isPast { return .white.opacity(0.42) }
            if isCurrent { return highlightTint }
            return .white
        }
    }

    private func teleprompterColumns(for width: CGFloat) -> [GridItem] {
        let minimum = width > 760 ? 120 : (width < 390 ? 58 : 72)
        return [GridItem(.adaptive(minimum: CGFloat(minimum)), spacing: width < 390 ? 8 : 10)]
    }

    private func prefersWideLayout(for width: CGFloat) -> Bool {
        width >= 940 || (horizontalSizeClass == .regular && width >= 820)
    }

    private func isCompactWidth(_ width: CGFloat) -> Bool {
        width < 390
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        if width < 390 { return 12 }
        return 16
    }
}

private struct PressEffect: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

private extension View {
    func pressEffect() -> some View {
        modifier(PressEffect())
    }
}

private struct ShakeDetector: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ShakeDetectingViewController {
        ShakeDetectingViewController()
    }
    func updateUIViewController(_ uiViewController: ShakeDetectingViewController, context: Context) {}
}

private class ShakeDetectingViewController: UIViewController {
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

#Preview {
    IOSReaderView(model: IOSTeleprompterModel())
}
