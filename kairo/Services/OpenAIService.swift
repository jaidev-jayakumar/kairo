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
        // Get major transits happening now and in the next 2 years
        let majorTransits = await calculateMajorUpcomingTransits(for: chart, years: 2)
        
        // Create a comprehensive astrological prediction
        return await generateSpecificPrediction(chart: chart, transits: majorTransits, context: question)
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
    
    private func generateSpecificPrediction(chart: BirthChart, transits: [TransitEvent], context: String) async -> String {
        if transits.isEmpty {
            return "You're in a relatively stable period with no major planetary transits disrupting your chart. This is actually a great time to consolidate gains and prepare for future growth cycles."
        }
        
        // Group transits by timeframe
        let nextSixMonths = transits.filter { $0.date <= Calendar.current.date(byAdding: .month, value: 6, to: Date())! }
        let nextYear = transits.filter { 
            let sixMonthsFromNow = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
            let oneYearFromNow = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
            return $0.date > sixMonthsFromNow && $0.date <= oneYearFromNow
        }
        let secondYear = transits.filter {
            let oneYearFromNow = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
            return $0.date > oneYearFromNow
        }
        
        var prediction = ""
        
        // Current major theme
        if let mostSignificant = transits.sorted(by: { $0.significance > $1.significance }).first {
            prediction += generateLifeThemePrediction(mostSignificant, chart: chart) + "\n\n"
        }
        
        // Next 6 months
        if !nextSixMonths.isEmpty {
            prediction += "Over the next 6 months: "
            prediction += generateTimeframePrediction(nextSixMonths, chart: chart) + "\n\n"
        }
        
        // Next year  
        if !nextYear.isEmpty {
            prediction += "In 2025: "
            prediction += generateTimeframePrediction(nextYear, chart: chart) + "\n\n"
        }
        
        // Year 2
        if !secondYear.isEmpty {
            prediction += "Looking ahead to 2026: "
            prediction += generateTimeframePrediction(secondYear, chart: chart)
        }
        
        return prediction.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func generateLifeThemePrediction(_ transit: TransitEvent, chart: BirthChart) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        let timeframe = dateFormatter.string(from: transit.date)
        
        switch (transit.planet.lowercased(), transit.natalPoint.lowercased()) {
        case ("saturn", "sun"):
            return "You're entering a major maturation cycle around \(timeframe). This is when life asks you to step up and become the authority figure you're meant to be. Expect significant responsibility and recognition."
            
        case ("jupiter", "sun"):
            return "A major expansion phase begins around \(timeframe). Your confidence, opportunities, and visibility will all increase dramatically. This is your time to shine on a bigger stage."
            
        case ("uranus", "sun"):
            return "Get ready for a complete identity revolution around \(timeframe). Everything about how you see yourself and how others see you is about to change. Embrace the authentic you that's emerging."
            
        case ("saturn", "moon"):
            return "You're being asked to mature emotionally around \(timeframe). Past emotional patterns that no longer serve you will be challenged. This leads to much greater emotional stability."
            
        case ("jupiter", "ascendant"):
            return "Around \(timeframe), you'll project a completely different energy to the world. People will see you as more confident, optimistic, and successful. New doors open because of this shift."
            
        case ("pluto", "sun"):
            return "You're undergoing a complete personality transformation around \(timeframe). The person you've been is dying so the person you're meant to be can be born. This is profound and permanent change."
            
        default:
            return "A significant life shift is occurring around \(timeframe) that will reshape how you approach \(getLifeArea(transit.natalPoint)). This isn't just a phase - it's a fundamental change in your life direction."
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
        let timeframe = years == 1 ? "year" : "\(years) years"
        
        switch (transit.planet.lowercased(), transit.natalPoint.lowercased()) {
        case ("saturn", "sun"):
            return "This \(timeframe) marks a major coming-of-age period. Saturn is teaching you to step into your full authority and take on serious responsibilities. What feels challenging now is actually preparing you for lasting success and recognition. You're building something that will define the next phase of your life."
            
        case ("jupiter", "sun"):
            return "Get ready for a breakthrough \(timeframe)! Jupiter is expanding everything about your identity, confidence, and opportunities. This is when doors open that have been closed before, and people start taking you seriously in ways they never have. Your natural talents get the recognition they deserve."
            
        case ("uranus", "sun"):
            return "Revolutionary change is coming to your core identity over the next \(timeframe). The person you've been is evolving into someone completely new. This isn't gradual - it's a lightning bolt of awakening that changes how you see yourself and how others see you. Embrace the rebellion against who you used to be."
            
        case ("saturn", "ascendant"):
            return "You're entering a major image transformation over the next \(timeframe). Saturn is maturing your public presence and the way others perceive you. You'll be seen as more serious, authoritative, and trustworthy. This is when your reputation solidifies and people start looking to you for leadership."
            
        case ("jupiter", "ascendant"):
            return "Your entire presence is about to expand dramatically over the next \(timeframe). Jupiter crossing your rising sign brings a glow-up that's both internal and external. You'll feel more optimistic and confident, and others will be drawn to your elevated energy. New opportunities come simply because of how you're showing up in the world."
            
        case ("saturn", "moon"):
            return "Deep emotional restructuring is happening over the next \(timeframe). Saturn is asking you to mature your emotional patterns and create real security in your inner world. Old ways of processing feelings won't work anymore. This creates lasting emotional stability and wisdom."
            
        case ("jupiter", "venus"):
            return "Love and abundance are the major themes for the next \(timeframe). Jupiter is blessing your relationships, creativity, and financial situation. This could be when you meet someone special, get engaged, or experience a significant boost in your income. Your values are expanding in beautiful ways."
            
        default:
            let area = getLifeArea(transit.natalPoint)
            return "The next \(timeframe) brings significant transformation to your \(area). This isn't just surface-level change - it's a fundamental shift in how this area of your life operates. What emerges will be stronger and more aligned with your authentic self."
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
