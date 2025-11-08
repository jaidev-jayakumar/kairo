import SwiftUI

struct ChatView: View {
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "What's on your mind?", isUser: false)
    ]
    @State private var inputText = ""
    @State private var isTyping = false
    @State private var userBirthChart: BirthChart?
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Minimal header
                VStack(spacing: 8) {
                    Text("ask me anything")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.4))
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                        .frame(maxWidth: 100)
                }
                .padding(.top, 40)
                .padding(.bottom, 20)
            
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 32) {
                            ForEach(messages) { message in
                                CosmicMessage(message: message)
                                    .id(message.id)
                            }
                            
                            if isTyping {
                                OracleTyping()
                            }
                        }
                        .padding(.vertical, 40)
                        .padding(.horizontal, 30)
                    }
                    .onChange(of: messages.count) { _ in
                        withAnimation {
                            proxy.scrollTo(messages.last?.id, anchor: .bottom)
                        }
                    }
                }
            
                // Input area
                VStack(spacing: 16) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                    
                    HStack(spacing: 16) {
                        TextField("", text: $inputText)
                            .placeholder(when: inputText.isEmpty) {
                                Text("Ask your question")
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(.white)
                            .accentColor(.white)
                        
                        Button(action: sendMessage) {
                            Text("send")
                                .font(.system(size: 12, weight: .medium))
                                .tracking(1)
                                .foregroundColor(inputText.isEmpty ? .white.opacity(0.2) : .white.opacity(0.8))
                        }
                        .disabled(inputText.isEmpty)
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            // Load user birth chart for personalized responses
            if let birthData = UserDataManager.shared.getBirthData() {
                userBirthChart = AstrologyService.shared.calculateBirthChart(for: birthData)
            }
        }
    }
    
    func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        let userMessage = ChatMessage(text: inputText, isUser: true)
        messages.append(userMessage)
        let questionText = inputText
        inputText = ""
        
        isTyping = true
        
        // Generate AI-powered response
        Task {
            let response = await generateCosmicResponseAI(to: questionText)
            DispatchQueue.main.async {
                self.isTyping = false
                self.messages.append(ChatMessage(text: response, isUser: false))
            }
        }
    }
    
    func generateCosmicResponseAI(to question: String) async -> String {
        guard let chart = userBirthChart else {
            return "I'm still loading your chart. Give me a sec."
        }
        
        return await AIInsightService.shared.generateChatResponse(question: question, chart: chart)
    }
    
    func generateCosmicResponse(to question: String) -> String {
        guard let chart = userBirthChart else {
            return "I'm still loading your chart. Give me a sec."
        }
        
        let currentTransits = AstrologyService.shared.calculateCurrentTransits()
        let sunSign = chart.sunSign
        let moonSign = chart.moonSign
        
        // Analyze the question and provide relevant astrological insight
        let questionLower = question.lowercased()
        
        if questionLower.contains("love") || questionLower.contains("relationship") {
            return generateLoveInsight(chart: chart, transits: currentTransits)
        } else if questionLower.contains("career") || questionLower.contains("work") || questionLower.contains("job") {
            return generateCareerInsight(chart: chart, transits: currentTransits)
        } else if questionLower.contains("money") || questionLower.contains("finance") {
            return generateMoneyInsight(chart: chart, transits: currentTransits)
        } else if questionLower.contains("future") || questionLower.contains("what will") {
            return generateFutureInsight(chart: chart, transits: currentTransits)
        } else {
            return generateGeneralInsight(chart: chart, transits: currentTransits)
        }
    }
    
    private func generateLoveInsight(chart: BirthChart, transits: [CelestialBody]) -> String {
        let venusSign = chart.venus.position.sign
        if let moonTransit = transits.first(where: { $0.name == "Moon" }) {
            let moonSign = moonTransit.position.sign
            return "With Venus in \(venusSign.rawValue) in your chart and the Moon currently in \(moonSign.rawValue), love flows through \(moonSign.element.rawValue.lowercased()) energy today. Your \(venusSign.rawValue) Venus seeks \(getVenusNeed(for: venusSign)). Trust what feels genuine."
        }
        return "Your Venus in \(venusSign.rawValue) reveals how you love - \(getVenusNeed(for: venusSign)). Honor this truth in all your connections."
    }
    
    private func generateCareerInsight(chart: BirthChart, transits: [CelestialBody]) -> String {
        let sunSign = chart.sunSign
        let marsSign = chart.mars.position.sign
        return "Your \(sunSign.rawValue) Sun drives you toward \(getSunPurpose(for: sunSign)), while Mars in \(marsSign.rawValue) gives you \(getMarsEnergy(for: marsSign)). Channel this energy into work that honors your authentic expression."
    }
    
    private func generateMoneyInsight(chart: BirthChart, transits: [CelestialBody]) -> String {
        let sunSign = chart.sunSign
        return "As a \(sunSign.rawValue), your relationship with resources reflects \(getMoneyMindset(for: sunSign)). True abundance comes when you align with your authentic values, not external expectations."
    }
    
    private func generateFutureInsight(chart: BirthChart, transits: [CelestialBody]) -> String {
        if let jupiterTransit = transits.first(where: { $0.name == "Jupiter" }) {
            let jupiterSign = jupiterTransit.position.sign
            return "Jupiter in \(jupiterSign.rawValue) expands opportunities in areas of \(getJupiterGrowth(for: jupiterSign)). The future unfolds through your willingness to grow beyond current limitations."
        }
        return "The future is written in your choices, not your stars. Your birth chart shows potential; your actions determine manifestation."
    }
    
    private func generateGeneralInsight(chart: BirthChart, transits: [CelestialBody]) -> String {
        let sunSign = chart.sunSign
        let moonSign = chart.moonSign
        if let moonTransit = transits.first(where: { $0.name == "Moon" }) {
            let currentMoonSign = moonTransit.position.sign
            return "Your \(sunSign.rawValue) essence and \(moonSign.rawValue) emotional nature are influenced by today's Moon in \(currentMoonSign.rawValue). This creates \(getMoodInfluence(natal: moonSign, transit: currentMoonSign)). Trust your inner knowing."
        }
        return "Your \(sunSign.rawValue) Sun and \(moonSign.rawValue) Moon create a unique lens through which you experience life. Honor both your need for expression and emotional authenticity."
    }
    
    // Helper functions for astrological interpretations
    private func getVenusNeed(for sign: ZodiacSign) -> String {
        switch sign {
        case .aries: return "passionate, direct connections"
        case .taurus: return "stable, sensual partnerships"
        case .gemini: return "intellectual stimulation and variety"
        case .cancer: return "emotional security and nurturing"
        case .leo: return "appreciation and dramatic romance"
        case .virgo: return "practical devotion and improvement"
        case .libra: return "harmony and beautiful partnerships"
        case .scorpio: return "intense, transformative bonds"
        case .sagittarius: return "freedom and adventurous love"
        case .capricorn: return "commitment and respect"
        case .aquarius: return "friendship and independence"
        case .pisces: return "spiritual connection and compassion"
        }
    }
    
    private func getSunPurpose(for sign: ZodiacSign) -> String {
        switch sign {
        case .aries: return "leadership and pioneering new paths"
        case .taurus: return "building lasting value and security"
        case .gemini: return "communication and connecting ideas"
        case .cancer: return "nurturing and creating emotional safety"
        case .leo: return "creative self-expression and inspiration"
        case .virgo: return "service and perfecting systems"
        case .libra: return "creating harmony and justice"
        case .scorpio: return "transformation and deep investigation"
        case .sagittarius: return "expansion and sharing wisdom"
        case .capricorn: return "achievement and building legacy"
        case .aquarius: return "innovation and humanitarian progress"
        case .pisces: return "healing and spiritual service"
        }
    }
    
    private func getMarsEnergy(for sign: ZodiacSign) -> String {
        switch sign {
        case .aries: return "direct, pioneering drive"
        case .taurus: return "steady, determined action"
        case .gemini: return "versatile, communicative energy"
        case .cancer: return "protective, intuitive motivation"
        case .leo: return "confident, creative force"
        case .virgo: return "precise, service-oriented action"
        case .libra: return "diplomatic, partnership-focused drive"
        case .scorpio: return "intense, transformative power"
        case .sagittarius: return "adventurous, philosophical energy"
        case .capricorn: return "disciplined, ambitious drive"
        case .aquarius: return "innovative, humanitarian action"
        case .pisces: return "compassionate, intuitive motivation"
        }
    }
    
    private func getMoneyMindset(for sign: ZodiacSign) -> String {
        switch sign {
        case .aries: return "quick decisions and bold investments"
        case .taurus: return "steady accumulation and tangible security"
        case .gemini: return "multiple income streams and variety"
        case .cancer: return "emotional security through savings"
        case .leo: return "generous spending on quality and status"
        case .virgo: return "careful budgeting and practical investments"
        case .libra: return "balanced spending and aesthetic purchases"
        case .scorpio: return "transformative investments and hidden resources"
        case .sagittarius: return "spending on experiences and education"
        case .capricorn: return "long-term planning and traditional investments"
        case .aquarius: return "innovative investments and group ventures"
        case .pisces: return "intuitive decisions and charitable giving"
        }
    }
    
    private func getJupiterGrowth(for sign: ZodiacSign) -> String {
        switch sign {
        case .aries: return "leadership and new initiatives"
        case .taurus: return "material growth and stability"
        case .gemini: return "learning and communication"
        case .cancer: return "home and emotional fulfillment"
        case .leo: return "creativity and self-expression"
        case .virgo: return "health and service improvement"
        case .libra: return "relationships and artistic pursuits"
        case .scorpio: return "transformation and hidden knowledge"
        case .sagittarius: return "travel and higher learning"
        case .capricorn: return "career and public recognition"
        case .aquarius: return "technology and humanitarian causes"
        case .pisces: return "spirituality and compassion"
        }
    }
    
    private func getMoodInfluence(natal: ZodiacSign, transit: ZodiacSign) -> String {
        if natal == transit {
            return "an emotionally centering influence"
        } else if natal.element == transit.element {
            return "a harmonious emotional flow"
        } else {
            return "an opportunity to integrate different emotional energies"
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
}

struct CosmicMessage: View {
    let message: ChatMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if message.isUser {
                // User question
                VStack(alignment: .trailing, spacing: 8) {
                    Text("you")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text(message.text)
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.trailing)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                // Oracle response
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 3, height: 3)
                        
                        Text("kaira")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(1.5)
                            .foregroundColor(.white.opacity(0.4))
                    }
                    
                    Text(message.text)
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(8)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct OracleTyping: View {
    @State private var opacity: Double = 0.3
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 3, height: 3)
            
            Text("thinking...")
                .font(.system(size: 10, weight: .medium))
                .tracking(1.5)
                .foregroundColor(.white.opacity(opacity))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                opacity = 0.6
            }
        }
    }
}

// Placeholder modifier extension
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    ChatView()
}