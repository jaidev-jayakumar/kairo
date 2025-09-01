import SwiftUI

struct WeekMonthView: View {
    @State private var selectedTimeframe: TimeFrame = .week
    @State private var selectedDate = Date()
    @State private var currentTransits: [CelestialBody] = []
    @State private var userBirthChart: BirthChart?
    @State private var weeklyInsight = ""
    
    enum TimeFrame {
        case week, month
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Header with toggle
                VStack(spacing: 20) {
                    Text("Cosmic Forecast")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.white)
                    
                    // Week/Month Toggle
                    HStack(spacing: 0) {
                        ForEach([TimeFrame.week, TimeFrame.month], id: \.self) { timeframe in
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedTimeframe = timeframe
                                }
                            }) {
                                Text(timeframe == .week ? "Week" : "Month")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(selectedTimeframe == timeframe ? .black : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        selectedTimeframe == timeframe ?
                                        Capsule().fill(Color.white) :
                                        Capsule().fill(Color.clear)
                                    )
                            }
                        }
                    }
                    .padding(4)
                    .background(
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .frame(width: 200)
                }
                .padding(.top, 20)
                
                if selectedTimeframe == .week {
                    WeekView(weeklyInsight: weeklyInsight, weeklyThemes: getWeeklyThemes())
                } else {
                    MonthView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .background(Color.black)
        .onAppear {
            loadAstrologicalData()
        }
    }
    
    private func loadAstrologicalData() {
        // Load current transits
        currentTransits = AstrologyService.shared.calculateCurrentTransits()
        
        // Load user birth chart
        if let birthData = UserDataManager.shared.getBirthData() {
            userBirthChart = AstrologyService.shared.calculateBirthChart(for: birthData)
            if let chart = userBirthChart {
                // Start with basic insight for immediate display
                weeklyInsight = generateWeeklyInsight(chart: chart, transits: currentTransits)
                
                // Then fetch AI-powered weekly insight
                Task {
                    let aiWeeklyInsight = await AstrologyService.shared.generateWeeklyInsight(for: chart)
                    DispatchQueue.main.async {
                        self.weeklyInsight = aiWeeklyInsight
                    }
                }
            }
        }
    }
    
    private func generateWeeklyInsight(chart: BirthChart, transits: [CelestialBody]) -> String {
        let sunSign = chart.sunSign
        
        if let moonTransit = transits.first(where: { $0.name == "Moon" }) {
            let moonSign = moonTransit.position.sign
            return "This week, the Moon's journey through \(moonSign.rawValue) highlights your \(getMoonFocus(for: moonSign)). As a \(sunSign.rawValue), you're called to \(getWeeklyTheme(for: sunSign)). Trust the rhythm of your authentic expression."
        }
        
        return "This week invites you to embody your \(sunSign.rawValue) essence more fully. The cosmos supports your journey toward authentic self-expression."
    }
    
    private func getMoonFocus(for sign: ZodiacSign) -> String {
        switch sign {
        case .aries: return "need for independence and new beginnings"
        case .taurus: return "desire for stability and sensual pleasures"
        case .gemini: return "curiosity and need for mental stimulation"
        case .cancer: return "emotional needs and desire for security"
        case .leo: return "creative expression and need for recognition"
        case .virgo: return "attention to detail and desire for improvement"
        case .libra: return "relationships and need for harmony"
        case .scorpio: return "transformation and emotional depth"
        case .sagittarius: return "expansion and philosophical exploration"
        case .capricorn: return "ambition and practical achievements"
        case .aquarius: return "innovation and humanitarian concerns"
        case .pisces: return "intuition and spiritual connection"
        }
    }
    
    private func getWeeklyTheme(for sign: ZodiacSign) -> String {
        switch sign {
        case .aries: return "initiate bold new projects"
        case .taurus: return "build lasting foundations"
        case .gemini: return "explore diverse interests"
        case .cancer: return "nurture yourself and others"
        case .leo: return "shine your unique light"
        case .virgo: return "refine and perfect your craft"
        case .libra: return "create harmony in relationships"
        case .scorpio: return "embrace transformative experiences"
        case .sagittarius: return "expand your horizons"
        case .capricorn: return "pursue meaningful goals"
        case .aquarius: return "innovate and inspire change"
        case .pisces: return "trust your intuitive wisdom"
        }
    }
    
    private func getWeeklyThemes() -> [String] {
        guard let chart = userBirthChart else {
            return ["Loading themes...", "Calculating influences...", "Preparing insights..."]
        }
        
        let sunSign = chart.sunSign
        let moonSign = chart.moonSign
        
        // Generate themes based on user's chart and current transits
        var themes: [String] = []
        
        // Theme based on sun sign
        themes.append("Embrace your \(sunSign.rawValue) nature")
        
        // Theme based on moon sign
        themes.append("Honor your \(moonSign.rawValue) emotional needs")
        
        // Theme based on current transits
        if let moonTransit = currentTransits.first(where: { $0.name == "Moon" }) {
            let transitSign = moonTransit.position.sign
            themes.append("Navigate \(transitSign.rawValue) lunar energy")
        } else {
            themes.append("Trust cosmic timing")
        }
        
        return themes
    }
}

struct WeekView: View {
    let weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    @State private var selectedDay = 3 // Thursday
    let weeklyInsight: String
    let weeklyThemes: [String]
    
    var body: some View {
        VStack(spacing: 24) {
            // Day selector
            HStack(spacing: 12) {
                ForEach(0..<7) { index in
                    VStack(spacing: 8) {
                        Text(weekDays[index])
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Circle()
                            .fill(selectedDay == index ? Color.white : Color.white.opacity(0.1))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text("\(15 + index)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(selectedDay == index ? .black : .white.opacity(0.6))
                            )
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            selectedDay = index
                        }
                    }
                }
            }
            
            // Daily insight
            AstroCard {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Today's Energy", systemImage: "waveform")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text(weeklyInsight.isEmpty ? "The cosmos is aligning your personalized insights..." : weeklyInsight)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.75))
                        .lineSpacing(6)
                }
            }
            
            // Week themes
            VStack(alignment: .leading, spacing: 16) {
                Text("This Week's Themes")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                ForEach(weeklyThemes, id: \.self) { theme in
                    HStack {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 4, height: 4)
                        
                        Text(theme)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct MonthView: View {
    let calendar = Calendar.current
    @State private var selectedDate = Date()
    
    var body: some View {
        VStack(spacing: 24) {
            // Month header
            HStack {
                Text("January 2025")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 20) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 15) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                ForEach(1..<32) { day in
                    Text("\(day)")
                        .font(.system(size: 14))
                        .foregroundColor(day == 15 ? .black : .white.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(day == 15 ? Color.white : Color.white.opacity(0.05))
                        )
                }
            }
            
            // Monthly overview
            AstroCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("January Overview")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Text("A month of new beginnings. Jupiter's influence brings expansion and opportunity. Stay grounded as you reach for the stars.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.75))
                        .lineSpacing(6)
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("Lucky Days")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            Text("7, 15, 23")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Challenge Days")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            Text("11, 19, 28")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    WeekMonthView()
}