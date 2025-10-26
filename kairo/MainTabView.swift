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
                
                VoiceAssistantView()
                    .tag(2)
                    .id("kaira-\(selectedTab)")
                
                ProfileView()
                    .tag(3)
                    .id("profile-\(selectedTab)")
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Custom tab bar with individual floating pills
            HStack(spacing: 10) {
                TabBarButton(icon: "sun.max", title: "Today", isSelected: selectedTab == 0)
                    .onTapGesture {
                        guard !isTransitioning else { return }
                        changeTab(to: 0)
                    }
                
                TabBarButton(icon: "calendar", title: "Week", isSelected: selectedTab == 1)
                    .onTapGesture {
                        guard !isTransitioning else { return }
                        changeTab(to: 1)
                    }
                
                TabBarButton(icon: "waveform", title: "Kaira", isSelected: selectedTab == 2)
                    .onTapGesture {
                        guard !isTransitioning else { return }
                        changeTab(to: 2)
                    }
                
                TabBarButton(icon: "person", title: "Profile", isSelected: selectedTab == 3)
                    .onTapGesture {
                        guard !isTransitioning else { return }
                        changeTab(to: 3)
                    }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
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
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
    }
}

#Preview {
    MainTabView()
}