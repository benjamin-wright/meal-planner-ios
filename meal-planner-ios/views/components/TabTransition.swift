import SwiftUI
import UIKit

/// Install inside tab content so the native tab controller is an ancestor.
struct TabTransitionConfigurator: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        TabTransitionInstaller()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private final class TabTransitionInstaller: UIViewController {
    // UITabBarController holds its delegate weakly.
    private var transitionDelegate: SlidingTabDelegate?

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        installTransition()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        installTransition()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        installTransition()
    }

    private func installTransition() {
        guard let controller = tabBarController,
              !(controller.delegate is SlidingTabDelegate) else { return }

        let delegate = SlidingTabDelegate(forwardingTo: controller.delegate)
        transitionDelegate = delegate
        controller.delegate = delegate
    }
}

/// Preserve SwiftUI's selection and other delegate handling, replacing only
/// the animation. Replacing the delegate outright would break tab selection.
private final class SlidingTabDelegate: NSObject, UITabBarControllerDelegate {
    private weak var originalDelegate: UITabBarControllerDelegate?

    init(forwardingTo delegate: UITabBarControllerDelegate?) {
        originalDelegate = delegate
        super.init()
    }

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || (originalDelegate?.responds(to: selector) ?? false)
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        if originalDelegate?.responds(to: selector) == true {
            return originalDelegate
        }
        return super.forwardingTarget(for: selector)
    }

    func tabBarController(
        _ tabBarController: UITabBarController,
        animationControllerForTransitionFrom fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        let controllers = tabBarController.viewControllers ?? []
        let fromIndex = controllers.firstIndex(of: fromVC) ?? 0
        let toIndex = controllers.firstIndex(of: toVC) ?? 0
        let isRightToLeft = tabBarController.view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let direction: CGFloat = (toIndex > fromIndex ? 1 : -1) * (isRightToLeft ? -1 : 1)
        return SlidingTabAnimator(direction: direction)
    }
}

private final class SlidingTabAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private let direction: CGFloat
    private let duration: TimeInterval

    init(direction: CGFloat) {
        self.direction = direction
        duration = UIAccessibility.isReduceMotionEnabled ? 0 : 0.25
        super.init()
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        duration
    }

    func animateTransition(using context: UIViewControllerContextTransitioning) {
        guard let fromView = context.view(forKey: .from),
              let toView = context.view(forKey: .to),
              let toController = context.viewController(forKey: .to) else {
            context.completeTransition(false)
            return
        }

        let container = context.containerView
        let wasClipped = container.clipsToBounds
        let fromTransform = fromView.transform
        let toTransform = toView.transform
        let distance = container.bounds.width * direction

        toView.frame = context.finalFrame(for: toController)
        container.addSubview(toView)
        toView.layoutIfNeeded()
        container.clipsToBounds = true

        let complete: (Bool) -> Void = { _ in
            let cancelled = context.transitionWasCancelled
            fromView.transform = fromTransform
            toView.transform = toTransform
            container.clipsToBounds = wasClipped
            if cancelled {
                toView.removeFromSuperview()
            }
            context.completeTransition(!cancelled)
        }

        guard duration > 0 else {
            complete(true)
            return
        }

        // Adjacent pages move together rather than fading on top of one another.
        toView.transform = toTransform.translatedBy(x: distance, y: 0)
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveEaseInOut],
            animations: {
                fromView.transform = fromTransform.translatedBy(x: -distance, y: 0)
                toView.transform = toTransform
            },
            completion: complete
        )
    }
}