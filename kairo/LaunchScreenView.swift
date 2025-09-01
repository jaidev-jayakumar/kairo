import SwiftUI

struct LaunchScreenView: View {
    @State private var showLogo = false
    @State private var expandCircle = false
    @State private var showStars = false
    @Binding var isLoading: Bool
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            // Animated stars background
            if showStars {
                StarsBackgroundView()
                    .opacity(0.5)
            }
            
            // Center cosmic circle animation
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: expandCircle ? 2 : 40
                )
                .frame(width: expandCircle ? 800 : 120, height: expandCircle ? 800 : 120)
                .opacity(expandCircle ? 0 : 1)
                .animation(.easeOut(duration: 1.5), value: expandCircle)
            
            // App logo/name
            VStack(spacing: 20) {
                // Constellation icon
                ZStack {
                    ForEach(0..<6) { index in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 4, height: 4)
                            .offset(x: cos(CGFloat(index) * .pi / 3) * 30,
                                   y: sin(CGFloat(index) * .pi / 3) * 30)
                            .opacity(showLogo ? 1 : 0)
                            .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.1), value: showLogo)
                    }
                    
                    // Connecting lines
                    ForEach(0..<6) { index in
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 1, height: 60)
                            .rotationEffect(.degrees(Double(index) * 60))
                            .opacity(showLogo ? 1 : 0)
                            .animation(.easeOut(duration: 0.5).delay(0.6), value: showLogo)
                    }
                }
                
                Text("KAIRO")
                    .font(.system(size: 28, weight: .ultraLight, design: .default))
                    .foregroundColor(.white)
                    .tracking(8)
                    .opacity(showLogo ? 1 : 0)
                    .offset(y: showLogo ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.3), value: showLogo)
                
                Text("cosmic guidance")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(2)
                    .textCase(.uppercase)
                    .opacity(showLogo ? 1 : 0)
                    .animation(.easeOut(duration: 0.8).delay(0.5), value: showLogo)
            }
            .scaleEffect(expandCircle ? 0.8 : 1)
            .opacity(expandCircle ? 0 : 1)
            .animation(.easeOut(duration: 0.8), value: expandCircle)
        }
        .onAppear {
            withAnimation {
                showStars = true
                showLogo = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeOut(duration: 1)) {
                    expandCircle = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    LaunchScreenView(isLoading: .constant(true))
}