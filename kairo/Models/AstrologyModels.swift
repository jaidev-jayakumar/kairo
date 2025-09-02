import Foundation
import SwiftUI

// MARK: - Birth Data
struct BirthData: Codable {
    let date: Date
    let latitude: Double
    let longitude: Double
    let timeZone: TimeZone
    
    init(date: Date, latitude: Double, longitude: Double, timeZone: TimeZone = .current) {
        self.date = date
        self.latitude = latitude
        self.longitude = longitude
        self.timeZone = timeZone
    }
}

// MARK: - Zodiac Sign
enum ZodiacSign: String, CaseIterable {
    case aries = "Aries"
    case taurus = "Taurus"
    case gemini = "Gemini"
    case cancer = "Cancer"
    case leo = "Leo"
    case virgo = "Virgo"
    case libra = "Libra"
    case scorpio = "Scorpio"
    case sagittarius = "Sagittarius"
    case capricorn = "Capricorn"
    case aquarius = "Aquarius"
    case pisces = "Pisces"
    
    var symbol: String {
        switch self {
        case .aries: return "♈"
        case .taurus: return "♉"
        case .gemini: return "♊"
        case .cancer: return "♋"
        case .leo: return "♌"
        case .virgo: return "♍"
        case .libra: return "♎"
        case .scorpio: return "♏"
        case .sagittarius: return "♐"
        case .capricorn: return "♑"
        case .aquarius: return "♒"
        case .pisces: return "♓"
        }
    }
    
    var element: Element {
        switch self {
        case .aries, .leo, .sagittarius: return .fire
        case .taurus, .virgo, .capricorn: return .earth
        case .gemini, .libra, .aquarius: return .air
        case .cancer, .scorpio, .pisces: return .water
        }
    }
    
    static func fromDegrees(_ degrees: Double) -> (sign: ZodiacSign, degree: Int, minute: Int) {
        let normalizedDegrees = degrees.truncatingRemainder(dividingBy: 360)
        let signIndex = Int(normalizedDegrees / 30)
        let signDegrees = normalizedDegrees.truncatingRemainder(dividingBy: 30)
        let degree = Int(signDegrees)
        let minute = Int((signDegrees - Double(degree)) * 60)
        
        return (ZodiacSign.allCases[signIndex], degree, minute)
    }
}

// MARK: - Element
enum Element: String {
    case fire = "Fire"
    case earth = "Earth"
    case air = "Air"
    case water = "Water"
    
    var color: String {
        switch self {
        case .fire: return "FF6B6B"
        case .earth: return "6B8E23"
        case .air: return "87CEEB"
        case .water: return "4682B4"
        }
    }
}

// MARK: - Celestial Body
struct CelestialBody {
    let name: String
    let symbol: String
    let longitude: Double
    let latitude: Double
    let distance: Double
    let speedLongitude: Double
    
    var position: (sign: ZodiacSign, degree: Int, minute: Int) {
        ZodiacSign.fromDegrees(longitude)
    }
    
    var formattedPosition: String {
        let pos = position
        return "\(pos.sign.symbol) \(pos.degree)°\(String(format: "%02d", pos.minute))'"
    }
    
    var signName: String {
        position.sign.rawValue
    }
    
    var formattedDegree: String {
        let pos = position
        return "\(pos.degree)°\(String(format: "%02d", pos.minute))'"
    }
}

// MARK: - House
struct House {
    let number: Int
    let cusp: Double
    
    var sign: ZodiacSign {
        ZodiacSign.fromDegrees(cusp).sign
    }
    
    var formattedCusp: String {
        let pos = ZodiacSign.fromDegrees(cusp)
        return "\(pos.sign.symbol) \(pos.degree)°\(String(format: "%02d", pos.minute))'"
    }
}

// MARK: - Birth Chart
struct BirthChart {
    let birthData: BirthData
    let sun: CelestialBody
    let moon: CelestialBody
    let mercury: CelestialBody
    let venus: CelestialBody
    let mars: CelestialBody
    let jupiter: CelestialBody
    let saturn: CelestialBody
    let uranus: CelestialBody
    let neptune: CelestialBody
    let pluto: CelestialBody
    let ascendant: Double
    let midheaven: Double
    let houses: [House]
    
    var ascendantSign: ZodiacSign {
        ZodiacSign.fromDegrees(ascendant).sign
    }
    
    var sunSign: ZodiacSign {
        sun.position.sign
    }
    
    var moonSign: ZodiacSign {
        moon.position.sign
    }
    
    var risingSign: ZodiacSign {
        ascendantSign
    }
    
    var formattedAscendant: String {
        let pos = ZodiacSign.fromDegrees(ascendant)
        return "\(pos.sign.symbol) \(pos.degree)°\(String(format: "%02d", pos.minute))'"
    }
}

// MARK: - Aspect
enum AspectType: String {
    case conjunction = "Conjunction"
    case sextile = "Sextile"
    case square = "Square"
    case trine = "Trine"
    case opposition = "Opposition"
    
    var symbol: String {
        switch self {
        case .conjunction: return "☌"
        case .sextile: return "⚹"
        case .square: return "□"
        case .trine: return "△"
        case .opposition: return "☍"
        }
    }
    
    var orb: Double {
        switch self {
        case .conjunction: return 8.0
        case .sextile: return 6.0
        case .square: return 8.0
        case .trine: return 8.0
        case .opposition: return 8.0
        }
    }
    
    var angle: Double {
        switch self {
        case .conjunction: return 0
        case .sextile: return 60
        case .square: return 90
        case .trine: return 120
        case .opposition: return 180
        }
    }
    
    var color: Color {
        switch self {
        case .conjunction: return .white
        case .trine: return .green
        case .square: return .red
        case .opposition: return .orange
        case .sextile: return .blue
        }
    }
}

struct Aspect {
    let planet1: CelestialBody
    let planet2: CelestialBody
    let type: AspectType
    let exactOrb: Double
    
    var description: String {
        "\(planet1.name) \(type.symbol) \(planet2.name)"
    }
}

// MARK: - Horoscope Scores
struct HoroscopeScores {
    let overall: Int
    let love: Int
    let career: Int
    let wealth: Int
    let date: Date
    
    init(overall: Int, love: Int, career: Int, wealth: Int, date: Date = Date()) {
        self.overall = max(0, min(100, overall))
        self.love = max(0, min(100, love))
        self.career = max(0, min(100, career))
        self.wealth = max(0, min(100, wealth))
        self.date = date
    }
}

// MARK: - Cycle/Transit Information
struct AstrologicalCycle {
    let id: UUID = UUID()
    let title: String
    let planetaryAspect: String
    let duration: String
    let description: String
    let influence: CycleInfluence
    
    enum CycleInfluence {
        case positive
        case challenging
        case transformative
        case neutral
        
        var color: String {
            switch self {
            case .positive: return "#4CAF50"
            case .challenging: return "#FF9800"
            case .transformative: return "#9C27B0"
            case .neutral: return "#607D8B"
            }
        }
    }
}