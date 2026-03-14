import SwiftUI

struct AudioWaveView: View {
    let level: Float
    private let barCount = 7

    // Each bar tracks its own smoothed level
    @State private var barLevels: [Float] = Array(repeating: 0, count: 7)

    // Smoothing factors per bar — center bars are snappy (high freq),
    // edge bars are sluggish (low freq)
    // [edge, mid, mid-center, center, mid-center, mid, edge]
    private static let smoothUp:   [Float] = [0.3, 0.5, 0.7, 0.9, 0.75, 0.45, 0.35]
    private static let smoothDown: [Float] = [0.15, 0.25, 0.5, 0.7, 0.55, 0.2, 0.18]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                WaveBar(level: barLevels[i], index: i)
            }
        }
        .frame(width: 30, height: 22)
        .onChange(of: level) { _, newLevel in
            for i in 0..<barCount {
                let current = barLevels[i]
                let target = newLevel
                if target > current {
                    barLevels[i] = current + (target - current) * Self.smoothUp[i]
                } else {
                    barLevels[i] = current + (target - current) * Self.smoothDown[i]
                }
                // Hard zero when input is silent
                if newLevel < 0.01 && barLevels[i] < 0.05 {
                    barLevels[i] = 0
                }
            }
        }
    }
}

private struct WaveBar: View {
    let level: Float
    let index: Int

    private static let multipliers: [CGFloat] = [0.5, 0.7, 0.9, 0.4, 1.0, 0.6, 0.75]
    private let base: CGFloat = 3
    private let maxExtra: CGFloat = 19

    private var barHeight: CGFloat {
        let spike = Self.multipliers[index % Self.multipliers.count]
        return base + maxExtra * CGFloat(level) * spike
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.red.opacity(0.9))
            .frame(width: 2, height: max(base, barHeight))
            .animation(.linear(duration: 0.04), value: level)
    }
}
