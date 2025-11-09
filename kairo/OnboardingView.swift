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
                    .scaleEffect(orbScale)
                
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
            }
            .offset(y: floatOffset)
            .opacity(showContent ? 1 : 0)
            
            Spacer().frame(height: 60)
            
            // Text content
            VStack(spacing: 24) {
                Text("welcome to kaira")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.white)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                
                Text("your personal astrologer")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
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
            // Gentle breathing animation
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                orbScale = 1.04
            }
            // Subtle floating up and down
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true).delay(0.5)) {
                floatOffset = -8
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
                Text("Real astrology, for you")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white)
                
                Text("Using your exact birth time and location, we calculate your personal chart and give you daily insights based on what's actually happening in the sky.")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineHeight(1.6)
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
                Text("Daily insights")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white)
                
                Text("Get your personalized daily horoscope delivered when you want it.")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineHeight(1.6)
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
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Birth chart visualization
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    .frame(width: 150, height: 150)
                
                ForEach(0..<12) { index in
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 75)
                        .offset(y: -37.5)
                        .rotationEffect(.degrees(Double(index) * 30))
                }
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
            }
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 1.0), value: showContent)
            
            VStack(spacing: 20) {
                Text("Your birth chart")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white)
                
                Text("To calculate your chart and give you accurate insights, we need your birth details.")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineHeight(1.6)
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