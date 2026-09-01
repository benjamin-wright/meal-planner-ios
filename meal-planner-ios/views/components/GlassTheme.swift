//
//  GlassTheme.swift
//  meal-planner-ios
//

import SwiftUI
import UIKit

/// The shared "wallpaper" background image.
///
/// `GlazedImage` uses `.aspectRatio(contentMode: .fill)`, which reports an
/// ideal size *larger* than the space offered. Rendering it directly inside a
/// `ZStack` would therefore inflate that stack (pushing sibling content
/// off-screen), so it's anchored to a `Color.clear` that accepts the proposed
/// size, with the image drawn as a clipped overlay. This keeps the background
/// purely decorative and out of the layout calculation.
struct AppGlassBackground: View {
    var body: some View {
        Color.clear
            .overlay {
                GlazedImage(named: "Background")
            }
            .clipped()
            .ignoresSafeArea()
    }
}

/// Makes the tab bar and navigation bar chrome transparent so the shared
/// background shows through them. `toolbarBackground(.hidden, for: .tabBar)`
/// is unreliable here, and there is no public SwiftUI API to clear the
/// backing views on iOS (`.tabView`/`.window` container background placements
/// are watchOS/macOS-only), so this configures `UIAppearance` directly.
enum GlassChrome {
    static func configure() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = .clear
        tabBarAppearance.backgroundEffect = nil
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithTransparentBackground()
        navigationBarAppearance.backgroundColor = .clear
        navigationBarAppearance.backgroundEffect = nil
        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
    }
}

/// Walks the UIKit hierarchy above this view and clears the opaque
/// `backgroundColor` that SwiftUI's hosting views, `UINavigationController`
/// and `UITabBarController` paint by default. There is no public SwiftUI API
/// to do this on iOS (`.tabView`/`.window` container background placements are
/// watchOS/macOS-only, and `toolbarBackground(.hidden:)` doesn't affect the
/// container behind the floating tab bar). Attach once near the root of
/// content hosted inside those containers via `.background`.
struct TransparentContainerConfigurator: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        TransparencyConfiguratorViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private final class TransparencyConfiguratorViewController: UIViewController {
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        clearAncestorBackgrounds()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        clearAncestorBackgrounds()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        clearAncestorBackgrounds()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        clearAncestorBackgrounds()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        clearAncestorBackgrounds()
    }

    private func clearAncestorBackgrounds() {
        // Clear every ancestor view controller's root view. This catches the
        // intermediate SwiftUI hosting controllers as well as the navigation
        // and tab bar controllers.
        var controller: UIViewController? = self
        while let current = controller {
            if current.isViewLoaded {
                current.view.backgroundColor = .clear
            }
            controller = current.parent
        }

        // Also clear any opaque superviews up to the window - the strip behind
        // the floating tab bar is painted by an internal container view that
        // isn't a view controller's root view.
        var view: UIView? = self.view
        while let current = view, !(current is UIWindow) {
            if current.backgroundColor != nil, current.backgroundColor != .clear {
                current.backgroundColor = .clear
            }
            current.isOpaque = false
            view = current.superview
        }
    }
}

/// A plain, tinted translucent color used in place of `Material`
/// (`.thinMaterial` etc.). System `Material`s are backed by
/// `UIVisualEffectView`, which needs to live-capture whatever's behind it and
/// visibly "warms up" over a render pass or two whenever its host view is
/// hidden/shown again (e.g. on tab reselection) - showing up as glass panels
/// popping in a beat after their surrounding content. A flat, alpha-blended
/// color has no backdrop to capture, so it appears instantly every time.
private func glassTintColor(reduceTransparency: Bool, colorScheme: ColorScheme) -> Color {
    if reduceTransparency {
        return Color(uiColor: .secondarySystemBackground)
    }
    return colorScheme == .dark ? Color.black.opacity(0.80) : Color.white.opacity(0.35)
}

private struct GlassBackground<BackgroundShape: Shape>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    let shape: BackgroundShape

    var body: some View {
        shape.fill(glassTintColor(reduceTransparency: reduceTransparency, colorScheme: colorScheme))
    }
}

struct GlassList<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        List {
            Group {
                content
            }
            .listRowBackground(GlassBackground(shape: Rectangle()))
        }
        .scrollContentBackground(.hidden)
    }
}

struct GlassForm<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Form {
            Group {
                content
            }
            .listRowBackground(GlassBackground(shape: Rectangle()))
        }
        .scrollContentBackground(.hidden)
    }
}

private struct GlassSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                shape.fill(glassTintColor(reduceTransparency: reduceTransparency, colorScheme: colorScheme))
            }
            .overlay {
                shape.stroke(.primary.opacity(0.08), lineWidth: 0.5)
            }
    }
}

private struct GlassControlModifier<ControlShape: Shape>: ViewModifier {
    let shape: ControlShape

    func body(content: Content) -> some View {
        content
            .background {
                GlassBackground(shape: shape)
            }
    }
}

/// A plain top-level `Section` header rendered as a small chip on its own
/// glass panel. The system's default small/uppercase `.secondary` header
/// text has poor contrast when it sits directly over `AppGlassBackground`'s
/// photo (once `scrollContentBackground(.hidden)` exposes it), so this gives
/// the header its own `glassSurface` backdrop to stay legible regardless of
/// what's behind it.
struct GlassSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .glassSurface(cornerRadius: 8)
            .textCase(nil)
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat = 15) -> some View {
        modifier(GlassSurfaceModifier(cornerRadius: cornerRadius))
    }

    func glassPanel(cornerRadius: CGFloat = 15) -> some View {
        glassSurface(cornerRadius: cornerRadius)
    }

    func glassControl(cornerRadius: CGFloat = 8) -> some View {
        glassControl(in: RoundedRectangle(
            cornerRadius: cornerRadius,
            style: .continuous
        ))
    }

    func glassControl<ControlShape: Shape>(in shape: ControlShape) -> some View {
        modifier(GlassControlModifier(shape: shape))
    }
}
