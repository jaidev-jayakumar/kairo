import Foundation
import SwissEphemeris

class AstrologyService {
    static let shared = AstrologyService()
    
    private init() {
        // Initialize Swiss Ephemeris with default path
        // The package will use its internal ephemeris data
        JPLFileManager.setEphemerisPath()
    }
    
    // MARK: - Birth Chart Calculation
    func calculateBirthChart(for birthData: BirthData) -> BirthChart? {
        print("🌟 Using SwissEphemeris for professional birth chart calculation")
        // Calculate planets using SwissEphemeris
        guard let sun = calculatePlanet(.sun, date: birthData.date),
              let moon = calculatePlanet(.moon, date: birthData.date),
              let mercury = calculatePlanet(.mercury, date: birthData.date),
              let venus = calculatePlanet(.venus, date: birthData.date),
              let mars = calculatePlanet(.mars, date: birthData.date),
              let jupiter = calculatePlanet(.jupiter, date: birthData.date),
              let saturn = calculatePlanet(.saturn, date: birthData.date),
              let uranus = calculatePlanet(.uranus, date: birthData.date),
              let neptune = calculatePlanet(.neptune, date: birthData.date),
              let pluto = calculatePlanet(.pluto, date: birthData.date) else {
            // Fallback to simplified service if SwissEphemeris fails
            print("SwissEphemeris calculation failed, falling back to simplified service")
            return SimplifiedAstrologyService.shared.calculateBirthChart(for: birthData)
        }
        
        // Calculate houses
        do {
            let houseCusps = try HouseCusps(
                date: birthData.date,
                latitude: birthData.latitude,
                longitude: birthData.longitude,
                houseSystem: .placidus
            )
            
            let houses = (1...12).map { houseNumber in
                House(number: houseNumber, cusp: getHouseCusp(houseCusps, house: houseNumber))
            }
            
            print("✅ SwissEphemeris calculation completed successfully!")
            return BirthChart(
                birthData: birthData,
                sun: sun,
                moon: moon,
                mercury: mercury,
                venus: venus,
                mars: mars,
                jupiter: jupiter,
                saturn: saturn,
                uranus: uranus,
                neptune: neptune,
                pluto: pluto,
                ascendant: getAscendant(houseCusps),
                midheaven: getMidheaven(houseCusps),
                houses: houses
            )
        } catch {
            print("House calculation failed: \(error)")
            // Fallback to simplified service
            return SimplifiedAstrologyService.shared.calculateBirthChart(for: birthData)
        }
    }
    
    // MARK: - Planet Calculation
    private func calculatePlanet(_ planet: SwissEphemeris.Planet, date: Date) -> CelestialBody? {
        do {
            let coordinate = try Coordinate<SwissEphemeris.Planet>(body: planet, date: date)
            
            return CelestialBody(
                name: planetName(planet),
                symbol: planetSymbol(planet),
                longitude: coordinate.longitude,
                latitude: coordinate.latitude,
                distance: coordinate.distance,
                speedLongitude: coordinate.speedLongitude
            )
        } catch {
            print("Error calculating planet \(planet): \(error)")
            return nil
        }
    }
    
    // MARK: - Transit Calculations
    func calculateCurrentTransits() -> [CelestialBody] {
        print("🌍 Using SwissEphemeris for current planetary transits")
        let now = Date()
        let planets: [SwissEphemeris.Planet] = [.sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune, .pluto]
        
        let transits = planets.compactMap { calculatePlanet($0, date: now) }
        
        // If SwissEphemeris fails, fallback to simplified service
        if transits.isEmpty {
            print("SwissEphemeris transit calculation failed, falling back to simplified service")
            return SimplifiedAstrologyService.shared.calculateCurrentTransits()
        }
        
        print("✅ SwissEphemeris transit calculations completed successfully!")
        return transits
    }
    
    // MARK: - Aspect Calculations
    func calculateAspects(for chart: BirthChart) -> [Aspect] {
        var aspects: [Aspect] = []
        let bodies = [chart.sun, chart.moon, chart.mercury, chart.venus, chart.mars,
                     chart.jupiter, chart.saturn, chart.uranus, chart.neptune, chart.pluto]
        
        for i in 0..<bodies.count {
            for j in (i+1)..<bodies.count {
                if let aspect = calculateAspect(between: bodies[i], and: bodies[j]) {
                    aspects.append(aspect)
                }
            }
        }
        
        return aspects
    }
    
    private func calculateAspect(between body1: CelestialBody, and body2: CelestialBody) -> Aspect? {
        let angle = abs(body1.longitude - body2.longitude)
        let normalizedAngle = angle > 180 ? 360 - angle : angle
        
        for aspectType in [AspectType.conjunction, .sextile, .square, .trine, .opposition] {
            let orb = abs(normalizedAngle - aspectType.angle)
            if orb <= aspectType.orb {
                return Aspect(planet1: body1, planet2: body2, type: aspectType, exactOrb: orb)
            }
        }
        
        return nil
    }
    
    // MARK: - Helper Methods for HouseCusps
    private func getHouseCusp(_ houseCusps: HouseCusps, house: Int) -> Double {
        let cusp: Cusp
        switch house {
        case 1: cusp = houseCusps.first
        case 2: cusp = houseCusps.second
        case 3: cusp = houseCusps.third
        case 4: cusp = houseCusps.fourth
        case 5: cusp = houseCusps.fifth
        case 6: cusp = houseCusps.sixth
        case 7: cusp = houseCusps.seventh
        case 8: cusp = houseCusps.eighth
        case 9: cusp = houseCusps.ninth
        case 10: cusp = houseCusps.tenth
        case 11: cusp = houseCusps.eleventh
        case 12: cusp = houseCusps.twelfth
        default: return 0
        }
        return cusp.tropical.value
    }
    
    private func getAscendant(_ houseCusps: HouseCusps) -> Double {
        return houseCusps.ascendent.tropical.value
    }
    
    private func getMidheaven(_ houseCusps: HouseCusps) -> Double {
        return houseCusps.midHeaven.tropical.value
    }
    
    // MARK: - Helper Methods
    private func planetName(_ planet: SwissEphemeris.Planet) -> String {
        switch planet {
        case .sun: return "Sun"
        case .moon: return "Moon"
        case .mercury: return "Mercury"
        case .venus: return "Venus"
        case .mars: return "Mars"
        case .jupiter: return "Jupiter"
        case .saturn: return "Saturn"
        case .uranus: return "Uranus"
        case .neptune: return "Neptune"
        case .pluto: return "Pluto"
        default: return "Unknown"
        }
    }
    
    private func planetSymbol(_ planet: SwissEphemeris.Planet) -> String {
        switch planet {
        case .sun: return "☉"
        case .moon: return "☽"
        case .mercury: return "☿"
        case .venus: return "♀"
        case .mars: return "♂"
        case .jupiter: return "♃"
        case .saturn: return "♄"
        case .uranus: return "♅"
        case .neptune: return "♆"
        case .pluto: return "♇"
        default: return "?"
        }
    }
    
    // MARK: - Daily Insights (AI-Powered)
    func generateDailyInsight(for chart: BirthChart) async -> String {
        let transits = calculateCurrentTransits()
        return await AIInsightService.shared.generateDailyInsight(for: chart, transits: transits)
    }
    
    func generateDailyInsightSync(for chart: BirthChart) -> String {
        // Synchronous fallback for immediate UI updates
        let transits = calculateCurrentTransits()
        
        if let moonTransit = transits.first(where: { $0.name == "Moon" }) {
            let moonSign = moonTransit.position.sign
            let natalSunSign = chart.sunSign
            
            if moonSign == natalSunSign {
                return "The Moon illuminates your essence today. Your emotions and identity align, bringing clarity to personal matters."
            } else if moonSign.element == natalSunSign.element {
                return "Harmonious lunar energy supports your natural rhythm. Flow with intuitive insights that arise."
            } else {
                return "Luna's journey through \(moonSign.rawValue) asks you to integrate different aspects of yourself. Balance is key."
            }
        }
        
        return "The cosmos holds space for your becoming. Trust the unfolding."
    }
    
    // MARK: - Weekly Insights (AI-Powered)
    func generateWeeklyInsight(for chart: BirthChart) async -> String {
        let transits = calculateCurrentTransits()
        return await AIInsightService.shared.generateWeeklyInsight(for: chart, transits: transits)
    }
}