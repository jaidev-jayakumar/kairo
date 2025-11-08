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
    func generateDailyInsight(for chart: BirthChart, transits: [CelestialBody], date: Date = Date()) async -> String {
        // USE DATA-DRIVEN INSIGHTS ONLY - they're specific, truthful, and based on actual transits
        // AI was making them too generic and similar, so we skip AI enhancement entirely
        return DataDrivenInsightGenerator.shared.generateDailyInsight(chart: chart, transits: transits, date: date)
    }
    
    /// Generate a personalized weekly insight
    func generateWeeklyInsight(for chart: BirthChart, transits: [CelestialBody], date: Date = Date()) async -> String {
        // Check feature flag - if OpenAI disabled, use comprehensive fallback directly
        guard FeatureFlags.enableOpenAI else {
            return createFallbackWeeklyInsight(chart: chart, transits: transits)
        }
        
        let cacheKey = createCacheKey(type: "weekly", chart: chart, date: date)
        
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
    func generateMonthlyInsight(for chart: BirthChart, transits: [CelestialBody], date: Date = Date()) async -> String {
        // Check feature flag - if OpenAI disabled, use comprehensive fallback directly
        guard FeatureFlags.enableOpenAI else {
            return createFallbackMonthlyInsight(chart: chart, transits: transits)
        }
        
        let cacheKey = createCacheKey(type: "monthly", chart: chart, date: date)
        
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
    func generateYearlyInsight(for chart: BirthChart, transits: [CelestialBody], date: Date = Date()) async -> String {
        // Check feature flag - if OpenAI disabled, use comprehensive fallback directly
        guard FeatureFlags.enableOpenAI else {
            return createFallbackYearlyInsight(chart: chart, transits: transits)
        }
        
        let cacheKey = createCacheKey(type: "yearly", chart: chart, date: date)
        
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
            return try await callOpenAIAPI(prompt: prompt, maxTokens: 150)
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
                You're Kaira, an astrologer who talks like a real person. Give direct, honest, specific advice. No generic platitudes or "cosmic journey" talk. If you see a clear answer in the astrology, say it confidently. Talk like you're texting a friend who needs real guidance. 2-3 sentences max.
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
    
    func createDailyInsightPrompt(chart: BirthChart, transits: [CelestialBody], baseInsight: String) -> String {
        let personalityTraits = getPersonalityTraits(chart)
        
        return """
        Base insight from actual planetary transits: "\(baseInsight)"
        
        Person's traits: \(personalityTraits)
        
        Rewrite this in 2 short sentences maximum. Keep it direct and truthful. No fluff, no emojis. Speak plainly about what's happening.
        
        Examples of the tone:
        - "You're being tested on your core identity. What you're facing now is showing you where you need to grow stronger."
        - "Doors are opening. Your confidence is high. This is your moment to expand."
        - "Your emotional needs are clashing with reality. Time to mature how you handle feelings."
        
        Make it specific, honest, and grounded in what the planets are actually doing.
        """
    }
    
    func createWeeklyInsightPrompt(chart: BirthChart, transits: [CelestialBody]) -> String {
        let personalityTraits = getPersonalityTraits(chart)
        let weeklyEnergyPattern = getWeeklyEnergyPattern(transits, chart)
        let specificTransitEffects = getSpecificTransitEffects(transits, chart)
        let weekDates = getWeekDateRange()
        let seasonalContext = getSeasonalContext()
        
        return """
        Weekly guidance for someone with these traits: \(personalityTraits)
        
        This week's cosmic weather (\(weekDates)): \(weeklyEnergyPattern)
        
        Specific life impacts this week: \(specificTransitEffects)
        
        Context: \(seasonalContext.lowercased())
        
        Write 3-4 sentences about their week ahead in this thoughtful, grounded style:
        
        Example: "This week, you may find that unexpected situations arise, prompting you to embrace flexibility and remain open to new possibilities. Your intuitive and empathetic nature will serve you well as you navigate these changes; trust your gut feelings when making decisions, especially in your relationships and at work. Use this time to connect deeply with those around you, as your emotional sensitivity can foster meaningful conversations and strengthen bonds."
        
        Focus on:
        - Specific weekly themes (communication patterns, relationship dynamics, work challenges, energy levels)
        - How their personality strengths help them navigate this week
        - Concrete situations they might encounter (difficult conversations, opportunities, obstacles, breakthroughs)
        - What days or moments might be pivotal
        - Practical weekly guidance (what to prioritize, what to avoid, what to prepare for)
        
        Be specific to what's happening this week astrologically. Make it feel personally relevant and actionable. No astrology jargon, no emojis. Write like a wise friend who knows them well.
        """
    }
    
    func createMonthlyInsightPrompt(chart: BirthChart, transits: [CelestialBody]) -> String {
        let personalityTraits = getPersonalityTraits(chart)
        let monthlyTheme = getMonthlyTheme(transits, chart)
        let monthYear = getMonthYear()
        let seasonalContext = getSeasonalContext()
        
        return """
        Monthly guidance for someone with these traits: \(personalityTraits)
        
        This month's major theme (\(monthYear)): \(monthlyTheme)
        
        Context: \(seasonalContext.lowercased())
        
        Write 4-5 sentences about their month ahead in this thoughtful, specific style:
        
        Example: "As you step into October, this month invites you to embrace change and recognize the power of your intuition and empathetic nature. In your career, consider how your sensitivity can guide you in navigating team dynamics—trust your instincts when it comes to collaboration and communication, as they can lead to innovative solutions. In relationships, focus on deepening connections; vulnerability to understand others' emotions will strengthen your bonds. This is also a time to reflect on what you truly need from these connections, focusing on your own emotional well-being and growth."
        
        Focus on:
        - Major monthly themes (career development, relationship patterns, personal transformation, financial focus)
        - How their personality traits interact with this month's energy
        - Specific areas of life that need attention (work projects, relationship decisions, health, finances)
        - What to build toward and what to let go of
        - Practical monthly strategies and focus areas
        - Timeline guidance (early month vs. late month if relevant)
        
        Make it specific to what's happening this month astrologically. Be concrete about life areas and actions. No astrology jargon. Write like a mentor who understands their journey.
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
        let specificEffects = getSpecificTransitEffects(transits, chart)
        
        // Get current date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy"
        let todayFormatted = dateFormatter.string(from: Date())
        
        return """
        You're Kaira - a real astrologer who talks like a human, not a bot.
        
        TODAY'S DATE: \(todayFormatted)
        
        Question: "\(question)"
        
        Person's nature: \(personalityTraits)
        Current planetary energy: \(todaysEnergy)
        What's actually happening today: \(specificEffects)
        
        Give them a straight, honest answer in 2-3 sentences about what's happening NOW. Be direct and specific. If the astrology says yes, say yes. If it says no, say no. If it's complicated, tell them what the real conflict is. Don't mention future months or dates - focus on today and the immediate near future (next few weeks at most).
        
        Talk like you're texting a friend, not writing a horoscope column. No "cosmic journey" bullshit. Just real talk about their current situation.
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
    
    func getSpecificTransitEffects(_ transits: [CelestialBody], _ chart: BirthChart) -> String {
        // Translate planetary transits into specific life area effects (in natural language for AI)
        var effects: [String] = []
        
        // Saturn effects - career, responsibility, structure, tests
        if let saturnTransit = transits.first(where: { $0.name == "Saturn" }) {
            let saturnToSun = abs(saturnTransit.longitude - chart.sun.longitude)
            let normalizedSaturn = saturnToSun > 180 ? 360 - saturnToSun : saturnToSun
            
            if normalizedSaturn < 8 || (82...98).contains(normalizedSaturn) {
                effects.append("facing serious pressure or obstacles at work or in long-term goals; authority figures may be challenging; feeling restricted or tested")
            } else if (172...188).contains(normalizedSaturn) {
                effects.append("external pressure from responsibilities or commitments; others demanding accountability; tension between personal needs and obligations")
            } else if (112...128).contains(normalizedSaturn) {
                effects.append("hard work paying off; recognition for discipline and effort; solid progress in career or goals")
            }
        }
        
        // Jupiter effects - opportunity, growth, expansion, optimism
        if let jupiterTransit = transits.first(where: { $0.name == "Jupiter" }) {
            let jupiterToSun = abs(jupiterTransit.longitude - chart.sun.longitude)
            let normalizedJupiter = jupiterToSun > 180 ? 360 - jupiterToSun : jupiterToSun
            
            if normalizedJupiter < 8 {
                effects.append("major opportunities arriving; feeling optimistic and expansive; doors opening in career or personal growth")
            } else if (112...128).contains(normalizedJupiter) {
                effects.append("things flowing easily; luck on your side; natural growth and positive developments")
            } else if (52...68).contains(normalizedJupiter) {
                effects.append("opportunities available if you take action; learning and growth through new experiences")
            } else if (82...98).contains(normalizedJupiter) {
                effects.append("tendency to overcommit or be overconfident; watch for excess spending or overpromising")
            }
        }
        
        // Mars effects - action, energy, conflicts, passion
        if let marsTransit = transits.first(where: { $0.name == "Mars" }) {
            let marsToSun = abs(marsTransit.longitude - chart.sun.longitude)
            let normalizedMars = marsToSun > 180 ? 360 - marsToSun : marsToSun
            
            if (82...98).contains(normalizedMars) {
                effects.append("feeling irritable or impatient; potential for arguments or conflicts; need to move carefully to avoid accidents or mistakes")
            } else if (172...188).contains(normalizedMars) {
                effects.append("confrontational energy with others; competition or power struggles; others pushing your buttons")
            } else if (112...128).contains(normalizedMars) {
                effects.append("high productive energy; taking decisive action feels natural; physical vitality and confidence")
            } else if normalizedMars < 8 {
                effects.append("surge of motivation and drive; ready to initiate new projects; bold energy")
            }
        }
        
        // Venus effects - relationships, love, money, values, aesthetics
        if let venusTransit = transits.first(where: { $0.name == "Venus" }) {
            let venusToNatalVenus = abs(venusTransit.longitude - chart.venus.longitude)
            let normalizedVenus = venusToNatalVenus > 180 ? 360 - venusToNatalVenus : venusToNatalVenus
            
            if normalizedVenus < 8 {
                effects.append("relationships feel renewed; attraction and magnetism heightened; clarity about what you value in love and money")
            } else if (82...98).contains(normalizedVenus) {
                effects.append("relationship tensions or value conflicts; what you want vs. what others want feels misaligned; financial decisions need care")
            } else if (112...128).contains(normalizedVenus) {
                effects.append("love and connection flowing naturally; good time for relationships and financial decisions; feeling attractive and valued")
            }
        }
        
        // Mercury effects - communication, thinking, decisions, plans
        if let mercuryTransit = transits.first(where: { $0.name == "Mercury" }) {
            let mercuryToSun = abs(mercuryTransit.longitude - chart.sun.longitude)
            let normalizedMercury = mercuryToSun > 180 ? 360 - mercuryToSun : mercuryToSun
            
            if normalizedMercury < 8 {
                effects.append("mental clarity and good communication; ideas flowing; good day for important conversations or decisions")
            } else if (82...98).contains(normalizedMercury) {
                effects.append("miscommunication likely; plans may get complicated; mental stress or overthinking; be extra clear in messages")
            } else if (112...128).contains(normalizedMercury) {
                effects.append("easy communication and mental flow; learning and sharing ideas feels natural")
            }
        }
        
        // Uranus effects - sudden change, breakthroughs, disruption, freedom
        if let uranusTransit = transits.first(where: { $0.name == "Uranus" }) {
            let uranusToSun = abs(uranusTransit.longitude - chart.sun.longitude)
            let normalizedUranus = uranusToSun > 180 ? 360 - uranusToSun : uranusToSun
            
            if normalizedUranus < 8 || (82...98).contains(normalizedUranus) {
                effects.append("unexpected changes or disruptions; feeling restless or rebellious; breakthroughs possible but through chaos; need for freedom intensified")
            } else if (112...128).contains(normalizedUranus) {
                effects.append("innovative breakthroughs and fresh perspectives; exciting changes that feel liberating; ready to try something new")
            }
        }
        
        // Pluto effects - transformation, power, intensity, letting go
        if let plutoTransit = transits.first(where: { $0.name == "Pluto" }) {
            let plutoToSun = abs(plutoTransit.longitude - chart.sun.longitude)
            let normalizedPluto = plutoToSun > 180 ? 360 - plutoToSun : plutoToSun
            
            if normalizedPluto < 8 || (82...98).contains(normalizedPluto) {
                effects.append("intense pressure to transform or let go of old patterns; power dynamics in relationships or work; deep psychological work happening")
            } else if (112...128).contains(normalizedPluto) {
                effects.append("feeling empowered and regenerated; able to transform situations positively; deep insight into yourself")
            }
        }
        
        // Moon effects - daily emotional tone
        if let moonTransit = transits.first(where: { $0.name == "Moon" }) {
            let moonToSun = abs(moonTransit.longitude - chart.sun.longitude)
            let normalizedMoon = moonToSun > 180 ? 360 - moonToSun : moonToSun
            
            if normalizedMoon < 8 {
                effects.append("emotionally introspective; good time for new beginnings and fresh starts")
            } else if (172...188).contains(normalizedMoon) {
                effects.append("emotions running high; things coming to culmination; increased sensitivity")
            } else if (82...98).contains(normalizedMoon) {
                effects.append("emotional complexity; internal tension between different needs")
            }
        }
        
        // Return combined effects or neutral if nothing major
        if effects.isEmpty {
            return "a relatively calm day with steady energy, good for routine activities and internal reflection"
        } else if effects.count == 1 {
            return effects[0]
        } else {
            // Show the 2 most significant effects
            return effects.prefix(2).joined(separator: "; ALSO: ")
        }
    }
    
    func getEnergyPattern(_ transits: [CelestialBody], _ chart: BirthChart) -> String {
        // REAL ASTROLOGICAL ANALYSIS - matches the sophisticated scoring system
        var energyDescriptions: [String] = []
        var dominantEnergy = "balanced and steady energy"
        var intensity = 0
        
        // === MAJOR CHALLENGING TRANSITS ===
        
        // Saturn challenging aspects - restriction, discipline, tests
        if let saturnTransit = transits.first(where: { $0.name == "Saturn" }) {
            let saturnToSun = abs(saturnTransit.longitude - chart.sun.longitude)
            let normalizedSaturn = saturnToSun > 180 ? 360 - saturnToSun : saturnToSun
            
            if normalizedSaturn < 8 { // Saturn conjunction/return
                energyDescriptions.append("serious restructuring and responsibility")
                intensity += 3
                dominantEnergy = "disciplined but pressured energy requiring patience"
            } else if (82...98).contains(normalizedSaturn) { // Square
                energyDescriptions.append("obstacles and important lessons")
                intensity += 4
                dominantEnergy = "challenging energy that builds character through perseverance"
            } else if (172...188).contains(normalizedSaturn) { // Opposition
                energyDescriptions.append("external pressure and authority challenges")
                intensity += 3
                dominantEnergy = "tense energy requiring maturity and careful decisions"
            } else if (112...128).contains(normalizedSaturn) { // Trine
                energyDescriptions.append("earned achievements and stable progress")
                intensity += 1
                dominantEnergy = "productive and structured energy"
            }
        }
        
        // Pluto transformational aspects - crisis, power, rebirth
        if let plutoTransit = transits.first(where: { $0.name == "Pluto" }) {
            let plutoToSun = abs(plutoTransit.longitude - chart.sun.longitude)
            let normalizedPluto = plutoToSun > 180 ? 360 - plutoToSun : plutoToSun
            
            if normalizedPluto < 8 || (82...98).contains(normalizedPluto) { // Conjunction or Square
                energyDescriptions.append("deep transformation and power dynamics")
                intensity += 5
                dominantEnergy = "intense transformational energy demanding psychological growth"
            } else if (172...188).contains(normalizedPluto) { // Opposition
                energyDescriptions.append("power struggles and external transformation pressure")
                intensity += 4
                dominantEnergy = "confrontational energy requiring inner strength"
            } else if (112...128).contains(normalizedPluto) { // Trine
                energyDescriptions.append("empowerment and positive regeneration")
                intensity += 2
                dominantEnergy = "powerfully transformative yet flowing energy"
            }
        }
        
        // Uranus disruptive aspects - sudden change, breakthrough, rebellion
        if let uranusTransit = transits.first(where: { $0.name == "Uranus" }) {
            let uranusToSun = abs(uranusTransit.longitude - chart.sun.longitude)
            let normalizedUranus = uranusToSun > 180 ? 360 - uranusToSun : uranusToSun
            
            if normalizedUranus < 8 || (82...98).contains(normalizedUranus) { // Conjunction or Square
                energyDescriptions.append("sudden changes and breakthrough moments")
                intensity += 4
                dominantEnergy = "unpredictable energy requiring flexibility and openness to change"
            } else if (172...188).contains(normalizedUranus) { // Opposition
                energyDescriptions.append("external disruptions and freedom conflicts")
                intensity += 3
                dominantEnergy = "restless energy seeking liberation from restrictions"
            } else if (112...128).contains(normalizedUranus) { // Trine
                energyDescriptions.append("innovative breakthroughs and exciting progress")
                intensity += 1
                dominantEnergy = "inventive and progressive energy"
            }
        }
        
        // === POSITIVE EXPANSIVE TRANSITS ===
        
        // Jupiter beneficial aspects - growth, opportunity, optimism
        if let jupiterTransit = transits.first(where: { $0.name == "Jupiter" }) {
            let jupiterToSun = abs(jupiterTransit.longitude - chart.sun.longitude)
            let normalizedJupiter = jupiterToSun > 180 ? 360 - jupiterToSun : jupiterToSun
            
            if normalizedJupiter < 8 { // Jupiter return
                energyDescriptions.append("major expansion and new opportunities")
                dominantEnergy = "optimistic and expansive energy with abundant possibilities"
            } else if (112...128).contains(normalizedJupiter) { // Trine
                energyDescriptions.append("natural growth and flowing abundance")
                dominantEnergy = "lucky and expansive energy supporting success"
            } else if (52...68).contains(normalizedJupiter) { // Sextile
                energyDescriptions.append("growth opportunities through effort")
                dominantEnergy = "optimistic energy with opportunities for development"
            } else if (82...98).contains(normalizedJupiter) { // Square
                energyDescriptions.append("overconfidence and excess tendencies")
                dominantEnergy = "overexpansive energy requiring moderation"
            }
        }
        
        // === DAILY ACTION AND EMOTION ===
        
        // Mars action energy
        if let marsTransit = transits.first(where: { $0.name == "Mars" }) {
            let marsToSun = abs(marsTransit.longitude - chart.sun.longitude)
            let normalizedMars = marsToSun > 180 ? 360 - marsToSun : marsToSun
            
            if (82...98).contains(normalizedMars) { // Square
                energyDescriptions.append("impatience and potential conflicts")
                intensity += 2
                if intensity <= 2 { dominantEnergy = "restless and impatient energy requiring careful action" }
            } else if (172...188).contains(normalizedMars) { // Opposition
                energyDescriptions.append("confrontational dynamics and competition")
                intensity += 2
                if intensity <= 2 { dominantEnergy = "competitive energy requiring diplomatic handling" }
            } else if (112...128).contains(normalizedMars) { // Trine
                energyDescriptions.append("productive action and clear direction")
                if intensity <= 1 { dominantEnergy = "energetic and productive energy for taking action" }
            }
        }
        
        // Moon emotional flow
        if let moonTransit = transits.first(where: { $0.name == "Moon" }) {
            let moonToSun = abs(moonTransit.longitude - chart.sun.longitude)
            let normalizedMoon = moonToSun > 180 ? 360 - moonToSun : moonToSun
            
            if normalizedMoon < 8 { // New Moon energy
                if intensity == 0 { dominantEnergy = "introspective and renewal-focused energy" }
            } else if (172...188).contains(normalizedMoon) { // Full Moon energy
                if intensity == 0 { dominantEnergy = "emotionally heightened and culminating energy" }
            } else if (82...98).contains(normalizedMoon) { // Quarter Moon tension
                if intensity == 0 { dominantEnergy = "emotionally complex energy requiring balance" }
            }
        }
        
        // === COMBINE DESCRIPTIONS ===
        if energyDescriptions.isEmpty {
            return dominantEnergy
        } else if energyDescriptions.count == 1 {
            return dominantEnergy
        } else {
            // Multiple influences - show complexity
            let combinedDescriptions = energyDescriptions.prefix(2).joined(separator: ", plus ")
            return "complex energy involving \(combinedDescriptions)"
        }
    }
    
    func getWeeklyEnergyPattern(_ transits: [CelestialBody], _ chart: BirthChart) -> String {
        // WEEKLY FOCUS - emphasize faster-moving planets for week-long themes
        var weeklyThemes: [String] = []
        let baseEnergy = getEnergyPattern(transits, chart)
        var weeklyFocus = baseEnergy
        var intensity = 0
        
        // === WEEKLY RELATIONSHIP & COMMUNICATION THEMES ===
        
        // Venus weekly themes - relationships, values, creativity, money
        if let venusTransit = transits.first(where: { $0.name == "Venus" }) {
            let venusToSun = abs(venusTransit.longitude - chart.sun.longitude)
            let normalizedVenus = venusToSun > 180 ? 360 - venusToSun : venusToSun
            
            if normalizedVenus < 8 { // Venus conjunction
                weeklyThemes.append("harmonious relationships and creative expression")
                weeklyFocus = "loving and creative energy with enhanced social connections"
                intensity += 2
            } else if (82...98).contains(normalizedVenus) { // Square
                weeklyThemes.append("relationship tensions and value conflicts")
                weeklyFocus = "complex relationship dynamics requiring diplomatic balance"
                intensity += 3
            } else if (172...188).contains(normalizedVenus) { // Opposition
                weeklyThemes.append("relationship polarities and partnership decisions")
                weeklyFocus = "relationship-focused energy requiring compromise and understanding"
                intensity += 2
            } else if (112...128).contains(normalizedVenus) { // Trine
                weeklyThemes.append("flowing social energy and creative abundance")
                weeklyFocus = "harmonious creative and social energy supporting connections"
                intensity += 1
            }
            
            // Check Venus to Moon for emotional relationships
            let venusToMoon = abs(venusTransit.longitude - chart.moon.longitude)
            let normalizedVenusMoon = venusToMoon > 180 ? 360 - venusToMoon : venusToMoon
            if normalizedVenusMoon < 8 || (112...128).contains(normalizedVenusMoon) {
                weeklyThemes.append("emotional fulfillment in relationships")
            }
        }
        
        // Mercury weekly themes - communication, decisions, learning
        if let mercuryTransit = transits.first(where: { $0.name == "Mercury" }) {
            let mercuryToSun = abs(mercuryTransit.longitude - chart.sun.longitude)
            let normalizedMercury = mercuryToSun > 180 ? 360 - mercuryToSun : mercuryToSun
            
            if normalizedMercury < 8 { // Mercury conjunction
                weeklyThemes.append("clear communication and mental clarity")
                if intensity <= 1 { weeklyFocus = "mentally stimulating energy perfect for planning and communication" }
            } else if (82...98).contains(normalizedMercury) { // Square
                weeklyThemes.append("communication challenges and decision pressure")
                if intensity <= 2 { weeklyFocus = "mentally complex energy requiring careful communication" }
                intensity += 2
            } else if (172...188).contains(normalizedMercury) { // Opposition
                weeklyThemes.append("differing perspectives and negotiation needs")
                if intensity <= 1 { weeklyFocus = "mentally active energy requiring balance between different viewpoints" }
            } else if (112...128).contains(normalizedMercury) { // Trine
                weeklyThemes.append("smooth communication and easy learning")
                if intensity == 0 { weeklyFocus = "mentally harmonious energy supporting clear thinking" }
            }
        }
        
        // Mars weekly themes - action, energy, initiative, conflicts
        if let marsTransit = transits.first(where: { $0.name == "Mars" }) {
            let marsToSun = abs(marsTransit.longitude - chart.sun.longitude)
            let normalizedMars = marsToSun > 180 ? 360 - marsToSun : marsToSun
            
            if normalizedMars < 8 { // Mars conjunction
                weeklyThemes.append("high energy and bold initiatives")
                weeklyFocus = "dynamic action-oriented energy perfect for starting new projects"
                intensity += 2
            } else if (82...98).contains(normalizedMars) { // Square
                weeklyThemes.append("impatience and potential conflicts")
                weeklyFocus = "restless and confrontational energy requiring patience and strategy"
                intensity += 3
            } else if (172...188).contains(normalizedMars) { // Opposition
                weeklyThemes.append("external challenges and competitive dynamics")
                weeklyFocus = "competitive energy requiring careful navigation of conflicts"
                intensity += 2
            } else if (112...128).contains(normalizedMars) { // Trine
                weeklyThemes.append("productive action and successful initiatives")
                weeklyFocus = "energetic and successful energy supporting bold moves"
                intensity += 1
            }
        }
        
        // === COMBINE WEEKLY THEMES ===
        if weeklyThemes.isEmpty {
            return baseEnergy + " with steady weekly progression"
        } else if weeklyThemes.count == 1 {
            return weeklyFocus
        } else {
            // Multiple weekly influences - show the complexity
            let primaryThemes = weeklyThemes.prefix(2).joined(separator: " combined with ")
            return "multifaceted energy involving " + primaryThemes
        }
    }
    
    func getMonthlyTheme(_ transits: [CelestialBody], _ chart: BirthChart) -> String {
        // REAL ASTROLOGICAL MONTHLY THEMES - focus on slower planets for sustained themes
        var monthlyThemes: [String] = []
        
        // Saturn monthly themes - structure, responsibility, lessons
        if let saturnTransit = transits.first(where: { $0.name == "Saturn" }) {
            let saturnToSun = abs(saturnTransit.longitude - chart.sun.longitude)
            let normalizedSaturn = saturnToSun > 180 ? 360 - saturnToSun : saturnToSun
            
            if normalizedSaturn < 8 || (82...98).contains(normalizedSaturn) {
                monthlyThemes.append("restructuring your life foundations and learning important lessons")
            } else if (172...188).contains(normalizedSaturn) {
                monthlyThemes.append("dealing with external pressure and authority challenges")
            } else if (112...128).contains(normalizedSaturn) {
                monthlyThemes.append("building solid foundations and achieving well-earned recognition")
            }
        }
        
        // Jupiter monthly themes - growth, opportunity, expansion
        if let jupiterTransit = transits.first(where: { $0.name == "Jupiter" }) {
            let jupiterToSun = abs(jupiterTransit.longitude - chart.sun.longitude)
            let normalizedJupiter = jupiterToSun > 180 ? 360 - jupiterToSun : jupiterToSun
            
            if normalizedJupiter < 8 {
                monthlyThemes.append("major expansion and seizing abundant new opportunities")
            } else if (112...128).contains(normalizedJupiter) {
                monthlyThemes.append("natural growth and expanding your horizons")
            } else if (52...68).contains(normalizedJupiter) {
                monthlyThemes.append("learning new skills and developing your potential")
            } else if (82...98).contains(normalizedJupiter) {
                monthlyThemes.append("moderating excess and avoiding overcommitment")
            }
        }
        
        // Uranus monthly themes - change, innovation, freedom
        if let uranusTransit = transits.first(where: { $0.name == "Uranus" }) {
            let uranusToSun = abs(uranusTransit.longitude - chart.sun.longitude)
            let normalizedUranus = uranusToSun > 180 ? 360 - uranusToSun : uranusToSun
            
            if normalizedUranus < 8 || (82...98).contains(normalizedUranus) {
                monthlyThemes.append("embracing revolutionary changes and breaking free from limitations")
            } else if (112...128).contains(normalizedUranus) {
                monthlyThemes.append("innovative breakthroughs and progressive personal development")
            }
        }
        
        // Pluto monthly themes - transformation, power, regeneration
        if let plutoTransit = transits.first(where: { $0.name == "Pluto" }) {
            let plutoToSun = abs(plutoTransit.longitude - chart.sun.longitude)
            let normalizedPluto = plutoToSun > 180 ? 360 - plutoToSun : plutoToSun
            
            if normalizedPluto < 8 || (82...98).contains(normalizedPluto) {
                monthlyThemes.append("deep personal transformation and releasing old patterns")
            } else if (112...128).contains(normalizedPluto) {
                monthlyThemes.append("empowerment and positive regeneration of your life direction")
            }
        }
        
        // Venus themes for relationship and money focus
        if let venusTransit = transits.first(where: { $0.name == "Venus" }) {
            let venusToNatalVenus = abs(venusTransit.longitude - chart.venus.longitude)
            let normalizedVenus = venusToNatalVenus > 180 ? 360 - venusToNatalVenus : venusToNatalVenus
            
            if normalizedVenus < 8 {
                monthlyThemes.append("relationship development and financial planning")
            } else if (112...128).contains(normalizedVenus) {
                monthlyThemes.append("harmonious relationship dynamics and creative self-expression")
            }
        }
        
        // Return the most significant theme or combination
        if monthlyThemes.isEmpty {
            return "inner reflection and steady personal development"
        } else if monthlyThemes.count == 1 {
            return monthlyThemes[0]
        } else {
            // Multiple themes - show the most significant
            return monthlyThemes[0] + ", alongside " + monthlyThemes[1]
        }
    }
    
    func getYearlyTheme(_ transits: [CelestialBody], _ chart: BirthChart) -> String {
        // REAL ASTROLOGICAL YEARLY THEMES - focus on major life cycle transits
        var yearlyThemes: [String] = []
        
        // Jupiter yearly themes - 12-year expansion cycles
        if let jupiterTransit = transits.first(where: { $0.name == "Jupiter" }) {
            let jupiterToSun = abs(jupiterTransit.longitude - chart.sun.longitude)
            let normalizedJupiter = jupiterToSun > 180 ? 360 - jupiterToSun : jupiterToSun
            
            if normalizedJupiter < 8 { // Jupiter return (every 12 years)
                yearlyThemes.append("stepping into a major expansion cycle and embracing abundant new opportunities")
            } else if (112...128).contains(normalizedJupiter) {
                yearlyThemes.append("expanding your worldview and achieving natural growth through flowing opportunities")
            } else if (52...68).contains(normalizedJupiter) {
                yearlyThemes.append("developing your potential and learning new perspectives through focused effort")
            }
        }
        
        // Saturn yearly themes - 29-year maturity cycles
        if let saturnTransit = transits.first(where: { $0.name == "Saturn" }) {
            let saturnToSun = abs(saturnTransit.longitude - chart.sun.longitude)
            let normalizedSaturn = saturnToSun > 180 ? 360 - saturnToSun : saturnToSun
            
            if normalizedSaturn < 8 { // Saturn return (every 29 years)
                yearlyThemes.append("completing a major life chapter and building lasting foundations for the next phase")
            } else if (82...98).contains(normalizedSaturn) {
                yearlyThemes.append("learning essential life lessons and developing authentic personal power through challenges")
            } else if (112...128).contains(normalizedSaturn) {
                yearlyThemes.append("building lasting foundations and achieving well-earned recognition for your efforts")
            }
        }
        
        // Uranus yearly themes - 84-year revolution cycles
        if let uranusTransit = transits.first(where: { $0.name == "Uranus" }) {
            let uranusToSun = abs(uranusTransit.longitude - chart.sun.longitude)
            let normalizedUranus = uranusToSun > 180 ? 360 - uranusToSun : uranusToSun
            
            if normalizedUranus < 8 || (82...98).contains(normalizedUranus) {
                yearlyThemes.append("embracing revolutionary personal change and breaking free from limiting patterns")
            } else if (112...128).contains(normalizedUranus) {
                yearlyThemes.append("innovative breakthroughs and finding your unique voice through progressive change")
            }
        }
        
        // Neptune yearly themes - 165-year spiritual cycles
        if let neptuneTransit = transits.first(where: { $0.name == "Neptune" }) {
            let neptuneToSun = abs(neptuneTransit.longitude - chart.sun.longitude)
            let normalizedNeptune = neptuneToSun > 180 ? 360 - neptuneToSun : neptuneToSun
            
            if normalizedNeptune < 8 || (82...98).contains(normalizedNeptune) {
                yearlyThemes.append("developing your intuition and navigating spiritual transformation with discernment")
            } else if (112...128).contains(normalizedNeptune) {
                yearlyThemes.append("developing your spiritual understanding and creative expression through inspiration")
            }
        }
        
        // Pluto yearly themes - 248-year regeneration cycles
        if let plutoTransit = transits.first(where: { $0.name == "Pluto" }) {
            let plutoToSun = abs(plutoTransit.longitude - chart.sun.longitude)
            let normalizedPluto = plutoToSun > 180 ? 360 - plutoToSun : plutoToSun
            
            if normalizedPluto < 8 || (82...98).contains(normalizedPluto) {
                yearlyThemes.append("healing old patterns and embracing profound personal transformation")
            } else if (112...128).contains(normalizedPluto) {
                yearlyThemes.append("stepping into authentic personal power through positive regeneration")
            }
        }
        
        // Return the most significant yearly theme
        if yearlyThemes.isEmpty {
            return "deepening relationships and developing emotional intelligence through steady growth"
        } else if yearlyThemes.count == 1 {
            return yearlyThemes[0]
        } else {
            // Multiple major themes - show the most transformational
            return yearlyThemes[0]
        }
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
        // Use data-driven insight generator - it's better than generic fallbacks
        return DataDrivenInsightGenerator.shared.generateDailyInsight(chart: chart, transits: transits, date: Date())
    }
    
    func createFallbackWeeklyInsight(chart: BirthChart, transits: [CelestialBody]) -> String {
        // Generate comprehensive weekly insight based on actual transits
        // This matches the quality and style of cycle descriptions
        
        var insights: [String] = []
        
        // Check for significant fast-moving transits this week
        let currentAspects = findWeeklyAspects(chart: chart, transits: transits)
        
        if let primaryAspect = currentAspects.first {
            // Use the most significant aspect to frame the week
            let aspectInsight = interpretWeeklyAspect(primaryAspect, chart: chart)
            insights.append(aspectInsight)
        }
        
        // Add context about the Moon's movement this week (changes ~4 times)
        if let moon = transits.first(where: { $0.name == "Moon" }) {
            let moonContext = getMoonWeeklyContext(moon, chart: chart)
            insights.append(moonContext)
        }
        
        // Add actionable advice based on overall energy
        let actionableAdvice = getWeeklyActionableAdvice(transits: transits, chart: chart)
        insights.append(actionableAdvice)
        
        // Combine into cohesive narrative
        return insights.joined(separator: " ")
    }
    
    func createFallbackMonthlyInsight(chart: BirthChart, transits: [CelestialBody]) -> String {
        // Generate comprehensive monthly insight based on slower-moving transits
        var insights: [String] = []
        
        // Check for significant monthly transits (Mars, Venus position)
        let monthlyAspects = findMonthlyAspects(chart: chart, transits: transits)
        
        if let primaryAspect = monthlyAspects.first {
            let aspectInsight = interpretMonthlyAspect(primaryAspect, chart: chart)
            insights.append(aspectInsight)
        }
        
        // Add Sun sign context for the month
        if let sun = transits.first(where: { $0.name == "Sun" }) {
            let sunContext = getSunMonthlyContext(sun, chart: chart)
            insights.append(sunContext)
        }
        
        // Add actionable monthly focus
        let monthlyFocus = getMonthlyFocus(transits: transits, chart: chart)
        insights.append(monthlyFocus)
        
        return insights.joined(separator: " ")
    }
    
    func createFallbackYearlyInsight(chart: BirthChart, transits: [CelestialBody]) -> String {
        // Generate comprehensive yearly insight based on major themes
        var insights: [String] = []
        
        // Check for significant yearly transits (Jupiter, Saturn if they're making aspects)
        let yearlyAspects = findYearlyAspects(chart: chart, transits: transits)
        
        if let primaryAspect = yearlyAspects.first {
            let aspectInsight = interpretYearlyAspect(primaryAspect, chart: chart)
            insights.append(aspectInsight)
        } else {
            // No major outer planet transits - give Sun sign yearly theme
            let sunTheme = getSunYearlyTheme(chart: chart)
            insights.append(sunTheme)
        }
        
        // Add yearly focus areas
        let yearlyFocus = getYearlyFocus(chart: chart, transits: transits)
        insights.append(yearlyFocus)
        
        // Add practical yearly advice
        let yearlyAdvice = getYearlyAdvice(chart: chart)
        insights.append(yearlyAdvice)
        
        return insights.joined(separator: " ")
    }
    
    func createFallbackCycleInsight(cycles: [AstrologicalCycle], chart: BirthChart) -> String {
        let personalityTraits = getPersonalityTraits(chart)
        
        if cycles.isEmpty {
            return "This is a time for steady progress and inner development. Trust your \(personalityTraits) nature to guide your decisions."
        }
        
        let dominantCycle = cycles[0]
        let influence = dominantCycle.influence
        
        switch influence {
        case .positive:
            return "Current planetary cycles support growth and positive development. Your \(personalityTraits) approach will help you maximize these favorable influences."
        case .challenging:
            return "Current cycles bring important lessons and character-building experiences. Your \(personalityTraits) strength will help you navigate these challenges with wisdom."
        case .transformative:
            return "Powerful transformational cycles are reshaping your path forward. Your \(personalityTraits) nature provides the foundation for embracing these deep changes."
        case .neutral:
            return "Current cycles support balanced progress and thoughtful decision-making. Your \(personalityTraits) perspective will guide you toward the right choices."
        }
    }
    
    func createFallbackChatResponse(question: String, chart: BirthChart) -> String {
        let transits = AstrologyService.shared.calculateCurrentTransits()
        let todaysEnergy = getEnergyPattern(transits, chart)
        let lowerQuestion = question.lowercased()
        
        // Relationship questions
        if lowerQuestion.contains("girlfriend") || lowerQuestion.contains("boyfriend") || 
           lowerQuestion.contains("relationship") || lowerQuestion.contains("reach out") ||
           lowerQuestion.contains("text") || lowerQuestion.contains("call") {
            if todaysEnergy.contains("challenging") || todaysEnergy.contains("obstacles") {
                return "The planets are testing you right now. If reaching out feels right despite the fear, that's your answer. But if it's coming from desperation, wait a bit."
            } else {
                return "If you're asking, part of you already knows what you want to do. What's your gut saying? That's usually the right call."
            }
        }
        
        // Career/job questions
        if lowerQuestion.contains("job") || lowerQuestion.contains("career") || 
           lowerQuestion.contains("work") || lowerQuestion.contains("quit") {
            return "The energy right now is pushing you toward what feels more authentic. What would you do if fear wasn't running the show?"
        }
        
        // Decision questions
        if lowerQuestion.contains("should i") {
            return "You already know what you want to do. The question is whether you trust yourself enough to do it."
        }
        
        // Default based on energy
        if todaysEnergy.contains("challenging") || todaysEnergy.contains("obstacles") {
            return "Things feel hard because they're forcing you to level up. Trust that the resistance has a purpose."
        } else {
            return "The timing looks good. Trust your instincts and move forward."
        }
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
    
    // MARK: - Comprehensive Weekly Insights
    
    func findWeeklyAspects(chart: BirthChart, transits: [CelestialBody]) -> [WeeklyTransitAspect] {
        var aspects: [WeeklyTransitAspect] = []
        
        let natalPlanets: [(String, Double)] = [
            ("Sun", chart.sun.longitude),
            ("Moon", chart.moon.longitude),
            ("Venus", chart.venus.longitude),
            ("Mars", chart.mars.longitude),
            ("Mercury", chart.mercury.longitude)
        ]
        
        // Check fast-moving planets that matter for weekly forecasts
        let weeklyPlanets = ["Mars", "Venus", "Mercury", "Sun"]
        
        for planetName in weeklyPlanets {
            guard let transit = transits.first(where: { $0.name == planetName }) else { continue }
            
            for (natalName, natalLong) in natalPlanets {
                let diff = abs(transit.longitude - natalLong)
                let angle = diff > 180 ? 360 - diff : diff
                
                // Weekly orbs (slightly wider since it covers 7 days)
                if angle < 10 {
                    aspects.append(WeeklyTransitAspect(transitPlanet: planetName, natalPlanet: natalName, type: .conjunction))
                } else if abs(angle - 90) < 10 {
                    aspects.append(WeeklyTransitAspect(transitPlanet: planetName, natalPlanet: natalName, type: .square))
                } else if abs(angle - 120) < 10 {
                    aspects.append(WeeklyTransitAspect(transitPlanet: planetName, natalPlanet: natalName, type: .trine))
                } else if abs(angle - 180) < 10 {
                    aspects.append(WeeklyTransitAspect(transitPlanet: planetName, natalPlanet: natalName, type: .opposition))
                }
            }
        }
        
        return aspects
    }
    
    func interpretWeeklyAspect(_ aspect: WeeklyTransitAspect, chart: BirthChart) -> String {
        let isHard = aspect.type == .square || aspect.type == .opposition
        
        switch (aspect.transitPlanet, aspect.natalPlanet) {
        case ("Mars", "Sun"):
            if isHard {
                return "Your energy levels might feel inconsistent this week—high one moment, drained the next. Don't commit to more than you can realistically handle. Rest matters even when you feel like pushing through. Save the big moves for when your stamina is more stable."
            } else {
                return "This week brings strong, steady energy for tackling whatever you've been putting off. Your confidence and drive are aligned, making it easier to take action on goals that require courage. Physical activity feels especially good and helps channel the momentum productively."
            }
        
        case ("Mars", "Venus"):
            if isHard {
                return "Tension between what you want and how aggressively you're pursuing it. You might push too hard in relationships or come on too strong. Ease up on the intensity and let things develop naturally. Sometimes backing off creates the space for what you want to actually happen."
            } else {
                return "Great week for going after what (or who) you want. Your desire and your ability to act on it work together smoothly. If you've been hesitating on making a move—romantic, creative, or otherwise—this is your window. Your timing and approach feel natural rather than forced."
            }
            
        case ("Venus", "Sun"):
            if isHard {
                return "You're questioning what actually makes you happy versus what you think should make you happy. The disconnect is uncomfortable but revealing. Don't make major decisions about relationships or values right now—just notice what's surfacing. The clarity comes after the confusion, not during it."
            } else {
                return "This week you feel good in your own skin. What you value and who you are line up naturally, which makes everything feel easier. Good time for social events, asking for what you're worth, or simply enjoying pleasures without guilt. Your natural charm is especially effective right now."
            }
            
        case ("Mercury", "Sun"), ("Mercury", "Moon"):
            if isHard {
                return "Communication feels harder than usual this week. What you're trying to say isn't landing right, or others are misinterpreting your intentions. Take extra time to clarify important points and double-check messages before sending. Better to over-communicate than assume understanding that isn't there."
            } else {
                return "Your thoughts are clear and your ability to express them is sharp. Great week for important conversations, presentations, or any communication that matters. People understand what you mean and respond well to your ideas. Use this mental clarity to tackle anything requiring focused thinking or articulate expression."
            }
            
        default:
            // Generic but still good
            if isHard {
                return "This week presents some friction that's asking you to grow. What feels difficult now is building capacity you'll need later. Push through the resistance when it matters, but also know when to step back and let things settle. Not everything needs to be forced."
            } else {
                return "Things flow more naturally this week. Opportunities align with effort in ways that feel lucky but are actually you being in the right place at the right time. Take advantage of the ease while it's here—it won't always feel this smooth."
            }
        }
    }
    
    func getMoonWeeklyContext(_ moon: CelestialBody, chart: BirthChart) -> String {
        let moonSign = moon.position.sign
        
        // The Moon changes signs ~4 times per week, so give general context
        return "Emotionally, the week starts with Moon in \(moonSign.rawValue), which shifts the general feeling tone. Your internal world might fluctuate as the Moon moves through different signs, so don't attach too much meaning to temporary moods. What you feel on Monday might not be what you feel by Friday."
    }
    
    func getWeeklyActionableAdvice(transits: [CelestialBody], chart: BirthChart) -> String {
        // Check for Mercury retrograde or other notable conditions
        if let mercury = transits.first(where: { $0.name == "Mercury" }) {
            // Simplified check - in real app you'd check actual retrograde status
            let mercuryDegree = Int(mercury.longitude) % 360
            // This is approximate - real retrograde detection would be more complex
            if mercuryDegree > 330 || mercuryDegree < 30 {
                return "Back up important files and double-check travel plans. Communication tech might act up this week, so don't wait until the last minute for anything crucial."
            }
        }
        
        // Check for Mars activity (energy levels)
        if let mars = transits.first(where: { $0.name == "Mars" }) {
            let marsSign = mars.position.sign
            if marsSign == .aries || marsSign == .scorpio {
                return "Physical energy runs high this week—channel it into workouts, projects, or anything requiring sustained effort. The drive is there; make sure you're directing it somewhere productive rather than letting it turn into irritability."
            }
        }
        
        // Default advice based on Sun sign
        let sunSign = chart.sunSign
        switch sunSign {
        case .aries, .leo, .sagittarius:
            return "Your natural optimism serves you well this week, but pair it with practical follow-through. Grand ideas need concrete action to manifest. Start something rather than just thinking about starting something."
        case .taurus, .virgo, .capricorn:
            return "This week rewards your practical approach. Focus on steady progress over dramatic breakthroughs. The work you put in now builds a foundation that lasts, even if results aren't immediately visible."
        case .gemini, .libra, .aquarius:
            return "Your ability to see multiple perspectives is an asset this week, but at some point you need to pick a direction. Gather the information, consider the options, then commit to a choice. Endless analysis doesn't move you forward."
        case .cancer, .scorpio, .pisces:
            return "Trust your emotional intelligence this week—it's picking up on things logic can't access. If something feels off, it probably is. If something feels right, it probably is. Your instincts are accurate even when you can't explain them."
        }
    }
    
    // MARK: - Comprehensive Monthly Insights
    
    func findMonthlyAspects(chart: BirthChart, transits: [CelestialBody]) -> [WeeklyTransitAspect] {
        var aspects: [WeeklyTransitAspect] = []
        
        let natalPlanets: [(String, Double)] = [
            ("Sun", chart.sun.longitude),
            ("Moon", chart.moon.longitude),
            ("Venus", chart.venus.longitude),
            ("Mars", chart.mars.longitude)
        ]
        
        // Monthly planets (slower movers that stay for the month)
        let monthlyPlanets = ["Mars", "Venus"]
        
        for planetName in monthlyPlanets {
            guard let transit = transits.first(where: { $0.name == planetName }) else { continue }
            
            for (natalName, natalLong) in natalPlanets {
                let diff = abs(transit.longitude - natalLong)
                let angle = diff > 180 ? 360 - diff : diff
                
                if angle < 8 {
                    aspects.append(WeeklyTransitAspect(transitPlanet: planetName, natalPlanet: natalName, type: .conjunction))
                } else if abs(angle - 90) < 8 {
                    aspects.append(WeeklyTransitAspect(transitPlanet: planetName, natalPlanet: natalName, type: .square))
                } else if abs(angle - 120) < 8 {
                    aspects.append(WeeklyTransitAspect(transitPlanet: planetName, natalPlanet: natalName, type: .trine))
                }
            }
        }
        
        return aspects
    }
    
    func interpretMonthlyAspect(_ aspect: WeeklyTransitAspect, chart: BirthChart) -> String {
        let isHard = aspect.type == .square
        
        switch (aspect.transitPlanet, aspect.natalPlanet) {
        case ("Mars", "Sun"):
            if isHard {
                return "This month tests your energy management and ability to assert yourself effectively. You might feel like you're pushing against resistance in areas where you want to make progress. The key is strategic effort rather than brute force. Pick your battles, conserve energy for what actually matters, and don't waste effort on things that won't budge right now. What you learn about pacing yourself this month serves you long-term."
            } else {
                return "Strong month for making things happen through sustained effort. Your energy levels are good and your confidence backs up your actions. This is your window to tackle ambitious projects, start new ventures, or make bold moves you've been planning. The drive is there, the timing is right, and results come from the work you put in. Don't waste this momentum on hesitation—use it."
            }
        
        case ("Mars", "Venus"):
            if isHard {
                return "This month brings tension between desire and pursuit, between what you want and how you go after it. You might feel frustrated that things aren't developing as quickly as you'd like, especially in relationships or creative work. The lesson is about sustainable pursuit versus forcing outcomes. Let go of what requires constant pushing and focus on what responds to your effort. Not everything is meant to be yours just because you want it."
            } else {
                return "Excellent month for combining passion with action. What you desire and your ability to go after it work together naturally. This is great energy for romance, creative projects, or anything requiring both wanting something and doing something about it. Your approach feels neither too passive nor too aggressive—just right. Take advantage of this balance to pursue what genuinely excites you."
            }
            
        case ("Venus", "Sun"):
            if isHard {
                return "This month asks you to reconsider what actually brings you joy versus what you think should bring you joy. There's discomfort in the gap between your values and your reality. Use this friction productively—it's showing you where you've been living according to someone else's definition of success or happiness. The clarity hurts before it helps, but it's necessary for authentic alignment."
            } else {
                return "This month you feel comfortable with who you are and what you value. Self-acceptance comes more easily, making everything from relationships to work feel less strained. Good month for enjoying life's pleasures without guilt, asking for what you're worth, and being yourself without apology. When you're at peace with yourself, others respond to that ease."
            }
            
        default:
            if isHard {
                return "This month brings friction that's asking you to grow. Challenges aren't punishment—they're showing you where you need to develop capacity. The difficulty you face now is building strength you'll need later. Work with the resistance rather than against it, and trust that struggle has purpose even when it's uncomfortable."
            } else {
                return "This month offers favorable conditions for progress in key areas of your life. Opportunities and effort align in ways that make forward movement feel natural. Take advantage of this ease while it's here—not every month flows this smoothly. When things come together easily, it's not luck, it's right timing meeting right action."
            }
        }
    }
    
    func getSunMonthlyContext(_ sun: CelestialBody, chart: BirthChart) -> String {
        let sunSign = sun.position.sign
        
        // Give context about the solar month's energy
        return "The Sun in \(sunSign.rawValue) colors the month with \(getSunSignMonthlyTone(sunSign)) energy. This affects everyone, but for you personally, it interacts with your \(chart.sunSign.rawValue) nature in ways that might feel either complementary or challenging depending on how aligned these energies are."
    }
    
    func getSunSignMonthlyTone(_ sign: ZodiacSign) -> String {
        switch sign {
        case .aries: return "bold, initiating"
        case .taurus: return "steady, grounding"
        case .gemini: return "curious, communicative"
        case .cancer: return "emotional, nurturing"
        case .leo: return "expressive, confident"
        case .virgo: return "practical, analytical"
        case .libra: return "balanced, relational"
        case .scorpio: return "intense, transformative"
        case .sagittarius: return "expansive, optimistic"
        case .capricorn: return "ambitious, disciplined"
        case .aquarius: return "innovative, detached"
        case .pisces: return "intuitive, compassionate"
        }
    }
    
    func getMonthlyFocus(transits: [CelestialBody], chart: BirthChart) -> String {
        // Check where Mars is (energy focus)
        if let mars = transits.first(where: { $0.name == "Mars" }) {
            let marsSign = mars.position.sign
            switch marsSign {
            case .aries, .scorpio:
                return "This month rewards direct action and bold moves. Channel your energy into starting things rather than maintaining things. Initiation is favored over continuation."
            case .taurus, .capricorn:
                return "This month rewards patience and sustained effort. Build something that lasts rather than chasing quick wins. Consistency matters more than intensity right now."
            case .gemini, .libra, .aquarius:
                return "This month rewards strategic thinking and communication. Mental energy is high—use it for planning, networking, and idea generation rather than just executing."
            case .cancer, .pisces:
                return "This month rewards emotional intelligence and intuitive action. Trust your gut about when to push and when to pull back. Feelings are information, not obstacles."
            default:
                return "Focus on aligning your actions with your actual priorities this month. It's easy to stay busy without being productive. Make sure your effort serves your real goals."
            }
        }
        
        return "This month asks you to focus on sustainable progress rather than dramatic breakthroughs. Small consistent action beats sporadic intensity. Show up daily and trust the compound effect."
    }
    
    // MARK: - Comprehensive Yearly Insights
    
    func findYearlyAspects(chart: BirthChart, transits: [CelestialBody]) -> [WeeklyTransitAspect] {
        var aspects: [WeeklyTransitAspect] = []
        
        let natalPlanets: [(String, Double)] = [
            ("Sun", chart.sun.longitude),
            ("Moon", chart.moon.longitude),
            ("Venus", chart.venus.longitude),
            ("Mars", chart.mars.longitude)
        ]
        
        // Yearly planets (slow movers)
        let yearlyPlanets = ["Jupiter", "Saturn"]
        
        for planetName in yearlyPlanets {
            guard let transit = transits.first(where: { $0.name == planetName }) else { continue }
            
            for (natalName, natalLong) in natalPlanets {
                let diff = abs(transit.longitude - natalLong)
                let angle = diff > 180 ? 360 - diff : diff
                
                // Tight orbs for major transits
                if angle < 6 {
                    aspects.append(WeeklyTransitAspect(transitPlanet: planetName, natalPlanet: natalName, type: .conjunction))
                } else if abs(angle - 90) < 6 {
                    aspects.append(WeeklyTransitAspect(transitPlanet: planetName, natalPlanet: natalName, type: .square))
                } else if abs(angle - 120) < 6 {
                    aspects.append(WeeklyTransitAspect(transitPlanet: planetName, natalPlanet: natalName, type: .trine))
                }
            }
        }
        
        return aspects
    }
    
    func interpretYearlyAspect(_ aspect: WeeklyTransitAspect, chart: BirthChart) -> String {
        let isHard = aspect.type == .square
        
        switch aspect.transitPlanet {
        case "Jupiter":
            if isHard {
                return "This is a year of expansion that requires wisdom. Opportunities come your way, but not all of them are as good as they seem. The challenge is discerning between real growth and empty inflation. You might be tempted to overextend, overpromise, or take on more than you can sustain. The lesson is about quality expansion rather than just getting bigger. Build something that lasts, not something that impresses. True growth has foundations."
            } else {
                return "This is a favorable year for growth, opportunity, and positive development in major life areas. Things you've been working toward start paying off, and new possibilities open up that actually align with who you are. This isn't magic—it's your preparation meeting good timing. Say yes to opportunities that genuinely excite you and no to ones that just sound good. Your judgment about what's worth pursuing is solid this year. Trust your optimism but pair it with practical follow-through."
            }
        
        case "Saturn":
            if isHard {
                return "This year tests your commitment, discipline, and resilience. What you face isn't punishment—it's life asking if you really want what you say you want. The difficulty you encounter is building character and capacity you'll need for what comes next. This is a year of maturation through challenge. Push through the resistance when it matters, but also learn to work smarter rather than just harder. The strength you build this year becomes permanent. What feels like limitation is actually focusing your energy on what truly matters."
            } else {
                return "This is a year when hard work pays off in tangible, lasting ways. Structure and discipline don't feel like burdens—they feel like tools that help you build something real. This is excellent for long-term projects, career advancement, or any goal requiring sustained commitment. You have the patience and the persistence to see things through. The results you create this year have staying power because you're building foundations, not facades. Take yourself and your goals seriously."
            }
        
        default:
            return "This year brings significant developments in areas you've been working on or thinking about. The timing is right for major moves if you've done the preparation. Trust that what's meant to unfold will, but don't wait passively—participate in your own evolution. Big years require bold action backed by careful planning."
        }
    }
    
    func getSunYearlyTheme(chart: BirthChart) -> String {
        let sunSign = chart.sunSign
        
        switch sunSign {
        case .aries:
            return "This year asks you to refine how you assert yourself and pursue what you want. The challenge is balancing boldness with wisdom, courage with patience. Your natural instinct to act quickly serves you well, but this year rewards strategic action over impulsive action. Lead, but make sure you're leading somewhere worth going."
        case .taurus:
            return "This year asks you to balance stability with necessary change. Your instinct is to hold onto what's proven and reliable, but growth sometimes requires letting go of security. The challenge is knowing when to stay the course and when to evolve. Build something lasting, but make sure it's actually aligned with who you're becoming, not just who you've been."
        case .gemini:
            return "This year asks you to focus your naturally scattered attention on things that actually matter. Your gift is seeing multiple perspectives and possibilities, but this year rewards depth over breadth. Pick something worth committing to and go all the way with it rather than sampling everything superficially. Real mastery requires sustained focus."
        case .cancer:
            return "This year asks you to balance caring for others with caring for yourself. Your instinct is to nurture and support, but you can't pour from an empty cup. The challenge is maintaining healthy boundaries while staying emotionally open. Protect your energy without becoming closed off. Your sensitivity is a strength when it's sustainable, a liability when it depletes you."
        case .leo:
            return "This year asks you to express yourself authentically while remaining grounded in reality. Your natural confidence and creativity are assets, but they work best when paired with self-awareness and humility. The challenge is shining brightly without needing constant validation. Create for the joy of creation, lead for the value you bring, not just for the attention it gets you."
        case .virgo:
            return "This year asks you to balance your analytical nature with acceptance of imperfection. Your gift for seeing what could be better is valuable, but perfectionism can paralyze progress. The challenge is improving things without being paralyzed by everything that's not yet perfect. Sometimes done is better than perfect. Focus your critical eye on what actually matters."
        case .libra:
            return "This year asks you to make decisions without endless deliberation. Your ability to see all sides is valuable, but at some point you need to commit to a direction. The challenge is choosing what's right for you rather than what keeps everyone happy. Not all conflicts are worth avoiding. Sometimes peace comes through difficult conversations, not by sidestepping them."
        case .scorpio:
            return "This year asks you to transform while maintaining stability. Your intensity and depth are powerful, but they can also be exhausting if there's no off switch. The challenge is allowing change without destroying everything. You can let go of what no longer serves you without burning your whole life to the ground. Evolution doesn't always require devastation."
        case .sagittarius:
            return "This year asks you to ground your vision in practical reality. Your optimism and big-picture thinking are gifts, but they need real-world execution to manifest. The challenge is following through on what you start rather than getting distracted by the next exciting possibility. Commitment isn't prison—it's how dreams become real. Finish something before starting something new."
        case .capricorn:
            return "This year asks you to balance ambition with presence. Your drive for achievement is admirable, but don't sacrifice the present for a future that keeps receding. The challenge is working toward goals while actually enjoying the process. Success you can't savor isn't success. Make sure the mountain you're climbing is actually the one you want to stand on top of."
        case .aquarius:
            return "This year asks you to balance innovation with connection. Your unique perspective is valuable, but don't let being different become more important than being real. The challenge is staying true to yourself while remaining emotionally available to others. Individuality doesn't require isolation. You can be yourself and belong at the same time."
        case .pisces:
            return "This year asks you to balance compassion with boundaries. Your empathy and intuition are gifts, but they can drain you if you absorb everyone's feelings as your own. The challenge is staying open-hearted without losing yourself in others' needs. You can care deeply without carrying everything. Your sensitivity serves you best when you protect it."
        }
    }
    
    func getYearlyFocus(chart: BirthChart, transits: [CelestialBody]) -> String {
        // Check Jupiter position for growth areas
        if let jupiter = transits.first(where: { $0.name == "Jupiter" }) {
            let jupiterSign = jupiter.position.sign
            return "Growth opportunities this year center around \(jupiterSign.rawValue) themes. This doesn't mean everything comes easily—it means this is where expansion is possible if you put in the work. Focus your efforts here."
        }
        
        return "This year rewards consistent effort in areas you've already been developing. Don't chase shiny new opportunities that distract from your real path. Double down on what's already working rather than starting from scratch in something new."
    }
    
    func getYearlyAdvice(chart: BirthChart) -> String {
        let sunSign = chart.sunSign
        
        // Element-based yearly advice
        switch sunSign.element {
        case .fire:
            return "Your natural enthusiasm serves you well this year, but pair it with patience. Not everything needs to be immediate. Sustainable success comes from steady fuel, not just bright flames. Start strong, but more importantly, finish."
        case .earth:
            return "Your practical approach is exactly what's needed this year. Trust your instinct to build slowly and thoroughly. In a world obsessed with speed, your patience and persistence create lasting value. Don't let anyone rush you out of doing things properly."
        case .air:
            return "Your mental agility is an asset this year, but at some point all that thinking needs to become doing. Make decisions and commit to them even when you see other possibilities. Perfect information never arrives—act on good enough information and adjust as you go."
        case .water:
            return "Your emotional intelligence is crucial this year. Trust what you feel even when you can't explain it logically. Your intuition is picking up on information others miss. Just remember that feeling everything doesn't mean you need to process everything—some things you can just notice and let pass."
        }
    }
}

// MARK: - Supporting Types for Weekly Insights

private struct WeeklyTransitAspect {
    let transitPlanet: String
    let natalPlanet: String
    let type: AspectType
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
