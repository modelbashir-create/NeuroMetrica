import SwiftUI

struct LoadingView: View {
    @ObservedObject var viewModel: LoadingViewModel

    var body: some View {
        ZStack {
            Color(red: 3 / 255, green: 5 / 255, blue: 8 / 255)
                .ignoresSafeArea()

            GridBackgroundView()
                .opacity(0.1)

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Image("regularicon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 240, height: 240)
                        .opacity(0.7)

                    Image("xrayicon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 240, height: 240)
                        .mask(
                            VStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(height: viewModel.progress * 240)
                                Spacer(minLength: 0)
                            }
                            .frame(width: 240, height: 240, alignment: .top)
                        )

                    LaserBarView(progress: viewModel.progress, fade: viewModel.laserFade)
                        .frame(width: 240, height: 240)
                        .zIndex(3)
                        .animation(.linear(duration: viewModel.laserFadeDuration), value: viewModel.laserFade)
                }
                .frame(width: 240, height: 240)

                VStack(spacing: 20) {
                    Text("NEUROMETRICA")
                        .font(.system(size: 28, weight: .ultraLight))
                        .kerning(10)
                        .foregroundColor(.white)
                        .padding(.top, 40)

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            .frame(width: 250, height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.cyan)
                            .shadow(color: .cyan, radius: 4)
                            .frame(width: 250 * viewModel.progress, height: 4)
                    }

                    Text("ADVANCED IMAGING VIEWER")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .kerning(5)
                        .foregroundColor(.gray)
                }

                Spacer()
            }
        }
        .accessibilityIdentifier("LoadingView")
        .onAppear {
            viewModel.start()
            withAnimation(.linear(duration: viewModel.duration)) {
                viewModel.progress = 1.0
            }
        }
    }
}

private struct GridBackgroundView: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let spacing: CGFloat = 40
                for x in stride(from: 0, to: geo.size.width, by: spacing) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geo.size.height))
                }
                for y in stride(from: 0, to: geo.size.height, by: spacing) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
            }
            .stroke(Color.cyan, lineWidth: 0.5)
        }
    }
}

private struct LaserBarView: View {
    let progress: CGFloat
    let fade: CGFloat

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let glowWidth = width + 40
            let clampedProgress = max(0, min(1, progress))
            let y = clampedProgress * geo.size.height

            ZStack {
                Rectangle()
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: glowWidth, height: 50)
                    .blur(radius: 20)

                Rectangle()
                    .fill(Color.cyan.opacity(0.5))
                    .frame(width: glowWidth - 20, height: 20)
                    .blur(radius: 8)

                Rectangle()
                    .fill(Color.cyan)
                    .frame(width: width, height: 8)
                    .blur(radius: 2)

                Rectangle()
                    .fill(Color.white)
                    .frame(width: width, height: 4)
            }
            .position(x: geo.size.width / 2, y: y)
            .opacity(fade)
            .shadow(color: .cyan.opacity(0.9), radius: 14)
            .compositingGroup()
            .blendMode(.screen)
        }
    }
}
