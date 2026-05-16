import SwiftUI

struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 10
    var maxWidth: CGFloat = .infinity

    struct Cache {
        var sizes: [CGSize] = []
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache(sizes: subviews.map { $0.sizeThatFits(.unspecified) })
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        guard cache.sizes.count != subviews.count else { return }
        cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let effectiveWidth = min(proposal.width ?? maxWidth, maxWidth)
        guard effectiveWidth > 0, !subviews.isEmpty else { return .zero }

        let sizes = cache.sizes
        guard sizes.count == subviews.count else {
            // Fallback if cache is somehow out of sync
            cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
            return sizeThatFits(proposal: proposal, subviews: subviews, cache: &cache)
        }

        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for size in sizes {
            if x + size.width > effectiveWidth, x > 0 {
                x = 0
                y += lineHeight + verticalSpacing
                lineHeight = 0
            }
            x += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: effectiveWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let effectiveWidth = min(bounds.width, maxWidth)
        guard effectiveWidth > 0, !subviews.isEmpty else { return }

        let sizes = cache.sizes
        guard sizes.count == subviews.count else {
            cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
            placeSubviews(in: bounds, proposal: proposal, subviews: subviews, cache: &cache)
            return
        }

        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = sizes[index]
            if x + size.width > effectiveWidth, x > 0 {
                x = 0
                y += lineHeight + verticalSpacing
                lineHeight = 0
            }
            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                proposal: .unspecified
            )
            x += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
