import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var isTransitioning = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                TodayView()
                    .tag(0)
                    .id("today-\(selectedTab)")
                
                WeekMonthView()
                    .tag(1)
                    .id("week-\(selectedTab)")
                
                if FeatureFlags.enableVoiceAssistant {
                    VoiceAssistantView()
                        .tag(2)
                        .id("kaira-\(selectedTab)")
                }
                
                ProfileView()
                    .tag(FeatureFlags.enableVoiceAssistant ? 3 : 2)
                    .id("profile-\(selectedTab)")
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Custom tab bar with individual floating pills
            VStack(spacing: 0) {
                // Gradient fade at top of tab bar
                LinearGradient(
                    colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.8),
                        Color.black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 40)
                
                // Tab bar buttons
                HStack(spacing: 10) {
                    TabBarButton(icon: "sun.max", title: "today", isSelected: selectedTab == 0)
                        .onTapGesture {
                            guard !isTransitioning else { return }
                            changeTab(to: 0)
                        }
                    
                    TabBarButton(icon: "calendar", title: "week", isSelected: selectedTab == 1)
                        .onTapGesture {
                            guard !isTransitioning else { return }
                            changeTab(to: 1)
                        }
                    
                    if FeatureFlags.enableVoiceAssistant {
                        TabBarButton(icon: "waveform", title: "kaira", isSelected: selectedTab == 2)
                            .onTapGesture {
                                guard !isTransitioning else { return }
                                changeTab(to: 2)
                            }
                    }
                    
                    TabBarButton(icon: "person", title: "profile", isSelected: selectedTab == (FeatureFlags.enableVoiceAssistant ? 3 : 2))
                        .onTapGesture {
                            guard !isTransitioning else { return }
                            changeTab(to: FeatureFlags.enableVoiceAssistant ? 3 : 2)
                        }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                .background(Color.black)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func changeTab(to newTab: Int) {
        isTransitioning = true
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTab = newTab
        }
        // Allow a brief moment for cleanup before allowing another tab change
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isTransitioning = false
        }
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
            
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white.opacity(0.95) : .white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            ZStack {
                if isSelected {
                    // Individual floating pill
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0.12)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.25),
                                            Color.white.opacity(0.08)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.8
                                )
                        )
                        .shadow(color: Color.white.opacity(0.05), radius: 8, x: 0, y: 0)
                        .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
                        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                } else {
                    // Subtle background for unselected
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.03))
                }
            }
        )
        .scaleEffect(isSelected ? 1.0 : 0.96)
        .scaleEffect(isPressed ? 0.94 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        .animation(.easeOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

#Preview {
    MainTabView()
}