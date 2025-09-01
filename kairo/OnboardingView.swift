import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @State private var currentPage = 0
    @Binding var isComplete: Bool
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            TabView(selection: $currentPage) {
                WelcomePage()
                    .tag(0)
                
                AstrologyExplanationPage()
                    .tag(1)
                
                PermissionsPage()
                    .tag(2)
                
                BirthDataIntroPage(isComplete: $isComplete)
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
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Logo or App Name
            VStack(spacing: 16) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(showContent ? 0 : -180))
                    .animation(.easeOut(duration: 1.0), value: showContent)
                
                Text("kairo")
                    .font(.system(size: 42, weight: .ultraLight))
                    .foregroundColor(.white)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 1.0).delay(0.3), value: showContent)
            }
            
            // Tagline
            Text("Your cosmic companion")
                .font(.system(size: 18, weight: .light))
                .foregroundColor(.white.opacity(0.8))
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 1.0).delay(0.6), value: showContent)
            
            Spacer()
            
            Text("Swipe to begin")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom, 20)
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 1.0).delay(1.0), value: showContent)
        }
        .onAppear {
            showContent = true
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
                Text("Personalized astrology")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white)
                
                Text("Based on your exact birth time and location, we calculate your unique cosmic blueprint and daily guidance.")
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
                Text("Daily cosmic insights")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white)
                
                Text("Get personalized daily horoscopes delivered at your preferred time.")
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
                Text("Enable notifications")
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
                Text("Maybe later")
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
    @Binding var isComplete: Bool
    
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
                Text("Your cosmic blueprint")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white)
                
                Text("To calculate your birth chart and provide accurate daily insights, we need your birth details.")
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
                Text("Enter birth details")
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
                isComplete = true
            }
        }
    }
}

#Preview {
    OnboardingView(isComplete: .constant(false))
}