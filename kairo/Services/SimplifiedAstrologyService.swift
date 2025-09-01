import Foundation

// Simplified astrology service for testing without SwissEphemeris
class SimplifiedAstrologyService {
    static let shared = SimplifiedAstrologyService()
    
    private init() {}
    
    // MARK: - Mock Birth Chart Calculation
    func calculateBirthChart(for birthData: BirthData) -> BirthChart? {
        // This is a simplified calculation for demo purposes
        // Real calculations would use SwissEphemeris
        
        let baseDate = birthData.date
        let dayOfYear = Calendar.current.ordinateOfDay(for: baseDate) ?? 1
        
        // Approximate sun position (moves ~1 degree per day)
        let sunLongitude = Double(dayOfYear - 80) // Spring equinox offset
        
        // Mock planet positions
        let sun = CelestialBody(
            name: "Sun",
            symbol: "☉",
            longitude: normalizeAngle(sunLongitude),
            latitude: 0,
            distance: 1.0,
            speedLongitude: 1.0
        )
        
        let moon = CelestialBody(
            name: "Moon",
            symbol: "☽",
            longitude: normalizeAngle(sunLongitude + 90),
            latitude: 5.0,
            distance: 0.00257,
            speedLongitude: 13.0
        )
        
        // Create other planets with offset positions
        let mercury = createMockPlanet("Mercury", "☿", offset: 30)
        let venus = createMockPlanet("Venus", "♀", offset: 60)
        let mars = createMockPlanet("Mars", "♂", offset: 120)
        let jupiter = createMockPlanet("Jupiter", "♃", offset: 180)
        let saturn = createMockPlanet("Saturn", "♄", offset: 210)
        let uranus = createMockPlanet("Uranus", "♅", offset: 240)
        let neptune = createMockPlanet("Neptune", "♆", offset: 270)
        let pluto = createMockPlanet("Pluto", "♇", offset: 300)
        
        // Calculate approximate ascendant based on time and location
        let hourAngle = getHourAngle(from: baseDate)
        let ascendant = normalizeAngle(sunLongitude + hourAngle + birthData.longitude)
        
        // Create mock houses
        let houses = (1...12).map { houseNumber in
            House(number: houseNumber, cusp: normalizeAngle(ascendant + Double((houseNumber - 1) * 30)))
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
            ascendant: ascendant,
            midheaven: normalizeAngle(ascendant + 270),
            houses: houses
        )
    }
    
    // MARK: - Transit Calculations
    func calculateCurrentTransits() -> [CelestialBody] {
        let now = Date()
        let dayOfYear = Calendar.current.ordinateOfDay(for: now) ?? 1
        let sunLongitude = Double(dayOfYear - 80)
        
        return [
            CelestialBody(name: "Sun", symbol: "☉", longitude: normalizeAngle(sunLongitude), latitude: 0, distance: 1.0, speedLongitude: 1.0),
            CelestialBody(name: "Moon", symbol: "☽", longitude: normalizeAngle(sunLongitude + Double.random(in: 0...360)), latitude: 5.0, distance: 0.00257, speedLongitude: 13.0),
            createMockPlanet("Mercury", "☿", offset: 20 + Double.random(in: -10...10)),
            createMockPlanet("Venus", "♀", offset: 48 + Double.random(in: -10...10)),
            createMockPlanet("Mars", "♂", offset: 120 + Double.random(in: -5...5))
        ]
    }
    
    // MARK: - Daily Horoscope
    func generateDailyInsight(for chart: BirthChart) -> String {
        let insights = [
            "Mercury's dance with Neptune creates a veil of mystery. Trust your intuition over logic today.",
            "The Moon in \(chart.moonSign.rawValue) harmonizes with your natal Sun. Emotional clarity emerges.",
            "Venus whispers secrets about what you truly value. Listen to your heart's quiet wisdom.",
            "Mars activates your house of transformation. Old patterns are ready to be released.",
            "Jupiter's benefic gaze brings unexpected opportunities. Say yes to what expands you.",
            "Saturn asks for patience. What feels like delay is actually divine timing.",
            "The cosmos aligns to support your authentic expression. Your uniqueness is your gift."
        ]
        
        // Select based on current date to have consistency
        let dayOfYear = Calendar.current.ordinateOfDay(for: Date()) ?? 1
        let index = dayOfYear % insights.count
        
        return insights[index]
    }
    
    // MARK: - Helper Methods
    private func createMockPlanet(_ name: String, _ symbol: String, offset: Double) -> CelestialBody {
        let basePosition = Double(Calendar.current.ordinateOfDay(for: Date()) ?? 1) - 80
        return CelestialBody(
            name: name,
            symbol: symbol,
            longitude: normalizeAngle(basePosition + offset),
            latitude: Double.random(in: -5...5),
            distance: Double.random(in: 0.5...30),
            speedLongitude: Double.random(in: 0.1...2.0)
        )
    }
    
    private func normalizeAngle(_ angle: Double) -> Double {
        var normalized = angle.truncatingRemainder(dividingBy: 360)
        if normalized < 0 { normalized += 360 }
        return normalized
    }
    
    private func getHourAngle(from date: Date) -> Double {
        let calendar = Calendar.current
        let hour = Double(calendar.component(.hour, from: date))
        let minute = Double(calendar.component(.minute, from: date))
        let totalHours = hour + (minute / 60)
        
        // Each hour represents 15 degrees (360/24)
        return totalHours * 15
    }
}

// Extension to make Calendar work
extension Calendar {
    func ordinateOfDay(for date: Date) -> Int? {
        let year = component(.year, from: date)
        guard let startOfYear = self.date(from: DateComponents(year: year, month: 1, day: 1)) else { return nil }
        let days = dateComponents([.day], from: startOfYear, to: date).day ?? 0
        return days + 1
    }
}