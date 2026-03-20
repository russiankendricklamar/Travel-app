import SwiftUI

/// Позиции bottom sheet (как в Apple Maps)
enum SheetDetent: Equatable {
    case peek       // ~120pt — search bar + category chips visible (Apple Maps style)
    case half       // 47% экрана — результаты поиска / краткая инфо
    case full       // весь экран — полная детализация

    func height(in screenHeight: CGFloat) -> CGFloat {
        switch self {
        case .peek: return 120
        case .half: return screenHeight * 0.47
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

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            let availableHeight = geo.size.height
            let sheetHeight = detent.height(in: availableHeight) + dragOffset
            let safeAreaTop = geo.safeAreaInsets.top

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 0) {
                    // Drag handle — always captures drag, above scroll
                    Capsule()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 60, height: 5)
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .gesture(dragGesture(totalHeight: availableHeight))

                    content()
                        .frame(maxWidth: .infinity, alignment: .top)
                    Spacer(minLength: 0)
                }
                .frame(height: max(sheetHeight, 60), alignment: .top)
                .frame(maxWidth: .infinity)
                .padding(.top, detent == .full ? safeAreaTop : 0)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 30,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 30
                    )
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 10, y: -5)
                    .ignoresSafeArea(edges: .bottom)
                )
            }
            .onAppear { screenHeight = availableHeight }
            .onChange(of: geo.size) { _, newSize in
                screenHeight = newSize.height
            }
        }
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
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    detent = nearest
                    dragOffset = 0
                }
            }
    }
}
