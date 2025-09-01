import SwiftUI

struct BirthChartView: View {
    @State private var rotationAngle: Double = 0
    @State private var selectedPlanet: Planet? = nil
    
    let planets = [
        Planet(name: "Sun", symbol: "☉", sign: "Leo", degree: "23°", color: Color.yellow),
        Planet(name: "Moon", symbol: "☽", sign: "Cancer", degree: "15°", color: Color.white),
        Planet(name: "Mercury", symbol: "☿", sign: "Virgo", degree: "7°", color: Color.orange),
        Planet(name: "Venus", symbol: "♀", sign: "Libra", degree: "29°", color: Color.pink),
        Planet(name: "Mars", symbol: "♂", sign: "Aries", degree: "11°", color: Color.red),
    ]
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                Text("Birth Chart")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.white)
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
                    ForEach(planets) { planet in
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
                
                // Planet details
                if let planet = selectedPlanet {
                    AstroCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(planet.symbol)
                                    .font(.system(size: 24))
                                    .foregroundColor(planet.color)
                                
                                Text(planet.name)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("\(planet.sign) \(planet.degree)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Text(planet.interpretation)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.75))
                                .lineSpacing(4)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
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

enum AspectType {
    case conjunction, trine, square, opposition, sextile
    
    var color: Color {
        switch self {
        case .conjunction: return .white
        case .trine: return .green
        case .square: return .red
        case .opposition: return .orange
        case .sextile: return .blue
        }
    }
    
    var symbol: String {
        switch self {
        case .conjunction: return "☌"
        case .trine: return "△"
        case .square: return "□"
        case .opposition: return "☍"
        case .sextile: return "⚹"
        }
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