import SwiftUI

struct WeekMonthView: View {
    @State private var selectedTimeframe: TimeFrame = .week
    @State private var selectedDate = Date()
    @State private var selectedWeekStart = Date()
    @State private var selectedMonth = Date()
    @State private var selectedYear = Date()
    @State private var currentTransits: [CelestialBody] = []
    @State private var userBirthChart: BirthChart?
    @State private var weeklyInsight = ""
    @State private var monthlyInsight = ""
    @State private var yearlyInsight = ""
    @State private var horoscopeScores: HoroscopeScores? = nil
    @State private var monthlyHoroscopeScores: HoroscopeScores? = nil
    @State private var yearlyHoroscopeScores: HoroscopeScores? = nil
    @State private var currentCycles: [AstrologicalCycle] = []
    
    // Task management to prevent crashes
    @State private var weeklyTask: Task<Void, Never>?
    @State private var monthlyTask: Task<Void, Never>?
    @State private var yearlyTask: Task<Void, Never>?
    
    enum TimeFrame {
        case week, month, year
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Header with toggle
                VStack(spacing: 20) {
                    Text("your forecast")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.white)
                    
                    // Week/Month/Year Toggle
                    HStack(spacing: 0) {
                        ForEach([TimeFrame.week, TimeFrame.month, TimeFrame.year], id: \.self) { timeframe in
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedTimeframe = timeframe
                                }
                            }) {
                                Text(timeframe == .week ? "week" : timeframe == .month ? "month" : "year")
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
                    .frame(width: 280)
                }
                .padding(.top, 20)
                
                if selectedTimeframe == .week {
                    WeekView(
                        selectedWeekStart: $selectedWeekStart,
                        weeklyInsight: weeklyInsight, 
                        weeklyThemes: getWeeklyThemes(),
                        horoscopeScores: horoscopeScores,
                        cycles: currentCycles
                    )
                } else if selectedTimeframe == .month {
                    MonthView(
                        selectedMonth: $selectedMonth,
                        monthlyInsight: monthlyInsight,
                        horoscopeScores: monthlyHoroscopeScores,
                        cycles: currentCycles
                    )
                } else {
                    YearView(
                        selectedYear: $selectedYear,
                        yearlyInsight: yearlyInsight,
                        horoscopeScores: yearlyHoroscopeScores,
                        cycles: currentCycles
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .background(Color.black)
        .onAppear {
            initializeSelectedPeriods()
            loadAstrologicalData()
        }
        .onDisappear {
            // Cancel all pending tasks to prevent crashes
            weeklyTask?.cancel()
            monthlyTask?.cancel()
            yearlyTask?.cancel()
        }
        .onChange(of: selectedWeekStart) { _ in
            loadWeeklyData()
        }
        .onChange(of: selectedMonth) { _ in
            loadMonthlyData()
        }
        .onChange(of: selectedYear) { _ in
            loadYearlyData()
        }
    }
    
    private func initializeSelectedPeriods() {
        // Initialize selected week start (Sunday of current week)
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysFromSunday = weekday - 1
        
        if let weekStart = calendar.date(byAdding: .day, value: -daysFromSunday, to: today) {
            selectedWeekStart = weekStart
        }
        
        selectedMonth = today
        selectedYear = today
    }
    
    private func loadAstrologicalData() {
        // Load user birth chart safely
        guard let birthData = UserDataManager.shared.getBirthData() else {
            print("⚠️ No birth data available")
            return
        }
        
        // Calculate birth chart on background thread to avoid blocking UI
        Task {
            guard let chart = AstrologyService.shared.calculateBirthChart(for: birthData) else {
                print("⚠️ Failed to calculate birth chart")
                return
            }
            
            await MainActor.run {
                userBirthChart = chart
                
                // Load all timeframe data
                loadWeeklyData()
                loadMonthlyData()
                loadYearlyData()
                
                // Calculate current cycles (stays the same for all timeframes)
                currentCycles = AstrologyService.shared.calculateCurrentCycles(for: chart)
                currentTransits = AstrologyService.shared.calculateCurrentTransits()
            }
        }
    }
    
    private func loadWeeklyData() {
        guard let chart = userBirthChart else { return }
        
        // Cancel any previous weekly task
        weeklyTask?.cancel()
        
        // Recalculate cycles for the selected week
        currentCycles = AstrologyService.shared.calculateCurrentCycles(for: chart, date: selectedWeekStart)
        currentTransits = AstrologyService.shared.calculateCurrentTransits(for: selectedWeekStart)
        
        // Generate insights for this specific week
        weeklyTask = Task { @MainActor in
            let freshWeeklyInsight = await AstrologyService.shared.generateWeeklyInsight(for: chart, date: selectedWeekStart)
            
            // Check if task was cancelled before updating state
            guard !Task.isCancelled else { return }
            
            weeklyInsight = freshWeeklyInsight
            horoscopeScores = AstrologyService.shared.calculateWeeklyHoroscopeScores(for: chart, date: selectedWeekStart)
        }
    }
    
    private func loadMonthlyData() {
        guard let chart = userBirthChart else { return }
        
        // Recalculate cycles for the selected month
        currentCycles = AstrologyService.shared.calculateCurrentCycles(for: chart, date: selectedMonth)
        currentTransits = AstrologyService.shared.calculateCurrentTransits(for: selectedMonth)
        
        // Cancel any previous monthly task
        monthlyTask?.cancel()
        
        // Generate insights for this specific month
        monthlyTask = Task { @MainActor in
            let freshMonthlyInsight = await AstrologyService.shared.generateMonthlyInsight(for: chart, date: selectedMonth)
            
            // Check if task was cancelled before updating state
            guard !Task.isCancelled else { return }
            
            monthlyInsight = freshMonthlyInsight
            monthlyHoroscopeScores = AstrologyService.shared.calculateMonthlyHoroscopeScores(for: chart, date: selectedMonth)
        }
    }
    
    private func loadYearlyData() {
        guard let chart = userBirthChart else { return }
        
        // Recalculate cycles for the selected year
        currentCycles = AstrologyService.shared.calculateCurrentCycles(for: chart, date: selectedYear)
        currentTransits = AstrologyService.shared.calculateCurrentTransits(for: selectedYear)
        
        // Cancel any previous yearly task
        yearlyTask?.cancel()
        
        // Generate insights for this specific year
        yearlyTask = Task { @MainActor in
            let freshYearlyInsight = await AstrologyService.shared.generateYearlyInsight(for: chart, date: selectedYear)
            
            // Check if task was cancelled before updating state
            guard !Task.isCancelled else { return }
            
            yearlyInsight = freshYearlyInsight
            yearlyHoroscopeScores = AstrologyService.shared.calculateYearlyHoroscopeScores(for: chart, date: selectedYear)
        }
    }
    
    private func generateWeeklyInsight(chart: BirthChart, transits: [CelestialBody]) -> String {
        let sunSign = chart.sunSign
        let moonSign = chart.moonSign
        
        // Generate DETERMINISTIC weekly insight based on user's chart and current week
        let weekOfYear = Calendar.current.component(.weekOfYear, from: Date())
        let year = Calendar.current.component(.year, from: Date())
        
        // Create a deterministic seed from user's chart + current week
        let chartSeed = sunSign.rawValue.hashValue ^ moonSign.rawValue.hashValue
        let timeSeed = weekOfYear ^ year
        let combinedSeed = chartSeed ^ timeSeed
        
        // Use current moon sign for primary insight direction
        if let moonTransit = transits.first(where: { $0.name == "Moon" }) {
            let currentMoonSign = moonTransit.position.sign
            
            // Get deterministic weekly insight based on Moon-Sun relationship
            let aspectAngle = abs(moonTransit.longitude - chart.sun.longitude)
            let normalizedAspect = aspectAngle > 180 ? 360 - aspectAngle : aspectAngle
            
            return generateWeeklyAspectInsight(
                natalSun: sunSign,
                natalMoon: moonSign,
                transitMoon: currentMoonSign,
                aspectDegrees: normalizedAspect,
                weekSeed: combinedSeed
            )
        }
        
        // Fallback when no moon transit - use deterministic selection
        let baseInsights = [
            "This week asks you to stop apologizing for taking up space.",
            "The version of yourself you're becoming is already here - you just need to let them out.", 
            "You've been waiting for permission to be yourself. Consider this your sign.",
            "This week teaches you the difference between what you want and what you actually need."
        ]
        
        let index = abs(combinedSeed) % baseInsights.count
        return baseInsights[index]
    }
    
    private func generateWeeklyAspectInsight(natalSun: ZodiacSign, natalMoon: ZodiacSign, transitMoon: ZodiacSign, aspectDegrees: Double, weekSeed: Int) -> String {
        
        // Generate different insights based on actual astrological aspects
        switch aspectDegrees {
        case 0...8: // Conjunction
            return "This week, your \(natalSun.rawValue) identity and current emotional climate are perfectly aligned. Trust this inner unity to guide your decisions."
            
        case 52...68: // Sextile
            return "A subtle opportunity presents itself this week. Your \(natalSun.rawValue) instincts and the current \(transitMoon.rawValue) energy are offering you a chance to grow."
            
        case 82...98: // Square  
            return "This week brings creative tension between your \(natalSun.rawValue) nature and current emotional needs. This friction is actually pushing you toward integration."
            
        case 112...128: // Trine
            return "This week flows naturally for you. Your \(natalSun.rawValue) energy and current \(transitMoon.rawValue) influences are working in perfect harmony."
            
        case 172...188: // Opposition
            return "This week asks you to balance two sides of yourself. Your \(natalSun.rawValue) nature and current emotional climate want different things - honor both."
            
        default: // No major aspect
            return generateWeeklyMoonTransitInsight(natalSun: natalSun, natalMoon: natalMoon, transitMoon: transitMoon, weekSeed: weekSeed)
        }
    }
    
    private func generateWeeklyMoonTransitInsight(natalSun: ZodiacSign, natalMoon: ZodiacSign, transitMoon: ZodiacSign, weekSeed: Int) -> String {
        
        if transitMoon == natalSun {
            return "This week amplifies your core \(natalSun.rawValue) identity. You're feeling more like yourself than usual - lean into this energy."
        } else if transitMoon == natalMoon {
            return "This week heightens your emotional patterns as a \(natalMoon.rawValue) Moon. Pay attention to what your feelings are trying to tell you."
        } else {
            // Use week seed to deterministically pick insight based on element relationship
            if transitMoon.element == natalSun.element {
                return "This week's \(transitMoon.rawValue) energy supports your natural \(natalSun.rawValue) qualities. It's a good time to express your authentic self."
            } else {
                return "This week's \(transitMoon.rawValue) energy offers a different perspective to your \(natalSun.rawValue) nature. Stay open to new ways of being."
            }
        }
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
            return ["reading your chart...", "calculating transits...", "preparing your themes..."]
        }
        
        // Generate personalized weekly themes based on actual transits
        return PersonalizedThemeGenerator.shared.generateWeeklyThemes(
            chart: chart,
            transits: currentTransits,
            count: 3
        )
    }
    
    private func getThemeForSun(_ sunSign: ZodiacSign) -> String {
        switch sunSign {
        case .aries: return "your impatience is just excitement with nowhere to go"
        case .taurus: return "comfort zones eventually become cages"
        case .gemini: return "your scattered thoughts are connecting dots others miss"
        case .cancer: return "home is a feeling you create inside first"
        case .leo: return "the spotlight's already on you, just step into it"
        case .virgo: return "good enough is sometimes exactly right"
        case .libra: return "peace isn't avoiding conflict, it's picking your battles"
        case .scorpio: return "your intensity isn't too much, most people just can't match it"
        case .sagittarius: return "the adventure you want is probably in your routine"
        case .capricorn: return "ambition without kindness to yourself is just harm"
        case .aquarius: return "your weirdness is actually your edge"
        case .pisces: return "your feelings are teaching you something, not drowning you"
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
    
    private func generateMonthlyInsight(chart: BirthChart, transits: [CelestialBody]) -> String {
        let sunSign = chart.sunSign
        let monthOfYear = Calendar.current.component(.month, from: Date())
        let year = Calendar.current.component(.year, from: Date())
        
        // Generate DETERMINISTIC monthly insight based on user's chart and current month
        var insights: [String] = []
        
        // Monthly sun sign influence
        switch sunSign {
        case .aries:
            insights.append("This month ignites your pioneering spirit, Aries. Mars energizes your leadership qualities, making this an excellent time for new ventures.")
        case .taurus:
            insights.append("Stability and growth define your month, Taurus. Venus blesses your financial and romantic endeavors with lasting foundation.")
        case .gemini:
            insights.append("Communication flows abundantly this month, Gemini. Mercury enhances your networking abilities and intellectual pursuits.")
        case .cancer:
            insights.append("Emotional depth and intuitive wisdom guide you this month, Cancer. The Moon amplifies your nurturing powers and family connections.")
        case .leo:
            insights.append("Creative expression reaches new heights this month, Leo. The Sun illuminates your talents and brings recognition to your efforts.")
        case .virgo:
            insights.append("Practical perfection is your superpower this month, Virgo. Mercury sharpens your analytical skills and attention to detail.")
        case .libra:
            insights.append("Balance and harmony characterize your month, Libra. Venus enhances your diplomatic abilities and aesthetic sensibilities.")
        case .scorpio:
            insights.append("Transformation and regeneration mark this powerful month, Scorpio. Pluto reveals hidden truths and deep psychological insights.")
        case .sagittarius:
            insights.append("Expansion and adventure beckon this month, Sagittarius. Jupiter opens doors to higher learning and philosophical growth.")
        case .capricorn:
            insights.append("Ambitious goals materialize this month, Capricorn. Saturn rewards your discipline with concrete achievements and recognition.")
        case .aquarius:
            insights.append("Innovation and humanitarian ideals inspire you this month, Aquarius. Uranus brings revolutionary ideas and progressive connections.")
        case .pisces:
            insights.append("Spiritual awakening and creative inspiration flow this month, Pisces. Neptune dissolves boundaries and enhances your intuitive gifts.")
        }
        
        // Monthly transit influences based on current planetary positions
        if let jupiter = transits.first(where: { $0.name == "Jupiter" }) {
            let jupiterDegree = Int(jupiter.longitude) % 30
            if jupiterDegree < 10 {
                insights.append("Jupiter's early degrees bring fresh opportunities for expansion in your chosen field.")
            } else if jupiterDegree < 20 {
                insights.append("Jupiter's middle passage amplifies your natural talents and brings beneficial connections.")
            } else {
                insights.append("Jupiter's late degrees prepare you for a significant breakthrough or achievement.")
            }
        }
        
        // Monthly themes based on current month
        switch monthOfYear {
        case 1: insights.append("January's New Year energy supports fresh starts and goal-setting.")
        case 2: insights.append("February's introspective energy encourages deep reflection and planning.")
        case 3: insights.append("March's awakening energy brings renewal and emerging opportunities.")
        case 4: insights.append("April's growth energy supports new beginnings and creative projects.")
        case 5: insights.append("May's abundance energy enhances material prosperity and sensual pleasures.")
        case 6: insights.append("June's communication energy facilitates important conversations and connections.")
        case 7: insights.append("July's emotional energy deepens relationships and family bonds.")
        case 8: insights.append("August's creative energy brings artistic inspiration and self-expression.")
        case 9: insights.append("September's harvest energy rewards hard work with tangible results.")
        case 10: insights.append("October's balance energy promotes harmony in relationships and partnerships.")
        case 11: insights.append("November's transformation energy brings profound change and regeneration.")
        case 12: insights.append("December's culmination energy brings closure and preparation for new cycles.")
        default: break
        }
        
        return insights.joined(separator: " ")
    }
    
    private func generateYearlyInsight(chart: BirthChart, transits: [CelestialBody]) -> String {
        let sunSign = chart.sunSign
        let year = Calendar.current.component(.year, from: Date())
        
        // Generate DETERMINISTIC yearly insight based on user's chart and current year
        var insights: [String] = []
        
        // Yearly overarching theme based on sun sign and year number
        let yearDigitSum = String(year).compactMap { Int(String($0)) }.reduce(0, +)
        let yearTheme = yearDigitSum % 9 + 1
        
        switch yearTheme {
        case 1: insights.append("This is a year of new beginnings and pioneering ventures.")
        case 2: insights.append("This is a year of cooperation, partnerships, and building relationships.")
        case 3: insights.append("This is a year of creative expression, communication, and artistic endeavors.")
        case 4: insights.append("This is a year of hard work, foundation building, and practical achievements.")
        case 5: insights.append("This is a year of freedom, adventure, and dynamic change.")
        case 6: insights.append("This is a year of responsibility, nurturing, and family focus.")
        case 7: insights.append("This is a year of spiritual growth, introspection, and inner wisdom.")
        case 8: insights.append("This is a year of material success, achievement, and recognition.")
        case 9: insights.append("This is a year of completion, humanitarian service, and universal understanding.")
        default: break
        }
        
        // Yearly sun sign influence
        switch sunSign {
        case .aries:
            insights.append("Your Aries energy drives you to lead groundbreaking initiatives and embrace bold challenges throughout the year.")
        case .taurus:
            insights.append("Your Taurus nature guides you to build lasting value and secure foundations in all areas of life this year.")
        case .gemini:
            insights.append("Your Gemini adaptability helps you navigate diverse opportunities and form meaningful intellectual connections this year.")
        case .cancer:
            insights.append("Your Cancer intuition deepens family bonds and emotional security while nurturing your long-term dreams this year.")
        case .leo:
            insights.append("Your Leo radiance attracts recognition and creative opportunities while inspiring others through your authentic leadership this year.")
        case .virgo:
            insights.append("Your Virgo precision perfects important systems and processes while serving others through your dedicated efforts this year.")
        case .libra:
            insights.append("Your Libra diplomacy creates beautiful partnerships and harmonious environments while advancing justice and aesthetic ideals this year.")
        case .scorpio:
            insights.append("Your Scorpio intensity transforms deep-seated patterns and emerges with powerful regenerative insights this year.")
        case .sagittarius:
            insights.append("Your Sagittarius vision expands your horizons through higher learning, travel, and philosophical exploration this year.")
        case .capricorn:
            insights.append("Your Capricorn determination achieves significant milestones and establishes your authority in your chosen field this year.")
        case .aquarius:
            insights.append("Your Aquarius innovation revolutionizes traditional approaches while contributing to collective progress and humanitarian causes this year.")
        case .pisces:
            insights.append("Your Pisces compassion channels divine inspiration into creative and healing work that touches many lives this year.")
        }
        
        // Major yearly transits and themes
        if let saturn = transits.first(where: { $0.name == "Saturn" }) {
            let saturnSignInfo = ZodiacSign.fromDegrees(saturn.longitude)
            let saturnSign = saturnSignInfo.sign
            insights.append("Saturn in \(saturnSign) teaches valuable lessons about discipline and long-term planning throughout the year.")
        }
        
        if let jupiter = transits.first(where: { $0.name == "Jupiter" }) {
            let jupiterSignInfo = ZodiacSign.fromDegrees(jupiter.longitude)
            let jupiterSign = jupiterSignInfo.sign
            insights.append("Jupiter in \(jupiterSign) expands opportunities and brings blessings in areas related to growth and wisdom.")
        }
        
        return insights.joined(separator: " ")
    }
}

// MARK: - Weekly Insight Sections
struct WeeklyInsightSections: View {
    let weeklyInsight: String
    let selectedWeekStart: Date
    
    private var currentWeekRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        
        let calendar = Calendar.current
        
        // Get end of selected week (Saturday)
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: selectedWeekStart) else {
            return "This Week"
        }
        
        return "\(formatter.string(from: selectedWeekStart)) - \(formatter.string(from: weekEnd))"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Week range header
            HStack {
                Text(currentWeekRange)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                    )
                
                Spacer()
            }
            
            // Weekly insight cards
            VStack(spacing: 16) {
                // Main weekly insight
                WeeklyInsightCard(
                    title: "overall energy",
                    content: weeklyInsight.isEmpty ? "calculating your week..." : weeklyInsight,
                    icon: "waveform"
                )
                
                // Weekly themes with comprehensive content like reference
                WeeklyInsightCard(
                    title: "Wealth",
                    subtitle: "Embrace new financial prospects.",
                    content: "New financial possibilities are opening up for you this week. You could come across a promising investment, receive a work-related bonus, or find an unexpected avenue to generate extra income. Both singles and couples should stay alert and ready to capitalize on these opportunities. Make informed choices and consider reinvesting some of your gains. This proactive mindset can significantly enhance your financial well-being and pave the way for future prosperity.",
                    icon: "brain.head.profile",
                    isHighlighted: true
                )
                
                WeeklyInsightCard(
                    title: "Love & Relationships",
                    subtitle: "Heart connections deepen this week.",
                    content: "This week brings a beautiful opportunity to strengthen your romantic connections. If you're in a relationship, expect deeper conversations and moments of genuine intimacy. Single? The universe is aligning to bring someone special into your orbit. Pay attention to the positive energy around you - it can lead to delightful experiences in love. Trust your intuition when it comes to matters of the heart.",
                    icon: "heart"
                )
                
                WeeklyInsightCard(
                    title: "Career & Growth",
                    subtitle: "Professional advancement awaits.",
                    content: "Your professional life takes on new momentum this week. A project you've been working on may finally gain the recognition it deserves, or you might receive an opportunity to showcase your skills to influential people. Leadership qualities emerge naturally, making this an excellent time to take initiative on important matters.",
                    icon: "briefcase"
                )
            }
        }
    }
}

struct WeeklyInsightCard: View {
    let title: String
    let subtitle: String?
    let content: String
    let icon: String
    let isHighlighted: Bool
    
    init(title: String, subtitle: String? = nil, content: String, icon: String, isHighlighted: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.icon = icon
        self.isHighlighted = isHighlighted
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with title and icon
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(.white.opacity(0.8))
                            .italic()
                    }
                }
                
                Spacer()
                
                if isHighlighted {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // Content with proper spacing and formatting
            Text(content)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(isHighlighted ? 0.08 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct WeekView: View {
    @Binding var selectedWeekStart: Date
    let weeklyInsight: String
    let weeklyThemes: [String]
    let horoscopeScores: HoroscopeScores?
    let cycles: [AstrologicalCycle]
    
    var body: some View {
        VStack(spacing: 24) {
            // Week Selector
            WeekSelector(selectedWeekStart: $selectedWeekStart)
            
            // Horoscope Scores
            if let scores = horoscopeScores {
                VStack(spacing: 24) {
                    // Four progress circles
                    HStack(spacing: 20) {
                        ProgressCircle(
                            title: "Overall",
                            score: scores.overall,
                            color: .white,
                            animate: true
                        )
                        
                        ProgressCircle(
                            title: "Love",
                            score: scores.love,
                            color: .white,
                            animate: true
                        )
                        
                        ProgressCircle(
                            title: "Career",
                            score: scores.career,
                            color: .white,
                            animate: true
                        )
                        
                        ProgressCircle(
                            title: "Wealth",
                            score: scores.wealth,
                            color: .white,
                            animate: true
                        )
                    }
                    
                    // Cosmic divider
                    CosmicDivider()
                }
            }
            
            // Weekly insight sections
            WeeklyInsightSections(weeklyInsight: weeklyInsight, selectedWeekStart: selectedWeekStart)
            
            // Cycles
            if !cycles.isEmpty {
                CyclesView(cycles: cycles)
            }
            
            // Week themes
            VStack(alignment: .leading, spacing: 16) {
                Text("this week's themes")
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

// MARK: - Monthly Insight Sections
struct MonthlyInsightSections: View {
    let monthlyInsight: String
    let selectedMonth: Date

    private var currentMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Month header
            HStack {
                Text(currentMonthYear)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                    )

                Spacer()
            }

            // Monthly insight cards
            VStack(spacing: 16) {
                // Main monthly insight
                MonthlyInsightCard(
                    title: "overall energy",
                    content: monthlyInsight.isEmpty ? "reading your month..." : monthlyInsight,
                    icon: "sparkles"
                )

                // Monthly themes with comprehensive content
                MonthlyInsightCard(
                    title: "Expansion & Growth",
                    subtitle: "Jupiter's monthly influence unfolds.",
                    content: "This month brings significant opportunities for personal and professional expansion. Jupiter's benefic influence creates pathways for growth that may have seemed impossible before. Whether through education, travel, publishing, or teaching, you're being called to step into a larger version of yourself. The key is to remain open to opportunities that stretch your comfort zone while staying grounded in your values.",
                    icon: "arrow.up.right.circle",
                    isHighlighted: true
                )

                MonthlyInsightCard(
                    title: "Relationships & Harmony",
                    subtitle: "Venus weaves connection through your month.",
                    content: "Your relationships take on new depth and meaning this month. Whether you're single or partnered, there's a beautiful energy around heart connections. For those in relationships, expect moments of renewed intimacy and understanding. Singles may find that meaningful connections come through unexpected channels. This is also an excellent time for healing old relationship wounds and attracting people who truly appreciate your authentic self.",
                    icon: "heart.circle"
                )

                MonthlyInsightCard(
                    title: "Career & Purpose",
                    subtitle: "Professional momentum builds steadily.",
                    content: "Your career path gains clarity and momentum this month. A project or goal you've been working toward reaches an important milestone, bringing both recognition and new opportunities. This is an excellent time to network, share your expertise, and position yourself for future advancement. Trust your professional instincts and don't be afraid to advocate for yourself when opportunities arise.",
                    icon: "briefcase.circle"
                )

                MonthlyInsightCard(
                    title: "Financial Flow",
                    subtitle: "Abundance streams in new directions.",
                    content: "Financial opportunities present themselves through multiple channels this month. Whether through your primary income source, investments, or unexpected windfalls, money flows more freely than usual. This is an ideal time to make strategic financial decisions, invest in your education or business, and set up systems for long-term wealth building. Pay attention to intuitive hunches about financial opportunities.",
                    icon: "dollarsign.circle"
                )
            }
        }
    }
}

struct MonthlyInsightCard: View {
    let title: String
    let subtitle: String?
    let content: String
    let icon: String
    let isHighlighted: Bool

    init(title: String, subtitle: String? = nil, content: String, icon: String, isHighlighted: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.icon = icon
        self.isHighlighted = isHighlighted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with title and icon
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(title)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    }
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(.white.opacity(0.8))
                            .italic()
                    }
                }
                
                Spacer()
                
                if isHighlighted {
                    Image(systemName: "star.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // Content with proper spacing and formatting
            Text(content)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
                        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(isHighlighted ? 0.08 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct MonthView: View {
    @Binding var selectedMonth: Date
    let monthlyInsight: String
    let horoscopeScores: HoroscopeScores?
    let cycles: [AstrologicalCycle]
    
    var body: some View {
        VStack(spacing: 24) {
            // Month Selector
            MonthSelector(selectedMonth: $selectedMonth)
            
            // Horoscope Scores
            if let scores = horoscopeScores {
                VStack(spacing: 24) {
                    // Four progress circles
                    HStack(spacing: 20) {
                        ProgressCircle(
                            title: "Overall",
                            score: scores.overall,
                            color: .white,
                            animate: true
                        )
                        
                        ProgressCircle(
                            title: "Love",
                            score: scores.love,
                            color: .white,
                            animate: true
                        )
                        
                        ProgressCircle(
                            title: "Career",
                            score: scores.career,
                            color: .white,
                            animate: true
                        )
                        
                        ProgressCircle(
                            title: "Wealth",
                            score: scores.wealth,
                            color: .white,
                            animate: true
                        )
                    }
                    
                    // Cosmic divider
                    CosmicDivider()
                }
            }
            
            // Monthly insight sections
            MonthlyInsightSections(monthlyInsight: monthlyInsight, selectedMonth: selectedMonth)
            
            // Cycles
            if !cycles.isEmpty {
                CyclesView(cycles: cycles)
            }
            
            // Monthly themes
                VStack(alignment: .leading, spacing: 16) {
                Text("this month's themes")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                ForEach(getMonthlyThemes(), id: \.self) { theme in
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
    
    private func getMonthlyThemes() -> [String] {
        let month = Calendar.current.component(.month, from: Date())
        let year = Calendar.current.component(.year, from: Date())
        
        // Monthly themes based on current month and astrological influences
        var themes: [String] = []
        
        switch month {
        case 1:
            themes = [
                "New year, new you - but honor who you've always been",
                "Set intentions that feel expansive, not restrictive",
                "Your past self would be proud of your growth"
            ]
        case 2:
            themes = [
                "Love yourself through the shadows and the light",
                "February's energy supports deep heart connections",
                "Emotional intelligence becomes your superpower"
            ]
        case 3:
            themes = [
                "Spring awakening brings fresh perspective on old patterns",
                "Trust your intuition over other people's opinions",
                "Growth happens in the space between comfort and fear"
            ]
        case 4:
            themes = [
                "Plant seeds for the garden you want to harvest later",
                "April's energy supports new creative ventures",
                "Your ideas need action to become reality"
            ]
        case 5:
            themes = [
                "Abundance flows when you release scarcity mindset",
                "May's Taurus energy grounds your wildest dreams",
                "Slow and steady wins the race this month"
            ]
        case 6:
            themes = [
                "Communication is the bridge to deeper connection",
                "June's Gemini energy sparks intellectual curiosity",
                "The conversations you're avoiding need to happen"
            ]
        case 7:
            themes = [
                "Home is wherever you feel most authentically yourself",
                "July's Cancer energy prioritizes emotional security",
                "Nurture your dreams like you would a garden"
            ]
        case 8:
            themes = [
                "Your authentic self is your greatest asset",
                "August's Leo energy illuminates your natural talents",
                "Confidence is quiet, insecurity is loud"
            ]
        case 9:
            themes = [
                "September's harvest energy rewards your hard work",
                "Perfection is the enemy of progress",
                "Organization creates space for inspiration"
            ]
        case 10:
            themes = [
                "Balance is not a destination, it's a daily practice",
                "October's Libra energy seeks harmony in relationships",
                "Diplomacy doesn't mean sacrificing your truth"
            ]
        case 11:
            themes = [
                "Transformation requires releasing what no longer serves",
                "November's Scorpio energy brings profound regeneration",
                "Your intensity is a gift, not something to apologize for"
            ]
        case 12:
            themes = [
                "Adventure begins at the edge of your comfort zone",
                "December's Sagittarius energy expands your horizons",
                "The year ends with wisdom you didn't have in January"
            ]
        default:
            themes = [
                "Trust the timing of your life",
                "Every season serves its purpose",
                "Your journey is uniquely yours"
            ]
        }
        
        return themes
    }
}

// MARK: - Yearly Insight Sections
struct YearlyInsightSections: View {
    let yearlyInsight: String
    let selectedYear: Date

    private var currentYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: selectedYear)
    }

    var body: some View {
        VStack(spacing: 20) {
            // Year header
            HStack {
                Text(currentYear)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                    )

                Spacer()
            }

            // Yearly insight cards
            VStack(spacing: 16) {
                // Main yearly insight
                YearlyInsightCard(
                    title: "overall energy",
                    content: yearlyInsight.isEmpty ? "mapping your year..." : yearlyInsight,
                    icon: "sun.max"
                )

                // Yearly themes with comprehensive content
                YearlyInsightCard(
                    title: "Life Purpose & Soul Mission",
                    subtitle: "Your authentic path unfolds this year.",
                    content: "This year marks a significant chapter in your soul's journey. The universe is aligning circumstances to help you step more fully into your authentic purpose. Whether through career shifts, spiritual awakening, or deep personal transformation, you're being called to embrace your unique gifts and share them with the world. Trust the process even when the path seems unclear - your soul knows the way.",
                    icon: "star.circle",
                    isHighlighted: true
                )

                YearlyInsightCard(
                    title: "Transformation & Regeneration",
                    subtitle: "Pluto's influence brings profound change.",
                    content: "Deep, structural changes characterize this year's energy. Like a phoenix rising from ashes, you're releasing old patterns, relationships, and belief systems that no longer serve your highest good. This process may feel intense at times, but it's ultimately liberating. You're becoming more authentically yourself by shedding layers of conditioning and expectation. Embrace the metamorphosis.",
                    icon: "arrow.clockwise.circle"
                )

                YearlyInsightCard(
                    title: "Relationships & Legacy",
                    subtitle: "Connections that matter take center stage.",
                    content: "Your relationships undergo significant evolution this year. Some connections deepen into soul-level bonds, while others naturally fade as you both grow in different directions. New relationships that enter your life this year carry karmic significance and may play important roles in your long-term journey. Focus on quality over quantity in all your connections.",
                    icon: "heart.text.square"
                )

                YearlyInsightCard(
                    title: "Material Mastery & Abundance",
                    subtitle: "Financial wisdom comes through experience.",
                    content: "This year teaches important lessons about money, resources, and material security. Whether through investment opportunities, career advancement, or learning to manage resources more wisely, you're developing a healthier relationship with material abundance. The key is balancing practical financial planning with trust in universal provision. Your relationship with money reflects your relationship with self-worth.",
                    icon: "banknote.circle"
                )

                YearlyInsightCard(
                    title: "Spiritual Evolution & Wisdom",
                    subtitle: "Higher consciousness awakens within.",
                    content: "Your spiritual understanding deepens significantly this year. Whether through meditation, study, travel, or direct mystical experience, you're accessing higher levels of consciousness and wisdom. This spiritual growth affects all areas of your life, bringing greater compassion, intuition, and understanding of life's deeper mysteries. Trust your inner guidance more than external authorities.",
                    icon: "moon.stars.circle"
                )
            }
        }
    }
}

struct YearlyInsightCard: View {
    let title: String
    let subtitle: String?
    let content: String
    let icon: String
    let isHighlighted: Bool

    init(title: String, subtitle: String? = nil, content: String, icon: String, isHighlighted: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.icon = icon
        self.isHighlighted = isHighlighted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with title and icon
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(title)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(.white.opacity(0.8))
                            .italic()
                    }
                }
                
                Spacer()
                
                if isHighlighted {
                    Image(systemName: "crown.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // Content with proper spacing and formatting
            Text(content)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(isHighlighted ? 0.08 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct YearView: View {
    @Binding var selectedYear: Date
    let yearlyInsight: String
    let horoscopeScores: HoroscopeScores?
    let cycles: [AstrologicalCycle]
    
    var body: some View {
        VStack(spacing: 24) {
            // Year Selector
            YearSelector(selectedYear: $selectedYear)
            
            // Horoscope Scores
            if let scores = horoscopeScores {
                VStack(spacing: 24) {
                    // Four progress circles
                    HStack(spacing: 20) {
                        ProgressCircle(
                            title: "Overall",
                            score: scores.overall,
                            color: .white,
                            animate: true
                        )
                        
                        ProgressCircle(
                            title: "Love",
                            score: scores.love,
                            color: .white,
                            animate: true
                        )
                        
                        ProgressCircle(
                            title: "Career",
                            score: scores.career,
                            color: .white,
                            animate: true
                        )
                        
                        ProgressCircle(
                            title: "Wealth",
                            score: scores.wealth,
                            color: .white,
                            animate: true
                        )
                    }
                    
                    // Cosmic divider
                    CosmicDivider()
                }
            }
            
            // Yearly insight sections
            YearlyInsightSections(yearlyInsight: yearlyInsight, selectedYear: selectedYear)
            
            // Cycles
            if !cycles.isEmpty {
                CyclesView(cycles: cycles)
            }
            
            // Yearly themes
            VStack(alignment: .leading, spacing: 16) {
                Text("this year's major themes")
                    .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                
                ForEach(getYearlyThemes(), id: \.self) { theme in
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
    
    private func getYearlyThemes() -> [String] {
        let year = Calendar.current.component(.year, from: Date())
        
        // Calculate year number for numerological themes
        let yearDigitSum = String(year).compactMap { Int(String($0)) }.reduce(0, +)
        let yearNumber = yearDigitSum % 9 + 1
        
        var themes: [String] = []
        
        switch yearNumber {
        case 1:
            themes = [
                "New beginnings and fresh starts define your year",
                "Leadership opportunities emerge naturally",
                "Independence and self-reliance grow stronger",
                "Pioneer new paths that others will follow"
            ]
        case 2:
            themes = [
                "Cooperation and partnerships take center stage",
                "Patience and diplomacy serve you well",
                "Emotional intelligence deepens significantly",
                "Balance becomes your greatest strength"
            ]
        case 3:
            themes = [
                "Creative expression flows through every area of life",
                "Communication skills reach new heights",
                "Social connections bring unexpected opportunities",
                "Optimism and enthusiasm attract abundance"
            ]
        case 4:
            themes = [
                "Foundation building for long-term success",
                "Hard work and discipline pay off handsomely",
                "Systems and structures support your goals",
                "Practical wisdom guides important decisions"
            ]
        case 5:
            themes = [
                "Freedom and adventure call your name",
                "Change and variety keep life interesting",
                "Travel or relocation brings new perspectives",
                "Versatility becomes your secret weapon"
            ]
        case 6:
            themes = [
                "Family and community responsibilities increase",
                "Nurturing others brings deep satisfaction",
                "Home and healing become priorities",
                "Service to others fulfills your soul's purpose"
            ]
        case 7:
            themes = [
                "Spiritual growth and inner development accelerate",
                "Solitude and reflection provide valuable insights",
                "Mystical experiences deepen your understanding",
                "Research and study reveal hidden truths"
            ]
        case 8:
            themes = [
                "Material success and recognition arrive",
                "Business acumen and financial wisdom grow",
                "Authority and influence expand naturally",
                "Achievement and accomplishment feel effortless"
            ]
        case 9:
            themes = [
                "Completion of major life cycles",
                "Humanitarian service calls your heart",
                "Wisdom sharing becomes your gift to the world",
                "Universal love and compassion guide actions"
            ]
        default:
            themes = [
                "This year brings unique lessons for your soul",
                "Trust the cosmic timing of your experiences",
                "Your journey is perfectly orchestrated",
                "Growth happens through both joy and challenge"
            ]
        }
        
        // Add universal yearly themes
        themes.append("The universe conspires to support your highest good")
        themes.append("Every experience contributes to your soul's evolution")
        
        return themes
    }
}

#Preview {
    WeekMonthView()
}