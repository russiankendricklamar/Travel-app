import SwiftUI

/// Позиции bottom sheet (как в Apple Maps)
enum SheetDetent: Equatable {
    case peek       // 56pt — drag handle + search bar visible
    case half       // 40% экрана — результаты поиска / краткая инфо
    case full       // весь экран — полная детализация

    func height(in screenHeight: CGFloat) -> CGFloat {
        switch self {
        case .peek: return 56
        case .half: return screenHeight * 0.40
        case .full: return screenHeight
        }
    }

    static func nearest(to offset: CGFloat, in screenHeight: CGFloat) -> SheetDetent {
        let heights: [(SheetDetent, CGFloat)] = [
            (.peek, SheetDetent.peek.height(in: screenHeight)),
            (.half, SheetDetent.half.height(in: screenHeight)),
            (.full, SheetDetent.full.height(in: screenHeight)),
        ]
        return heights.min(by: { abs($0.1 - offset) < abs($1.1 - offset) })!.0
    }
}

/// Always-present draggable bottom sheet в стиле Apple Maps
struct MapBottomSheet<Content: View>: View {
    @Binding var detent: SheetDetent
    @ViewBuilder var content: () -> Content

    @State private var dragOffset: CGFloat = 0
    @State private var screenHeight: CGFloat = 0
    @State private var safeAreaTop: CGFloat = 0

    var body: some View {
        let isPeek = detent == .peek
        let sheetHeight = detent.height(in: screenHeight) + dragOffset

        ZStack(alignment: .bottom) {
            // Zero-height geometry sensor — does not participate in layout
            Color.clear
                .frame(height: 0)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newHeight in
                    screenHeight = newHeight
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.safeAreaInsets.top
                } action: { newTop in
                    safeAreaTop = newTop
                }

            VStack(spacing: 0) {
                // MARK: Drag handle — visible in ALL states
                Capsule()
                    .fill(Color(.systemFill))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    // In half/full: drag gesture on handle only
                    .gesture(isPeek ? nil : dragGesture(totalHeight: screenHeight))
                    .accessibilityLabel("Переместить панель")
                    .accessibilityHint("Потяните вверх или вниз для изменения размера")

                content()
                    .frame(maxWidth: .infinity, alignment: .top)
                    // In peek mode: drag gesture on entire content area
                    .gesture(isPeek ? dragGesture(totalHeight: screenHeight) : nil)

                Spacer(minLength: 0)
            }
            .frame(height: max(sheetHeight, 60), alignment: .top)
            .frame(maxWidth: .infinity)
            // Pad content below status bar in full mode
            .padding(.top, detent == .full ? safeAreaTop : 0)
            // Floating horizontal margins in peek, full width in half/full
            .padding(.horizontal, isPeek ? 16 : 0)
            // Bottom gap in peek: 8pt above safe area / tab bar
            .padding(.bottom, isPeek ? 8 : 0)
            .background {
                let progress = dragProgress(in: screenHeight)
                ZStack {
                    // Peek background (blur pill) — fades OUT as sheet rises
                    UnevenRoundedRectangle(
                        topLeadingRadius: 22, bottomLeadingRadius: 22,
                        bottomTrailingRadius: 22, topTrailingRadius: 22, style: .continuous
                    )
                    .fill(.ultraThinMaterial)
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 22, bottomLeadingRadius: 22,
                            bottomTrailingRadius: 22, topTrailingRadius: 22, style: .continuous
                        )
                        .fill(Color.black.opacity(0.35))
                    )
                    .environment(\.colorScheme, .dark)
                    .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 4)
                    .opacity(1 - progress)

                    // Expanded background (opaque) — fades IN as sheet rises
                    // Bottom corners interpolate: 22pt → 0pt when fully expanded
                    UnevenRoundedRectangle(
                        topLeadingRadius: 22,
                        bottomLeadingRadius: 22 * (1 - progress),
                        bottomTrailingRadius: 22 * (1 - progress),
                        topTrailingRadius: 22,
                        style: .continuous
                    )
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: .black.opacity(0.15), radius: 10, y: -5)
                    .ignoresSafeArea(edges: detent == .full ? [.bottom, .top] : .bottom)
                    .opacity(progress)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: detent)
            .accessibilityElement(children: .contain)
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Drag Progress

    private func dragProgress(in screenHeight: CGFloat) -> CGFloat {
        guard screenHeight > 0 else { return detent == .peek ? 0 : 1 }
        let peekH = SheetDetent.peek.height(in: screenHeight)
        let halfH = SheetDetent.half.height(in: screenHeight)
        let currentH = detent.height(in: screenHeight) + dragOffset
        return max(0, min(1, (currentH - peekH) / (halfH - peekH)))
    }

    // MARK: - Drag Gesture

    private func dragGesture(totalHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .onChanged { value in
                dragOffset = -value.translation.height
            }
            .onEnded { value in
                let currentHeight = detent.height(in: totalHeight) + dragOffset
                let velocity = -value.predictedEndTranslation.height / totalHeight

                let targetHeight: CGFloat
                if abs(velocity) > 0.3 {
                    if velocity > 0 {
                        targetHeight = currentHeight + totalHeight * 0.2
                    } else {
                        targetHeight = currentHeight - totalHeight * 0.2
                    }
                } else {
                    targetHeight = currentHeight
                }

                let nearest = SheetDetent.nearest(to: targetHeight, in: totalHeight)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    detent = nearest
                    dragOffset = 0
                }
            }
    }
}
