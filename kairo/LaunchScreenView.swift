import SwiftUI

struct LaunchScreenView: View {
    @State private var showStars = false
    @State private var pulseScale: Double = 1.0
    @State private var fadeOut = false
    @Binding var isLoading: Bool
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            // Subtle star field
            if showStars {
                ForEach(0..<20) { index in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.3...0.8)))
                        .frame(width: CGFloat.random(in: 1...3))
                        .position(
                            x: CGFloat.random(in: 50...350),
                            y: CGFloat.random(in: 100...700)
                        )
                        .opacity(showStars ? 1 : 0)
                        .animation(.easeOut(duration: 1.0).delay(Double(index) * 0.05), value: showStars)
                }
            }
            
            // Central constellation
            ZStack {
                ForEach(0..<6) { index in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 4, height: 4)
                        .offset(
                            x: cos(CGFloat(index) * .pi / 3) * 30,
                            y: sin(CGFloat(index) * .pi / 3) * 30
                        )
                        .opacity(showStars ? 1 : 0)
                        .scaleEffect(pulseScale)
                        .animation(.easeOut(duration: 0.8).delay(Double(index) * 0.1), value: showStars)
                }
            }
            .scaleEffect(fadeOut ? 0.8 : 1)
            .opacity(fadeOut ? 0 : 1)
            .animation(.easeOut(duration: 0.8), value: fadeOut)
        }
        .onAppear {
            startSubtleAnimation()
        }
    }
    
    private func startSubtleAnimation() {
        // Show stars and constellation
        withAnimation {
            showStars = true
        }
        
        // Gentle pulsing
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulseScale = 1.2
        }
        
        // Fade out and complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.8)) {
                fadeOut = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                isLoading = false
            }
        }
    }
}

struct LaunchScreenView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchScreenView(isLoading: .constant(true))
    }
}