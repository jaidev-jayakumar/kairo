import SwiftUI

struct TodayView: View {
    @State private var showContent = false
    @State private var selectedCategory: AstroCategory? = nil
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Date Header
                DateHeaderView()
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.6), value: showContent)
                
                // Daily Insight Card
                DailyInsightCard()
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.2), value: showContent)
                
                // Categories Row
                CategoriesRowView(selectedCategory: $selectedCategory)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.4), value: showContent)
                
                // Navigation Button
                NavigationLinkButton()
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.8).delay(0.6), value: showContent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 32)
        }
        .background(Color.black)
        .onAppear {
            withAnimation {
                showContent = true
            }
        }
    }
}

// MARK: - Date Header
struct DateHeaderView: View {
    let today = Date()
    
    var body: some View {
        VStack(spacing: 4) {
            Text(today.formatted(.dateTime.weekday(.wide)))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .tracking(1.5)
                .textCase(.uppercase)
            
            Text(today.formatted(.dateTime.day().month(.wide)))
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Daily Insight Card
struct DailyInsightCard: View {
    var body: some View {
        AstroCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "moon.stars")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Today's Cosmic Weather")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Text("Mercury's dance with Neptune creates a veil of mystery. Trust your intuition over logic today. The answers you seek are found in the spaces between words.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.75))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Categories Row
struct CategoriesRowView: View {
    @Binding var selectedCategory: AstroCategory?
    
    let categories = [
        AstroCategory(icon: "heart.fill", title: "Love", color: Color(red: 1.0, green: 0.4, blue: 0.4)),
        AstroCategory(icon: "briefcase.fill", title: "Work", color: Color(red: 0.4, green: 0.8, blue: 0.4)),
        AstroCategory(icon: "bolt.fill", title: "Energy", color: Color(red: 1.0, green: 0.8, blue: 0.2))
    ]
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(categories) { category in
                CategoryCard(category: category, isSelected: selectedCategory?.id == category.id)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedCategory = selectedCategory?.id == category.id ? nil : category
                        }
                    }
            }
        }
    }
}

struct CategoryCard: View {
    let category: AstroCategory
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isSelected ? category.color.opacity(0.2) : Color.white.opacity(0.05))
                    .frame(width: 56, height: 56)
                
                Image(systemName: category.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? category.color : .white.opacity(0.6))
            }
            
            Text(category.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(isSelected ? 0.9 : 0.6))
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(isSelected ? 1.05 : 1.0)
    }
}

// MARK: - Navigation Button
struct NavigationLinkButton: View {
    var body: some View {
        HStack {
            Text("See Week")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
            
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(Color.white)
        )
        .shadow(color: .white.opacity(0.2), radius: 10, x: 0, y: 0)
        .padding(.top, 20)
    }
}

// MARK: - Models
struct AstroCategory: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let color: Color
}

// MARK: - Preview
#Preview {
    TodayView()
}