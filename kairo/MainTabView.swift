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
                
                BirthChartView()
                    .tag(2)
                
                ChatView()
                    .tag(3)
                
                ProfileView()
                    .tag(4)
            }
            
            // Custom tab bar
            HStack(spacing: 0) {
                TabBarButton(icon: "sun.max", title: "Today", isSelected: selectedTab == 0)
                    .onTapGesture { selectedTab = 0 }
                
                TabBarButton(icon: "calendar", title: "Week", isSelected: selectedTab == 1)
                    .onTapGesture { selectedTab = 1 }
                
                TabBarButton(icon: "sparkles", title: "Chart", isSelected: selectedTab == 2)
                    .onTapGesture { selectedTab = 2 }
                
                TabBarButton(icon: "bubble.left", title: "Chat", isSelected: selectedTab == 3)
                    .onTapGesture { selectedTab = 3 }
                
                TabBarButton(icon: "person", title: "Profile", isSelected: selectedTab == 4)
                    .onTapGesture { selectedTab = 4 }
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
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isSelected ? .white : .white.opacity(0.4))
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

#Preview {
    MainTabView()
}