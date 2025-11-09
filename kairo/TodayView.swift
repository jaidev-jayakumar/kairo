import SwiftUI

struct TodayView: View {
    @State private var showContent = false
    @State private var selectedInsight: CosmicInsight? = nil
    @State private var constellationPhase: CGFloat = 0
    @State private var dailyInsight: String = ""
    @State private var currentTransits: [CelestialBody] = []
    @State private var userBirthData: BirthData? = nil
    @State private var userBirthChart: BirthChart? = nil
    @State private var horoscopeScores: HoroscopeScores? = nil
    @State private var currentCycles: [AstrologicalCycle] = []
    @State private var selectedDate: Date = Date()
    
    // Task management to prevent crashes
    @State private var insightTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            // Background with subtle animation
            Color.black
                .ignoresSafeArea()
            
            // Ambient coral/pink gradient overlays
            RadialGradient(
                colors: [
                    Color(hex: "FF8A8A")?.opacity(0.08) ?? .pink.opacity(0.08),
                    Color(hex: "FF6B6B")?.opacity(0.04) ?? .red.opacity(0.04),
                    Color.black.opacity(0)
                ],
                center: .topTrailing,
                startRadius: 100,
                endRadius: 700
            )
            .ignoresSafeArea()
            
            // Subtle top glow
            LinearGradient(
                colors: [
                    Color(hex: "FFBABA")?.opacity(0.04) ?? .pink.opacity(0.04),
                    Color.black.opacity(0)
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            
            // Bottom accent glow
            RadialGradient(
                colors: [
                    Color(hex: "FF6B6B")?.opacity(0.06) ?? .red.opacity(0.06),
                    Color.black.opacity(0)
                ],
                center: .bottom,
                startRadius: 50,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            // Constellation lines in background
            ConstellationBackground(phase: constellationPhase)
                .opacity(0.15)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Philosophical question header
                    PhilosophicalHeader()
                        .padding(.top, 60)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 1.2), value: showContent)
                    
                    // Horoscope Scores
                    if let scores = horoscopeScores {
                        HoroscopeScoresView(scores: scores, selectedDate: $selectedDate)
                            .padding(.top, 40)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 30)
                            .animation(.easeOut(duration: 1.0).delay(0.3), value: showContent)
                    }
                    
                    // Main cosmic insight
                    MainCosmicMessage(dailyInsight: dailyInsight, currentTransits: currentTransits)
                        .padding(.top, 60)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 30)
                        .animation(.easeOut(duration: 1.0).delay(0.5), value: showContent)
                    
                    // Cycles
                    if !currentCycles.isEmpty {
                        CyclesView(cycles: currentCycles)
                            .padding(.top, 60)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 1.0).delay(0.7), value: showContent)
                    }
                    
                    // Energy manifestations
                    EnergyManifestations(chart: userBirthChart, transits: currentTransits)
                        .padding(.top, 60)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 1.0).delay(0.9), value: showContent)
                    
                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            withAnimation {
                showContent = true
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                constellationPhase = 1
            }
            
            // Load user birth data
            userBirthData = UserDataManager.shared.getBirthData()
            
            // Calculate for initial date (today)
            calculateForDate(selectedDate)
        }
        .onDisappear {
            // Cancel pending tasks to prevent crashes
            insightTask?.cancel()
        }
        .onChange(of: selectedDate) { newDate in
            // Recalculate everything when date changes
            calculateForDate(newDate)
        }
    }
    
    private func calculateForDate(_ date: Date) {
        // Calculate daily insight and scores for the selected date
        guard let birthData = userBirthData,
              let chart = AstrologyService.shared.calculateBirthChart(for: birthData) else {
            return
        }
        
        // Store the birth chart
        userBirthChart = chart
        
        // Calculate transits for the SELECTED date, not today
        currentTransits = AstrologyService.shared.calculateCurrentTransits(for: date)
        
        // Cancel any previous insight task
        insightTask?.cancel()
        
        // Use AI-powered fresh daily insight FOR THE SELECTED DATE
        insightTask = Task { @MainActor in
            let freshInsight = await AIInsightService.shared.generateDailyInsight(for: chart, transits: currentTransits, date: date)
            
            // Check if task was cancelled before updating state
            guard !Task.isCancelled else { return }
            
            dailyInsight = freshInsight
        }
        
        // Calculate DAILY horoscope scores based on user's birth chart and selected date
        horoscopeScores = AstrologyService.shared.calculateDailyHoroscopeScores(for: chart, date: date)
        
        // Calculate astrological cycles for the selected date
        currentCycles = AstrologyService.shared.calculateCurrentCycles(for: chart, date: date)
    }
}

// MARK: - Philosophical Header
struct PhilosophicalHeader: View {
    @State private var breathingScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 8) {
            Text("today's question")
                .font(.system(size: 11, weight: .medium))
                .tracking(2)
                .foregroundColor(.white.opacity(0.4))
            
            Text("tiny gains, everyday...")
                .font(.system(size: 28, weight: .light, design: .serif))
                .foregroundColor(.white)
                .shadow(color: .white.opacity(0.08), radius: 12, x: 0, y: 0)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .scaleEffect(breathingScale)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                breathingScale = 1.015
            }
        }
    }
}

// MARK: - Main Cosmic Message
struct MainCosmicMessage: View {
    let dailyInsight: String
    let currentTransits: [CelestialBody]
    
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 24) {
                Text(getCurrentTransitTitle())
                    .font(.system(size: 13, weight: .medium))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(dailyInsight.isEmpty ? "reading your chart..." : dailyInsight)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .white.opacity(0.05), radius: 8, x: 0, y: 0)
                    .lineHeight(1.6)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    func getCurrentTransitTitle() -> String {
        guard let moon = currentTransits.first(where: { $0.name == "Moon" }) else {
            return "calculating your chart"
        }
        
        let moonSign = moon.position.sign
        return "moon in \(moonSign.rawValue.lowercased())"
    }
}

// MARK: - Energy Manifestations
struct EnergyManifestations: View {
    let chart: BirthChart?
    let transits: [CelestialBody]
    
    private var todaysManifestations: [(String, String)] {
        guard let chart = chart else {
            // Fallback icons for loading state
            return [
                ("loading your personalized themes...", "sparkles"),
                ("calculating today's transits...", "moon.stars"),
                ("reading your chart...", "star")
            ]
        }
        
        // Generate personalized themes based on actual transits
        let themes = PersonalizedThemeGenerator.shared.generateDailyThemes(
            chart: chart,
            transits: transits,
            count: 3
        )
        
        // Assign contextual icons based on theme content
        return themes.map { theme in
            (theme, iconForTheme(theme))
        }
    }
    
    private func iconForTheme(_ theme: String) -> String {
        let lower = theme.lowercased()
        
        // Smart icon matching based on theme content
        if lower.contains("gut") || lower.contains("intuition") || lower.contains("instinct") {
            return "brain.head.profile"
        } else if lower.contains("boundary") || lower.contains("boundaries") {
            return "heart.shield"
        } else if lower.contains("change") || lower.contains("changing") || lower.contains("growth") {
            return "arrow.triangle.2.circlepath"
        } else if lower.contains("truth") || lower.contains("authentic") || lower.contains("real") {
            return "star"
        } else if lower.contains("emotion") || lower.contains("feel") || lower.contains("heart") {
            return "heart"
        } else if lower.contains("think") || lower.contains("mind") || lower.contains("clarity") {
            return "lightbulb"
        } else if lower.contains("people") || lower.contains("relationship") || lower.contains("connection") {
            return "person.2"
        } else if lower.contains("energy") || lower.contains("power") || lower.contains("strength") {
            return "bolt"
        } else if lower.contains("past") || lower.contains("time") || lower.contains("timing") {
            return "clock"
        } else if lower.contains("fear") || lower.contains("anxiety") || lower.contains("scared") {
            return "flame"
        } else if lower.contains("trust") || lower.contains("faith") {
            return "hand.raised"
        } else if lower.contains("anger") || lower.contains("frustration") {
            return "exclamationmark.triangle"
        } else if lower.contains("love") || lower.contains("connection") {
            return "heart.circle"
        } else {
            // Default cosmic icon
            return "sparkles"
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ForEach(todaysManifestations, id: \.0) { text, icon in
                HStack(spacing: 16) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 24)
                    
                    Text(text)
                        .font(.system(size: 15, weight: .light))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Cosmic Timing
struct CosmicTiming: View {
    var body: some View {
        VStack(spacing: 32) {
            // Divider line
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
                .frame(maxWidth: 200)
            
            VStack(spacing: 16) {
                Text("peak intuition")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.4))
                
                Text("3:17 PM")
                    .font(.system(size: 32, weight: .ultraLight))
                    .foregroundColor(.white)
                
                Text("trust what comes up in quiet moments")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - Simple Constellation View (Co-Star Style)
struct SimpleConstellationView: View {
    var body: some View {
        ZStack {
            // Just the dots and connections like Co-Star
            let positions: [CGPoint] = [
                CGPoint(x: 60, y: 30),   // Top
                CGPoint(x: 90, y: 75),   // Bottom right  
                CGPoint(x: 30, y: 75)    // Bottom left
            ]
            
            // Connection lines
            Path { path in
                path.move(to: positions[0])
                path.addLine(to: positions[1])
                path.addLine(to: positions[2])
                path.addLine(to: positions[0])
            }
            .stroke(Color.white.opacity(0.3), lineWidth: 1)
            
            // Planet dots
            ForEach(0..<positions.count, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(index == 0 ? 1.0 : 0.7))
                    .frame(width: index == 0 ? 8 : 6, height: index == 0 ? 8 : 6)
                    .position(positions[index])
            }
        }
        .frame(width: 120, height: 105)
    }
}

// MARK: - Constellation Background (for main background)
struct ConstellationBackground: View {
    let phase: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let points = generateConstellationPoints(in: size)
                
                // Draw subtle background stars
                for point in points {
                    context.fill(
                        Circle().path(in: CGRect(x: point.x - 0.5, y: point.y - 0.5, width: 1, height: 1)),
                        with: .color(.white.opacity(0.1))
                    )
                }
            }
        }
    }
    
    func generateConstellationPoints(in size: CGSize) -> [CGPoint] {
        var points: [CGPoint] = []
        for _ in 0..<30 {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height)
            points.append(CGPoint(x: x, y: y))
        }
        return points
    }
}

// MARK: - Models
struct CosmicInsight: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let planetAlignment: String
}

// MARK: - Line Height Extension
extension View {
    func lineHeight(_ height: CGFloat) -> some View {
        self.modifier(LineHeightModifier(height: height))
    }
}


struct LineHeightModifier: ViewModifier {
    let height: CGFloat
    
    func body(content: Content) -> some View {
        content
            .lineSpacing(height * 8)
    }
}

#Preview {
    TodayView()
}