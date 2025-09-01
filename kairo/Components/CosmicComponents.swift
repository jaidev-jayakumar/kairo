import SwiftUI

// MARK: - Cosmic Section
struct CosmicSection<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Philosophical Card
struct PhilosophicalCard: View {
    let question: String
    let answer: String
    let alignment: String?
    
    var body: some View {
        VStack(spacing: 40) {
            // Question
            VStack(spacing: 8) {
                Text("YOU ASKED")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.4))
                
                Text(question)
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Cosmic visual
            if let alignment = alignment {
                PlanetAlignmentVisual(alignment: alignment)
                    .frame(height: 120)
                    .padding(.vertical, 20)
            }
            
            // Answer
            Text(answer)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(10)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            // Dismiss area
            VStack(spacing: 16) {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                    .frame(maxWidth: 100)
                
                Text("DISMISS")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, 20)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

// MARK: - Planet Alignment Visual
struct PlanetAlignmentVisual: View {
    let alignment: String
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Simple orbital representation
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                .frame(width: 100, height: 100)
            
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                .frame(width: 70, height: 70)
            
            // Planets
            PlanetDots(rotation: rotation)
            
            // Center label
            Text(alignment)
                .font(.system(size: 9, weight: .medium))
                .tracking(1)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(width: 120, height: 120)
        .onAppear {
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                rotation = 2 * .pi
            }
        }
    }
}

struct PlanetDots: View {
    let rotation: Double
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                PlanetDot(index: index, rotation: rotation)
            }
        }
    }
}

struct PlanetDot: View {
    let index: Int
    let rotation: Double
    
    var body: some View {
        let angle = rotation + Double(index) * .pi / 2
        let radius: CGFloat = 50
        
        Circle()
            .fill(Color.white)
            .frame(width: index == 0 ? 12 : 6, height: index == 0 ? 12 : 6)
            .offset(x: cos(angle) * radius, y: sin(angle) * radius)
    }
}

// MARK: - Cosmic Divider
struct CosmicDivider: View {
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 3, height: 3)
            
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
            
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 3, height: 3)
        }
        .frame(maxWidth: 200)
    }
}

// MARK: - Energy Indicator
struct EnergyIndicator: View {
    let label: String
    let energy: String
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Energy symbol
            ZStack {
                if isActive {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 32, height: 32)
                }
                
                Image(systemName: energy)
                    .font(.system(size: 16))
                    .foregroundColor(isActive ? .white : .white.opacity(0.3))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.4))
                
                Text(isActive ? "ACTIVE" : "DORMANT")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(isActive ? .white.opacity(0.8) : .white.opacity(0.3))
            }
            
            Spacer()
        }
    }
}

// MARK: - Cosmic Time Display
struct CosmicTimeDisplay: View {
    let label: String
    let time: String
    let description: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .medium))
                .tracking(2)
                .foregroundColor(.white.opacity(0.4))
            
            Text(time)
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundColor(.white)
            
            Text(description)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Insight Block
struct InsightBlock: View {
    let insight: String
    let symbol: String?
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            if let symbol = symbol {
                Text(symbol)
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Text(insight)
                .font(.system(size: 15, weight: .light))
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

#Preview {
    VStack {
        PhilosophicalCard(
            question: "What truth am I avoiding?",
            answer: "The part of you that seeks validation is the same part that fears being seen. Today's cosmic energy asks you to sit with this paradox.",
            alignment: "MERCURY ☍ NEPTUNE"
        )
    }
    .background(Color.black)
}