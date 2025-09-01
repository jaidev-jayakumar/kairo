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
        // Generate accurate, deterministic insights based on actual astrological transits
        let transits = calculateCurrentTransits()
        let sunSign = chart.sunSign
        let moonSign = chart.moonSign
        
        if let moonTransit = transits.first(where: { $0.name == "Moon" }) {
            let currentMoonSign = moonTransit.position.sign
            
            // Calculate deterministic insight based on actual aspect between Moon and Sun
            let aspectAngle = abs(moonTransit.longitude - chart.sun.longitude)
            let normalizedAspect = aspectAngle > 180 ? 360 - aspectAngle : aspectAngle
            
            // Generate insight based on actual astrological relationship
            return generateAspectBasedInsight(
                natalSun: sunSign,
                natalMoon: moonSign,
                transitMoon: currentMoonSign,
                aspectDegrees: normalizedAspect
            )
        }
        
        // When no moon transit available, use deterministic natal insight
        return generateDeterministicNatalInsight(sunSign: sunSign, moonSign: moonSign)
    }
    
    private func generateAspectBasedInsight(natalSun: ZodiacSign, natalMoon: ZodiacSign, transitMoon: ZodiacSign, aspectDegrees: Double) -> String {
        // Generate deterministic insight based on actual aspect degrees
        switch aspectDegrees {
        case 0...8: // Conjunction
            return "Your emotions and identity are perfectly aligned today. Your \(natalSun.rawValue) nature and current \(transitMoon.rawValue) feelings are working as one. Trust this inner unity."
            
        case 52...68: // Sextile  
            return "A subtle opportunity is available today. Your \(natalSun.rawValue) instincts and current \(transitMoon.rawValue) emotional climate are offering you a chance to blend your strengths. Pay attention to gentle nudges."
            
        case 82...98: // Square
            return "There's creative tension between your \(natalSun.rawValue) identity and current \(transitMoon.rawValue) emotions. This friction is actually pushing you to integrate different parts of yourself."
            
        case 112...128: // Trine
            return "Today flows naturally for you. Your \(natalSun.rawValue) energy and \(transitMoon.rawValue) emotions are in perfect harmony, making everything feel effortless."
            
        case 172...188: // Opposition
            return "Today asks you to balance two sides of yourself. Your \(natalSun.rawValue) nature wants one thing while your emotions crave another. The key is honoring both."
            
        default: // No major aspect
            let moonInfluence = getMoonSignDailyInfluence(transitMoon)
            let personalResponse = getPersonalResponseToMoon(natalSun, natalMoon, transitMoon)
            return "The Moon in \(transitMoon.rawValue) \(moonInfluence). For you as a \(natalSun.rawValue) with \(natalMoon.rawValue) Moon, \(personalResponse)."
        }
    }
    
    private func generateDeterministicNatalInsight(sunSign: ZodiacSign, moonSign: ZodiacSign) -> String {
        // When no transits available, use day of month to deterministically select insight
        let dayNumber = Calendar.current.component(.day, from: Date())
        let insights = [
            "Your \(sunSign.rawValue) nature and \(moonSign.rawValue) emotions create a unique blend that's especially highlighted today.",
            "The tension between your \(sunSign.rawValue) identity and \(moonSign.rawValue) feelings is actually your greatest source of creativity.",
            "Today highlights the beautiful complexity of being a \(sunSign.rawValue) with a \(moonSign.rawValue) emotional nature.",
            "Your \(sunSign.rawValue) drive combined with \(moonSign.rawValue) intuition gives you a special kind of wisdom today."
        ]
        
        // Use day of month to deterministically select insight (not random!)
        let index = (dayNumber - 1) % insights.count
        return insights[index]
    }
    
    private func generateCoStarStyleInsights(sunSign: ZodiacSign, moonSign: ZodiacSign, currentMoon: ZodiacSign) -> [String] {
        var insights: [String] = []
        
        // Moon-sign specific insights
        switch currentMoon {
        case .aries:
            insights.append("Your impatience today is actually intuition in disguise.")
            insights.append("The thing you want to start right now? That's your soul talking.")
            insights.append("Anger is just passion wearing a disguise. What's it really about?")
            
        case .taurus:
            insights.append("Slow down. Your body is trying to teach your brain something.")
            insights.append("Today's craving for comfort isn't weakness - it's wisdom.")
            insights.append("The pleasure you're denying yourself is probably exactly what you need.")
            
        case .gemini:
            insights.append("That conversation you keep avoiding? It's time.")
            insights.append("Your scattered thoughts are actually connecting dots you couldn't see before.")
            insights.append("Stop explaining yourself to people who are determined to misunderstand you.")
            
        case .cancer:
            insights.append("Vulnerability isn't weakness when it's a choice.")
            insights.append("That feeling of homesickness? You're missing a version of yourself.")
            insights.append("Your sensitivity is picking up on something everyone else is missing.")
            
        case .leo:
            insights.append("The spotlight you crave is already on you - you just can't see it yet.")
            insights.append("Your need to be seen conflicts with your fear of being truly known.")
            insights.append("Today you realize that confidence isn't the absence of doubt - it's dancing with it.")
            
        case .virgo:
            insights.append("Perfectionism is just fear wearing a productive mask.")
            insights.append("The thing you're nitpicking isn't really the problem.")
            insights.append("Sometimes 'good enough' is actually perfect timing.")
            
        case .libra:
            insights.append("Your people-pleasing is really self-preservation in disguise.")
            insights.append("The decision you're avoiding is already made - you just need to admit it.")
            insights.append("Balance isn't about being in the middle - it's about knowing when to tip the scales.")
            
        case .scorpio:
            insights.append("What you think is paranoia is actually pattern recognition.")
            insights.append("The intensity you're feeling isn't too much - the world is just too small.")
            insights.append("That thing you're hiding? Everyone already knows. The secret is how you feel about it.")
            
        case .sagittarius:
            insights.append("Your restlessness is your compass pointing toward growth.")
            insights.append("The truth you're avoiding is the adventure you've been looking for.")
            insights.append("Freedom isn't about having no commitments - it's about choosing the right ones.")
            
        case .capricorn:
            insights.append("Your ambition is really just love wearing a business suit.")
            insights.append("The goal you're chasing is actually chasing you back.")
            insights.append("Sometimes the mountain climbs you more than you climb it.")
            
        case .aquarius:
            insights.append("Your need to be different conflicts with your need to belong.")
            insights.append("The revolution you're planning starts with the person in the mirror.")
            insights.append("Your weirdness is actually your superpower in disguise.")
            
        case .pisces:
            insights.append("Your emotions aren't drowning you - they're teaching you to swim.")
            insights.append("That dream you had? It wasn't random.")
            insights.append("Your empathy is a gift, not a burden - but boundaries are still necessary.")
        }
        
        // Add some sun-moon combination insights
        if sunSign.element != moonSign.element {
            insights.append("The tension between your \(sunSign.rawValue) self and \(moonSign.rawValue) feelings is actually creating something new.")
            insights.append("Your head says \(getSunDesire(sunSign)), but your heart needs \(getMoonNeed(moonSign)). Both are right.")
        }
        
        return insights
    }
    
    private func getSunDesire(_ sign: ZodiacSign) -> String {
        switch sign {
        case .aries: return "action"
        case .taurus: return "stability"
        case .gemini: return "variety"
        case .cancer: return "security"
        case .leo: return "recognition"
        case .virgo: return "perfection"
        case .libra: return "harmony"
        case .scorpio: return "truth"
        case .sagittarius: return "freedom"
        case .capricorn: return "success"
        case .aquarius: return "innovation"
        case .pisces: return "connection"
        }
    }
    
    private func getMoonNeed(_ sign: ZodiacSign) -> String {
        switch sign {
        case .aries: return "excitement"
        case .taurus: return "comfort"
        case .gemini: return "stimulation"
        case .cancer: return "nurturing"
        case .leo: return "appreciation"
        case .virgo: return "order"
        case .libra: return "peace"
        case .scorpio: return "depth"
        case .sagittarius: return "adventure"
        case .capricorn: return "structure"
        case .aquarius: return "independence"
        case .pisces: return "understanding"
        }
    }
    
    // MARK: - Weekly Insights (AI-Powered)
    func generateWeeklyInsight(for chart: BirthChart) async -> String {
        let transits = calculateCurrentTransits()
        return await AIInsightService.shared.generateWeeklyInsight(for: chart, transits: transits)
    }
    
    // MARK: - Astrological Helper Functions
    
    private func getMoonSignDailyInfluence(_ sign: ZodiacSign) -> String {
        switch sign {
        case .aries: return "brings impulsive energy and the urge for new beginnings"
        case .taurus: return "encourages slowing down and appreciating simple pleasures"
        case .gemini: return "sparks curiosity and the need for mental stimulation"
        case .cancer: return "heightens emotions and the desire for security"
        case .leo: return "amplifies creativity and the need for recognition"
        case .virgo: return "focuses attention on details and improvement"
        case .libra: return "emphasizes relationships and the search for balance"
        case .scorpio: return "intensifies emotions and the desire for transformation"
        case .sagittarius: return "inspires adventure and philosophical thinking"
        case .capricorn: return "brings focus to goals and long-term planning"
        case .aquarius: return "encourages innovation and humanitarian thinking"
        case .pisces: return "enhances intuition and emotional sensitivity"
        }
    }
    
    private func getPersonalResponseToMoon(_ natalSun: ZodiacSign, _ natalMoon: ZodiacSign, _ transitMoon: ZodiacSign) -> String {
        if transitMoon == natalSun {
            return "this energy feels natural and amplifies your core identity"
        } else if transitMoon == natalMoon {
            return "you're feeling extra emotional and in tune with your inner world"
        } else if transitMoon.element == natalSun.element {
            return "this energy supports and enhances your natural \(natalSun.rawValue) qualities"
        } else if transitMoon.element == natalMoon.element {
            return "your emotional patterns are heightened and familiar"
        } else {
            return "this brings a different flavor to your usual emotional experience"
        }
    }
    
}