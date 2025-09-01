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
        let ascendantSign = chart.ascendantSign
        
        // Get current moon transit for daily energy
        if let moonTransit = transits.first(where: { $0.name == "Moon" }) {
            let currentMoonSign = moonTransit.position.sign
            
            let dailyInsights = [
                "The Moon is in \(currentMoonSign.rawValue) today, which means \(getPlainEnglishMoonMessage(currentMoonSign)). Since you're a \(sunSign.rawValue) with a \(moonSign.rawValue) moon, \(getPersonalizedDailyMessage(sun: sunSign, moon: moonSign, currentMoon: currentMoonSign))",
                
                "Today feels like \(getDailyMoodMessage(currentMoonSign)). Your \(sunSign.rawValue) side wants \(getSunDriveMessage(sunSign)), while your emotional \(moonSign.rawValue) nature is \(getMoonMoodMessage(moonSign)). \(getDailyAdviceMessage(sun: sunSign, moon: moonSign))",
                
                "You might notice \(getDailyExperienceMessage(currentMoonSign)) today. That's because the Moon is moving through \(currentMoonSign.rawValue). For someone like you (\(sunSign.rawValue) sun, \(moonSign.rawValue) moon), this means \(getPersonalDailyGuidance(sun: sunSign, moon: moonSign, currentMoon: currentMoonSign))",
                
                "Today's energy: \(getDailyEnergyDescription(currentMoonSign)). You might feel more \(getCurrentMoodInfluence(currentMoonSign)) than usual. As a \(sunSign.rawValue), \(getSunResponseToMoon(sun: sunSign, currentMoon: currentMoonSign))"
            ]
            
            return dailyInsights.randomElement() ?? getSimpleDefaultMessage()
        }
        
        return getSimpleDefaultMessage()
    }
    
    func createFallbackWeeklyInsight(chart: BirthChart, transits: [CelestialBody]) -> String {
        let sunSign = chart.sunSign
        let moonSign = chart.moonSign
        
        let weeklyThemes = [
            "This week is all about listening to your feelings. You're a \(sunSign.rawValue), so you naturally \(getSunWeeklyTendency(sunSign)). But your \(moonSign.rawValue) emotional side needs \(getMoonWeeklyNeed(moonSign)). Try to balance both.",
            
            "You might feel like you're changing this week, and that's good. Sometimes what we think is our 'personality' is just old habits. As a \(sunSign.rawValue) with \(moonSign.rawValue) emotions, \(getWeeklyGrowthMessage(sun: sunSign, moon: moonSign))",
            
            "This week, pay attention to the difference between what you want (\(sunSign.rawValue) energy) and what you need emotionally (\(moonSign.rawValue) side). \(getWeeklyBalanceAdvice(sun: sunSign, moon: moonSign))",
            
            "You know that feeling when your head and heart want different things? This week is about making friends with that tension. Your \(sunSign.rawValue) nature and \(moonSign.rawValue) emotions can actually work together really well."
        ]
        
        return weeklyThemes.randomElement() ?? "This week is about finding balance between who you are and how you feel."
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
    
    // MARK: - Plain English Message Generators
    
    private func getPlainEnglishMoonMessage(_ moonSign: ZodiacSign) -> String {
        switch moonSign {
        case .aries: return "people tend to feel more impulsive and ready for action"
        case .taurus: return "everyone's craving comfort, good food, and chill vibes"
        case .gemini: return "conversations flow easily and everyone's curious about everything"
        case .cancer: return "emotions run deep and people want to feel safe and nurtured"
        case .leo: return "everyone's feeling a bit more dramatic and wants to shine"
        case .virgo: return "people feel like organizing and getting things done perfectly"
        case .libra: return "harmony and beauty matter more, and decisions feel harder"
        case .scorpio: return "emotions get intense and people want real, honest connections"
        case .sagittarius: return "everyone's craving adventure and freedom"
        case .capricorn: return "people feel serious and want to build something lasting"
        case .aquarius: return "everyone's thinking outside the box and wanting independence"
        case .pisces: return "emotions flow freely and empathy is heightened"
        }
    }
    
    private func getPersonalizedDailyMessage(sun: ZodiacSign, moon: ZodiacSign, currentMoon: ZodiacSign) -> String {
        switch currentMoon {
        case .aries: return "you might feel extra fired up to take action"
        case .taurus: return "you probably want to slow down and enjoy simple pleasures"
        case .gemini: return "your mind is buzzing with ideas and you want to talk them through"
        case .cancer: return "you're feeling more sensitive and want emotional comfort"
        case .leo: return "you want to be seen and appreciated for who you really are"
        case .virgo: return "you feel like getting organized and fixing what's not working"
        case .libra: return "you're focused on relationships and making things fair"
        case .scorpio: return "you want deeper connections and real conversations"
        case .sagittarius: return "you're craving something new and exciting"
        case .capricorn: return "you feel motivated to work toward your bigger goals"
        case .aquarius: return "you want to break free from whatever's feeling limiting"
        case .pisces: return "your intuition is extra strong and you're feeling everything deeply"
        }
    }
    
    private func getDailyMoodMessage(_ moonSign: ZodiacSign) -> String {
        switch moonSign {
        case .aries: return "a 'let's do this right now' kind of day"
        case .taurus: return "a slow, cozy, comfort-focused day"
        case .gemini: return "a chatty, curious, 'tell me everything' day"
        case .cancer: return "a feelings-heavy, 'I need my people' day"
        case .leo: return "a 'notice me and tell me I'm awesome' day"
        case .virgo: return "a 'let me fix and organize everything' day"
        case .libra: return "a 'why can't we all just get along' day"
        case .scorpio: return "an intense, 'let's go deep or go home' day"
        case .sagittarius: return "a 'I need adventure and new experiences' day"
        case .capricorn: return "a serious, 'time to get things done' day"
        case .aquarius: return "an 'I'm thinking differently today' day"
        case .pisces: return "a dreamy, emotional, 'feeling everything' day"
        }
    }
    
    private func getSunDriveMessage(_ sunSign: ZodiacSign) -> String {
        switch sunSign {
        case .aries: return "to jump into action and lead the way"
        case .taurus: return "to take things slow and build something solid"
        case .gemini: return "to learn, share, and connect with people"
        case .cancer: return "to protect and nurture the people you care about"
        case .leo: return "to be creative and get appreciation for your talents"
        case .virgo: return "to help, improve things, and get the details right"
        case .libra: return "to bring harmony and make everyone happy"
        case .scorpio: return "to get to the truth and transform things deeply"
        case .sagittarius: return "to explore, learn, and experience new things"
        case .capricorn: return "to achieve your goals and build lasting success"
        case .aquarius: return "to innovate and make the world a better place"
        case .pisces: return "to help others and follow your intuition"
        }
    }
    
    private func getMoonMoodMessage(_ moonSign: ZodiacSign) -> String {
        switch moonSign {
        case .aries: return "feeling restless and wanting quick emotional responses"
        case .taurus: return "needing stability and comfort to feel secure"
        case .gemini: return "wanting to talk through your feelings with someone"
        case .cancer: return "extra sensitive and needing emotional safety"
        case .leo: return "needing recognition and wanting your feelings to be appreciated"
        case .virgo: return "analyzing your emotions and wanting to fix what's wrong"
        case .libra: return "seeking emotional balance and harmony in relationships"
        case .scorpio: return "feeling everything intensely and wanting deep connections"
        case .sagittarius: return "feeling emotionally restless and craving freedom"
        case .capricorn: return "building walls around your feelings to stay in control"
        case .aquarius: return "stepping back emotionally to understand what's happening"
        case .pisces: return "absorbing everyone else's emotions like a sponge"
        }
    }
    
    private func getSimpleDefaultMessage() -> String {
        let messages = [
            "Today's a good day to pay attention to both what you want and what you need emotionally.",
            "Sometimes the best guidance is just trusting your gut and taking things one step at a time.",
            "You're exactly where you need to be, even if it doesn't feel like it right now.",
            "Today might feel a little different, and that's actually a good sign. Change is coming.",
            "Trust yourself more. Your instincts are usually right, even when you doubt them."
        ]
        return messages.randomElement() ?? "You've got good instincts. Trust them today."
    }
    
    // Additional helper functions for new simplified content
    private func getDailyAdviceMessage(sun: ZodiacSign, moon: ZodiacSign) -> String {
        return "The key is finding a middle ground between the two."
    }
    
    private func getDailyExperienceMessage(_ moonSign: ZodiacSign) -> String {
        switch moonSign {
        case .aries: return "things moving faster than usual"
        case .taurus: return "a need to slow down and appreciate simple things"
        case .gemini: return "your mind jumping from topic to topic"
        case .cancer: return "emotions feeling stronger than normal"
        case .leo: return "a desire to be in the spotlight"
        case .virgo: return "an urge to organize and perfect things"
        case .libra: return "wanting everything to be fair and balanced"
        case .scorpio: return "intensity in your interactions"
        case .sagittarius: return "restlessness and wanderlust"
        case .capricorn: return "focus on long-term goals"
        case .aquarius: return "thinking outside the box"
        case .pisces: return "heightened intuition and empathy"
        }
    }
    
    private func getPersonalDailyGuidance(sun: ZodiacSign, moon: ZodiacSign, currentMoon: ZodiacSign) -> String {
        return "it's a good time to balance your natural \(sun.rawValue) energy with what you're feeling emotionally."
    }
    
    private func getDailyEnergyDescription(_ moonSign: ZodiacSign) -> String {
        switch moonSign {
        case .aries: return "Fast-paced and action-oriented"
        case .taurus: return "Steady and comfort-seeking"
        case .gemini: return "Chatty and curious"
        case .cancer: return "Emotional and nurturing"
        case .leo: return "Dramatic and attention-seeking"
        case .virgo: return "Detail-focused and helpful"
        case .libra: return "Harmony-seeking and indecisive"
        case .scorpio: return "Intense and transformative"
        case .sagittarius: return "Adventurous and freedom-loving"
        case .capricorn: return "Goal-oriented and serious"
        case .aquarius: return "Independent and innovative"
        case .pisces: return "Dreamy and emotionally sensitive"
        }
    }
    
    private func getCurrentMoodInfluence(_ moonSign: ZodiacSign) -> String {
        switch moonSign {
        case .aries: return "impatient"
        case .taurus: return "chill"
        case .gemini: return "talkative"
        case .cancer: return "emotional"
        case .leo: return "dramatic"
        case .virgo: return "picky"
        case .libra: return "indecisive"
        case .scorpio: return "intense"
        case .sagittarius: return "restless"
        case .capricorn: return "serious"
        case .aquarius: return "detached"
        case .pisces: return "sensitive"
        }
    }
    
    private func getSunResponseToMoon(sun: ZodiacSign, currentMoon: ZodiacSign) -> String {
        return "this energy might feel either natural or challenging, depending on how it meshes with your personality."
    }
    
    // Weekly insight helpers
    private func getSunWeeklyTendency(_ sunSign: ZodiacSign) -> String {
        switch sunSign {
        case .aries: return "want to charge ahead and make things happen"
        case .taurus: return "prefer to take your time and do things properly"
        case .gemini: return "want to learn and communicate with everyone"
        case .cancer: return "focus on family and emotional security"
        case .leo: return "want to be creative and get recognition"
        case .virgo: return "want to help others and perfect systems"
        case .libra: return "seek harmony and avoid conflict"
        case .scorpio: return "go deep and transform things completely"
        case .sagittarius: return "seek adventure and new experiences"
        case .capricorn: return "work toward your long-term goals"
        case .aquarius: return "think independently and innovate"
        case .pisces: return "follow your intuition and help others"
        }
    }
    
    private func getMoonWeeklyNeed(_ moonSign: ZodiacSign) -> String {
        switch moonSign {
        case .aries: return "quick emotional satisfaction and excitement"
        case .taurus: return "emotional stability and comfort"
        case .gemini: return "variety and mental stimulation"
        case .cancer: return "safety, nurturing, and emotional connection"
        case .leo: return "appreciation and recognition for your feelings"
        case .virgo: return "order and the ability to help others"
        case .libra: return "harmony and balanced relationships"
        case .scorpio: return "deep, authentic emotional connections"
        case .sagittarius: return "emotional freedom and new experiences"
        case .capricorn: return "structure and emotional control"
        case .aquarius: return "independence and intellectual understanding"
        case .pisces: return "compassion, creativity, and spiritual connection"
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
