import SwiftUI

// MARK: - Horoscope Scores View
struct HoroscopeScoresView: View {
    let scores: HoroscopeScores
    @State private var animateProgress = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Day selector similar to reference app
            DaySelector()
            
            // Four progress circles
            HStack(spacing: 20) {
                ProgressCircle(
                    title: "Overall",
                    score: scores.overall,
                    color: .white,
                    animate: animateProgress
                )
                
                ProgressCircle(
                    title: "Love",
                    score: scores.love,
                    color: .white,
                    animate: animateProgress
                )
                
                ProgressCircle(
                    title: "Career",
                    score: scores.career,
                    color: .white,
                    animate: animateProgress
                )
                
                ProgressCircle(
                    title: "Wealth",
                    score: scores.wealth,
                    color: .white,
                    animate: animateProgress
                )
            }
            
            // Cosmic divider
            CosmicDivider()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).delay(0.5)) {
                animateProgress = true
            }
        }
    }
}

// MARK: - Day Selector
struct DaySelector: View {
    @State private var selectedDayIndex: Int = 0
    @State private var weekdays: [(String, Int)] = []
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<weekdays.count, id: \.self) { index in
                let (day, date) = weekdays[index]
                let isToday = index == selectedDayIndex
                
                VStack(spacing: 8) {
                    Text(day)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("\(date)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isToday ? .black : .white.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isToday ? Color.pink.opacity(0.8) : Color.clear)
                        )
                }
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        selectedDayIndex = index
                    }
                }
            }
        }
        .onAppear {
            generateWeekDays()
        }
    }
    
    private func generateWeekDays() {
        let calendar = Calendar.current
        let today = Date()
        
        // Find the current day of week (0 = Sunday, 1 = Monday, etc.)
        let todayWeekday = calendar.component(.weekday, from: today)
        
        // Calculate the start of the week (3 days before today)
        let startOffset = -3
        
        var tempWeekdays: [(String, Int)] = []
        var todayIndex = 3 // Today should be in the middle (index 3)
        
        for i in 0..<7 {
            let offset = startOffset + i
            
            if let date = calendar.date(byAdding: .day, value: offset, to: today) {
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "E" // Short day name (Mon, Tue, etc.)
                let dayName = dayFormatter.string(from: date)
                
                let dayNumber = calendar.component(.day, from: date)
                tempWeekdays.append((dayName, dayNumber))
            }
        }
        
        self.weekdays = tempWeekdays
        self.selectedDayIndex = todayIndex
    }
}

// MARK: - Progress Circle
struct ProgressCircle: View {
    let title: String
    let score: Int
    let color: Color
    let animate: Bool
    
    private var progress: Double {
        animate ? Double(score) / 100.0 : 0.0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 6)
                    .frame(width: 70, height: 70)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.2), value: progress)
                
                // Score text
                Text("\(score)")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .scaleEffect(animate ? 1.0 : 0.8)
                    .opacity(animate ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.8).delay(0.8), value: animate)
            }
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}



// MARK: - Cycles View
struct CyclesView: View {
    let cycles: [AstrologicalCycle]
    @State private var showCycles = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Cycles header
            HStack {
                Text("Cycles")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            // Cycle cards
            VStack(spacing: 16) {
                ForEach(Array(cycles.enumerated()), id: \.element.id) { index, cycle in
                    CycleCard(cycle: cycle)
                        .opacity(showCycles ? 1 : 0)
                        .offset(y: showCycles ? 0 : 30)
                        .animation(.easeOut(duration: 0.6).delay(Double(index) * 0.1), value: showCycles)
                }
            }
        }
        .onAppear {
            withAnimation {
                showCycles = true
            }
        }
    }
}

// MARK: - Cycle Card
struct CycleCard: View {
    let cycle: AstrologicalCycle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cycle.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(cycle.planetaryAspect)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(hex: cycle.influence.color) ?? .white.opacity(0.7))
                }
                
                Spacer()
                
                Text(cycle.duration)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
            }
            
            Text(cycle.description)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.white.opacity(0.75))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Color Extension
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if hex.count == 6 {
            let scanner = Scanner(string: hex)
            var hexNumber: UInt64 = 0
            
            if scanner.scanHexInt64(&hexNumber) {
                let r = Double((hexNumber & 0xff0000) >> 16) / 255
                let g = Double((hexNumber & 0x00ff00) >> 8) / 255
                let b = Double(hexNumber & 0x0000ff) / 255
                
                self.init(red: r, green: g, blue: b)
                return
            }
        }
        
        return nil
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 40) {
            HoroscopeScoresView(scores: HoroscopeScores(overall: 81, love: 77, career: 77, wealth: 90))
            
            CyclesView(cycles: [
                AstrologicalCycle(
                    title: "Shift Your Perspective",
                    planetaryAspect: "Venus ☍ Mercury",
                    duration: "> 30 days",
                    description: "You will have to face the way you are used to thinking and seeing the world. If you feel something, force yourself to articulate it.",
                    influence: .transformative
                ),
                AstrologicalCycle(
                    title: "Embrace Emotional Journeys",
                    planetaryAspect: "Saturn ⚹ Neptune",
                    duration: "< 3 days",
                    description: "You will have a period of self-discovery related to how you process emotions.",
                    influence: .positive
                )
            ])
        }
        .padding()
    }
}
