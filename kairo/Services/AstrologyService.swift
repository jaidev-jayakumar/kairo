import Foundation
import SwissEphemeris

class AstrologyService {
    static let shared = AstrologyService()
    
    private init() {
        // Initialize Swiss Ephemeris with default path
        // The package will use its internal ephemeris data
    }
    
    // MARK: - Birth Chart Calculation
    func calculateBirthChart(for birthData: BirthData) -> BirthChart? {
        // Calculate planets
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
            return nil
        }
        
        // Calculate houses
        let houseCusps = HouseCusps(
            date: birthData.date,
            latitude: birthData.latitude,
            longitude: birthData.longitude,
            houseSystem: .placidus
        )
        
        let houses = (1...12).map { houseNumber in
            House(number: houseNumber, cusp: getHouseCusp(houseCusps, house: houseNumber))
        }
        
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
    }
    
    // MARK: - Planet Calculation
    private func calculatePlanet(_ planet: Planet, date: Date) -> CelestialBody? {
        let coordinate = Coordinate<Planet>(body: planet, date: date)
        
        return CelestialBody(
            name: planet.formatted.replacingOccurrences(of: planet.symbol + " ", with: ""),
            symbol: planet.symbol,
            longitude: coordinate.longitude,
            latitude: coordinate.latitude,
            distance: coordinate.distance,
            speedLongitude: coordinate.speedLongitude
        )
    }
    
    // MARK: - Transit Calculations
    func calculateCurrentTransits() -> [CelestialBody] {
        let now = Date()
        let planets: [Planet] = [.sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune, .pluto]
        
        return planets.compactMap { calculatePlanet($0, date: now) }
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
    
    // MARK: - Daily Horoscope
    func generateDailyInsight(for chart: BirthChart) -> String {
        let transits = calculateCurrentTransits()
        
        // Find most significant transit
        if let moonTransit = transits.first(where: { $0.name == "Moon" }) {
            let moonSign = moonTransit.position.sign
            let natalSunSign = chart.sunSign
            
            // Simple interpretation based on moon transit to sun sign
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
}