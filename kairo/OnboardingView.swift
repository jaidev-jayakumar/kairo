import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @State private var currentPage = 0
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            // Ambient gradient overlays for depth
            RadialGradient(
                colors: [
                    Color.purple.opacity(0.06),
                    Color.blue.opacity(0.04),
                    Color.black.opacity(0)
                ],
                center: .topTrailing,
                startRadius: 100,
                endRadius: 700
            )
            .ignoresSafeArea()
            
            LinearGradient(
                colors: [
                    Color.indigo.opacity(0.03),
                    Color.black.opacity(0)
                ],
                startPoint: .top,
                endPoint: .center
            )
                .ignoresSafeArea()
            
            TabView(selection: $currentPage) {
                WelcomePage()
                    .tag(0)
                
                AstrologyExplanationPage()
                    .tag(1)
                
                PermissionsPage()
                    .tag(2)
                
                BirthDataIntroPage(onComplete: onComplete)
                    .tag(3)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Custom page indicator
            VStack {
                Spacer()
                
                HStack(spacing: 8) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(currentPage == index ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(currentPage == index ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - Welcome Page
struct WelcomePage: View {
    @State private var showContent = false
    @State private var orbScale: CGFloat = 0.98
    @State private var floatOffset: CGFloat = 0
    @State private var driftOffset: CGFloat = 0
    @State private var rotationAngle: Double = 0
    @State private var innerRotation: Double = 0
    @State private var glowPulse: Double = 1.0
    
    var body: some View {
        VStack(spacing: 50) {
            Spacer()
            
            // Glowing orb - organic, soft shape
            ZStack {
                // Large soft glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "FF6B6B")?.opacity(0.3) ?? .red.opacity(0.3),
                                Color(hex: "FF6B6B")?.opacity(0.15) ?? .red.opacity(0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 160
                        )
                    )
                    .frame(width: 320, height: 320)
                    .blur(radius: 60)
                    .scaleEffect(orbScale * glowPulse)
                    .rotationEffect(.degrees(rotationAngle))
                
                // Main glowing blob
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "FFBABA") ?? .pink,
                                Color(hex: "FF8A8A") ?? .red.opacity(0.9),
                                Color(hex: "FF6B6B") ?? .red,
                                Color(hex: "CC5555")?.opacity(0.4) ?? .red.opacity(0.4)
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: 110
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 25)
                    .scaleEffect(orbScale * 1.02)
                    .rotationEffect(.degrees(rotationAngle * 0.5))
                
                // Smaller intense center
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "FFD4D4")?.opacity(0.9) ?? .pink.opacity(0.9),
                                Color(hex: "FF9999") ?? .red.opacity(0.8),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.48, y: 0.48),
                            startRadius: 1,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 15)
                    .scaleEffect(orbScale)
                    .rotationEffect(.degrees(innerRotation))
            }
            .offset(x: driftOffset, y: floatOffset)
            .opacity(showContent ? 1 : 0)
            
            Spacer().frame(height: 60)
            
            // Text content
            VStack(spacing: 24) {
                Text("hi, i’m kairo")
                    .font(.system(size: 32, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.92))
                    .kerning(0.3)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 16)
                
                Text("ready when you are...")
                    .font(.system(size: 15, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .kerning(0.3)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 16)
            }
            
            Spacer()
            
            // Call to action
            Text("swipe to start")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom, 20)
                .opacity(showContent ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
            showContent = true
            }
            // Gentle breathing animation - more noticeable
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                orbScale = 1.1
            }
            // Floating up and down - more pronounced
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true).delay(0.5)) {
                floatOffset = -15
            }
            // Horizontal drift - more visible
            withAnimation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true).delay(1.0)) {
                driftOffset = 12
            }
            // Slow rotation - faster
            withAnimation(.linear(duration: 12.0).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            // Counter-rotation for inner circle - faster
            withAnimation(.linear(duration: 9.0).repeatForever(autoreverses: false)) {
                innerRotation = -360
            }
            // Glow pulse - more noticeable
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(0.3)) {
                glowPulse = 1.12
            }
        }
    }
}

// MARK: - Astrology Explanation
struct AstrologyExplanationPage: View {
    @State private var showContent = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Constellation visualization
            ZStack {
                ForEach(0..<7) { index in
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 4, height: 4)
                        .offset(
                            x: cos(Double(index) * .pi / 3.5) * 60,
                            y: sin(Double(index) * .pi / 3.5) * 60
                        )
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(Double(index) * 0.1), value: showContent)
                }
            }
            .frame(width: 120, height: 120)
            
            VStack(spacing: 20) {
                Text("real astrology, for you")
                    .font(.system(size: 22, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.92))
                    .kerning(0.3)
                
                Text("using your exact birth time and location, we calculate your personal chart and give you daily insights based on what's actually happening in the sky.")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.75))
                    .kerning(0.2)
                    .multilineTextAlignment(.center)
                    .lineHeight(1.7)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 40)
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 1.0).delay(0.3), value: showContent)
            
            Spacer()
        }
        .onAppear {
            showContent = true
        }
    }
}

// MARK: - Permissions Page
struct PermissionsPage: View {
    @State private var showContent = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            Image(systemName: "bell.badge")
                .font(.system(size: 60))
                .foregroundColor(.white)
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 1.0), value: showContent)
            
            VStack(spacing: 20) {
                Text("daily insights")
                    .font(.system(size: 22, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.92))
                    .kerning(0.3)
                
                Text("get your personalized daily horoscope delivered when you want it.")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.75))
                    .kerning(0.2)
                    .multilineTextAlignment(.center)
                    .lineHeight(1.7)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 40)
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 1.0).delay(0.3), value: showContent)
            
            Spacer()
            
            Button(action: {
                // Request notification permissions
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    // Handle permission result
                }
            }) {
                Text("turn on notifications")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(Color.white))
            }
            .padding(.bottom, 20)
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 1.0).delay(0.6), value: showContent)
            
            Button(action: {}) {
                Text("not now")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 1.0).delay(0.8), value: showContent)
        }
        .onAppear {
            showContent = true
        }
    }
}

// MARK: - Birth Data Intro
struct BirthDataIntroPage: View {
    @State private var showContent = false
    @State private var showBirthDataInput = false
    @State private var orbPulse: CGFloat = 1.0
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Birth chart visualization - hollow glowing orb with edges
            ZStack {
                // Massive soft outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "FFBABA")?.opacity(0.1) ?? .pink.opacity(0.1),
                                Color(hex: "FF9999")?.opacity(0.05) ?? .red.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 80,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .blur(radius: 70)
                    .scaleEffect(orbPulse)
                
                // Outer ring glow
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "FFBABA")?.opacity(0.6) ?? .pink.opacity(0.6),
                                Color(hex: "FF9999")?.opacity(0.5) ?? .red.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 40
                    )
                    .frame(width: 180, height: 180)
                    .blur(radius: 35)
                    .scaleEffect(orbPulse * 0.98)
                
                // Distinct edge ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "FFD4D4")?.opacity(0.8) ?? .pink.opacity(0.8),
                                Color(hex: "FFBABA")?.opacity(0.7) ?? .pink.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 1)
                    .scaleEffect(orbPulse)
                
                // Inner glow
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color(hex: "FFF0F0")?.opacity(0.3) ?? .pink.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 25
                    )
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)
                    .scaleEffect(orbPulse * 1.01)
                
                // Bright center
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.8),
                                Color(hex: "FFF5F5")?.opacity(0.6) ?? .pink.opacity(0.6),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 1,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                    .blur(radius: 25)
                    .scaleEffect(orbPulse * 1.03)
            }
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 1.0), value: showContent)
            
            VStack(spacing: 20) {
                Text("your birth chart")
                    .font(.system(size: 22, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.92))
                    .kerning(0.3)
                
                Text("to calculate your chart and give you accurate insights, we need your birth details.")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.75))
                    .kerning(0.2)
                    .multilineTextAlignment(.center)
                    .lineHeight(1.7)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 40)
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 1.0).delay(0.3), value: showContent)
            
            Spacer()
            
            Button(action: {
                showBirthDataInput = true
            }) {
                Text("add my birth info")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(Color.white))
            }
            .padding(.bottom, 40)
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 1.0).delay(0.6), value: showContent)
        }
        .onAppear {
            showContent = true
            
            // Gentle pulsing - soft breathing effect
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                orbPulse = 1.06
            }
        }
        .sheet(isPresented: $showBirthDataInput) {
            BirthDataInputView { birthData in
                UserDataManager.shared.saveBirthData(birthData)
                showBirthDataInput = false
                onComplete()
            }
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}