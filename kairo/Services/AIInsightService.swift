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
                You're an astrology translator. Take the astrological insight and make it even more direct and human. 2 sentences max. Be honest, specific, and grounded. No planets or astrology jargon in output - translate to real life experiences. No fluff.
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
        let weeklyTheme = getEnergyPattern(transits, chart)
        let personalityTraits = getPersonalityTraits(chart)
        
        if weeklyTheme.contains("challenging") || weeklyTheme.contains("obstacles") {
            return "This week presents important learning opportunities that will build lasting strength. Your \(personalityTraits) nature will help you turn challenges into wisdom."
        } else if weeklyTheme.contains("expansive") || weeklyTheme.contains("abundant") {
            return "This week offers excellent opportunities for growth and new beginnings. Your \(personalityTraits) approach will attract positive developments."
        } else {
            return "This week's \(weeklyTheme) encourages steady progress toward your goals. Trust your \(personalityTraits) judgment to make the right decisions."
        }
    }
    
    func createFallbackMonthlyInsight(chart: BirthChart, transits: [CelestialBody]) -> String {
        let monthlyTheme = getMonthlyTheme(transits, chart)
        let personalityTraits = getPersonalityTraits(chart)
        
        return "This month focuses on \(monthlyTheme). Your \(personalityTraits) nature will be essential in navigating this period with grace and achieving meaningful progress."
    }
    
    func createFallbackYearlyInsight(chart: BirthChart, transits: [CelestialBody]) -> String {
        let yearlyTheme = getYearlyTheme(transits, chart)
        let personalityTraits = getPersonalityTraits(chart)
        
        return "This year is about \(yearlyTheme). Your \(personalityTraits) essence will guide you through this significant period of development and authentic self-expression."
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
        let personalityTraits = getPersonalityTraits(chart)
        let transits = AstrologyService.shared.calculateCurrentTransits()
        let todaysEnergy = getEnergyPattern(transits, chart)
        
        // Create an accurate fallback that uses real astrological data
        if todaysEnergy.contains("challenging") || todaysEnergy.contains("obstacles") {
            return "Given your \(personalityTraits) nature and today's challenging energy, approach this situation with patience and trust your inner strength to guide you through."
        } else if todaysEnergy.contains("expansive") || todaysEnergy.contains("abundant") {
            return "With your \(personalityTraits) qualities and today's positive energy, this is a great time to trust your instincts and move forward confidently."
        } else {
            return "Your \(personalityTraits) nature combined with today's \(todaysEnergy) suggests taking a thoughtful approach to this situation."
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
