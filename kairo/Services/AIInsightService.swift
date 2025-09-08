import Foundation

/// Service for generating AI-powered astrological insights using Claude API
class AIInsightService: ObservableObject {
    static let shared = AIInsightService()
    
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    private var urlSession: URLSession
    private var cache: NSCache<NSString, NSString>
    
    private init() {
        // Load API key from APIKeys.plist (not committed to git)
        if let path = Bundle.main.path(forResource: "APIKeys", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let key = plist["OPENAI_API_KEY"] as? String {
            self.apiKey = key
        } else {
            // Fallback for development - TODO: Create APIKeys.plist with your key
            self.apiKey = ""
            print("⚠️ Warning: Please create APIKeys.plist with OPENAI_API_KEY to enable AI features.")
            print("📋 Instructions: Create kairo/APIKeys.plist and add your OpenAI API key")
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: config)
        
        self.cache = NSCache<NSString, NSString>()
        self.cache.countLimit = 100 // Cache up to 100 insights
    }
    
    // MARK: - Public Interface
    
    /// Generate a personalized daily insight
    func generateDailyInsight(for chart: BirthChart, transits: [CelestialBody]) async -> String {
        let cacheKey = createCacheKey(type: "daily", chart: chart, date: Date())
        
        // Check cache first
        if let cachedInsight = cache.object(forKey: cacheKey as NSString) {
            return String(cachedInsight)
        }
        
        let prompt = createDailyInsightPrompt(chart: chart, transits: transits)
        
        do {
            let insight = try await callOpenAIAPI(prompt: prompt, maxTokens: 300)
            cache.setObject(insight as NSString, forKey: cacheKey as NSString)
            return insight
        } catch {
            print("Failed to generate AI daily insight: \(error)")
            return createFallbackDailyInsight(chart: chart, transits: transits)
        }
    }
    
    /// Generate a personalized weekly insight
    func generateWeeklyInsight(for chart: BirthChart, transits: [CelestialBody]) async -> String {
        let cacheKey = createCacheKey(type: "weekly", chart: chart, date: Date())
        
        if let cachedInsight = cache.object(forKey: cacheKey as NSString) {
            return String(cachedInsight)
        }
        
        let prompt = createWeeklyInsightPrompt(chart: chart, transits: transits)
        
        do {
            let insight = try await callOpenAIAPI(prompt: prompt, maxTokens: 400)
            cache.setObject(insight as NSString, forKey: cacheKey as NSString)
            return insight
        } catch {
            print("Failed to generate AI weekly insight: \(error)")
            return createFallbackWeeklyInsight(chart: chart, transits: transits)
        }
    }
    
    /// Generate a personalized monthly insight
    func generateMonthlyInsight(for chart: BirthChart, transits: [CelestialBody]) async -> String {
        let cacheKey = createCacheKey(type: "monthly", chart: chart, date: Date())
        
        if let cachedInsight = cache.object(forKey: cacheKey as NSString) {
            return String(cachedInsight)
        }
        
        let prompt = createMonthlyInsightPrompt(chart: chart, transits: transits)
        
        do {
            let insight = try await callOpenAIAPI(prompt: prompt, maxTokens: 500)
            cache.setObject(insight as NSString, forKey: cacheKey as NSString)
            return insight
        } catch {
            print("Failed to generate AI monthly insight: \(error)")
            return createFallbackMonthlyInsight(chart: chart, transits: transits)
        }
    }
    
    /// Generate a personalized yearly insight
    func generateYearlyInsight(for chart: BirthChart, transits: [CelestialBody]) async -> String {
        let cacheKey = createCacheKey(type: "yearly", chart: chart, date: Date())
        
        if let cachedInsight = cache.object(forKey: cacheKey as NSString) {
            return String(cachedInsight)
        }
        
        let prompt = createYearlyInsightPrompt(chart: chart, transits: transits)
        
        do {
            let insight = try await callOpenAIAPI(prompt: prompt, maxTokens: 600)
            cache.setObject(insight as NSString, forKey: cacheKey as NSString)
            return insight
        } catch {
            print("Failed to generate AI yearly insight: \(error)")
            return createFallbackYearlyInsight(chart: chart, transits: transits)
        }
    }
    
    /// Generate personalized cycle insights
    func generateCycleInsight(for cycles: [AstrologicalCycle], chart: BirthChart) async -> String {
        let prompt = createCycleInsightPrompt(cycles: cycles, chart: chart)
        
        do {
            return try await callOpenAIAPI(prompt: prompt, maxTokens: 400)
        } catch {
            print("Failed to generate AI cycle insight: \(error)")
            return createFallbackCycleInsight(cycles: cycles, chart: chart)
        }
    }
    
    /// Generate a personalized chat response
    func generateChatResponse(question: String, chart: BirthChart) async -> String {
        let prompt = createChatPrompt(question: question, chart: chart)
        
        do {
            return try await callOpenAIAPI(prompt: prompt, maxTokens: 250)
        } catch {
            print("Failed to generate AI chat response: \(error)")
            return createFallbackChatResponse(question: question, chart: chart)
        }
    }
}

// MARK: - API Communication

private extension AIInsightService {
    
    func callOpenAIAPI(prompt: String, maxTokens: Int) async throws -> String {
        guard let url = URL(string: baseURL) else { throw AIInsightError.invalidURL }

        var attempt = 0
        let maxAttempts = 4

        while true {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let system = OpenAIMessage(
                role: "system", 
                content: """
                You're giving thoughtful life guidance to someone. Write in a calm, grounded tone like the reference examples. Focus on real-life situations and personal growth, not astrological concepts. Use their personality insights to give relevant advice, but translate everything into everyday language about confidence, intuition, planning, communication, etc. Never mention planets, signs, or astrological terms in your response.
                """
            )
            
            let requestBody = OpenAIRequest(
                model: "gpt-4o-mini",
                messages: [system, OpenAIMessage(role: "user", content: prompt)],
                max_tokens: maxTokens,
                temperature: 0.7,
                top_p: 0.9,
                presence_penalty: 0.2,
                frequency_penalty: 0.1
            )

            do {
                request.httpBody = try JSONEncoder().encode(requestBody)
            } catch {
                throw AIInsightError.encodingFailed
            }

            do {
                let (data, response) = try await urlSession.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw AIInsightError.invalidResponse }

                if http.statusCode == 200 {
                    let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                    guard let content = decoded.choices.first?.message.content, 
                          !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    else { throw AIInsightError.noContent }
                    return content.trimmingCharacters(in: .whitespacesAndNewlines)
                }

                // For 429/5xx, backoff & retry
                if http.statusCode == 429 || (500...599).contains(http.statusCode), attempt < maxAttempts - 1 {
                    attempt += 1
                    let delayMs = Int(pow(2.0, Double(attempt)) * 250) // 250ms, 500ms, 1s, 2s
                    try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                    continue
                }

                // Try to read error message for logs
                if let errText = String(data: data, encoding: .utf8) {
                    print("OpenAI error \(http.statusCode): \(errText)")
                }
                throw AIInsightError.apiError(http.statusCode)

            } catch {
                // Network-level error: retry a couple times too
                if attempt < maxAttempts - 1 {
                    attempt += 1
                    let delayMs = Int(pow(2.0, Double(attempt)) * 250)
                    try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                    continue
                }
                throw error
            }
        }
    }
}

// MARK: - Prompt Templates

private extension AIInsightService {
    
    func createDailyInsightPrompt(chart: BirthChart, transits: [CelestialBody]) -> String {
        let personalityTraits = getPersonalityTraits(chart)
        let energyPattern = getEnergyPattern(transits, chart)
        let currentDate = formatCurrentDate()
        let dayOfWeek = getDayOfWeekContext()
        let seasonalContext = getSeasonalContext()
        
        return """
        You're giving daily life guidance to someone with these personality traits: \(personalityTraits)
        
        Today's energy pattern suggests: \(energyPattern)
        
        Context: \(currentDate), \(dayOfWeek), \(seasonalContext.lowercased())
        
        Write 2-3 sentences of thoughtful daily guidance in this exact style:
        
        "Today, you may find your plans for the future wavering as you seek support and understanding from friends. Unfortunately, they might not fully grasp your points, leaving their encouragement feeling somewhat hollow. It's a day to seek clarity within yourself and not rely solely on external validation."
        
        Focus on:
        - Real-life situations (work, relationships, decisions, self-reflection)
        - Their natural personality strengths and tendencies
        - What today's energy supports or challenges
        - Internal vs external focus
        - Practical emotional or life guidance
        
        Use the same thoughtful, grounded tone. No astrology terms, no emojis. Write as if you understand both their personality and what today brings.
        """
    }
    
    func createWeeklyInsightPrompt(chart: BirthChart, transits: [CelestialBody]) -> String {
        let personalityTraits = getPersonalityTraits(chart)
        let weeklyEnergyPattern = getWeeklyEnergyPattern(transits, chart)
        let weekDates = getWeekDateRange()
        let seasonalContext = getSeasonalContext()
        
        return """
        Weekly guidance for someone with these traits: \(personalityTraits)
        
        This week's energy pattern (\(weekDates)): \(weeklyEnergyPattern)
        
        Context: \(seasonalContext.lowercased())
        
        Write 3-4 sentences about their week ahead in this thoughtful, grounded style. Focus on:
        - Weekly themes and patterns
        - How their personality navigates this week's challenges/opportunities  
        - Relationships, work decisions, personal growth
        - Planning and goal-setting
        - What to focus on or be mindful of
        
        Match this tone - thoughtful and specific to real life, not abstract. No astrology terms.
        """
    }
    
    func createMonthlyInsightPrompt(chart: BirthChart, transits: [CelestialBody]) -> String {
        let personalityTraits = getPersonalityTraits(chart)
        let monthlyTheme = getMonthlyTheme(transits, chart)
        let monthYear = getMonthYear()
        let seasonalContext = getSeasonalContext()
        
        return """
        Monthly guidance for someone with these traits: \(personalityTraits)
        
        This month's theme (\(monthYear)): \(monthlyTheme)
        
        Context: \(seasonalContext.lowercased())
        
        Write 4-5 sentences about their month ahead. Focus on:
        - Major themes and longer-term patterns
        - Career, relationships, personal development
        - How their natural strengths serve them this month
        - What to build toward or release
        - Practical monthly focus areas
        
        Keep the tone grounded and specific to real life situations. No astrology jargon.
        """
    }
    
    func createYearlyInsightPrompt(chart: BirthChart, transits: [CelestialBody]) -> String {
        let personalityCore = getPersonalityCore(chart)
        let yearlyTheme = getYearlyTheme(transits, chart)
        let currentYear = getCurrentYear()
        
        return """
        Yearly guidance for someone with this core personality: \(personalityCore)
        
        This year's major theme (\(currentYear)): \(yearlyTheme)
        
        Write 5-6 sentences about their year ahead. Focus on:
        - Major life direction and evolution
        - Career development and life goals
        - Relationship patterns and growth
        - Personal transformation themes
        - What this year is asking them to build, release, or become
        
        Keep it grounded in real life development and growth. No astrology terms.
        """
    }
    
    func createCycleInsightPrompt(cycles: [AstrologicalCycle], chart: BirthChart) -> String {
        let personalityTraits = getPersonalityTraits(chart)
        let currentTheme = getCycleTheme(cycles, chart)
        
        return """
        Life guidance for someone with these traits: \(personalityTraits)
        
        Current life theme: \(currentTheme)
        
        Write 3-4 sentences about navigating this period. Focus on:
        - How to work with current life patterns and energies
        - Personal growth and evolution
        - Timing and patience
        - What this phase is asking of them
        
        Keep it practical and grounded in personal development. No astrology terms.
        """
    }
    
    func createChatPrompt(question: String, chart: BirthChart) -> String {
        let personalityTraits = getPersonalityTraits(chart)
        let transits = AstrologyService.shared.calculateCurrentTransits()
        let todaysEnergy = getEnergyPattern(transits, chart)
        
        return """
        Someone with these traits asked: "\(question)"
        
        Their personality: \(personalityTraits)
        Today's energy: \(todaysEnergy)
        
        Give honest, practical advice that relates to their question in 2-3 sentences. Reference their natural strengths and how today's energy helps or challenges what they're asking about. No astrology terms, just real life guidance.
        """
    }
    
    // MARK: - Personality Translation Helpers
    
    func getPersonalityTraits(_ chart: BirthChart) -> String {
        var traits: [String] = []
        
        // Translate sun sign to personality traits
        switch chart.sunSign {
        case .aries: traits.append("natural leadership and initiative")
        case .taurus: traits.append("steady determination and practical approach")
        case .gemini: traits.append("curiosity and communication skills")
        case .cancer: traits.append("emotional intelligence and nurturing nature")
        case .leo: traits.append("confidence and creative self-expression")
        case .virgo: traits.append("attention to detail and helpful nature")
        case .libra: traits.append("desire for harmony and strong aesthetic sense")
        case .scorpio: traits.append("intensity and ability to see beneath the surface")
        case .sagittarius: traits.append("optimism and love of learning")
        case .capricorn: traits.append("ambition and long-term planning skills")
        case .aquarius: traits.append("innovative thinking and humanitarian values")
        case .pisces: traits.append("intuition and empathetic nature")
        }
        
        // Add moon sign emotional style
        switch chart.moonSign {
        case .aries: traits.append("direct emotional expression")
        case .taurus: traits.append("need for emotional security")
        case .gemini: traits.append("mental processing of emotions")
        case .cancer: traits.append("deep emotional sensitivity")
        case .leo: traits.append("dramatic emotional expression")
        case .virgo: traits.append("practical emotional approach")
        case .libra: traits.append("need for emotional balance")
        case .scorpio: traits.append("intense emotional depth")
        case .sagittarius: traits.append("optimistic emotional outlook")
        case .capricorn: traits.append("controlled emotional expression")
        case .aquarius: traits.append("unique emotional perspective")
        case .pisces: traits.append("intuitive emotional understanding")
        }
        
        return traits.prefix(3).joined(separator: ", ")
    }
    
    func getPersonalityCore(_ chart: BirthChart) -> String {
        return getPersonalityTraits(chart) + ", with a " + getLifeApproach(chart)
    }
    
    func getLifeApproach(_ chart: BirthChart) -> String {
        switch chart.ascendantSign {
        case .aries: return "direct, action-oriented approach to life"
        case .taurus: return "steady, practical approach to life"
        case .gemini: return "curious, communicative approach to life"
        case .cancer: return "protective, nurturing approach to life"
        case .leo: return "confident, expressive approach to life"
        case .virgo: return "analytical, service-oriented approach to life"
        case .libra: return "balanced, relationship-focused approach to life"
        case .scorpio: return "transformative, depth-seeking approach to life"
        case .sagittarius: return "adventurous, growth-oriented approach to life"
        case .capricorn: return "structured, achievement-focused approach to life"
        case .aquarius: return "innovative, group-minded approach to life"
        case .pisces: return "intuitive, compassionate approach to life"
        }
    }
    
    func getEnergyPattern(_ transits: [CelestialBody], _ chart: BirthChart) -> String {
        // Translate current transits into energy descriptions without astrology terms
        let patterns = [
            "focused energy for decision-making",
            "creative and expressive energy",
            "introspective and planning energy",
            "collaborative and social energy",
            "intense focus and determination",
            "expansive and optimistic energy",
            "grounding and practical energy",
            "transformative and growth-oriented energy"
        ]
        
        // Use transit data to determine which pattern fits (safe from overflow)
        let hash = transits.map { abs($0.name.hashValue % 10000) }.reduce(0) { $0 &+ $1 }
        return patterns[Int(hash) % patterns.count]
    }
    
    func getWeeklyEnergyPattern(_ transits: [CelestialBody], _ chart: BirthChart) -> String {
        return "themes of " + getEnergyPattern(transits, chart) + " and relationship dynamics"
    }
    
    func getMonthlyTheme(_ transits: [CelestialBody], _ chart: BirthChart) -> String {
        let themes = [
            "building foundations and planning ahead",
            "creative self-expression and personal growth",
            "relationship development and communication",
            "career advancement and goal achievement",
            "inner reflection and emotional healing",
            "learning new skills and expanding horizons",
            "financial planning and resource management",
            "personal transformation and releasing old patterns"
        ]
        
        let hash = transits.map { abs($0.name.hashValue % 10000) }.reduce(0) { $0 &+ $1 }
        return themes[Int(hash) % themes.count]
    }
    
    func getYearlyTheme(_ transits: [CelestialBody], _ chart: BirthChart) -> String {
        let themes = [
            "stepping into authentic personal power and leadership",
            "deepening relationships and emotional intelligence",
            "career evolution and professional development",
            "creative expression and finding your unique voice",
            "building lasting foundations for future growth",
            "expanding your worldview and learning new perspectives",
            "healing old patterns and embracing personal transformation",
            "developing your intuition and spiritual understanding"
        ]
        
        let hash = transits.map { abs($0.name.hashValue % 10000) }.reduce(0) { $0 &+ $1 }
        return themes[Int(hash) % themes.count]
    }
    
    func getCycleTheme(_ cycles: [AstrologicalCycle], _ chart: BirthChart) -> String {
        return "a time of personal evolution and aligning with your authentic path"
    }
    
    func createChartSummary(_ chart: BirthChart) -> String {
        return "Sun in \(chart.sunSign.rawValue), Moon in \(chart.moonSign.rawValue), \(chart.ascendantSign.rawValue) rising"
    }
    
    func createTransitSummary(_ transits: [CelestialBody]) -> String {
        return transits.prefix(5).map { transit in
            "\(transit.name) in \(transit.position.sign.rawValue)"
        }.joined(separator: ", ")
    }
    
    // MARK: - Date and Context Helpers
    
    func formatCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
    
    func getWeekDateRange() -> String {
        let calendar = Calendar.current
        let today = Date()
        
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else {
            return formatCurrentDate()
        }
        
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? today
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
    }
    
    func getMonthYear() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
    
    func getCurrentYear() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }
    
    func getDayOfWeekContext() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }
    
    func getSeasonalContext() -> String {
        let month = Calendar.current.component(.month, from: Date())
        
        switch month {
        case 12, 1, 2: return "Winter reflection season"
        case 3, 4, 5: return "Spring growth season"
        case 6, 7, 8: return "Summer expansion season"
        case 9, 10, 11: return "Autumn harvest season"
        default: return "Seasonal transition"
        }
    }
}

// MARK: - Fallback Content

private extension AIInsightService {
    
    func createFallbackDailyInsight(chart: BirthChart, transits: [CelestialBody]) -> String {
        return "Today brings an opportunity to trust your natural instincts and focus on what truly matters to you."
    }
    
    func createFallbackWeeklyInsight(chart: BirthChart, transits: [CelestialBody]) -> String {
        return "This week asks you to balance your personal goals with the needs of those around you."
    }
    
    func createFallbackMonthlyInsight(chart: BirthChart, transits: [CelestialBody]) -> String {
        return "This month is about building something meaningful while staying true to your core values."
    }
    
    func createFallbackYearlyInsight(chart: BirthChart, transits: [CelestialBody]) -> String {
        return "This year represents a significant step in your personal evolution and authentic self-expression."
    }
    
    func createFallbackCycleInsight(cycles: [AstrologicalCycle], chart: BirthChart) -> String {
        return "This period invites you to embrace change while honoring your natural strengths and wisdom."
    }
    
    func createFallbackChatResponse(question: String, chart: BirthChart) -> String {
        return "Trust your natural wisdom and consider both your logical mind and intuitive feelings about this situation."
    }
}

// MARK: - Utility

private extension AIInsightService {
    
    func createCacheKey(type: String, chart: BirthChart, date: Date) -> String {
        let dateFormatter = DateFormatter()
        switch type {
        case "daily": dateFormatter.dateFormat = "yyyy-MM-dd"
        case "weekly": dateFormatter.dateFormat = "yyyy-'W'ww"
        case "monthly": dateFormatter.dateFormat = "yyyy-MM"
        case "yearly": dateFormatter.dateFormat = "yyyy"
        default: dateFormatter.dateFormat = "yyyy-MM-dd"
        }
        let dateString = dateFormatter.string(from: date)
        
        let chartHash = "\(chart.sunSign.rawValue)-\(chart.moonSign.rawValue)-\(chart.ascendantSign.rawValue)"
        return "\(type)-\(dateString)-\(chartHash)"
    }
}

// MARK: - Data Models

private struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let max_tokens: Int
    let temperature: Double?
    let top_p: Double?
    let presence_penalty: Double?
    let frequency_penalty: Double?
}

private struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
}

private struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

// MARK: - Errors

enum AIInsightError: Error, LocalizedError {
    case invalidURL
    case encodingFailed
    case invalidResponse
    case apiError(Int)
    case noContent
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .encodingFailed:
            return "Failed to encode request"
        case .invalidResponse:
            return "Invalid API response"
        case .apiError(let code):
            return "API error with status code: \(code)"
        case .noContent:
            return "No content in API response"
        }
    }
}
