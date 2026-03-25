import SwiftUI

/// Shared pill style constants — single source of truth.
/// Change these and it updates quote, peek, and body-reminder pills.
enum ZenPillStyle {
    static let cornerRadius: CGFloat = 14
    static let pillHeight: CGFloat = 56
    static let textFont: Font = .system(size: 13, weight: .light, design: .serif)
    static let textColor: Color = .black.opacity(0.5)
}

/// Shared frosted-glass pill used by quote, peek, and body-reminder surfaces.
struct ZenPillView<Content: View>: View {
    let isVisible: Bool
    let pillScale: CGFloat
    let shadowOpacity: CGFloat
    let lineProgress: CGFloat
    let lineVisible: Bool
    let showShimmer: Bool
    @ViewBuilder let content: () -> Content

    private let cr = ZenPillStyle.cornerRadius

    @State private var shimmerAngle: Angle = .zero

    // Black/silver spark gradient — startAngle shifts to animate
    private func sparkGradient(angle: Angle) -> AngularGradient {
        AngularGradient(
            stops: [
                .init(color: .black.opacity(0.06), location: 0.0),
                .init(color: .black.opacity(0.06), location: 0.6),
                .init(color: .black.opacity(0.2), location: 0.7),
                .init(color: .white.opacity(0.65), location: 0.78),
                .init(color: .black.opacity(0.2), location: 0.86),
                .init(color: .black.opacity(0.06), location: 0.96),
            ],
            center: .center,
            startAngle: angle,
            endAngle: angle + .degrees(360)
        )
    }

    // Softer glow version
    private func glowGradient(angle: Angle) -> AngularGradient {
        AngularGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .clear, location: 0.65),
                .init(color: .white.opacity(0.18), location: 0.78),
                .init(color: .clear, location: 0.91),
                .init(color: .clear, location: 1.0),
            ],
            center: .center,
            startAngle: angle,
            endAngle: angle + .degrees(360)
        )
    }

    var body: some View {
        ZStack {
            // Outer glow — behind everything, not clipped
            if showShimmer {
                RoundedRectangle(cornerRadius: cr + 4)
                    .stroke(glowGradient(angle: shimmerAngle), lineWidth: 8)
                    .blur(radius: 5)
            }

            // Clipped pill content
            Group {
                RoundedRectangle(cornerRadius: cr)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: cr)
                    .fill(.white.opacity(0.82))

                content()

                // Breathing line — pinned to bottom
                VStack {
                    Spacer()
                    GeometryReader { geo in
                        let totalWidth = geo.size.width
                        let lineWidth = max(0, totalWidth * lineProgress)
                        let xOffset = (totalWidth - lineWidth) / 2

                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(.black.opacity(0.09))
                            .frame(width: lineWidth, height: 1.25)
                            .offset(x: xOffset)
                    }
                    .frame(height: 1)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)
                    .opacity(lineVisible ? 1 : 0)
                }
            }
            .frame(height: ZenPillStyle.pillHeight)
            .clipShape(RoundedRectangle(cornerRadius: cr))

            // Border shimmer — on top, not clipped
            if showShimmer {
                RoundedRectangle(cornerRadius: cr)
                    .inset(by: 0.5)
                    .stroke(sparkGradient(angle: shimmerAngle), lineWidth: 1)
                    .frame(height: ZenPillStyle.pillHeight)
            } else {
                RoundedRectangle(cornerRadius: cr)
                    .stroke(Color.black.opacity(0.07), lineWidth: 0.5)
                    .frame(height: ZenPillStyle.pillHeight)
            }
        }
        .shadow(color: .black.opacity(0.03 * shadowOpacity), radius: 6, y: 2)
        .shadow(color: .black.opacity(0.05 * shadowOpacity), radius: 12, y: 4)
        .scaleEffect(pillScale)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 12)
        .onAppear {
            if showShimmer {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    shimmerAngle = .degrees(360)
                }
            }
        }
    }
}
