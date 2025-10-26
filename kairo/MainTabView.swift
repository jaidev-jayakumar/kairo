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
            
            // Custom tab bar
            HStack(spacing: 0) {
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
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.white.opacity(0.05))
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
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
            if isSelected {
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 4, height: 4)
            }
            
            Image(systemName: icon)
                .font(.system(size: isSelected ? 22 : 20, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .white : .white.opacity(0.3))
            
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .white.opacity(0.8) : .white.opacity(0.3))
                .opacity(isSelected ? 1 : 0.7)
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    MainTabView()
}