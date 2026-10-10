import SwiftUI
import UIKit

/// Scrolls the form directly because component targets share one native form row.
@MainActor
final class MealComponentScrollController {
    private weak var scrollView: UIScrollView?

    fileprivate func connect(to scrollView: UIScrollView) {
        self.scrollView = scrollView
    }

    func scroll(by distance: CGFloat) {
        guard let scrollView, distance.isFinite, scrollView.bounds.height > 0 else { return }
        let insets = scrollView.adjustedContentInset
        let minimum = -insets.top
        let maximum = max(minimum, scrollView.contentSize.height - scrollView.bounds.height + insets.bottom)
        let offset = min(maximum, max(minimum, scrollView.contentOffset.y + distance))
        guard offset != scrollView.contentOffset.y else { return }
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: offset), animated: false)
    }
}

/// Place inside a form row so the nearest scroll ancestor is the form's scroll view.
struct MealComponentScrollProbe: UIViewRepresentable {
    let controller: MealComponentScrollController

    func makeUIView(context: Context) -> UIView {
        let view = ScrollAncestorView()
        view.controller = controller
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let view = uiView as? ScrollAncestorView else { return }
        view.controller = controller
        view.resolveScrollView()
    }
}

private final class ScrollAncestorView: UIView {
    weak var controller: MealComponentScrollController?

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        resolveScrollView()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        resolveScrollView()
    }

    func resolveScrollView() {
        connectToAncestor()
        Task { @MainActor [weak self] in
            self?.connectToAncestor()
        }
    }

    private func connectToAncestor() {
        var ancestor = superview
        while let view = ancestor {
            if let scrollView = view as? UIScrollView {
                controller?.connect(to: scrollView)
                return
            }
            ancestor = view.superview
        }
    }
}
