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
                // Use our deterministic, personalized insight (no AI override)
                dailyInsight = AstrologyService.shared.generateDailyInsightSync(for: chart)
                currentTransits = AstrologyService.shared.calculateCurrentTransits()
                
                // Calculate horoscope scores based on user's birth chart
                horoscopeScores = AstrologyService.shared.calculateHoroscopeScores(for: chart)
                
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
            // Swiss Ephemeris indicator
            HStack(spacing: 4) {
                Image(systemName: "star.circle.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 10))
                Text("Real-time Swiss Ephemeris")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(.yellow.opacity(0.1))
            .cornerRadius(8)
            
            // Planet alignment visual
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    .frame(width: 120, height: 120)
                
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.white)
                        .frame(width: index == 1 ? 12 : 6, height: index == 1 ? 12 : 6)
                        .offset(x: cos(CGFloat(index) * 2 * .pi / 3) * 50,
                               y: sin(CGFloat(index) * 2 * .pi / 3) * 50)
                }
                
                // Connection lines
                Path { path in
                    path.move(to: CGPoint(x: 50, y: 0))
                    path.addLine(to: CGPoint(x: -25, y: 43))
                    path.addLine(to: CGPoint(x: -25, y: -43))
                    path.closeSubpath()
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            }
            
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

// MARK: - Constellation Background
struct ConstellationBackground: View {
    let phase: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let points = generateConstellationPoints(in: size)
                
                // Draw connections
                for i in 0..<points.count {
                    for j in (i+1)..<points.count {
                        let distance = hypot(points[i].x - points[j].x, points[i].y - points[j].y)
                        if distance < 150 {
                            var path = Path()
                            path.move(to: points[i])
                            path.addLine(to: points[j])
                            
                            let opacity = 0.1 * (1.0 - distance / 150.0)
                            context.stroke(
                                path,
                                with: .color(.white.opacity(opacity)),
                                lineWidth: 0.5
                            )
                        }
                    }
                }
                
                // Draw points
                for point in points {
                    context.fill(
                        Circle().path(in: CGRect(x: point.x - 1, y: point.y - 1, width: 2, height: 2)),
                        with: .color(.white.opacity(0.3))
                    )
                }
            }
        }
    }
    
    func generateConstellationPoints(in size: CGSize) -> [CGPoint] {
        var points: [CGPoint] = []
        for _ in 0..<12 {
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