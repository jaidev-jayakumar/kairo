import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                TodayView()
                    .tag(0)
                
                WeekMonthView()
                    .tag(1)
                
                VoiceAssistantView()
                    .tag(2)
                
                ProfileView()
                    .tag(3)
            }
            
            // Custom tab bar
            HStack(spacing: 0) {
                TabBarButton(icon: "sun.max", title: "Today", isSelected: selectedTab == 0)
                    .onTapGesture { selectedTab = 0 }
                
                TabBarButton(icon: "calendar", title: "Week", isSelected: selectedTab == 1)
                    .onTapGesture { selectedTab = 1 }
                
                TabBarButton(icon: "mic", title: "Kaira", isSelected: selectedTab == 2)
                    .onTapGesture { selectedTab = 2 }
                
                TabBarButton(icon: "person", title: "Profile", isSelected: selectedTab == 3)
                    .onTapGesture { selectedTab = 3 }
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