import Foundation

/// Service for generating AI-powered astrological insights using Claude API
class AIInsightService: ObservableObject {
    static let shared = AIInsightService()
    
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    
    private var urlSession: URLSession
    private var cache: NSCache<NSString, NSString>
    
    private init() {
        // Load API key from APIKeys.plist (not committed to git)
        if let path = Bundle.main.path(forResource: "APIKeys", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let key = plist["CLAUDE_API_KEY"] as? String {
            self.apiKey = key
        } else {
            // Fallback for development - TODO: Create APIKeys.plist with your key
            self.apiKey = ""
            print("⚠️ Warning: Please create APIKeys.plist with CLAUDE_API_KEY to enable AI features.")
            print("📋 Instructions: Create kairo/APIKeys.plist and add your Claude API key")
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
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
            let insight = try await callClaudeAPI(prompt: prompt, maxTokens: 300)
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
            let insight = try await callClaudeAPI(prompt: prompt, maxTokens: 400)
            cache.setObject(insight as NSString, forKey: cacheKey as NSString)
            return insight
        } catch {
            print("Failed to generate AI weekly insight: \(error)")
            return createFallbackWeeklyInsight(chart: chart, transits: transits)
        }
    }
    
    /// Generate a personalized chat response
    func generateChatResponse(question: String, chart: BirthChart) async -> String {
        let prompt = createChatPrompt(question: question, chart: chart)
        
        do {
            return try await callClaudeAPI(prompt: prompt, maxTokens: 250)
        } catch {
            print("Failed to generate AI chat response: \(error)")
            return createFallbackChatResponse(question: question, chart: chart)
        }
    }
}

// MARK: - API Communication

private extension AIInsightService {
    
    func callClaudeAPI(prompt: String, maxTokens: Int) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw AIInsightError.invalidURL
        }
        
        let requestBody = ClaudeRequest(
            model: "claude-3-5-sonnet-20241022",
            maxTokens: maxTokens,
            messages: [
                ClaudeMessage(role: "user", content: prompt)
            ]
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw AIInsightError.encodingFailed
        }
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIInsightError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AIInsightError.apiError(httpResponse.statusCode)
        }
        
        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        
        guard let content = claudeResponse.content.first?.text else {
            throw AIInsightError.noContent
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Prompt Templates

private extension AIInsightService {
    
    func createDailyInsightPrompt(chart: BirthChart, transits: [CelestialBody]) -> String {
        let chartSummary = createChartSummary(chart)
        let transitSummary = createTransitSummary(transits)
        
        return """
        You are a sophisticated astrologer writing in the style of Co-Star app. Create a daily insight that is:
        - Psychologically nuanced and slightly provocative
        - Direct, poetic, and mysterious
        - Personally relevant but universally resonant
        - 2-3 sentences maximum
        
        User's Birth Chart:
        \(chartSummary)
        
        Current Planetary Transits:
        \(transitSummary)
        
        Write a daily insight that combines their natal chart with today's transits. Focus on emotional/psychological themes, not literal predictions. Use Co-Star's distinctive voice: insightful, slightly edgy, spiritually aware.
        
        Examples of Co-Star style:
        "The courage you're looking for already lives inside your fear."
        "Today you realize that what you thought was intuition was actually trauma."
        "Your need to be understood conflicts with your need to be mysterious."
        
        Generate one insight now:
        """
    }
    
    func createWeeklyInsightPrompt(chart: BirthChart, transits: [CelestialBody]) -> String {
        let chartSummary = createChartSummary(chart)
        let transitSummary = createTransitSummary(transits)
        
        return """
        You are a sophisticated astrologer writing in Co-Star app's style. Create a weekly insight that is:
        - Deeper and more developmental than daily insights
        - Focuses on growth, patterns, and psychological evolution
        - 3-4 sentences maximum
        - Mystical yet practical
        
        User's Birth Chart:
        \(chartSummary)
        
        Current Week's Transits:
        \(transitSummary)
        
        Write about weekly themes, personal growth opportunities, and psychological patterns. Use Co-Star's voice: profound, slightly challenging, spiritually intelligent.
        
        Generate one weekly insight now:
        """
    }
    
    func createChatPrompt(question: String, chart: BirthChart) -> String {
        let chartSummary = createChartSummary(chart)
        
        return """
        You are the cosmic oracle in Co-Star app. Respond to the user's question with:
        - Deep astrological wisdom
        - Psychological insight
        - Co-Star's distinctive voice (mystical, direct, slightly provocative)
        - Personal relevance based on their chart
        - 2-3 sentences maximum
        
        User's Question: "\(question)"
        
        User's Birth Chart:
        \(chartSummary)
        
        Respond as the cosmic oracle, weaving their astrological makeup into your answer. Be insightful but not literal. Focus on psychological/spiritual guidance.
        
        Generate response now:
        """
    }
    
    func createChartSummary(_ chart: BirthChart) -> String {
        return """
        Sun: \(chart.sun.name) in \(chart.sunSign.rawValue) at \(chart.sun.formattedDegree)
        Moon: \(chart.moon.name) in \(chart.moonSign.rawValue) at \(chart.moon.formattedDegree)
        Rising: \(chart.ascendantSign.rawValue) at \(String(format: "%.1f", chart.ascendant))°
        Mercury: \(chart.mercury.name) in \(chart.mercury.position.sign.rawValue)
        Venus: \(chart.venus.name) in \(chart.venus.position.sign.rawValue)
        Mars: \(chart.mars.name) in \(chart.mars.position.sign.rawValue)
        """
    }
    
    func createTransitSummary(_ transits: [CelestialBody]) -> String {
        return transits.prefix(5).map { transit in
            "\(transit.name) in \(transit.position.sign.rawValue) at \(transit.formattedDegree)"
        }.joined(separator: "\n")
    }
}

// MARK: - Fallback Content

private extension AIInsightService {
    
    func createFallbackDailyInsight(chart: BirthChart, transits: [CelestialBody]) -> String {
        let sunSign = chart.sunSign
        let moonSign = chart.moonSign
        
        // Generate Co-Star style daily insights
        if let moonTransit = transits.first(where: { $0.name == "Moon" }) {
            let currentMoonSign = moonTransit.position.sign
            
            // Use the same Co-Star style insights from AstrologyService
            return generateCoStarStyleInsights(sunSign: sunSign, moonSign: moonSign, currentMoon: currentMoonSign).randomElement() ?? getCoStarStyleDefault()
        }
        
        // Fallback insights when no moon transit available
        let fallbackInsights = [
            "Your instincts are trying to tell you something important today.",
            "The gap between who you are and who you think you should be is closing.",
            "Today you realize that waiting for permission was just another form of procrastination.",
            "What you're avoiding has been avoiding you too. Time to meet in the middle.",
            "Your past self would be proud of how far you've come, even when progress feels invisible."
        ]
        
        return fallbackInsights.randomElement() ?? "Trust yourself more. Your gut knows."
    }
    
    private func generateCoStarStyleInsights(sunSign: ZodiacSign, moonSign: ZodiacSign, currentMoon: ZodiacSign) -> [String] {
        var insights: [String] = []
        
        // Moon-sign specific insights
        switch currentMoon {
        case .aries:
            insights.append("Your impatience today is actually intuition in disguise.")
            insights.append("The thing you want to start right now? That's your soul talking.")
            insights.append("Anger is just passion wearing a disguise. What's it really about?")
            
        case .taurus:
            insights.append("Slow down. Your body is trying to teach your brain something.")
            insights.append("Today's craving for comfort isn't weakness - it's wisdom.")
            insights.append("The pleasure you're denying yourself is probably exactly what you need.")
            
        case .gemini:
            insights.append("That conversation you keep avoiding? It's time.")
            insights.append("Your scattered thoughts are actually connecting dots you couldn't see before.")
            insights.append("Stop explaining yourself to people who are determined to misunderstand you.")
            
        case .cancer:
            insights.append("Vulnerability isn't weakness when it's a choice.")
            insights.append("That feeling of homesickness? You're missing a version of yourself.")
            insights.append("Your sensitivity is picking up on something everyone else is missing.")
            
        case .leo:
            insights.append("The spotlight you crave is already on you - you just can't see it yet.")
            insights.append("Your need to be seen conflicts with your fear of being truly known.")
            insights.append("Today you realize that confidence isn't the absence of doubt - it's dancing with it.")
            
        case .virgo:
            insights.append("Perfectionism is just fear wearing a productive mask.")
            insights.append("The thing you're nitpicking isn't really the problem.")
            insights.append("Sometimes 'good enough' is actually perfect timing.")
            
        case .libra:
            insights.append("Your people-pleasing is really self-preservation in disguise.")
            insights.append("The decision you're avoiding is already made - you just need to admit it.")
            insights.append("Balance isn't about being in the middle - it's about knowing when to tip the scales.")
            
        case .scorpio:
            insights.append("What you think is paranoia is actually pattern recognition.")
            insights.append("The intensity you're feeling isn't too much - the world is just too small.")
            insights.append("That thing you're hiding? Everyone already knows. The secret is how you feel about it.")
            
        case .sagittarius:
            insights.append("Your restlessness is your compass pointing toward growth.")
            insights.append("The truth you're avoiding is the adventure you've been looking for.")
            insights.append("Freedom isn't about having no commitments - it's about choosing the right ones.")
            
        case .capricorn:
            insights.append("Your ambition is really just love wearing a business suit.")
            insights.append("The goal you're chasing is actually chasing you back.")
            insights.append("Sometimes the mountain climbs you more than you climb it.")
            
        case .aquarius:
            insights.append("Your need to be different conflicts with your need to belong.")
            insights.append("The revolution you're planning starts with the person in the mirror.")
            insights.append("Your weirdness is actually your superpower in disguise.")
            
        case .pisces:
            insights.append("Your emotions aren't drowning you - they're teaching you to swim.")
            insights.append("That dream you had? It wasn't random.")
            insights.append("Your empathy is a gift, not a burden - but boundaries are still necessary.")
        }
        
        // Add some sun-moon combination insights
        if sunSign.element != moonSign.element {
            insights.append("The tension between your \(sunSign.rawValue) self and \(moonSign.rawValue) feelings is actually creating something new.")
            insights.append("Your head says \(getSunDesire(sunSign)), but your heart needs \(getMoonNeed(moonSign)). Both are right.")
        }
        
        return insights
    }
    
    private func getSunDesire(_ sign: ZodiacSign) -> String {
        switch sign {
        case .aries: return "action"
        case .taurus: return "stability"
        case .gemini: return "variety"
        case .cancer: return "security"
        case .leo: return "recognition"
        case .virgo: return "perfection"
        case .libra: return "harmony"
        case .scorpio: return "truth"
        case .sagittarius: return "freedom"
        case .capricorn: return "success"
        case .aquarius: return "innovation"
        case .pisces: return "connection"
        }
    }
    
    private func getMoonNeed(_ sign: ZodiacSign) -> String {
        switch sign {
        case .aries: return "excitement"
        case .taurus: return "comfort"
        case .gemini: return "stimulation"
        case .cancer: return "nurturing"
        case .leo: return "appreciation"
        case .virgo: return "order"
        case .libra: return "peace"
        case .scorpio: return "depth"
        case .sagittarius: return "adventure"
        case .capricorn: return "structure"
        case .aquarius: return "independence"
        case .pisces: return "understanding"
        }
    }
    
    private func getCoStarStyleDefault() -> String {
        let defaults = [
            "You're exactly where you need to be, even when it doesn't feel like it.",
            "Your instincts are trying to tell you something important today.",
            "The gap between who you are and who you think you should be is closing.",
            "What you're avoiding has been avoiding you too. Time to meet in the middle."
        ]
        return defaults.randomElement() ?? "Trust yourself more. Your gut knows."
    }
    
    func createFallbackWeeklyInsight(chart: BirthChart, transits: [CelestialBody]) -> String {
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
            "The person you were last week couldn't handle what's coming next. Good thing you're evolving."
        ]
        
        return weeklyInsights.randomElement() ?? "This week, trust the process even when you can't see the outcome."
    }
    
    func createFallbackChatResponse(question: String, chart: BirthChart) -> String {
        let sunSign = chart.sunSign
        let moonSign = chart.moonSign
        let asc = chart.ascendantSign
        
        let questionLower = question.lowercased()
        
        if questionLower.contains("love") || questionLower.contains("relationship") {
            return "In relationships, your \(moonSign.rawValue) side needs \(getSimpleMoonLoveNeed(moonSign)). But as a \(sunSign.rawValue), you express love by \(getSimpleSunLoveExpression(sunSign)). The trick is finding someone who gets both sides of you."
        } else if questionLower.contains("career") || questionLower.contains("work") {
            return "Career-wise, people see you as \(getSimpleRisingCareerImage(asc)). But what really drives you is \(getSimpleSunCareerDrive(sunSign)). Don't be afraid to show more of your real self at work."
        } else if questionLower.contains("future") || questionLower.contains("what will") {
            return "Here's the thing about the future - you already have the answer. Your \(sunSign.rawValue) instincts are usually right, and your \(moonSign.rawValue) gut feelings are trying to tell you something. Trust yourself more."
        } else {
            let responses = [
                "You know what? You already know the answer to this. Your \(sunSign.rawValue) side has good instincts, and your \(moonSign.rawValue) emotions are trying to guide you. Sometimes we just need permission to trust ourselves.",
                "Honestly, this question is really about something deeper. As a \(sunSign.rawValue), you probably \(getSunQuestionPattern(sunSign)). Listen to what your gut (\(moonSign.rawValue) moon) is actually asking.",
                "Your \(sunSign.rawValue) nature wants to figure this out, while your \(moonSign.rawValue) emotions are feeling something important. Both are right. The answer is probably somewhere in the middle.",
                "Sometimes when we're confused, it's because we're ready for something new. You're a \(sunSign.rawValue) - \(getSunReadinessMessage(sunSign)). Trust the process."
            ]
            return responses.randomElement() ?? "Trust yourself. You've got good instincts, even when things feel unclear."
        }
    }
    
    
    private func getWeeklyGrowthMessage(sun: ZodiacSign, moon: ZodiacSign) -> String {
        return "you're learning to balance what you want to do with what you actually need emotionally."
    }
    
    private func getWeeklyBalanceAdvice(sun: ZodiacSign, moon: ZodiacSign) -> String {
        return "When they seem to conflict, try to find a way to honor both instead of choosing one over the other."
    }
    
    // Chat response helpers
    private func getSimpleMoonLoveNeed(_ moonSign: ZodiacSign) -> String {
        switch moonSign {
        case .aries: return "excitement and passion, but also some independence"
        case .taurus: return "stability, affection, and lots of quality time"
        case .gemini: return "someone who can keep up with your mind and talk about everything"
        case .cancer: return "emotional security and someone who feels like home"
        case .leo: return "admiration, romance, and someone who makes you feel special"
        case .virgo: return "practical support and someone who appreciates your helpful nature"
        case .libra: return "harmony, partnership, and someone who values fairness"
        case .scorpio: return "deep emotional intimacy and complete honesty"
        case .sagittarius: return "freedom within the relationship and shared adventures"
        case .capricorn: return "commitment, loyalty, and someone who shares your goals"
        case .aquarius: return "friendship first, and someone who respects your independence"
        case .pisces: return "emotional understanding and someone who gets your sensitivity"
        }
    }
    
    private func getSimpleSunLoveExpression(_ sunSign: ZodiacSign) -> String {
        switch sunSign {
        case .aries: return "being direct, passionate, and taking the lead"
        case .taurus: return "showing love through actions, gifts, and physical affection"
        case .gemini: return "talking, sharing ideas, and keeping things interesting"
        case .cancer: return "caring for them and creating a safe, loving environment"
        case .leo: return "grand gestures, creativity, and making them feel like royalty"
        case .virgo: return "helping them improve their life and paying attention to details"
        case .libra: return "creating harmony, being romantic, and making everything beautiful"
        case .scorpio: return "going all-in emotionally and creating intense intimacy"
        case .sagittarius: return "sharing adventures and being honest about everything"
        case .capricorn: return "building a solid future together and providing stability"
        case .aquarius: return "being a best friend first and supporting their independence"
        case .pisces: return "being intuitive, compassionate, and emotionally supportive"
        }
    }
    
    private func getSimpleRisingCareerImage(_ risingSign: ZodiacSign) -> String {
        switch risingSign {
        case .aries: return "a leader and go-getter"
        case .taurus: return "reliable and down-to-earth"
        case .gemini: return "communicative and adaptable"
        case .cancer: return "caring and protective"
        case .leo: return "confident and creative"
        case .virgo: return "detail-oriented and helpful"
        case .libra: return "diplomatic and charming"
        case .scorpio: return "intense and mysterious"
        case .sagittarius: return "optimistic and adventurous"
        case .capricorn: return "professional and ambitious"
        case .aquarius: return "innovative and unique"
        case .pisces: return "intuitive and compassionate"
        }
    }
    
    private func getSimpleSunCareerDrive(_ sunSign: ZodiacSign) -> String {
        switch sunSign {
        case .aries: return "leading projects and being first at something"
        case .taurus: return "building something lasting and valuable"
        case .gemini: return "communicating, learning, and connecting people"
        case .cancer: return "helping others and creating emotional safety"
        case .leo: return "being creative and getting recognition for your work"
        case .virgo: return "improving systems and helping people solve problems"
        case .libra: return "creating harmony and making things fair for everyone"
        case .scorpio: return "transforming things and getting to the truth"
        case .sagittarius: return "exploring new ideas and sharing knowledge"
        case .capricorn: return "achieving long-term goals and building authority"
        case .aquarius: return "innovating and making positive changes"
        case .pisces: return "helping others and following your intuition"
        }
    }
    
    private func getSunQuestionPattern(_ sunSign: ZodiacSign) -> String {
        switch sunSign {
        case .aries: return "want to solve this quickly and move forward"
        case .taurus: return "want to think it through thoroughly before deciding"
        case .gemini: return "want to talk it through with someone first"
        case .cancer: return "want to make sure everyone's feelings are considered"
        case .leo: return "want to make sure you're making the right choice for your future"
        case .virgo: return "want to analyze all the details before moving forward"
        case .libra: return "want to weigh all the options and find the fairest solution"
        case .scorpio: return "want to understand the deeper truth behind the situation"
        case .sagittarius: return "want to explore all possibilities before committing"
        case .capricorn: return "want to make sure this aligns with your long-term goals"
        case .aquarius: return "want to find a unique solution that feels authentic to you"
        case .pisces: return "want to follow your intuition and do what feels right"
        }
    }
    
    private func getSunReadinessMessage(_ sunSign: ZodiacSign) -> String {
        switch sunSign {
        case .aries: return "you're ready for action, even if you don't have all the answers yet"
        case .taurus: return "you prefer to move slowly, but when you're ready, you're really ready"
        case .gemini: return "you're ready to learn and adapt to whatever comes next"
        case .cancer: return "you're ready when you feel emotionally secure about the decision"
        case .leo: return "you're ready to shine and show the world what you're capable of"
        case .virgo: return "you're ready when you've analyzed everything and have a plan"
        case .libra: return "you're ready when you've considered how it affects everyone involved"
        case .scorpio: return "you're ready to transform and go deeper than before"
        case .sagittarius: return "you're ready for the next adventure, whatever it might be"
        case .capricorn: return "you're ready to build something that will last"
        case .aquarius: return "you're ready to do things your own way"
        case .pisces: return "you're ready when it feels right in your heart"
        }
    }
    

}

// MARK: - Utility

private extension AIInsightService {
    
    func createCacheKey(type: String, chart: BirthChart, date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = type == "daily" ? "yyyy-MM-dd" : "yyyy-'W'ww"
        let dateString = dateFormatter.string(from: date)
        
        let chartHash = "\(chart.sunSign.rawValue)-\(chart.moonSign.rawValue)-\(chart.ascendantSign.rawValue)"
        return "\(type)-\(dateString)-\(chartHash)"
    }
}

// MARK: - Data Models

private struct ClaudeRequest: Codable {
    let model: String
    let maxTokens: Int
    let messages: [ClaudeMessage]
    
    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }
}

private struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

private struct ClaudeResponse: Codable {
    let content: [ClaudeContent]
}

private struct ClaudeContent: Codable {
    let text: String
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
