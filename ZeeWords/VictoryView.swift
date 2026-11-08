import SwiftUI

struct VictoryView: View {
    let playerScore: Int
    let computerScore: Int
    let playAgain: () -> Void
    let viewBoard: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var celebrating = false
    private let colors: [Color] = [.yellow, .cyan, .pink, .orange, .mint]

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.14, blue: 0.20).ignoresSafeArea()
            GeometryReader { geometry in
                ForEach(0..<45) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors[i % colors.count])
                        .frame(width: 7, height: 13)
                        .rotationEffect(.degrees(celebrating ? Double(i * 37) : Double(i * 13)))
                        .position(x: geometry.size.width * CGFloat((i * 37) % 101) / 100,
                                  y: reduceMotion ? geometry.size.height * CGFloat((i * 23) % 100) / 100 :
                                    celebrating ? geometry.size.height + 30 : -30 - CGFloat(i * 8))
                        .animation(reduceMotion ? nil : .linear(duration: 3.5 + Double(i % 4) * 0.3).delay(Double(i % 7) * 0.12), value: celebrating)
                }
            }.allowsHitTesting(false).accessibilityHidden(true)
            VStack(spacing: 24) {
                Image(systemName: "trophy.fill").font(.system(size: 80)).foregroundStyle(.yellow)
                    .accessibilityHidden(true)
                Text("You won!").font(.largeTitle.bold())
                Text("Well played.").font(.title2)
                Text("You \(playerScore)  ·  Computer \(computerScore)").font(.title3.monospacedDigit())
                Button("Play again", action: playAgain).buttonStyle(.borderedProminent).tint(.orange)
                Button("View final board", action: viewBoard).foregroundStyle(.white)
            }.padding(24).foregroundStyle(.white)
        }
        .onAppear { celebrating = true }
    }
}
