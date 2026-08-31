//
//  GlassTheme.swift
//  meal-planner-ios
//

import SwiftUI
import UIKit

private final class WindowSizeView: UIView {
    var onSizeChange: ((CGSize) -> Void)?

    private var lastReportedSize = CGSize.zero

    override func didMoveToWindow() {
        super.didMoveToWindow()
        reportSizeIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        reportSizeIfNeeded()
    }

    private func reportSizeIfNeeded() {
        guard let size = window?.bounds.size, size != lastReportedSize else { return }
        lastReportedSize = size
        onSizeChange?(size)
    }
}

private struct WindowSizeReader: UIViewRepresentable {
    @Binding var size: CGSize

    func makeUIView(context: Context) -> WindowSizeView {
        let view = WindowSizeView()
        view.isUserInteractionEnabled = false
        configure(view)
        return view
    }

    func updateUIView(_ view: WindowSizeView, context: Context) {
        configure(view)
    }

    private func configure(_ view: WindowSizeView) {
        view.onSizeChange = { newSize in
            guard size != newSize else { return }
            DispatchQueue.main.async {
                size = newSize
            }
        }
    }
}

struct AppGlassBackground<Content: View>: View {
    @State private var windowSize = CGSize.zero

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                GeometryReader { geometry in
                    let frame = geometry.frame(in: .global)
                    let backgroundSize = windowSize == .zero ? geometry.size : windowSize

                    ZStack {
                        GlazedImage(named: "Background")
                            .frame(width: backgroundSize.width, height: backgroundSize.height)
                            .offset(x: -frame.minX, y: -frame.minY)

                        WindowSizeReader(size: $windowSize)
                    }
                }
                .clipped()
                .ignoresSafeArea()
            }
            .scrollContentBackground(.hidden)
    }
}

private struct GlassBackground<BackgroundShape: Shape>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let shape: BackgroundShape

    var body: some View {
        if reduceTransparency {
            shape.fill(Color(uiColor: .secondarySystemBackground))
        } else {
            shape.fill(.thinMaterial)
        }
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
    }
}

private struct GlassSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let cornerRadius: CGFloat
    let material: Material

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                if reduceTransparency {
                    shape.fill(Color(uiColor: .secondarySystemBackground))
                } else {
                    shape.fill(material)
                }
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

extension View {
    func glassSurface(
        cornerRadius: CGFloat = 15,
        material: Material = .thinMaterial
    ) -> some View {
        modifier(GlassSurfaceModifier(cornerRadius: cornerRadius, material: material))
    }

    func glassPanel(cornerRadius: CGFloat = 15) -> some View {
        glassSurface(cornerRadius: cornerRadius, material: .thinMaterial)
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
