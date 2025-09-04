import SwiftUI

struct BirthChartView: View {
    @State private var rotationAngle: Double = 0
    @State private var selectedPlanet: Planet? = nil
    @State private var birthChart: BirthChart? = nil
    @State private var userBirthData: BirthData? = nil
    @State private var showAPIChart = false
    @State private var selectedView: ChartViewType = .traditional
    
    enum ChartViewType: String, CaseIterable {
        case traditional = "Traditional"
        case professional = "Professional"
        
        var displayName: String { return self.rawValue }
    }
    
    // Calculate display planets from real birth chart data
    var displayPlanets: [Planet] {
        guard let chart = birthChart else {
            // Fallback data while loading
            return [
                Planet(name: "Loading...", symbol: "⏳", sign: "...", degree: "...", color: .gray, angle: 0)
            ]
        }
        
        // Helper function to safely calculate angle from longitude
        func safeAngle(from longitude: Double) -> Double {
            if longitude.isNaN || longitude.isInfinite {
                return Double.random(in: 0...(2 * .pi)) // Fallback to random if invalid
            }
            // Convert longitude (0-360°) to radians (0-2π)
            let normalized = longitude.truncatingRemainder(dividingBy: 360)
            let positive = normalized < 0 ? normalized + 360 : normalized
            return (positive * .pi) / 180
        }
        
        return [
            Planet(name: "Sun", symbol: "☉", sign: chart.sun.signName, degree: chart.sun.formattedDegree, color: .yellow, angle: safeAngle(from: chart.sun.longitude)),
            Planet(name: "Moon", symbol: "☽", sign: chart.moon.signName, degree: chart.moon.formattedDegree, color: .gray, angle: safeAngle(from: chart.moon.longitude)),
            Planet(name: "Mercury", symbol: "☿", sign: chart.mercury.signName, degree: chart.mercury.formattedDegree, color: .cyan, angle: safeAngle(from: chart.mercury.longitude)),
            Planet(name: "Venus", symbol: "♀", sign: chart.venus.signName, degree: chart.venus.formattedDegree, color: .pink, angle: safeAngle(from: chart.venus.longitude)),
            Planet(name: "Mars", symbol: "♂", sign: chart.mars.signName, degree: chart.mars.formattedDegree, color: .red, angle: safeAngle(from: chart.mars.longitude)),
            Planet(name: "Jupiter", symbol: "♃", sign: chart.jupiter.signName, degree: chart.jupiter.formattedDegree, color: .orange, angle: safeAngle(from: chart.jupiter.longitude)),
            Planet(name: "Saturn", symbol: "♄", sign: chart.saturn.signName, degree: chart.saturn.formattedDegree, color: .brown, angle: safeAngle(from: chart.saturn.longitude)),
            Planet(name: "Uranus", symbol: "♅", sign: chart.uranus.signName, degree: chart.uranus.formattedDegree, color: .blue, angle: safeAngle(from: chart.uranus.longitude)),
            Planet(name: "Neptune", symbol: "♆", sign: chart.neptune.signName, degree: chart.neptune.formattedDegree, color: .teal, angle: safeAngle(from: chart.neptune.longitude)),
            Planet(name: "Pluto", symbol: "♇", sign: chart.pluto.signName, degree: chart.pluto.formattedDegree, color: .purple, angle: safeAngle(from: chart.pluto.longitude))
        ]
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Text("Birth Chart")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.white)
                    
                    // Chart type selector
                    Picker("Chart Style", selection: $selectedView) {
                        ForEach(ChartViewType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    .frame(width: 280)
                    
                    // SwissEphemeris indicator
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 10))
                        Text(selectedView == .traditional ? "Powered by Swiss Ephemeris" : "Professional Chart by Astrologer API")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.yellow.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.yellow.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.top, 20)
                
                // Chart display
                if selectedView == .traditional {
                    // Traditional Chart wheel
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
                                .offset(
                                    x: planet.angle.isNaN || planet.angle.isInfinite ? 0 : cos(planet.angle) * 120,
                                    y: planet.angle.isNaN || planet.angle.isInfinite ? 0 : sin(planet.angle) * 120
                                )
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
                } else if let birthData = userBirthData {
                    // Professional API Chart with fallback
                    Group {
                        if UserDataManager.shared.hasBirthData {
                            BirthChartDisplayView(birthData: birthData)
                                .frame(height: 500)
                        } else {
                            BirthDataMissingView()
                        }
                    }

                } else {
                    // No birth data available
                    BirthDataMissingView()

                }
                
                // Chart Info (only show for traditional view)
                if selectedView == .traditional, let chart = birthChart {
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
                
                // Aspects (only for traditional view)
                if selectedView == .traditional {
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
    let angle: Double
    
    init(name: String, symbol: String, sign: String, degree: String, color: Color, angle: Double? = nil) {
        self.name = name
        self.symbol = symbol
        self.sign = sign
        self.degree = degree
        self.color = color
        self.angle = angle ?? Double.random(in: 0...(2 * .pi))
    }
    
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

struct BirthDataMissingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.6))
            
            Text("Birth Data Required")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
            
            Text("Please set up your birth information in the Profile tab to generate professional charts.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(height: 400)
    }
}

#Preview {
    BirthChartView()
}