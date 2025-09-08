import SwiftUI

struct TodayView: View {
    @State private var showContent = false
    @State private var selectedInsight: CosmicInsight? = nil
    @State private var constellationPhase: CGFloat = 0
    @State private var dailyInsight: String = ""
    @State private var currentTransits: [CelestialBody] = []
    @State private var userBirthData: BirthData? = nil
    @State private var horoscopeScores: HoroscopeScores? = nil
    @State private var currentCycles: [AstrologicalCycle] = []
    
    var body: some View {
        ZStack {
            // Background with subtle animation
            Color.black
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
                        HoroscopeScoresView(scores: scores)
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
                    EnergyManifestations()
                        .padding(.top, 60)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 1.0).delay(0.9), value: showContent)
                    
                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 30)
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
            
            // Calculate daily insight and scores
            if let birthData = userBirthData,
               let chart = AstrologyService.shared.calculateBirthChart(for: birthData) {
                
                currentTransits = AstrologyService.shared.calculateCurrentTransits()
                
                // Use AI-powered fresh daily insight
                Task {
                    let freshInsight = await AstrologyService.shared.generateDailyInsight(for: chart)
                    await MainActor.run {
                        dailyInsight = freshInsight
                    }
                }
                
                // Calculate DAILY horoscope scores based on user's birth chart
                horoscopeScores = AstrologyService.shared.calculateDailyHoroscopeScores(for: chart)
                
                // Calculate current astrological cycles
                currentCycles = AstrologyService.shared.calculateCurrentCycles(for: chart)
            }
        }
    }
}

// MARK: - Philosophical Header
struct PhilosophicalHeader: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("TODAY YOU ASKED")
                .font(.system(size: 11, weight: .medium))
                .tracking(2)
                .foregroundColor(.white.opacity(0.4))
            
            Text("What truth am I avoiding?")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
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
                
                Text(dailyInsight.isEmpty ? "The cosmos is calculating your guidance..." : dailyInsight)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.white.opacity(0.85))
                    .lineHeight(1.6)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    func getCurrentTransitTitle() -> String {
        guard let moon = currentTransits.first(where: { $0.name == "Moon" }) else {
            return "COSMIC ALIGNMENT IN PROGRESS"
        }
        
        let moonSign = moon.position.sign
        return "MOON IN \(moonSign.rawValue.uppercased())"
    }
}

// MARK: - Energy Manifestations
struct EnergyManifestations: View {
    @State private var manifestations: [(String, String)] = []
    
    private var todaysManifestations: [(String, String)] {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        
        let allManifestations = [
            ("Your intuition is louder than your anxiety today", "brain.head.profile"),
            ("Stop explaining yourself to people who won't listen anyway", "bubble.left.and.bubble.right"),
            ("The thing you're avoiding is the thing that will set you free", "key"),
            ("Your boundaries are love letters to your future self", "heart.shield"),
            ("What feels like falling apart is actually falling together", "sparkles"),
            ("Your sensitivity is a superpower, not a weakness", "wand.and.stars"),
            ("The person you're becoming is worth the discomfort", "figure.walk"),
            ("Trust the process even when you can't see the outcome", "eye"),
            ("Your weirdness is your authenticity trying to escape", "star"),
            ("The resistance you feel is just fear dressed up as logic", "flame"),
            ("Your gut knows things your brain hasn't figured out yet", "brain"),
            ("Dreams carry more weight than facts when you're changing", "moon.zzz"),
            ("Clarity arrives through confusion, not around it", "lightbulb"),
            ("Your body keeps the score your mind tries to forget", "figure.mind.and.body"),
            ("Sometimes the answer is to stop asking the question", "questionmark.diamond")
        ]
        
        // Select 3 deterministic manifestations based on day of year
        var selected: [(String, String)] = []
        for i in 0..<3 {
            let index = (dayOfYear + i * 7) % allManifestations.count
            selected.append(allManifestations[index])
        }
        
        return selected
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
                Text("PEAK INTUITION")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.4))
                
                Text("3:17 PM")
                    .font(.system(size: 32, weight: .ultraLight))
                    .foregroundColor(.white)
                
                Text("Trust what emerges in silence")
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