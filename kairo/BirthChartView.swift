import SwiftUI

struct BirthChartView: View {
    @State private var rotationAngle: Double = 0
    @State private var selectedPlanet: Planet? = nil
    @State private var birthChart: BirthChart? = nil
    @State private var userBirthData: BirthData? = nil
    
    // Calculate display planets from real birth chart data
    var displayPlanets: [Planet] {
        guard let chart = birthChart else {
            // Fallback data while loading
            return [
                Planet(name: "Loading...", symbol: "⏳", sign: "...", degree: "...", color: .gray)
            ]
        }
        
        return [
            Planet(name: "Sun", symbol: "☉", sign: chart.sun.signName, degree: chart.sun.formattedDegree, color: .yellow),
            Planet(name: "Moon", symbol: "☽", sign: chart.moon.signName, degree: chart.moon.formattedDegree, color: .gray),
            Planet(name: "Mercury", symbol: "☿", sign: chart.mercury.signName, degree: chart.mercury.formattedDegree, color: .cyan),
            Planet(name: "Venus", symbol: "♀", sign: chart.venus.signName, degree: chart.venus.formattedDegree, color: .pink),
            Planet(name: "Mars", symbol: "♂", sign: chart.mars.signName, degree: chart.mars.formattedDegree, color: .red),
            Planet(name: "Jupiter", symbol: "♃", sign: chart.jupiter.signName, degree: chart.jupiter.formattedDegree, color: .orange),
            Planet(name: "Saturn", symbol: "♄", sign: chart.saturn.signName, degree: chart.saturn.formattedDegree, color: .brown),
            Planet(name: "Uranus", symbol: "♅", sign: chart.uranus.signName, degree: chart.uranus.formattedDegree, color: .blue),
            Planet(name: "Neptune", symbol: "♆", sign: chart.neptune.signName, degree: chart.neptune.formattedDegree, color: .teal),
            Planet(name: "Pluto", symbol: "♇", sign: chart.pluto.signName, degree: chart.pluto.formattedDegree, color: .purple)
        ]
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Birth Chart")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.white)
                    
                    // SwissEphemeris indicator
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 10))
                        Text("Powered by Swiss Ephemeris")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.yellow.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.yellow.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.top, 20)
                
                // Chart wheel
                ZStack {
                    // Outer circle
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        .frame(width: 320, height: 320)
                    
                    // Zodiac ring
                    ForEach(0..<12) { index in
                        ZodiacSegment(index: index)
                    }
                    
                    // Inner circles
                    Circle()
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        .frame(width: 240, height: 240)
                    
                    Circle()
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        .frame(width: 160, height: 160)
                    
                    // Center
                    Circle()
                        .fill(Color.black)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text("YOU")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .tracking(2)
                        )
                    
                    // Planet positions
                    ForEach(displayPlanets) { planet in
                        PlanetView(planet: planet, isSelected: selectedPlanet?.id == planet.id)
                            .offset(x: cos(planet.angle) * 120, y: sin(planet.angle) * 120)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedPlanet = selectedPlanet?.id == planet.id ? nil : planet
                                }
                            }
                    }
                }
                .frame(width: 320, height: 320)
                .rotationEffect(.degrees(rotationAngle))
                .onAppear {
                    withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                }
                
                // Chart Info
                if let chart = birthChart {
                    VStack(spacing: 20) {
                        // Big Three
                        AstroCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("YOUR BIG THREE")
                                    .font(.system(size: 12, weight: .medium))
                                    .tracking(1.5)
                                    .foregroundColor(.white.opacity(0.6))
                                
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("☉ Sun")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white.opacity(0.8))
                                        Spacer()
                                        Text(chart.sun.formattedPosition)
                                            .font(.system(size: 16, weight: .light))
                                            .foregroundColor(.white)
                                    }
                                    
                                    HStack {
                                        Text("☽ Moon")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white.opacity(0.8))
                                        Spacer()
                                        Text(chart.moon.formattedPosition)
                                            .font(.system(size: 16, weight: .light))
                                            .foregroundColor(.white)
                                    }
                                    
                                    HStack {
                                        Text("↑ Rising")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white.opacity(0.8))
                                        Spacer()
                                        Text(chart.formattedAscendant)
                                            .font(.system(size: 16, weight: .light))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        
                        // Planets
                        AstroCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("PLANETARY POSITIONS")
                                    .font(.system(size: 12, weight: .medium))
                                    .tracking(1.5)
                                    .foregroundColor(.white.opacity(0.6))
                                
                                VStack(spacing: 10) {
                                    PlanetRow(celestialBody: chart.mercury)
                                    PlanetRow(celestialBody: chart.venus)
                                    PlanetRow(celestialBody: chart.mars)
                                    PlanetRow(celestialBody: chart.jupiter)
                                    PlanetRow(celestialBody: chart.saturn)
                                }
                            }
                        }
                    }
                }
                
                // Aspects
                VStack(alignment: .leading, spacing: 16) {
                    Text("Key Aspects")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    AspectRow(aspect: "Sun trine Moon", type: .trine, description: "Emotional harmony")
                    AspectRow(aspect: "Venus square Mars", type: .square, description: "Passionate tension")
                    AspectRow(aspect: "Mercury conjunct Jupiter", type: .conjunction, description: "Expansive thinking")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .background(Color.black)
        .onAppear {
            // Load user birth data and calculate chart
            userBirthData = UserDataManager.shared.getBirthData()
            if let birthData = userBirthData {
                birthChart = AstrologyService.shared.calculateBirthChart(for: birthData)
            }
        }
    }
}

// MARK: - Planet Row
struct PlanetRow: View {
    let celestialBody: CelestialBody
    
    var body: some View {
        HStack {
            Text("\(celestialBody.symbol) \(celestialBody.name)")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(celestialBody.formattedPosition)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

struct Planet: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    let sign: String
    let degree: String
    let color: Color
    var angle: Double = Double.random(in: 0...(2 * .pi))
    
    var interpretation: String {
        switch name {
        case "Sun":
            return "Your core essence shines through creative self-expression. Leadership comes naturally."
        case "Moon":
            return "Deep emotional intelligence guides your intuition. Home and family are sacred."
        case "Mercury":
            return "Quick wit and analytical mind. Communication is your superpower."
        case "Venus":
            return "Harmony and beauty attract abundance. Love flows through aesthetic expression."
        case "Mars":
            return "Pioneering spirit drives ambition. Action brings manifestation."
        default:
            return ""
        }
    }
}

struct PlanetView: View {
    let planet: Planet
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(planet.color.opacity(0.2))
                .frame(width: isSelected ? 40 : 30, height: isSelected ? 40 : 30)
            
            Text(planet.symbol)
                .font(.system(size: isSelected ? 20 : 16))
                .foregroundColor(planet.color)
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .shadow(color: planet.color.opacity(0.5), radius: isSelected ? 10 : 5)
    }
}

struct ZodiacSegment: View {
    let index: Int
    let signs = ["♈", "♉", "♊", "♋", "♌", "♍", "♎", "♏", "♐", "♑", "♒", "♓"]
    
    var body: some View {
        let angle = Double(index) * .pi / 6 - .pi / 2
        let xOffset = cos(angle) * 150
        let yOffset = sin(angle) * 150
        
        Text(signs[index])
            .font(.system(size: 16))
            .foregroundColor(.white.opacity(0.3))
            .rotationEffect(.degrees(-Double(index) * 30))
            .offset(x: xOffset, y: yOffset)
    }
}


struct AspectRow: View {
    let aspect: String
    let type: AspectType
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(type.symbol)
                .font(.system(size: 20))
                .foregroundColor(type.color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(aspect)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
    }
}

#Preview {
    BirthChartView()
}