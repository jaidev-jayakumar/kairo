import Foundation
import SwissEphemeris

// MARK: - Intent Classification Types

enum IntentType: String, Codable {
    case birthChartSummary          // "what's my sun/moon/rising"
    case dailyInsight               // "how's today look"
    case currentTransits            // "what's happening in the sky now"
    case planetToPointTransit       // "when does Jupiter hit my Sun/Moon/Asc?"
    case planetTransitThroughHouse  // "when is Saturn in my 7th"
    case yearAheadForecast          // "2026 overview"
    case compatibility              // "synastry with …"
    case generalChat                // fallback
}

struct IntentRequest: Codable {
    let intent: IntentType
    // optional args depending on intent
    let planet: String?            // "jupiter", "saturn", etc.
    let targetPoint: String?       // "sun", "moon", "ascendant", "mc", "venus"… 
    let houseNumber: Int?          // 1…12
    let timeframeYears: Int?       // 1..10
    let orbDegrees: Double?        // e.g., 1.0
    let personName: String?        // for compatibility
    let notes: String?             // freeform hints ("exact dates", "windows")
}

struct TransitEvent {
    let planet: String
    let aspect: String
    let natalPoint: String
    let date: Date
    let significance: Int
}

/// Service for handling conversational AI using OpenAI GPT-4 with function calling
class OpenAIService: ObservableObject {
    static let shared = OpenAIService()
    
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private var urlSession: URLSession
    
    private init() {
        // Load API key from APIKeys.plist
        if let path = Bundle.main.path(forResource: "APIKeys", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let key = plist["OPENAI_API_KEY"] as? String {
            self.apiKey = key
        } else {
            self.apiKey = ""
            print("⚠️ Warning: Please add OPENAI_API_KEY to APIKeys.plist to enable OpenAI features.")
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.urlSession = URLSession(configuration: config)
    }
    
    // MARK: - Intent Classification
    
    private func classifyIntent(_ userMessage: String) async throws -> IntentRequest {
        let system = """
        You are an intent classifier for an astrology assistant. 
        Output ONLY valid JSON matching this Swift Codable schema:

        {
          "intent": "<one of: birthChartSummary|dailyInsight|currentTransits|planetToPointTransit|planetTransitThroughHouse|yearAheadForecast|compatibility|generalChat>",
          "planet": "<optional lowercased planet name>",
          "targetPoint": "<optional: sun|moon|ascendant|mc|venus|mars|mercury|jupiter|saturn|uranus|neptune|pluto>",
          "houseNumber": <optional int 1-12>,
          "timeframeYears": <optional int>,
          "orbDegrees": <optional double>,
          "personName": "<optional>",
          "notes": "<optional>"
        }

        Rules:
        - If user mentions a specific planet + specific point(s) (sun/moon/ascendant), use planetToPointTransit.
        - For multiple targets like "sun or moon or rising", put all targets in targetPoint field separated by " or "
        - If user says "current transits", use currentTransits.
        - If user asks for 'today/tomorrow', use dailyInsight.
        - If user asks "when is <planet> in my <Nth> house", use planetTransitThroughHouse.
        - If user asks "overall for 2026", use yearAheadForecast with timeframeYears=1 (or as implied).
        - If user asks about birth chart or chart info, use birthChartSummary.
        - If user asks about scores or horoscope, use dailyInsight.
        - If it's vague, use generalChat.
        - For planet names: jupiter, saturn, mars, venus, mercury, sun, moon, uranus, neptune, pluto
        - For target points: sun, moon, ascendant (or rising), mc (midheaven), venus, mars, mercury, jupiter, saturn, uranus, neptune, pluto
        - Examples: "Jupiter to my sun or moon" → targetPoint: "sun or moon", "Saturn hitting my ascendant" → targetPoint: "ascendant"
        """

        let user = userMessage

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "temperature": 0,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: body)
        var req = URLRequest(url: URL(string: baseURL)!)
        req.httpMethod = "POST"
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data

        let (raw, resp) = try await urlSession.data(for: req)
        guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 else {
            throw OpenAIError.invalidResponse
        }

        // Extract assistant content string from the OpenAI response (choices[0].message.content)
        let json = try JSONSerialization.jsonObject(with: raw) as? [String: Any]
        guard
            let choices = json?["choices"] as? [[String: Any]],
            let content = (choices.first?["message"] as? [String: Any])?["content"] as? String
        else { 
            throw OpenAIError.invalidResponse 
        }

        // content is the JSON string; decode to IntentRequest
        let intentData = Data(content.utf8)
        return try JSONDecoder().decode(IntentRequest.self, from: intentData)
    }
    
    // MARK: - Main Conversation Method
    
    func generateResponse(to userMessage: String) async throws -> String {
        guard !apiKey.isEmpty else { 
            throw OpenAIError.missingAPIKey 
        }
        guard let chart = getCurrentBirthChart() else {
            return "I need your birth details first to personalize this. Please add your birth chart."
        }

        // 1) classify intent with fallback
        let intent: IntentRequest
        do {
            intent = try await classifyIntent(userMessage)
        } catch {
            // If classification fails, fall back to general chat
            return await generateGeneralResponse(for: chart, question: userMessage)
        }

        // 2) dispatch based on intent
        switch intent.intent {
        case .birthChartSummary:
            return generateBirthChartResponse(for: chart)

        case .dailyInsight:
            return await generateDailyInsightResponse(for: chart)

        case .currentTransits:
            return generateTransitsResponse()

        case .planetToPointTransit:
            let planet = intent.planet ?? "jupiter"
            let target = (intent.targetPoint ?? "sun").lowercased()
            let orb = intent.orbDegrees ?? 1.0
            let years = intent.timeframeYears ?? 3
            return await generatePlanetToPointTransit(
                planet: planet, target: target, chart: chart, orb: orb, yearsAhead: years
            )

        case .planetTransitThroughHouse:
            guard let planet = intent.planet, let house = intent.houseNumber else {
                return "Tell me which planet and house (1–12), e.g., \"When is Saturn in my 7th?\""
            }
            return await generatePlanetThroughHouse(planet: planet, house: house, chart: chart)

        case .yearAheadForecast:
            let years = intent.timeframeYears ?? 1
            return await generatePredictiveYearAhead(chart: chart, years: years)

        case .compatibility:
            return "For synastry I'll need the other person's birth details."

        case .generalChat:
            return await generatePredictiveGeneralResponse(for: chart, question: userMessage)
        }
    }
    
    private func getCurrentBirthChart() -> BirthChart? {
        guard let birthData = UserDataManager.shared.getBirthData() else {
            return nil
        }
        return AstrologyService.shared.calculateBirthChart(for: birthData)
    }
    
    private func generateBirthChartResponse(for chart: BirthChart) -> String {
        return """
        Your cosmic blueprint reveals: Sun in \(chart.sunSign.rawValue), Moon in \(chart.moonSign.rawValue), with \(chart.ascendantSign.rawValue) rising. 
        Your \(chart.sunSign.rawValue) essence illuminates your core identity, while your \(chart.moonSign.rawValue) Moon governs your emotional depths. 
        This powerful combination creates your unique cosmic signature.
        """
    }
    
    private func generateHoroscopeScoresResponse(for chart: BirthChart) -> String {
        let scores = AstrologyService.shared.calculateDailyHoroscopeScores(for: chart)
        return """
        Today's cosmic energies reveal: Overall harmony at \(scores.overall)%, Love flowing at \(scores.love)%, 
        Career momentum at \(scores.career)%, and Wealth potential at \(scores.wealth)%. 
        The stars suggest focusing on areas where your energy is strongest today.
        """
    }
    
    private func generateTransitsResponse() -> String {
        let transits = AstrologyService.shared.calculateCurrentTransits()
        let transitSummary = transits.prefix(3).map { "\($0.name) in \($0.signName)" }.joined(separator: ", ")
        return "The current planetary dance shows \(transitSummary). These cosmic movements are influencing the collective energy and your personal journey."
    }
    
    private func generateDailyInsightResponse(for chart: BirthChart) async -> String {
        return await AstrologyService.shared.generateDailyInsight(for: chart)
    }
    
    private func generateGeneralResponse(for chart: BirthChart, question: String) async -> String {
        // Use existing AI insight service for complex questions
        return await AIInsightService.shared.generateChatResponse(question: question, chart: chart)
    }
    
    private func generatePredictiveGeneralResponse(for chart: BirthChart, question: String) async -> String {
        // Get current transits and ONLY near-term major transits (next 2 months)
        // We don't want to talk about events 6+ months away in casual conversation
        let majorTransits = await calculateUpcomingTransits(for: chart, months: 2)
        let currentTransits = AstrologyService.shared.calculateCurrentTransits()
        
        // Create a natural, human astrological response
        return await generateHumanAstrologerResponse(chart: chart, transits: majorTransits, currentTransits: currentTransits, question: question)
    }
    
    private func calculateUpcomingTransits(for chart: BirthChart, months: Int) async -> [TransitEvent] {
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .month, value: months, to: startDate)!
        
        var majorEvents: [TransitEvent] = []
        
        // Check for major outer planet transits (these create life events)
        let outerPlanets = ["jupiter", "saturn", "mars"] // Removed slower planets - they're too slow for 2-month window
        let personalPoints = [
            ("sun", chart.sun.longitude),
            ("moon", chart.moon.longitude), 
            ("ascendant", chart.ascendant),
            ("venus", chart.venus.longitude),
            ("mars", chart.mars.longitude)
        ]
        
        for planet in outerPlanets {
            for (pointName, natalPosition) in personalPoints {
                let transits = await findMajorTransits(
                    planet: planet,
                    toNatalPoint: natalPosition,
                    pointName: pointName,
                    startDate: startDate,
                    endDate: endDate
                )
                majorEvents.append(contentsOf: transits)
            }
        }
        
        // Sort by date and return most significant ones
        return Array(majorEvents.sorted { $0.significance > $1.significance }.prefix(5))
    }
    
    private func calculateMajorUpcomingTransits(for chart: BirthChart, years: Int) async -> [TransitEvent] {
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .year, value: years, to: startDate)!
        
        var majorEvents: [TransitEvent] = []
        
        // Check for major outer planet transits (these create life events)
        let outerPlanets = ["jupiter", "saturn", "uranus", "neptune", "pluto"]
        let personalPoints = [
            ("sun", chart.sun.longitude),
            ("moon", chart.moon.longitude), 
            ("ascendant", chart.ascendant),
            ("midheaven", chart.midheaven),
            ("venus", chart.venus.longitude),
            ("mars", chart.mars.longitude)
        ]
        
        for planet in outerPlanets {
            for (pointName, natalPosition) in personalPoints {
                let transits = await findMajorTransits(
                    planet: planet,
                    toNatalPoint: natalPosition,
                    pointName: pointName,
                    startDate: startDate,
                    endDate: endDate
                )
                majorEvents.append(contentsOf: transits)
            }
        }
        
        // Sort by date and return most significant ones
        return Array(majorEvents.sorted { $0.date < $1.date }.prefix(8))
    }
    
    private func findMajorTransits(
        planet: String,
        toNatalPoint natalPosition: Double,
        pointName: String,
        startDate: Date,
        endDate: Date
    ) async -> [TransitEvent] {
        var events: [TransitEvent] = []
        let checkInterval = getCheckInterval(for: planet)
        var currentDate = startDate
        
        while currentDate <= endDate {
            if let transitPosition = calculatePlanetPosition(planet, date: currentDate) {
                let angle = abs(transitPosition - natalPosition)
                let normalizedAngle = angle > 180 ? 360 - angle : angle
                
                // Only major aspects with tight orbs for life-changing events
                if let aspect = getMajorAspectType(normalizedAngle) {
                    // Avoid duplicates within 30 days for slower planets
                    let duplicateWindow: TimeInterval = planet == "jupiter" || planet == "saturn" ? 30 * 24 * 60 * 60 : 7 * 24 * 60 * 60
                    
                    let isDuplicate = events.contains { existingEvent in
                        abs(existingEvent.date.timeIntervalSince(currentDate)) < duplicateWindow &&
                        existingEvent.planet == planet &&
                        existingEvent.natalPoint == pointName
                    }
                    
                    if !isDuplicate {
                        events.append(TransitEvent(
                            planet: planet,
                            aspect: aspect,
                            natalPoint: pointName,
                            date: currentDate,
                            significance: getEventSignificance(planet: planet, aspect: aspect, point: pointName)
                        ))
                    }
                }
            }
            
            currentDate = currentDate.addingTimeInterval(checkInterval)
        }
        
        return events
    }
    
    private func getMajorAspectType(_ angle: Double) -> String? {
        // Tighter orbs for major life events
        if angle <= 2.0 { return "Conjunction" }
        if (58...62).contains(angle) { return "Sextile" }  
        if (88...92).contains(angle) { return "Square" }
        if (118...122).contains(angle) { return "Trine" }
        if (178...182).contains(angle) { return "Opposition" }
        return nil
    }
    
    private func getEventSignificance(planet: String, aspect: String, point: String) -> Int {
        var significance = 1
        
        // Outer planets create bigger life changes
        switch planet.lowercased() {
        case "pluto": significance += 5
        case "neptune", "uranus": significance += 4
        case "saturn": significance += 3
        case "jupiter": significance += 2
        default: significance += 1
        }
        
        // Personal points are more significant
        switch point.lowercased() {
        case "sun", "moon", "ascendant": significance += 2
        case "midheaven": significance += 1
        default: significance += 1
        }
        
        // Conjunctions and oppositions are most significant
        switch aspect.lowercased() {
        case "conjunction", "opposition": significance += 2
        case "square": significance += 1
        default: significance += 0
        }
        
        return significance
    }
    
    private func generateHumanAstrologerResponse(chart: BirthChart, transits: [TransitEvent], currentTransits: [CelestialBody], question: String) async -> String {
        // Build astrological context for the AI
        var astrologyContext = ""
        
        // Current planetary weather
        let todaysEnergy = getDetailedCurrentEnergy(currentTransits, chart)
        astrologyContext += "Current cosmic weather: \(todaysEnergy)\n"
        
        // Only show VERY near-term transits (next 6 weeks max)
        let now = Date()
        let sixWeeksFromNow = Calendar.current.date(byAdding: .weekOfYear, value: 6, to: now)!
        
        let nearTermTransits = transits.filter { 
            $0.date >= now && $0.date <= sixWeeksFromNow
        }.prefix(2) // Only top 2 most significant
        
        if !nearTermTransits.isEmpty {
            astrologyContext += "\nVery near future (next 6 weeks):\n"
            for transit in nearTermTransits {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMMM d"
                let date = dateFormatter.string(from: transit.date)
                
                // Calculate days from now
                let daysAway = Calendar.current.dateComponents([.day], from: now, to: transit.date).day ?? 0
                let timing = daysAway < 7 ? "this week" : daysAway < 14 ? "next week" : "in \(daysAway / 7) weeks"
                
                let meaning = getTransitMeaning(transit)
                astrologyContext += "- \(timing) (\(date)): \(meaning)\n"
            }
        }
        
        // Now call OpenAI with natural astrologer prompt
        return await callOpenAIForHumanResponse(
            question: question,
            chart: chart,
            astrologyContext: astrologyContext
        )
    }
    
    private func getDetailedCurrentEnergy(_ transits: [CelestialBody], _ chart: BirthChart) -> String {
        var energies: [String] = []
        
        // Check for current major aspects
        let natalPoints = [
            ("Sun", chart.sun.longitude),
            ("Moon", chart.moon.longitude),
            ("Venus", chart.venus.longitude),
            ("Mars", chart.mars.longitude)
        ]
        
        for transit in transits {
            for (pointName, natalLong) in natalPoints {
                let angle = abs(transit.longitude - natalLong)
                let normalized = angle > 180 ? 360 - angle : angle
                
                if normalized < 8 {
                    energies.append("\(transit.name) is activating your \(pointName) - this affects \(getPointLifeArea(pointName))")
                } else if abs(normalized - 90) < 8 {
                    energies.append("\(transit.name) is challenging your \(pointName) - testing your \(getPointLifeArea(pointName))")
                } else if abs(normalized - 120) < 8 {
                    energies.append("\(transit.name) is supporting your \(pointName) - helping with \(getPointLifeArea(pointName))")
                }
            }
        }
        
        return energies.isEmpty ? "Relatively calm planetary weather today" : energies.prefix(2).joined(separator: "; ")
    }
    
    private func getPointLifeArea(_ point: String) -> String {
        switch point {
        case "Sun": return "identity, confidence, and life direction"
        case "Moon": return "emotions, instincts, and needs"
        case "Venus": return "relationships, values, and what you love"
        case "Mars": return "drive, action, and how you go after what you want"
        default: return "personal development"
        }
    }
    
    private func getTransitMeaning(_ transit: TransitEvent) -> String {
        let planet = transit.planet.capitalized
        let point = transit.natalPoint
        let aspect = transit.aspect
        
        switch (planet.lowercased(), aspect.lowercased(), point.lowercased()) {
        case ("jupiter", _, "sun"):
            return "Jupiter brings expansion and opportunities to your core identity - doors opening"
        case ("jupiter", _, "venus"):
            return "Jupiter blessing your love life and finances - expect good things"
        case ("saturn", "conjunction", _), ("saturn", "square", _):
            return "Saturn bringing reality checks and important life lessons"
        case ("saturn", "trine", _):
            return "Saturn helping you build something solid and lasting"
        case ("uranus", _, _):
            return "Uranus bringing unexpected changes and breakthroughs"
        case ("pluto", _, _):
            return "Pluto bringing deep transformation in how you approach life"
        default:
            return "\(planet) influencing your \(point) - creating change"
        }
    }
    
    private func callOpenAIForHumanResponse(question: String, chart: BirthChart, astrologyContext: String) async -> String {
        do {
            guard let url = URL(string: baseURL) else { 
                return "I'm having trouble connecting right now. Can you ask me again?"
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            
            // Get current date for context
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE, MMMM d, yyyy"
            let todayFormatted = dateFormatter.string(from: Date())
            
            let systemPrompt = """
            You are Kaira, a highly skilled and intuitive astrologer who speaks like a real person, not a bot. You blend deep astrological knowledge with genuine human warmth and directness.
            
            TODAY'S DATE: \(todayFormatted)
            IMPORTANT: When you see months mentioned in the astrology data, be aware of how far away they are from today. Don't talk about distant future events as if they're happening now.

            YOUR VOICE:
            - Talk like you're texting a friend who needs real advice
            - Be direct, honest, and specific - no generic platitudes
            - Use "you" and "your" freely - make it personal
            - Keep responses SHORT (2-3 sentences max)
            - Sound natural, not corporate or overly spiritual
            - Give clear YES/NO guidance when appropriate, not just "it depends"
            
            ASTROLOGY APPROACH:
            - Focus on what's happening NOW and in the very near future (next few weeks)
            - If an event is more than 2 months away, don't mention it unless specifically asked
            - Translate astrology into practical advice, not vague cosmic talk
            - Don't mention planet names unless it adds value - focus on MEANING
            - When you see a clear answer in the chart, say it confidently
            
            FORBIDDEN:
            - Never mention months that are far in the future as if they're relevant today
            - Never say generic shit like "a significant life shift is happening"
            - Never use words like "cosmic journey" or "universe has plans"
            - Never be vague when you can be specific
            - Never give wishy-washy "only you can decide" answers if the astrology is clear
            
            RESPONSE STYLE:
            - If the chart says YES → tell them yes and why
            - If the chart says NO → tell them no and why  
            - If it's complicated → explain the real conflict they're facing
            - Always ground advice in what's ACTUALLY happening in their chart RIGHT NOW, not months from now
            
            Person's chart: \(chart.sunSign.rawValue) Sun, \(chart.moonSign.rawValue) Moon, \(chart.ascendantSign.rawValue) Rising
            
            Current astrology: \(astrologyContext)
            """
            
            let userPrompt = "Question: \(question)\n\nGive me a straight answer based on what you see in the astrology. Be real with me."
            
            let requestBody: [String: Any] = [
                "model": "gpt-4o",
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": userPrompt]
                ],
                "max_tokens": 150,
                "temperature": 0.8,
                "presence_penalty": 0.3,
                "frequency_penalty": 0.3
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw OpenAIError.invalidResponse
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let choices = json?["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw OpenAIError.invalidResponse
            }
            
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
            
        } catch {
            print("OpenAI API error: \(error)")
            // Fallback to simple response based on current energy
            return generateSimpleFallbackResponse(question: question, chart: chart)
        }
    }
    
    private func generateSimpleFallbackResponse(question: String, chart: BirthChart) -> String {
        let lowerQuestion = question.lowercased()
        
        // Relationship questions
        if lowerQuestion.contains("girlfriend") || lowerQuestion.contains("boyfriend") || 
           lowerQuestion.contains("relationship") || lowerQuestion.contains("reach out") ||
           lowerQuestion.contains("text") || lowerQuestion.contains("call") {
            return "If you're asking, part of you already knows the answer. What's your gut telling you? That's usually the right move."
        }
        
        // Career/job questions
        if lowerQuestion.contains("job") || lowerQuestion.contains("career") || 
           lowerQuestion.contains("work") || lowerQuestion.contains("quit") {
            return "The planets are pushing you toward what feels more authentic, even if it's scary. What would you do if fear wasn't a factor?"
        }
        
        // Decision questions
        if lowerQuestion.contains("should i") || lowerQuestion.contains("should i") {
            return "You already know what you want to do. The question is whether you're ready to trust yourself enough to do it."
        }
        
        // Default
        return "The astrology says you're at a decision point. Trust your instincts more than your fears right now."
    }
    
    private func generateLifeThemePrediction(_ transit: TransitEvent, chart: BirthChart) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        let month = dateFormatter.string(from: transit.date)
        
        switch (transit.planet.lowercased(), transit.natalPoint.lowercased()) {
        case ("saturn", "sun"):
            return "Around \(month), life's asking you to step up in a major way. This is your maturation moment - expect real responsibility and the recognition that comes with it."
            
        case ("jupiter", "sun"):
            return "\(month) kicks off a major expansion phase. Doors that were closed start opening, and people take you more seriously. This is when you level up."
            
        case ("uranus", "sun"):
            return "Get ready - \(month) brings a complete identity shake-up. Who you've been is evolving fast. The change is liberating once you stop fighting it."
            
        case ("saturn", "moon"):
            return "Around \(month), you're being pushed to mature emotionally. Old patterns that kept you stuck get challenged. It's uncomfortable but leads to real stability."
            
        case ("jupiter", "ascendant"):
            return "\(month) brings a glow-up in how people see you. Your energy shifts, and suddenly new opportunities come just because you're showing up differently."
            
        case ("pluto", "sun"):
            return "Deep transformation around \(month). The old version of you is dying so the real you can emerge. It's intense but it's evolution, not destruction."
            
        default:
            return "Around \(month), something shifts in your \(getLifeArea(transit.natalPoint)) that changes how you move through life. Pay attention - this matters."
        }
    }
    
    private func generateTimeframePrediction(_ transits: [TransitEvent], chart: BirthChart) -> String {
        let sortedTransits = transits.sorted { $0.significance > $1.significance }
        let primary = sortedTransits.first!
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        let month = dateFormatter.string(from: primary.date)
        
        switch (primary.planet.lowercased(), primary.aspect.lowercased(), primary.natalPoint.lowercased()) {
        case ("jupiter", "conjunction", "venus"):
            return "Love and money get a major boost in \(month). You could meet someone significant or receive a financial windfall. Your charm will be irresistible."
            
        case ("saturn", "square", "mars"):
            return "In \(month), you'll face obstacles that force you to develop better strategies. What feels like resistance now is actually building your strength and teaching you patience."
            
        case ("uranus", "trine", "moon"):
            return "\(month) brings an emotional breakthrough that liberates you from old family patterns. You'll feel freer to express your authentic feelings."
            
        case ("jupiter", "opposition", "sun"):
            return "Relationships take center stage in \(month). A significant partnership opportunity arises, but you'll need to balance your needs with theirs."
            
        case ("saturn", "conjunction", "ascendant"):
            return "In \(month), you'll be seen as a serious authority figure. Others will look to you for leadership. This is when your reputation solidifies."
            
        default:
            let eventType = getEventType(primary.planet, primary.aspect, primary.natalPoint)
            return "\(month) marks a significant \(eventType) in your \(getLifeArea(primary.natalPoint)). This has lasting impact on your life direction."
        }
    }
    
    private func getLifeArea(_ point: String) -> String {
        switch point.lowercased() {
        case "sun": return "core identity and life purpose"
        case "moon": return "emotional world and home life"
        case "ascendant": return "public image and first impressions"
        case "midheaven": return "career and reputation"
        case "venus": return "love life and financial situation"
        case "mars": return "energy levels and assertion style"
        default: return "personal development"
        }
    }
    
    private func getEventType(_ planet: String, _ aspect: String, _ point: String) -> String {
        switch planet.lowercased() {
        case "jupiter": return "expansion and opportunity"
        case "saturn": return "restructuring and maturation"
        case "uranus": return "breakthrough and liberation"
        case "neptune": return "spiritual awakening"
        case "pluto": return "complete transformation"
        default: return "significant change"
        }
    }
    
    // MARK: - New Intent-Based Response Methods
    
    private func generatePlanetToPointTransit(
        planet: String, 
        target: String, 
        chart: BirthChart, 
        orb: Double, 
        yearsAhead: Int
    ) async -> String {
        // Handle multiple target points from voice queries like "sun or moon or rising"
        let possibleTargets = extractMultipleTargets(from: target)
        var transitResults: [String] = []
        
        for targetPoint in possibleTargets {
            if let natalPosition = getNatalPosition(targetPoint, chart: chart) {
                let results = await calculateTransitsToPoint(
                    planet: planet,
                    targetPoint: targetPoint,
                    natalLongitude: natalPosition,
                    chart: chart,
                    orb: orb,
                    yearsAhead: yearsAhead
                )
                transitResults.append(results)
            }
        }
        
        if transitResults.isEmpty {
            return "I couldn't find the target point(s) you mentioned. Please specify sun, moon, ascendant/rising, or other natal points."
        }
        
        let capitalizedPlanet = planet.capitalized
        // Convert results to plain English insights
        let insights = transitResults.map { result in
            convertToPlainEnglishInsight(result)
        }
        
        if insights.count == 1 {
            return insights[0]
        } else {
            return "Here's what I see for \(capitalizedPlanet):\n\n" + insights.joined(separator: "\n\n")
        }
    }
    
    private func extractMultipleTargets(from input: String) -> [String] {
        let lowercased = input.lowercased()
        
        // First check if the AI classifier returned multiple targets separated by " or "
        if lowercased.contains(" or ") {
            return lowercased.components(separatedBy: " or ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        
        // Otherwise, check for multiple targets in voice queries like "sun or moon or rising"
        var targets: [String] = []
        
        if lowercased.contains("sun") { targets.append("sun") }
        if lowercased.contains("moon") { targets.append("moon") }
        if lowercased.contains("rising") || lowercased.contains("ascendant") { 
            targets.append("ascendant") 
        }
        if lowercased.contains("midheaven") || lowercased.contains("mc") { 
            targets.append("midheaven") 
        }
        if lowercased.contains("venus") { targets.append("venus") }
        if lowercased.contains("mars") { targets.append("mars") }
        if lowercased.contains("mercury") { targets.append("mercury") }
        if lowercased.contains("jupiter") { targets.append("jupiter") }
        if lowercased.contains("saturn") { targets.append("saturn") }
        
        // If no specific targets found, default to the original target
        return targets.isEmpty ? [input] : targets
    }
    
    private func getNatalPosition(_ point: String, chart: BirthChart) -> Double? {
        switch point.lowercased() {
        case "sun":
            return chart.sun.longitude
        case "moon":
            return chart.moon.longitude
        case "ascendant", "rising":
            return chart.ascendant
        case "midheaven", "mc":
            return chart.midheaven
        case "venus":
            return chart.venus.longitude
        case "mars":
            return chart.mars.longitude
        case "mercury":
            return chart.mercury.longitude
        case "jupiter":
            return chart.jupiter.longitude
        case "saturn":
            return chart.saturn.longitude
        case "uranus":
            return chart.uranus.longitude
        case "neptune":
            return chart.neptune.longitude
        case "pluto":
            return chart.pluto.longitude
        default:
            return nil
        }
    }
    
    private func calculateTransitsToPoint(
        planet: String,
        targetPoint: String,
        natalLongitude: Double,
        chart: BirthChart,
        orb: Double,
        yearsAhead: Int
    ) async -> String {
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .year, value: yearsAhead, to: startDate)!
        
        var transitEvents: [(date: Date, longitude: Double, aspect: String)] = []
        
        // Check transits approximately every 7 days for faster planets, 30 days for slower ones
        let checkInterval: TimeInterval = getCheckInterval(for: planet)
        var currentDate = startDate
        
        while currentDate <= endDate {
            if let transitPosition = calculatePlanetPosition(planet, date: currentDate) {
                let angle = abs(transitPosition - natalLongitude)
                let normalizedAngle = angle > 180 ? 360 - angle : angle
                
                // Check for major aspects within orb
                if let aspect = getAspectType(normalizedAngle, orb: orb) {
                    // Avoid duplicate close dates (within 5 days)
                    let isDuplicate = transitEvents.contains { existingTransit in
                        abs(existingTransit.date.timeIntervalSince(currentDate)) < (5 * 24 * 60 * 60)
                    }
                    
                    if !isDuplicate {
                        transitEvents.append((
                            date: currentDate,
                            longitude: transitPosition,
                            aspect: aspect
                        ))
                    }
                }
            }
            
            currentDate = currentDate.addingTimeInterval(checkInterval)
        }
        
        if transitEvents.isEmpty {
            return "NO_TRANSITS|\(planet)|\(targetPoint)|\(yearsAhead)"
        }
        
        // Sort by date and format results
        transitEvents.sort { $0.date < $1.date }
        
        let transitList = transitEvents.prefix(3).map { event in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d, yyyy"
            return "\(event.aspect)|\(dateFormatter.string(from: event.date))"
        }.joined(separator: ",")
        
        return "TRANSITS|\(planet)|\(targetPoint)|\(transitList)"
    }
    
    private func convertToPlainEnglishInsight(_ result: String) -> String {
        let components = result.components(separatedBy: "|")
        
        if components.first == "NO_TRANSITS" {
            let planet = components[1].capitalized
            let targetPoint = components[2].capitalized
            let years = components[3]
            
            return "\(planet) won't make any major aspects to your \(targetPoint) over the next \(years) years. This means steady energy in this area of your life - no major shake-ups coming from this planetary influence."
        }
        
        if components.first == "TRANSITS" {
            let planet = components[1].capitalized
            let targetPoint = components[2].capitalized
            let transitData = components[3].components(separatedBy: ",")
            
            var insights: [String] = []
            
            for transit in transitData {
                let parts = transit.components(separatedBy: "|")
                if parts.count == 2 {
                    let aspect = parts[0]
                    let date = parts[1]
                    let insight = generateAspectInsight(planet: planet, aspect: aspect, target: targetPoint, date: date)
                    insights.append(insight)
                }
            }
            
            if insights.count == 1 {
                return insights[0]
            } else {
                return "Looking at \(planet) and your \(targetPoint):\n\n" + insights.joined(separator: "\n\n")
            }
        }
        
        return result // fallback
    }
    
    private func generateAspectInsight(planet: String, aspect: String, target: String, date: String) -> String {
        let monthYear = date.replacingOccurrences(of: ", ", with: " ")
        
        switch (planet.lowercased(), aspect.lowercased(), target.lowercased()) {
        // Jupiter transits
        case ("jupiter", "conjunction", "sun"):
            return "Around \(monthYear), Jupiter meets your Sun - this is a major expansion year for your identity and confidence. Great time for new ventures and personal growth."
            
        case ("jupiter", "conjunction", "moon"):
            return "In \(monthYear), Jupiter connects with your Moon, bringing emotional abundance and possibly family blessings. Your intuition will be especially strong."
            
        case ("jupiter", "conjunction", "ascendant"):
            return "Jupiter crosses your Ascendant around \(monthYear) - you'll feel more optimistic and others will see you as more expansive. Great for making a fresh impression."
            
        case ("jupiter", "trine", "sun"):
            return "Around \(monthYear), Jupiter flows beautifully with your Sun. Easy success and natural confidence - whatever you start now has Jupiter's blessing."
            
        case ("jupiter", "sextile", "moon"):
            return "In \(monthYear), Jupiter supports your emotional world with gentle growth opportunities. Good time for home improvements or family expansion."
            
        case ("jupiter", "square", "sun"):
            return "Jupiter challenges your Sun around \(monthYear) - you might feel restless or overconfident. Channel this energy into meaningful goals rather than scattered efforts."
            
        case ("jupiter", "opposition", "sun"):
            return "In \(monthYear), Jupiter opposes your Sun, bringing relationship opportunities and the need to balance personal desires with others' needs."
            
        // Saturn transits
        case ("saturn", "conjunction", "sun"):
            return "Saturn meets your Sun around \(monthYear) - this is a major maturing period. Time to get serious about your goals and build lasting foundations."
            
        case ("saturn", "conjunction", "moon"):
            return "In \(monthYear), Saturn connects with your Moon, asking you to get real about your emotional needs and security. Tough but ultimately stabilizing."
            
        case ("saturn", "trine", "sun"):
            return "Around \(monthYear), Saturn supports your Sun with steady progress. Your discipline pays off and authorities recognize your efforts."
            
        case ("saturn", "square", "sun"):
            return "Saturn challenges your Sun around \(monthYear) - obstacles test your resolve but ultimately make you stronger. Patience and persistence required."
            
        // Mars transits
        case ("mars", "conjunction", "sun"):
            return "Mars energizes your Sun around \(monthYear) - you'll feel driven and assertive. Great for starting new projects, but watch for impatience."
            
        case ("mars", "square", "moon"):
            return "In \(monthYear), Mars squares your Moon, stirring up emotions and possibly causing irritability. Channel this energy into physical activity."
            
        // Venus transits  
        case ("venus", "conjunction", "sun"):
            return "Venus kisses your Sun around \(monthYear) - enhanced charm and attractiveness. Great time for love, creativity, and social connections."
            
        case ("venus", "trine", "moon"):
            return "In \(monthYear), Venus harmonizes with your Moon, bringing emotional sweetness and possibly romantic developments."
            
        // Generic fallback
        default:
            return "Around \(monthYear), \(planet) makes a \(aspect) to your \(target) - this brings \(getGenericAspectMeaning(aspect)) energy to your \(getPointMeaning(target))."
        }
    }
    
    private func getGenericAspectMeaning(_ aspect: String) -> String {
        switch aspect.lowercased() {
        case "conjunction": return "intense, focused"
        case "trine": return "harmonious, flowing"
        case "sextile": return "supportive, opportunistic"  
        case "square": return "challenging, motivating"
        case "opposition": return "balancing, relationship-focused"
        default: return "significant"
        }
    }
    
    private func getPointMeaning(_ point: String) -> String {
        switch point.lowercased() {
        case "sun": return "identity and core self"
        case "moon": return "emotional world and instincts"
        case "ascendant": return "public image and first impressions"
        case "midheaven": return "career and reputation"
        case "venus": return "love life and values"
        case "mars": return "drive and action"
        case "mercury": return "communication and thinking"
        default: return "life area"
        }
    }
    
    private func calculatePlanetPosition(_ planetName: String, date: Date) -> Double? {
        // Use the existing AstrologyService to calculate planet position
        let planet = getSwissEphemerisPlanet(from: planetName)
        return AstrologyService.shared.calculatePlanetPositionAt(planet: planet, date: date)?.longitude
    }
    
    private func getSwissEphemerisPlanet(from name: String) -> SwissEphemeris.Planet {
        switch name.lowercased() {
        case "sun": return .sun
        case "moon": return .moon
        case "mercury": return .mercury
        case "venus": return .venus
        case "mars": return .mars
        case "jupiter": return .jupiter
        case "saturn": return .saturn
        case "uranus": return .uranus
        case "neptune": return .neptune
        case "pluto": return .pluto
        default: return .jupiter // fallback
        }
    }
    
    private func getCheckInterval(for planet: String) -> TimeInterval {
        // Different check intervals based on planet speed
        switch planet.lowercased() {
        case "moon": return 24 * 60 * 60 // 1 day
        case "sun", "mercury", "venus", "mars": return 7 * 24 * 60 * 60 // 7 days
        case "jupiter", "saturn": return 30 * 24 * 60 * 60 // 30 days
        case "uranus", "neptune", "pluto": return 90 * 24 * 60 * 60 // 90 days
        default: return 30 * 24 * 60 * 60
        }
    }
    
    private func getAspectType(_ angle: Double, orb: Double) -> String? {
        if angle <= orb { return "Conjunction" }
        if (60 - orb...60 + orb).contains(angle) { return "Sextile" }
        if (90 - orb...90 + orb).contains(angle) { return "Square" }
        if (120 - orb...120 + orb).contains(angle) { return "Trine" }
        if (180 - orb...180 + orb).contains(angle) { return "Opposition" }
        return nil
    }
    
    private func formatDegrees(_ longitude: Double) -> String {
        let degrees = Int(longitude.truncatingRemainder(dividingBy: 30))
        let minutes = Int((longitude.truncatingRemainder(dividingBy: 30) - Double(degrees)) * 60)
        return "\(degrees)°\(String(format: "%02d", minutes))'"
    }
    
    private func generatePlanetThroughHouse(planet: String, house: Int, chart: BirthChart) async -> String {
        let capitalizedPlanet = planet.capitalized
        
        return """
        Calculating when \(capitalizedPlanet) transits through your \(house.ordinalString) house...
        
        This transit will influence areas related to your \(house.ordinalString) house themes.
        
        [Note: This method needs integration with Swiss Ephemeris for accurate house transit calculations]
        """
    }
    
    private func generateYearAhead(chart: BirthChart, years: Int) async -> String {
        let timeframe = years == 1 ? "year ahead" : "\(years) years ahead"
        
        return """
        Your \(timeframe) cosmic forecast:
        
        With your \(chart.sunSign.rawValue) Sun, \(chart.moonSign.rawValue) Moon, and \(chart.ascendantSign.rawValue) rising, the coming period holds significant potential for growth and transformation.
        
        [Note: This method should integrate major transits to natal planets for a comprehensive forecast]
        """
    }
    
    private func generatePredictiveYearAhead(chart: BirthChart, years: Int) async -> String {
        // Get major transits for the specified time period
        let majorTransits = await calculateMajorUpcomingTransits(for: chart, years: years)
        
        if majorTransits.isEmpty {
            let timeframe = years == 1 ? "year ahead" : "\(years) years ahead"
            return "The \(timeframe) looks relatively stable with no major planetary disruptions. This is a time for steady progress and building on your existing foundations. Your \(chart.sunSign.rawValue) nature will help you make consistent advances without dramatic upheavals."
        }
        
        // Generate comprehensive year ahead prediction
        return await generateYearAheadFromTransits(chart: chart, transits: majorTransits, years: years)
    }
    
    private func generateYearAheadFromTransits(chart: BirthChart, transits: [TransitEvent], years: Int) async -> String {
        let timeframe = years == 1 ? "year ahead" : "\(years) years ahead"
        let mostSignificant = transits.sorted { $0.significance > $1.significance }
        
        var prediction = ""
        
        // Major theme for the period
        if let primaryTransit = mostSignificant.first {
            prediction += generateYearTheme(primaryTransit, chart: chart, years: years) + "\n\n"
        }
        
        // Key months/periods - STRICTLY one event per month
        let sortedTransits = mostSignificant.sorted { $0.date < $1.date }
        let monthlyEvents = getOneEventPerMonth(from: sortedTransits)
        let keyEvents = Array(monthlyEvents.prefix(3))
        
        if keyEvents.count >= 1 {
            prediction += "Key periods to watch:\n\n"
            
            var usedDescriptions: Set<String> = []
            var validEvents: [(String, String)] = []
            
            for event in keyEvents {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMMM yyyy"
                let timing = dateFormatter.string(from: event.date)
                
                let eventDescription = generateKeyEventDescription(event, chart: chart)
                
                // Skip if we've already used this exact description
                if !usedDescriptions.contains(eventDescription) {
                    usedDescriptions.insert(eventDescription)
                    validEvents.append((timing, eventDescription))
                }
            }
            
            // If we have no unique descriptions, force diversity
            if validEvents.isEmpty && !keyEvents.isEmpty {
                let event = keyEvents[0]
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMMM yyyy"
                let timing = dateFormatter.string(from: event.date)
                validEvents.append((timing, "A significant planetary shift occurs that transforms your approach to life. This marks a turning point in your personal evolution."))
            }
            
            for (index, (timing, description)) in validEvents.enumerated() {
                prediction += "\(timing): \(description)"
                
                if index < validEvents.count - 1 {
                    prediction += "\n\n"
                }
            }
        } else {
            // Fallback if filtering removed too much - give a general prediction with timing
            prediction += "This transformation will unfold gradually throughout the year, with the most intense periods likely occurring during major planetary stations and eclipses. Pay attention to opportunities that arise in the spring and fall seasons, when cosmic energy is most dynamic."
        }
        
        return prediction
    }
    
    private func getOneEventPerMonth(from transits: [TransitEvent]) -> [TransitEvent] {
        // First, remove duplicate planet-point combinations (keep only the first occurrence)
        var seenPlanetPoints: Set<String> = []
        var uniqueTransits: [TransitEvent] = []
        
        for transit in transits {
            let planetPointKey = "\(transit.planet.lowercased())_\(transit.natalPoint.lowercased())"
            
            if !seenPlanetPoints.contains(planetPointKey) {
                seenPlanetPoints.insert(planetPointKey)
                uniqueTransits.append(transit)
            }
        }
        
        // Then, ensure only one event per month from the unique transits
        var monthlyBestEvents: [String: TransitEvent] = [:]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        
        for transit in uniqueTransits {
            let monthKey = dateFormatter.string(from: transit.date)
            
            if let existingEvent = monthlyBestEvents[monthKey] {
                // Replace if this event is more significant
                if transit.significance > existingEvent.significance {
                    monthlyBestEvents[monthKey] = transit
                }
            } else {
                // First event for this month
                monthlyBestEvents[monthKey] = transit
            }
        }
        
        // Convert back to sorted array
        return Array(monthlyBestEvents.values).sorted { $0.date < $1.date }
    }
    
    private func generateYearTheme(_ transit: TransitEvent, chart: BirthChart, years: Int) -> String {
        let timeframe = years == 1 ? "year" : "next couple years"
        
        switch (transit.planet.lowercased(), transit.natalPoint.lowercased()) {
        case ("saturn", "sun"):
            return "This \(timeframe) is your coming-of-age moment. Life's handing you real responsibility and the recognition that comes with it. What feels heavy now is actually building your authority."
            
        case ("jupiter", "sun"):
            return "Breakthrough \(timeframe) ahead. Doors that were closed are opening, and people are finally taking you seriously. Your confidence is about to hit a whole new level."
            
        case ("uranus", "sun"):
            return "Everything about who you are is changing over the \(timeframe). The person you've been is evolving fast into someone more authentic. Stop fighting the change - it's liberation."
            
        case ("saturn", "ascendant"):
            return "Your reputation is solidifying over the \(timeframe). People start seeing you as more serious, more capable, more authoritative. This is when you step into real leadership."
            
        case ("jupiter", "ascendant"):
            return "Major glow-up coming over the \(timeframe). Your whole energy shifts, and suddenly opportunities appear just because of how you're showing up. Confidence and optimism become your default."
            
        case ("saturn", "moon"):
            return "Deep emotional maturation happening over the \(timeframe). Old patterns that kept you emotionally stuck are getting challenged. It's uncomfortable but leads to real stability."
            
        case ("jupiter", "venus"):
            return "Love and money get blessed over the \(timeframe). This could be meeting someone special, a relationship leveling up, or a significant financial boost. Good things coming in what you value."
            
        default:
            let area = getLifeArea(transit.natalPoint)
            return "The \(timeframe) brings real transformation to your \(area). This isn't surface-level - it's fundamental change in how this part of your life works."
        }
    }
    
    private func generateKeyEventDescription(_ event: TransitEvent, chart: BirthChart) -> String {
        switch (event.planet.lowercased(), event.aspect.lowercased(), event.natalPoint.lowercased()) {
        // Jupiter transits
        case ("jupiter", "conjunction", "venus"):
            return "A major blessing in love or money. This could be an engagement, significant relationship milestone, or unexpected financial gain. Your charm and attractiveness peak."
        case ("jupiter", "conjunction", "sun"):
            return "Your personal new year begins! This marks a major expansion in confidence, opportunities, and recognition. Whatever you launch now has Jupiter's blessing for success."
        case ("jupiter", "conjunction", "mars"):
            return "Your energy and ambition reach new heights. Perfect timing for starting ambitious projects or taking bold action. Your enthusiasm becomes contagious."
        case ("jupiter", "trine", "ascendant"):
            return "Others see you in a much more positive light. Your reputation expands and new doors open through personal connections. Natural leadership emerges."
        case ("jupiter", "sextile", "moon"):
            return "Emotional abundance and family blessings. This could bring pregnancy news, home improvements, or healing of family relationships. Inner peace grows."
            
        // Saturn transits
        case ("saturn", "conjunction", "sun"):
            return "A major coming-of-age moment. Life hands you significant responsibility and the recognition that comes with it. You step into your full authority."
        case ("saturn", "square", "mars"):
            return "A test of your willpower and strategy. Obstacles force you to develop patience and better planning. What doesn't kill you makes you significantly stronger."
        case ("saturn", "conjunction", "ascendant"):
            return "Others start taking you much more seriously. Your reputation matures and solidifies. You become the go-to person for important matters."
        case ("saturn", "trine", "venus"):
            return "Serious commitments in love or business partnerships. What you build now has lasting value and stability. Mature love is favored over infatuation."
        case ("saturn", "conjunction", "midheaven"):
            return "Career peak or major professional recognition. You achieve something you've been working toward for years. Authority figures take notice of your accomplishments."
            
        // Uranus transits
        case ("uranus", "conjunction", "sun"):
            return "Complete identity revolution! The person you've been is evolving rapidly. Sudden insights about your true self create dramatic life changes."
        case ("uranus", "trine", "sun"):
            return "A breakthrough moment that liberates your authentic self. You'll have the courage to make changes you've been contemplating for years. Freedom and innovation take center stage."
        case ("uranus", "square", "mars"):
            return "Restless energy demands change in how you assert yourself. Unexpected events force you to find new ways to express your drive and ambition."
        case ("uranus", "sextile", "venus"):
            return "Unusual romantic or creative opportunities arise. You're attracted to what's different and exciting. Unconventional relationships or artistic projects flourish."
            
        // Neptune transits
        case ("neptune", "sextile", "venus"):
            return "A dreamy, romantic period that enhances your creativity and spiritual connection to love. Ideal conditions for artistic projects or soul-mate connections."
        case ("neptune", "trine", "sun"):
            return "Spiritual awakening and enhanced intuition. Your creative and compassionate sides are highlighted. Dreams and visions provide important guidance."
        case ("neptune", "square", "mars"):
            return "Confusion about your direction requires spiritual guidance. What you thought you wanted may not be what your soul needs. Trust your intuition over ego."
            
        // Pluto transits
        case ("pluto", "conjunction", "sun"):
            return "Complete personality transformation. The person you've been is dying so a more authentic version can emerge. This change is profound and permanent."
        case ("pluto", "square", "moon"):
            return "Intense emotional transformation. Deep psychological patterns surface for healing. This fundamentally changes your relationship with your inner world."
        case ("pluto", "trine", "venus"):
            return "Your capacity for love and intimacy deepens dramatically. Past wounds heal, allowing for much more meaningful connections. Relationships transform or end."
        case ("pluto", "opposition", "mars"):
            return "Power struggles reveal where you need to transform your approach to conflict and assertion. Hidden strength emerges from facing your shadows."
            
        // Generic cases with more variety
        default:
            return generateVariedEventDescription(event)
        }
    }
    
    private func generateVariedEventDescription(_ event: TransitEvent) -> String {
        let planet = event.planet.capitalized
        let aspect = event.aspect.lowercased()
        
        // Handle all major planet-point combinations to avoid generic fallbacks
        switch (event.planet.lowercased(), event.natalPoint.lowercased()) {
        // Jupiter expansions
        case ("jupiter", "sun"):
            return aspect == "conjunction" ? 
                "Your confidence and opportunities expand dramatically. This is your breakthrough year for recognition and success." :
                "Jupiter boosts your core identity and leadership abilities. Natural charisma attracts new opportunities."
        case ("jupiter", "moon"):
            return aspect == "conjunction" ? 
                "Emotional abundance and family blessings arrive. Home life becomes source of joy and expansion." :
                "Your intuition and emotional intelligence reach new heights. Inner wisdom guides you to growth."
        case ("jupiter", "ascendant"):
            return aspect == "conjunction" ? 
                "Major glow-up in how others perceive you. Your reputation and social status expand significantly." :
                "Others see you as more successful and optimistic. New social circles open up."
        case ("jupiter", "venus"):
            return aspect == "conjunction" ? 
                "Love and money receive Jupiter's biggest blessing. Romance flourishes and finances improve dramatically." :
                "Your charm and attractiveness increase. Creative projects and relationships benefit from positive energy."
        case ("jupiter", "mars"):
            return aspect == "conjunction" ? 
                "Your energy and ambition reach peak levels. Perfect time to launch major projects with confidence." :
                "Your drive becomes more optimistic and effective. Actions taken now have lasting positive impact."
        case ("jupiter", "midheaven"):
            return aspect == "conjunction" ? 
                "Career reaches new heights of success and recognition. Professional opportunities multiply rapidly." :
                "Your reputation grows in positive directions. Authority figures support your advancement."
                
        // Saturn structures
        case ("saturn", "sun"):
            return aspect == "conjunction" ? 
                "Major maturation period begins. Life hands you serious responsibility and the recognition that comes with it." :
                "Your authority and leadership skills are tested and strengthened. Long-term success is being built."
        case ("saturn", "moon"):
            return aspect == "conjunction" ? 
                "Emotional patterns undergo serious restructuring. Past issues require mature handling for lasting stability." :
                "Your emotional security gets more solid foundation. Family responsibilities may increase."
        case ("saturn", "ascendant"):
            return aspect == "conjunction" ? 
                "Others start taking you much more seriously. Your image matures and reputation solidifies permanently." :
                "Your public persona becomes more authoritative and respected. Leadership roles become natural."
        case ("saturn", "venus"):
            return aspect == "conjunction" ? 
                "Relationships and finances require serious commitment. What you build now has lasting value." :
                "Love becomes more mature and stable. Financial discipline leads to long-term security."
        case ("saturn", "mars"):
            return aspect == "square" ? 
                "Your ambitions face reality tests. Obstacles force development of patience and better strategies." :
                "Your energy becomes more disciplined and effective. Sustained effort replaces scattered action."
        case ("saturn", "midheaven"):
            return aspect == "conjunction" ? 
                "Career peak moment arrives. Years of effort culminate in major professional recognition." :
                "Your professional reputation stabilizes at a higher level. Authority figures respect your competence."
                
        // Uranus breakthroughs
        case ("uranus", "sun"):
            return aspect == "conjunction" ? 
                "Complete identity revolution begins. The person you've been evolves into someone entirely new." :
                "Breakthrough insights about your true self create liberating changes in life direction."
        case ("uranus", "moon"):
            return aspect == "conjunction" ? 
                "Emotional breakthrough liberates you from old family and security patterns forever." :
                "Your feelings become more authentic and free. Emotional independence increases dramatically."
        case ("uranus", "ascendant"):
            return aspect == "conjunction" ? 
                "Your entire image undergoes shocking transformation. Others are amazed by your sudden evolution." :
                "Unexpected changes in how you present yourself to the world. Independence becomes your signature."
        case ("uranus", "venus"):
            return aspect == "conjunction" ? 
                "Unusual romantic developments disrupt your love life in exciting ways. Attraction to the unconventional." :
                "Creative inspiration strikes like lightning. Artistic projects take unexpected innovative directions."
        case ("uranus", "mars"):
            return aspect == "conjunction" ? 
                "Your energy and drive undergo complete revolution. New ways of taking action emerge suddenly." :
                "Restless energy demands changes in how you assert yourself and pursue goals."
                
        // Pluto transformations
        case ("pluto", "sun"):
            return aspect == "conjunction" ? 
                "Complete personality transformation. Death of old self enables birth of authentic power and purpose." :
                "Deep changes in core identity create permanent shift in life direction and personal power."
        case ("pluto", "moon"):
            return aspect == "conjunction" ? 
                "Intense emotional transformation heals deep psychological patterns permanently." :
                "Hidden emotions and family secrets surface for complete healing and transformation."
        case ("pluto", "ascendant"):
            return aspect == "conjunction" ? 
                "Your entire persona transforms with magnetic intensity. Others notice your increased personal power." :
                "Your image becomes more mysterious and powerful. People sense your inner strength and transformation."
        case ("pluto", "venus"):
            return aspect == "conjunction" ? 
                "Love and values undergo complete transformation. Capacity for intimacy deepens dramatically." :
                "Relationships either deepen profoundly or end completely. Your standards for love evolve."
        case ("pluto", "mars"):
            return aspect == "conjunction" ? 
                "Your drive and ambition transform completely. Hidden strength and determination emerge powerfully." :
                "Power struggles reveal where you need to transform your approach to conflict and assertion."
                
        // Neptune spiritual awakenings
        case ("neptune", "sun"):
            return aspect == "conjunction" ? 
                "Spiritual awakening dissolves ego boundaries. Your identity becomes more fluid and compassionate." :
                "Enhanced intuition and creativity. Your sense of purpose becomes more spiritually guided."
        case ("neptune", "moon"):
            return aspect == "conjunction" ? 
                "Psychic abilities and emotional sensitivity increase dramatically. Dreams become prophetic." :
                "Your emotional world becomes more intuitive and spiritually connected. Boundaries soften."
        case ("neptune", "ascendant"):
            return aspect == "conjunction" ? 
                "Your image becomes more ethereal and mysterious. Others see you as more spiritual and artistic." :
                "Your presence becomes more compassionate and inspiring. Others seek your spiritual guidance."
        case ("neptune", "venus"):
            return aspect == "conjunction" ? 
                "Spiritual and unconditional love awakens. Romantic idealism reaches peak expression." :
                "Your capacity for love becomes more selfless and transcendent. Artistic inspiration flows."
        case ("neptune", "mars"):
            return aspect == "conjunction" ? 
                "Your drive becomes spiritually guided rather than ego-driven. Actions align with higher purpose." :
                "Confusion about direction requires trusting intuition over logical planning."
                
        default:
            // Catch-all with more variety to avoid repetition
            let variations = [
                "\(planet) brings a significant shift to your \(getLifeArea(event.natalPoint)), opening new possibilities.",
                "\(planet) influences your \(getLifeArea(event.natalPoint)) in ways that create lasting positive change.",
                "\(planet) activates important developments in your \(getLifeArea(event.natalPoint)) that shape your future.",
                "A \(planet.lowercased()) cycle begins that transforms your relationship to \(getLifeArea(event.natalPoint)).",
                "\(planet) energy peaks in your \(getLifeArea(event.natalPoint)), bringing clarity and new direction."
            ]
            return variations.randomElement() ?? "\(planet) brings meaningful change to your \(getLifeArea(event.natalPoint))."
        }
    }
    
    private func getNatalPointSign(_ point: String, chart: BirthChart) -> String {
        switch point.lowercased() {
        case "sun":
            return chart.sunSign.rawValue
        case "moon":
            return chart.moonSign.rawValue
        case "ascendant", "rising":
            return chart.ascendantSign.rawValue
        default:
            return "the zodiac"
        }
    }
}

// MARK: - Extensions

extension Int {
    var ordinalString: String {
        let suffix: String
        let lastDigit = self % 10
        let lastTwoDigits = self % 100
        
        if lastTwoDigits >= 11 && lastTwoDigits <= 13 {
            suffix = "th"
        } else {
            switch lastDigit {
            case 1: suffix = "st"
            case 2: suffix = "nd"  
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        
        return "\(self)\(suffix)"
    }
}

// MARK: - Error Handling

enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(Int)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is missing. Please add it to APIKeys.plist."
        case .invalidResponse:
            return "Invalid response from OpenAI API."
        case .apiError(let statusCode):
            return "OpenAI API error with status code: \(statusCode)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
