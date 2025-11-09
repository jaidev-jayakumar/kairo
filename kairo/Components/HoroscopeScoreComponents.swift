import SwiftUI

// MARK: - Horoscope Scores View
struct HoroscopeScoresView: View {
    let scores: HoroscopeScores
    @Binding var selectedDate: Date
    @State private var animateProgress = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Day selector similar to reference app
            DaySelector(selectedDate: $selectedDate)
            
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
        .onChange(of: selectedDate) { _ in
            // Trigger animation when date changes
            animateProgress = false
            withAnimation(.easeOut(duration: 1.5).delay(0.2)) {
                animateProgress = true
            }
        }
    }
}

// MARK: - Day Selector
struct DaySelector: View {
    @Binding var selectedDate: Date
    @State private var weekdays: [(date: Date, dayName: String, dayNumber: Int)] = []
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<weekdays.count, id: \.self) { index in
                    let weekday = weekdays[index]
                    let isSelected = Calendar.current.isDate(selectedDate, inSameDayAs: weekday.date)
                    
                    VStack(spacing: 8) {
                        Text(weekday.dayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("\(weekday.dayNumber)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isSelected ? .black : .white.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Color.pink.opacity(0.8) : Color.clear)
                            )
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            selectedDate = weekday.date
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            generateWeekDays()
        }
    }
    
    private func generateWeekDays() {
        let calendar = Calendar.current
        let today = Date()
        
        // Show 3 days in the past and 10 days in the future (14 days total)
        let startOffset = -3
        let daysToShow = 14
        
        var tempWeekdays: [(date: Date, dayName: String, dayNumber: Int)] = []
        
        for i in 0..<daysToShow {
            let offset = startOffset + i
            
            if let date = calendar.date(byAdding: .day, value: offset, to: today) {
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "E" // Short day name (Mon, Tue, etc.)
                let dayName = dayFormatter.string(from: date)
                
                let dayNumber = calendar.component(.day, from: date)
                tempWeekdays.append((date: date, dayName: dayName, dayNumber: dayNumber))
            }
        }
        
        self.weekdays = tempWeekdays
    }
}

// MARK: - Week Selector
struct WeekSelector: View {
    @Binding var selectedWeekStart: Date
    @State private var weeks: [(startDate: Date, endDate: Date, label: String)] = []
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<weeks.count, id: \.self) { index in
                    let week = weeks[index]
                    let isSelected = Calendar.current.isDate(selectedWeekStart, inSameDayAs: week.startDate)
                    
                    VStack(spacing: 4) {
                        Text(week.label)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isSelected ? .black : .white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? Color.pink.opacity(0.8) : Color.white.opacity(0.1))
                            )
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            selectedWeekStart = week.startDate
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            generateWeeks()
        }
    }
    
    private func generateWeeks() {
        let calendar = Calendar.current
        let today = Date()
        
        // Show 3 weeks in the past and 5 weeks in the future (9 weeks total)
        let weeksToShow = 9
        let startOffset = -3
        
        var tempWeeks: [(startDate: Date, endDate: Date, label: String)] = []
        
        for i in 0..<weeksToShow {
            let weekOffset = startOffset + i
            
            if let targetDate = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: today) {
                // Get Sunday of this week (start of week)
                let weekday = calendar.component(.weekday, from: targetDate)
                let daysFromSunday = weekday - 1
                
                if let weekStart = calendar.date(byAdding: .day, value: -daysFromSunday, to: targetDate),
                   let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) {
                    
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MM/dd"
                    
                    let label = "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
                    tempWeeks.append((startDate: weekStart, endDate: weekEnd, label: label))
                }
            }
        }
        
        self.weeks = tempWeeks
    }
}

// MARK: - Month Selector
struct MonthSelector: View {
    @Binding var selectedMonth: Date
    @State private var months: [(date: Date, label: String)] = []
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<months.count, id: \.self) { index in
                    let month = months[index]
                    let calendar = Calendar.current
                    let isSelected = calendar.component(.month, from: selectedMonth) == calendar.component(.month, from: month.date) &&
                                   calendar.component(.year, from: selectedMonth) == calendar.component(.year, from: month.date)
                    
                    VStack(spacing: 4) {
                        Text(month.label)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isSelected ? .black : .white.opacity(0.7))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? Color.pink.opacity(0.8) : Color.white.opacity(0.1))
                            )
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            selectedMonth = month.date
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            generateMonths()
        }
    }
    
    private func generateMonths() {
        let calendar = Calendar.current
        let today = Date()
        
        // Show 3 months in the past and 5 months in the future (9 months total)
        let monthsToShow = 9
        let startOffset = -3
        
        var tempMonths: [(date: Date, label: String)] = []
        
        for i in 0..<monthsToShow {
            let monthOffset = startOffset + i
            
            if let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: today) {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM yyyy"
                let label = formatter.string(from: monthDate)
                
                tempMonths.append((date: monthDate, label: label))
            }
        }
        
        self.months = tempMonths
    }
}

// MARK: - Year Selector
struct YearSelector: View {
    @Binding var selectedYear: Date
    @State private var years: [(date: Date, label: String)] = []
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<years.count, id: \.self) { index in
                    let year = years[index]
                    let calendar = Calendar.current
                    let isSelected = calendar.component(.year, from: selectedYear) == calendar.component(.year, from: year.date)
                    
                    VStack(spacing: 4) {
                        Text(year.label)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isSelected ? .black : .white.opacity(0.7))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? Color.pink.opacity(0.8) : Color.white.opacity(0.1))
                            )
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            selectedYear = year.date
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            generateYears()
        }
    }
    
    private func generateYears() {
        let calendar = Calendar.current
        let today = Date()
        
        // Show 2 years in the past and 3 years in the future (6 years total)
        let yearsToShow = 6
        let startOffset = -2
        
        var tempYears: [(date: Date, label: String)] = []
        
        for i in 0..<yearsToShow {
            let yearOffset = startOffset + i
            
            if let yearDate = calendar.date(byAdding: .year, value: yearOffset, to: today) {
                let yearNum = calendar.component(.year, from: yearDate)
                let label = "\(yearNum)"
                
                tempYears.append((date: yearDate, label: label))
            }
        }
        
        self.years = tempYears
    }
}

// MARK: - Progress Circle
struct ProgressCircle: View {
    let title: String
    let score: Int
    let color: Color
    let animate: Bool
    @State private var glowPulse: Bool = false
    
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
                
                // Progress circle with color
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [Color.pink, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.2), value: progress)
                    .shadow(color: Color.pink.opacity(glowPulse ? 0.7 : 0.5), radius: glowPulse ? 14 : 12, x: 0, y: 0)
                    .shadow(color: Color.purple.opacity(glowPulse ? 0.6 : 0.4), radius: glowPulse ? 22 : 20, x: 0, y: 0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: glowPulse)
                
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
        .onAppear {
            glowPulse = true
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
                Text("cycles")
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
                VStack(alignment: .leading, spacing: 8) {
                    Text(cycle.title)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Text(cycle.planetaryAspect)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 4)
                            
                            // Progress
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: cycle.influence.color) ?? .white)
                                .frame(width: geometry.size.width * cycle.progressPercentage, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                
                Spacer()
                
                Text(cycle.duration)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                    )
            }
            
            Text(cycle.description)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.12),
                            Color.pink.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.purple.opacity(0.35),
                                    Color.pink.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.purple.opacity(0.1), radius: 12, x: 0, y: 4)
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
    struct PreviewWrapper: View {
        @State private var selectedDate = Date()
        
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 40) {
                    HoroscopeScoresView(
                        scores: HoroscopeScores(overall: 81, love: 77, career: 77, wealth: 90),
                        selectedDate: $selectedDate
                    )
                    
                    CyclesView(cycles: [
                        AstrologicalCycle(
                            title: "Shift Your Perspective",
                            planetaryAspect: "Venus opposite Mercury",
                            duration: "> 30 days",
                            description: "You will have to face the way you are used to thinking and seeing the world. If you feel something, force yourself to articulate it.",
                            influence: .transformative,
                            progressPercentage: 0.45
                        ),
                        AstrologicalCycle(
                            title: "Embrace Emotional Journeys",
                            planetaryAspect: "Saturn sextile Neptune",
                            duration: "< 3 days",
                            description: "You will have a period of self-discovery related to how you process emotions.",
                            influence: .positive,
                            progressPercentage: 0.7
                        )
                    ])
                }
                .padding()
            }
        }
    }
    
    return PreviewWrapper()
}
