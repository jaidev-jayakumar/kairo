import SwiftUI

/// Agent states that control the visualizer animation behavior
enum AgentState {
    case idle
    case listening
    case thinking 
    case speaking
}

/// A SwiftUI view that visualizes audio levels and agent states as animated vertical bars.
/// Adapted for the Kairo voice assistant interface to provide visual feedback.
struct BarAudioVisualizer: View {
    let barCount: Int
    let barColor: Color
    let barCornerRadius: CGFloat
    let barSpacingFactor: CGFloat
    let barMinOpacity: Double
    let isCentered: Bool
    
    private let agentState: AgentState
    
    @State private var animationPhase: Int = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var bars: [Double] = []
    
    init(agentState: AgentState = .speaking,
         barColor: Color = .white,
         barCount: Int = 5,
         barCornerRadius: CGFloat = 100,
         barSpacingFactor: CGFloat = 0.02,
         barMinOpacity: CGFloat = 0.16,
         isCentered: Bool = true) {
        
        self.agentState = agentState
        self.barColor = barColor
        self.barCount = barCount
        self.barCornerRadius = barCornerRadius
        self.barSpacingFactor = barSpacingFactor
        self.barMinOpacity = Double(barMinOpacity)
        self.isCentered = isCentered
        
        // Initialize bars with default values
        _bars = State(initialValue: Array(repeating: 0.1, count: barCount))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let highlightedBars = getHighlightedBars()
            
            barsView(geometry: geometry, highlighted: highlightedBars)
                .onAppear {
                    startAnimation()
                }
                .onDisappear {
                    stopAnimation()
                }
                .onChange(of: agentState) { _ in
                    startAnimation()
                }
                .animation(.easeInOut, value: animationPhase)
                .animation(.easeInOut(duration: 0.3), value: agentState)
        }
    }
    
    @ViewBuilder
    private func barsView(geometry: GeometryProxy, highlighted: Set<Int>) -> some View {
        let totalSpacing = geometry.size.width * barSpacingFactor * CGFloat(barCount + 1)
        let availableWidth = geometry.size.width - totalSpacing
        let barWidth = availableWidth / CGFloat(barCount)
        let barMinHeight = barWidth * 0.5 // Minimum height for visibility
        
        HStack(alignment: .center, spacing: geometry.size.width * barSpacingFactor) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: barCornerRadius)
                    .fill(barColor)
                    .opacity(highlighted.contains(index) ? 1.0 : barMinOpacity)
                    .frame(
                        width: barWidth,
                        height: calculateBarHeight(
                            index: index,
                            minHeight: barMinHeight,
                            maxHeight: geometry.size.height
                        )
                    )
                    .frame(maxHeight: .infinity, alignment: .center)
                    .animation(.easeInOut(duration: 0.15), value: bars[safe: index] ?? 0.1)
            }
        }
        .frame(width: geometry.size.width)
    }
    
    private func calculateBarHeight(index: Int, minHeight: CGFloat, maxHeight: CGFloat) -> CGFloat {
        let normalizedValue = bars[safe: index] ?? 0.1
        let availableHeight = maxHeight - minHeight
        return minHeight + (availableHeight * CGFloat(normalizedValue))
    }
    
    private func getHighlightedBars() -> Set<Int> {
        let sequence = highlightingSequence()
        let highlighted = sequence[animationPhase % sequence.count]
        return highlighted
    }
    
    private func highlightingSequence() -> [Set<Int>] {
        switch agentState {
        case .idle:
            // Gentle wave from outside to center
            return (0..<barCount).map { Set([$0, barCount - 1 - $0]) }
            
        case .listening:
            // Center bars highlighted
            if barCount % 2 == 0 {
                return [Set([(barCount / 2) - 1, barCount / 2]), Set()]
            } else {
                return [Set([barCount / 2]), Set()]
            }
            
        case .thinking:
            // Sequential highlighting back and forth
            let forward = Array(0..<barCount)
            let backward = Array(forward.reversed())
            return (forward + backward).map { Set([$0]) }
            
        case .speaking:
            // All bars active with random heights
            return [Set(0..<barCount)]
        }
    }
    
    private func animationDuration() -> TimeInterval {
        switch agentState {
        case .idle: return 2.0 / Double(barCount)
        case .listening: return 0.5
        case .thinking: return 0.15
        case .speaking: return 0.1 // Fast for dynamic audio visualization
        }
    }
    
    private func startAnimation() {
        animationTask?.cancel()
        animationPhase = 0
        
        animationTask = Task {
            while !Task.isCancelled {
                // Update bar heights for dynamic effect
                updateBarHeights()
                
                try? await Task.sleep(nanoseconds: UInt64(animationDuration() * Double(NSEC_PER_SEC)))
                if !Task.isCancelled {
                    animationPhase += 1
                }
            }
        }
    }
    
    private func stopAnimation() {
        animationTask?.cancel()
    }
    
    private func updateBarHeights() {
        switch agentState {
        case .idle:
            // Gentle, slow wave
            bars = (0..<barCount).map { index in
                let phase = Double(animationPhase) * 0.3 + Double(index) * 0.5
                return 0.1 + 0.3 * (sin(phase) + 1) / 2
            }
            
        case .listening:
            // Subtle breathing effect on center bars
            let breathe = 0.2 + 0.2 * sin(Double(animationPhase) * 0.5)
            bars = (0..<barCount).map { index in
                let centerDistance = abs(index - barCount / 2)
                return centerDistance < 2 ? breathe : 0.1
            }
            
        case .thinking:
            // Moderate activity with sequential peaks
            bars = (0..<barCount).map { index in
                let activeIndex = animationPhase % barCount
                if index == activeIndex {
                    return 0.7 + 0.3 * Double.random(in: 0...1)
                } else {
                    return 0.1 + 0.2 * Double.random(in: 0...1)
                }
            }
            
        case .speaking:
            // Dynamic, high-energy visualization
            bars = (0..<barCount).map { _ in
                Double.random(in: 0.2...1.0)
            }
        }
    }
}

// MARK: - Array Extension for Safe Access
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview
struct BarAudioVisualizer_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            BarAudioVisualizer(agentState: .idle)
                .frame(height: 60)
                .background(Color.black)
            
            BarAudioVisualizer(agentState: .listening, barColor: .blue)
                .frame(height: 60)
                .background(Color.black)
            
            BarAudioVisualizer(agentState: .thinking, barColor: .orange)
                .frame(height: 60)
                .background(Color.black)
            
            BarAudioVisualizer(agentState: .speaking, barColor: .green)
                .frame(height: 60)
                .background(Color.black)
        }
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}