import Foundation

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
    
    // MARK: - Main Conversation Method
    
    func generateResponse(to userMessage: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }
        
        // For now, use a simple implementation without function calling
        // We'll build the astrological responses directly
        return await generateAstrologicalResponse(to: userMessage)
    }
    
    private func generateAstrologicalResponse(to userMessage: String) async -> String {
        // Get birth chart if available
        guard let birthChart = getCurrentBirthChart() else {
            return "I sense your cosmic energy, but I need your birth information to provide personalized insights. Please set up your birth chart first."
        }
        
        let message = userMessage.lowercased()
        
        if message.contains("birth chart") || message.contains("chart") {
            return generateBirthChartResponse(for: birthChart)
        } else if message.contains("score") || message.contains("horoscope") {
            return generateHoroscopeScoresResponse(for: birthChart)
        } else if message.contains("transit") || message.contains("current") {
            return generateTransitsResponse()
        } else if message.contains("daily") || message.contains("today") {
            return await generateDailyInsightResponse(for: birthChart)
        } else {
            return await generateGeneralResponse(for: birthChart, question: userMessage)
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
