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
        let moonSign = chart.moonSign
        
        // Generate Co-Star style weekly insights
        let weeklyInsights = [
            "This week asks you to stop apologizing for taking up space.",
            "The version of yourself you're becoming is already here - you just need to let them out.",
            "This week, your biggest breakthrough comes disguised as your biggest breakdown.",
            "You've been waiting for permission to be yourself. Consider this your sign.",
            "This week teaches you the difference between what you want and what you actually need.",
            "The resistance you're feeling isn't a stop sign - it's a muscle you need to build.",
            "This week, your intuition gets louder than your anxiety. Finally.",
            "You're not falling behind - you're taking a different path. Trust the detour.",
            "This week shows you that vulnerability and strength aren't opposites.",
            "The person you were last week couldn't handle what's coming next. Good thing you're evolving.",
        ]
        
        // Add sign-specific insights
        let signSpecificInsights = getWeeklyInsightsForSign(sunSign: sunSign, moonSign: moonSign, transits: transits)
        
        return (weeklyInsights + signSpecificInsights).randomElement() ?? "This week, trust the process even when you can't see the outcome."
    }
    
    
    private func getWeeklyInsightsForSign(sunSign: ZodiacSign, moonSign: ZodiacSign, transits: [CelestialBody]) -> [String] {
        var insights: [String] = []
        
        // Sun sign specific weekly insights
        switch sunSign {
        case .aries:
            insights.append("This week, your impatience is actually your superpower in disguise.")
            insights.append("The project you've been putting off? Your future self is waiting for you to start it.")
            
        case .taurus:
            insights.append("This week teaches you that comfort zones are only comfortable until they become cages.")
            insights.append("Your stubbornness this week is actually your values trying to protect you.")
            
        case .gemini:
            insights.append("This week, your scattered energy is actually you gathering intel for something bigger.")
            insights.append("That conversation you've been avoiding contains the answer you've been seeking.")
            
        case .cancer:
            insights.append("This week, your sensitivity picks up on what everyone else is missing.")
            insights.append("The home you're trying to create exists first in your heart, then in the world.")
            
        case .leo:
            insights.append("This week, the spotlight you crave is already on you - you just need to step into it.")
            insights.append("Your need for recognition this week is really your soul asking to be seen authentically.")
            
        case .virgo:
            insights.append("This week shows you that perfectionism is just fear wearing a productivity mask.")
            insights.append("The details you're obsessing over matter less than the courage to begin.")
            
        case .libra:
            insights.append("This week, your people-pleasing reveals where you've been abandoning yourself.")
            insights.append("The balance you seek isn't about making everyone happy - it's about choosing your battles.")
            
        case .scorpio:
            insights.append("This week, what you think is paranoia is actually pattern recognition.")
            insights.append("The transformation you fear is the one you've been unconsciously choosing all along.")
            
        case .sagittarius:
            insights.append("This week, your restlessness is your compass pointing toward unexplored territory.")
            insights.append("The adventure you're seeking is hidden in the routine you're trying to escape.")
            
        case .capricorn:
            insights.append("This week teaches you that ambition without self-compassion is just elaborate self-harm.")
            insights.append("The mountain you're climbing is also climbing you. Let it change you.")
            
        case .aquarius:
            insights.append("This week, your need to be different conflicts with your need to belong. Both are valid.")
            insights.append("The revolution you want to see in the world starts with the one in your mirror.")
            
        case .pisces:
            insights.append("This week, your empathy shows you truths that logic can't reach.")
            insights.append("The dream you had isn't just a dream - it's your subconscious working through something real.")
        }
        
        return insights
    }
    
    private func getWeeklyThemes() -> [String] {
        guard let chart = userBirthChart else {
            return ["Preparing your cosmic insights...", "Aligning with your birth chart...", "Calculating your weekly themes..."]
        }
        
        let sunSign = chart.sunSign
        let moonSign = chart.moonSign
        
        // Generate relatable, Co-Star style themes
        let universalThemes = [
            "Stop explaining yourself to people who are determined to misunderstand you",
            "Your intuition is louder than your anxiety this week",
            "The thing you're avoiding is the thing that will set you free",
            "Your past self would be proud of how far you've come",
            "Trust the process even when you can't see the outcome",
            "Your sensitivity is a superpower, not a weakness",
            "The person you're becoming is worth the discomfort",
            "Your boundaries are love letters to your future self"
        ]
        
        // Add sign-specific themes
        let signSpecificThemes = [
            getThemeForSun(sunSign),
            getThemeForMoon(moonSign),
            getThemeForCurrentEnergy()
        ]
        
        let allThemes = universalThemes + signSpecificThemes
        return Array(allThemes.shuffled().prefix(3))
    }
    
    private func getThemeForSun(_ sunSign: ZodiacSign) -> String {
        switch sunSign {
        case .aries: return "Your impatience is just excitement with nowhere to go"
        case .taurus: return "Comfort zones are only comfortable until they become cages"
        case .gemini: return "Your scattered thoughts are connecting dots others can't see"
        case .cancer: return "Creating home in your heart before anywhere else"
        case .leo: return "The spotlight is already on you - step into it"
        case .virgo: return "Good enough is actually perfect timing"
        case .libra: return "Peace isn't about avoiding conflict - it's about choosing your battles"
        case .scorpio: return "Your intensity isn't too much - the world is just too small"
        case .sagittarius: return "The adventure you seek is hiding in your daily routine"
        case .capricorn: return "Ambition without self-compassion is just elaborate self-harm"
        case .aquarius: return "Your weirdness is your superpower in disguise"
        case .pisces: return "Your emotions are teaching you to swim, not drowning you"
        }
    }
    
    private func getThemeForMoon(_ moonSign: ZodiacSign) -> String {
        switch moonSign {
        case .aries: return "Honor your need for emotional independence"
        case .taurus: return "Your craving for comfort is actually wisdom"
        case .gemini: return "Process your feelings by talking them through"
        case .cancer: return "Vulnerability is strength when it's a choice"
        case .leo: return "Your emotions deserve an audience - start with yourself"
        case .virgo: return "Stop trying to fix your feelings and start listening to them"
        case .libra: return "You can't keep the peace by abandoning yourself"
        case .scorpio: return "Feel everything deeply - that's where your power lives"
        case .sagittarius: return "Your emotional restlessness is pointing toward growth"
        case .capricorn: return "Structure your feelings without suppressing them"
        case .aquarius: return "Your emotional detachment is self-protection, not indifference"
        case .pisces: return "Your empathy needs boundaries to stay a gift"
        }
    }
    
    private func getThemeForCurrentEnergy() -> String {
        if let moonTransit = currentTransits.first(where: { $0.name == "Moon" }) {
            let transitSign = moonTransit.position.sign
            switch transitSign {
            case .aries: return "Act on your impulses - they're smarter than you think"
            case .taurus: return "Slow down and savor the moment you're in"
            case .gemini: return "Have the conversations you've been avoiding"
            case .cancer: return "Trust your emotional instincts over logic"
            case .leo: return "Let yourself be seen exactly as you are"
            case .virgo: return "The details matter, but don't lose sight of the bigger picture"
            case .libra: return "Seek harmony without sacrificing authenticity"
            case .scorpio: return "Go deeper - surface level won't satisfy you"
            case .sagittarius: return "Expand your perspective beyond what feels safe"
            case .capricorn: return "Build something that will outlast your doubts"
            case .aquarius: return "Break the rules that were never serving you anyway"
            case .pisces: return "Trust the feelings you can't quite explain"
            }
        }
        
        return "The universe is conspiring to help you, not against you"
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