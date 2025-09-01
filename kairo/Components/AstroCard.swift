import SwiftUI

struct AstroCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Astro Summary Row
struct AstroSummaryRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Text(value)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
        }
    }
}

// MARK: - Animated Stars Background
struct StarsBackgroundView: View {
    @State private var animateStars = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<50) { index in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.1...0.3)))
                        .frame(width: CGFloat.random(in: 1...3))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .opacity(animateStars ? Double.random(in: 0.3...1) : 0)
                        .animation(
                            .easeInOut(duration: Double.random(in: 2...4))
                            .repeatForever(autoreverses: true)
                            .delay(Double.random(in: 0...2)),
                            value: animateStars
                        )
                }
            }
        }
        .onAppear {
            animateStars = true
        }
    }
}

// MARK: - Gradient Text
struct GradientText: View {
    let text: String
    let gradient: LinearGradient
    
    init(_ text: String, gradient: LinearGradient = LinearGradient(
        colors: [.white, .white.opacity(0.8)],
        startPoint: .leading,
        endPoint: .trailing
    )) {
        self.text = text
        self.gradient = gradient
    }
    
    var body: some View {
        Text(text)
            .foregroundStyle(gradient)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        AstroCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sample Card")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("This is a reusable card component with a subtle glass effect.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        
        AstroSummaryRow(
            icon: "sun.max.fill",
            title: "Rising",
            value: "Leo"
        )
    }
    .padding()
    .background(Color.black)
}