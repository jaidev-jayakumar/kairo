import Foundation
import SwissEphemeris

class AstrologyService {
    static let shared = AstrologyService()
    
    // CRITICAL: SwissEphemeris is NOT thread-safe! Must serialize all access
    private let ephemerisQueue = DispatchQueue(label: "com.kairo.swissephemeris", qos: .userInitiated)
    
    // Cache for horoscope scores
    private var cachedDailyScores: HoroscopeScores?
    private var cachedWeeklyScores: HoroscopeScores?
    private var cachedMonthlyScores: HoroscopeScores?
    private var cachedYearlyScores: HoroscopeScores?
    
    private init() {
        // Initialize Swiss Ephemeris with default path
        // The package will use its internal ephemeris data
        JPLFileManager.setEphemerisPath()
    }
    
    
    // MARK: - Safe Array Access Helpers
    /// Safely access a house cusp by number (1-12)
    private func getHouseCusp(from chart: BirthChart, house: Int) -> Double? {
        guard house >= 1 && house <= 12, house <= chart.houses.count else {
            print("⚠️ Warning: Attempted to access house \(house) but only \(chart.houses.count) houses available")
            return nil
        }
        return chart.houses[house - 1].cusp
    }
    // MARK: - Birth Chart Calculation
    func calculateBirthChart(for birthData: BirthData) -> BirthChart? {
        print("🌟 Using SwissEphemeris for professional birth chart calculation")
        
        // Use the birth date directly - it's already correctly stored as the exact moment in time
        let utcDate = birthData.date
        
        print("📅 Birth time: \(birthData.date) in \(birthData.timeZone.identifier)")
        print("📅 UTC time for ephemeris: \(utcDate)")
        print("🌍 Location: lat=\(birthData.latitude), lng=\(birthData.longitude), location=\(birthData.locationName ?? "Unknown")")
        
        // Calculate planets using SwissEphemeris
        guard let sun = calculatePlanet(.sun, date: utcDate),
              let moon = calculatePlanet(.moon, date: utcDate),
              let mercury = calculatePlanet(.mercury, date: utcDate),
              let venus = calculatePlanet(.venus, date: utcDate),
              let mars = calculatePlanet(.mars, date: utcDate),
              let jupiter = calculatePlanet(.jupiter, date: utcDate),
              let saturn = calculatePlanet(.saturn, date: utcDate),
              let uranus = calculatePlanet(.uranus, date: utcDate),
              let neptune = calculatePlanet(.neptune, date: utcDate),
              let pluto = calculatePlanet(.pluto, date: utcDate) else {
            // Fallback to simplified service if SwissEphemeris fails
            print("SwissEphemeris calculation failed, falling back to simplified service")
            return SimplifiedAstrologyService.shared.calculateBirthChart(for: birthData)
        }
        
        // Calculate houses - CRITICAL: Serialize access to SwissEphemeris
        return ephemerisQueue.sync {
            do {
                let houseCusps = try HouseCusps(
                    date: utcDate,
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
    }
    
    // MARK: - Planet Calculation
    private func calculatePlanet(_ planet: SwissEphemeris.Planet, date: Date) -> CelestialBody? {
        // CRITICAL: Serialize access to SwissEphemeris (C library is not thread-safe)
        return ephemerisQueue.sync {
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
    }
    
    // MARK: - Transit Calculations
    func calculatePlanetPositionAt(planet: SwissEphemeris.Planet, date: Date) -> CelestialBody? {
        return calculatePlanet(planet, date: date)
    }
    
    func calculateCurrentTransits(for date: Date = Date()) -> [CelestialBody] {
        print("🌍 Using SwissEphemeris for planetary transits on \(date)")
        let planets: [SwissEphemeris.Planet] = [.sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune, .pluto]
        
        let transits = planets.compactMap { calculatePlanet($0, date: date) }
        
        // If SwissEphemeris fails, fallback to simplified service
        if transits.isEmpty {
            print("SwissEphemeris transit calculation failed, falling back to simplified service")
            return SimplifiedAstrologyService.shared.calculateCurrentTransits()
        }
        
        print("✅ SwissEphemeris transit calculations completed for \(date)!")
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
        // Generate provocative, Co-Star style insights based on actual aspects
        switch aspectDegrees {
        case 0...8: // Conjunction
            return getConjunctionInsight(natalSun: natalSun, transitMoon: transitMoon)
            
        case 52...68: // Sextile  
            return getSextileInsight(natalSun: natalSun, transitMoon: transitMoon)
            
        case 82...98: // Square
            return getSquareInsight(natalSun: natalSun, transitMoon: transitMoon)
            
        case 112...128: // Trine
            return getTrineInsight(natalSun: natalSun, transitMoon: transitMoon)
            
        case 172...188: // Opposition
            return getOppositionInsight(natalSun: natalSun, transitMoon: transitMoon)
            
        default: // No major aspect
            return getNoAspectInsight(natalSun: natalSun, natalMoon: natalMoon, transitMoon: transitMoon)
        }
    }
    
    private func getConjunctionInsight(natalSun: ZodiacSign, transitMoon: ZodiacSign) -> String {
        // Moon conjunct Sun - New Moon energy, fresh starts, alignment of conscious and unconscious
        return "Moon Conjunction Sun: A powerful new beginning is emerging in your life. This conjunction represents the perfect alignment between your conscious identity (\(natalSun.rawValue)) and your emotional needs. You're experiencing a rare moment of inner unity where what you want and what you feel are completely synchronized. This is an excellent time to set intentions, start new projects, or make important decisions because your head and heart are speaking the same language. Your intuition is especially strong, providing clear guidance about your next steps. You may feel more emotionally centered and self-aware than usual. Pay attention to insights that arise naturally - they're coming from your deepest wisdom. This energy supports authentic self-expression and genuine connections with others. Trust that what feels right emotionally is also what serves your highest good. New opportunities that align with your true nature are likely to present themselves. Take action on what genuinely excites you."
    }
    
    private func getSquareInsight(natalSun: ZodiacSign, transitMoon: ZodiacSign) -> String {
        // Moon square Sun - Creative tension, growth through challenge
        return "Moon Square Sun: You're experiencing dynamic tension between your core identity (\(natalSun.rawValue)) and your current emotional state. This challenging aspect creates friction that, while uncomfortable, is essential for growth and development. You may feel pulled in different directions - what your mind thinks is best versus what your emotions are telling you. This inner conflict isn't a problem to be solved but rather creative energy to be harnessed. The pressure you're feeling is actually building strength and resilience. This is an excellent time for breakthrough thinking and innovative solutions to long-standing problems. Your emotional responses may seem at odds with your rational mind, but both contain important truths. Instead of choosing one over the other, look for ways to integrate these different aspects of yourself. This tension often leads to important realizations about your authentic needs and desires. Physical exercise or creative expression can help channel this dynamic energy constructively. Expect some emotional ups and downs, but trust that this process is refining your character and clarifying your true priorities."
    }
    
    private func getTrineInsight(natalSun: ZodiacSign, transitMoon: ZodiacSign) -> String {
        // Moon trine Sun - Harmonious flow, natural talents activated
        return "Moon Trine Sun: This harmonious aspect brings a sense of ease and natural flow to your day. Your \(natalSun.rawValue) identity and current emotional state are working in perfect cooperation, creating conditions for effortless progress and genuine satisfaction. You're likely to feel more confident, optimistic, and emotionally balanced than usual. This supportive energy enhances your natural talents and makes it easier to express your authentic self without resistance. Creative endeavors, social connections, and personal projects benefit from this flowing energy. Others are drawn to your positive presence and may offer support or opportunities. Trust your instincts - they're aligned with your highest good right now. This is an excellent time for collaborative efforts, as you can easily harmonize with others while maintaining your individual identity. Your emotional intelligence is heightened, helping you navigate relationships with grace and understanding. Take advantage of this supportive energy to move forward on important goals or to simply enjoy a sense of inner peace and contentment."
    }
    
    private func getOppositionInsight(natalSun: ZodiacSign, transitMoon: ZodiacSign) -> String {
        // Moon opposition Sun - Full Moon energy, culmination, conscious awareness of patterns
        return "Moon Opposition Sun: This aspect represents a culmination point where opposing forces in your life come into clear focus. Your \(natalSun.rawValue) conscious identity is directly facing your emotional needs and subconscious patterns. This can create tension, but it also brings valuable awareness about internal contradictions that need resolution. You may feel torn between what you think you should do and what you emotionally want to do. This is actually an opportunity to find a more authentic balance between these different aspects of yourself. Relationships may reflect this internal tension - others might mirror back parts of yourself you're not fully acknowledging. Pay attention to what irritates or attracts you in others right now, as it often reveals something important about your own psyche. This energy supports bringing unconscious patterns into conscious awareness. It's a powerful time for emotional releases, important conversations, or major realizations about your life direction. The goal isn't to eliminate the tension but to find a higher synthesis that honors both sides of the equation."
    }
    
    private func getSextileInsight(natalSun: ZodiacSign, transitMoon: ZodiacSign) -> String {
        // Moon sextile Sun - Supportive opportunities, gentle growth
        return "Moon Sextile Sun: This supportive aspect creates gentle opportunities for growth and positive change. Your \(natalSun.rawValue) identity and current emotional state are working cooperatively, though with a bit more effort required than a trine. You're in a good position to take productive action toward your goals, especially those that involve both practical planning and emotional fulfillment. This energy supports learning, communication, and building bridges between different areas of your life. You may find it easier to express your feelings clearly or to understand others' emotional needs. Small but significant opportunities may present themselves - pay attention to subtle invitations or openings that could lead to meaningful developments. Your social connections are highlighted, with potential for making new friendships or strengthening existing relationships. This is an excellent time for constructive conversations, creative collaborations, or taking modest steps toward important goals. While not as intense as other aspects, this gentle support helps you move forward with confidence and emotional clarity."
    }
    
    private func getNoAspectInsight(natalSun: ZodiacSign, natalMoon: ZodiacSign, transitMoon: ZodiacSign) -> String {
        // No major aspect - focus on moon sign influence
        if transitMoon == natalSun {
            return "Today amplifies everything that makes you, you. Lean into your \(natalSun.rawValue) nature - but maybe tone it down like 10%."
        } else if transitMoon == natalMoon {
            return "Your \(natalMoon.rawValue) Moon is having a moment today. Pay attention to what your gut is trying to tell your brain."
        } else {
            return getMoonSpecificInsight(transitMoon)
        }
    }
    
    private func getMoonSpecificInsight(_ moonSign: ZodiacSign) -> String {
        // Generate detailed, comprehensive insights like the reference app
        switch moonSign {
        case .aries:
            return "The Moon in Aries activates your initiative and courage today. You may feel an urgent need to start new projects or take decisive action on matters you've been postponing. This impulsive energy can lead to breakthrough moments, but be mindful of rushing into situations without proper planning. Your leadership qualities are heightened, making this an excellent time to take charge of group situations or advocate for yourself. However, avoid making major decisions when emotions are running high. Channel this dynamic energy into physical activities or creative pursuits. Trust your first instincts today - they're likely more accurate than overthinking would be."
            
        case .taurus:
            return "With the Moon in Taurus, you're craving stability and comfort in all areas of life. This is a powerful time for grounding yourself and focusing on practical matters that bring long-term security. Your senses are heightened, making it an ideal day for enjoying good food, beautiful surroundings, or tactile experiences. You may feel more stubborn than usual, but this isn't necessarily negative - it's your inner wisdom protecting you from unnecessary changes. Focus on building rather than destroying today. Financial matters and material possessions may demand your attention. Take time to appreciate what you already have before seeking more. Your patience and persistence will pay off in tangible ways."
            
        case .gemini:
            return "The Moon in Gemini stimulates your curiosity and desire for mental stimulation. Communication takes center stage today - you'll find yourself more talkative, inquisitive, and eager to share ideas. This is an excellent time for learning, writing, or engaging in meaningful conversations that expand your perspective. However, you may feel scattered or unable to focus on one thing for long. Embrace this versatility rather than fighting it. Multiple projects or interests can coexist productively. Pay attention to the information coming your way through various channels - social media, conversations, books, or news may contain important insights. Your adaptability is your superpower today."
            
        case .cancer:
            return "The Moon in Cancer heightens your emotional sensitivity and intuitive abilities. You may find yourself more protective of loved ones and drawn to nurturing activities. Home and family matters take priority, and you might feel the urge to create a cozy, secure environment. Trust your emotional responses today - they're providing valuable information about people and situations. You may experience mood swings, but these fluctuations are helping you process important feelings. This is an excellent time for self-care, cooking, or engaging in activities that make you feel emotionally fulfilled. Don't apologize for needing more emotional support than usual - it's perfectly natural during this transit."
            
        case .leo:
            return "The Moon in Leo amplifies your need for recognition, creativity, and self-expression. You're feeling more dramatic and confident, with a natural magnetism that draws others to you. This is an ideal time for creative projects, performances, or any activities that allow you to shine. Your generous spirit is highlighted, making you want to share your talents and resources with others. However, be aware of ego-driven reactions if you don't receive the attention you're seeking. Focus on expressing yourself authentically rather than performing for validation. Children or youthful energy may play an important role today. Your heart is your guide - follow what genuinely excites and inspires you."
            
        case .virgo:
            return "The Moon in Virgo activates your analytical mind and desire for improvement. You'll feel compelled to organize, analyze, and perfect various aspects of your life. This practical energy is excellent for tackling detailed work, health matters, or service-oriented activities. You may be more critical than usual - both of yourself and others - but this discernment can lead to valuable improvements. Pay attention to your body's needs and daily routines. Small adjustments to your habits can have significant long-term benefits. Your helpful nature is highlighted, making this a good time to assist others or engage in meaningful work. Don't let perfectionist tendencies paralyze you - progress is more important than perfection."
            
        case .libra:
            return "The Moon in Libra emphasizes relationships, balance, and aesthetic harmony. You're seeking fairness and beauty in all interactions today, with a heightened sensitivity to discord or imbalance. Partnership matters - both romantic and business - may require your attention. Your diplomatic skills are enhanced, making you an excellent mediator in conflicts. However, you might struggle with decision-making as you weigh all options carefully. Trust that the 'right' choice often becomes clear when you consider what serves the highest good for all involved. Surround yourself with beauty, whether through art, music, or harmonious environments. Your charm and social grace are particularly powerful today."
            
        case .scorpio:
            return "The Moon in Scorpio intensifies your emotional depth and desire for authentic connection. You're not interested in surface-level interactions today - you want to dig deeper and uncover hidden truths. This powerful energy can facilitate transformation and healing, but it may also bring up intense emotions or psychological material that needs processing. Trust your instincts about people and situations - your psychological radar is especially accurate. This is an excellent time for research, investigation, or any work that requires penetrating insight. Intimate relationships may reach new levels of honesty and connection. Don't shy away from difficult conversations if they lead to greater understanding."
            
        case .sagittarius:
            return "The Moon in Sagittarius ignites your adventurous spirit and philosophical nature. You're seeking meaning, truth, and expansion in all forms today. This restless energy may manifest as wanderlust, a desire to learn about different cultures, or engagement with higher education or spiritual practices. Your optimism is contagious, inspiring others to think bigger and aim higher. However, you may feel confined by routine or small-minded thinking. Seek opportunities to broaden your horizons - whether through travel, learning, or connecting with people from different backgrounds. Your wisdom and experience are valuable to others. Share your insights generously, but avoid being preachy or dogmatic."
            
        case .capricorn:
            return "The Moon in Capricorn activates your ambition and desire for achievement. You're feeling more serious and goal-oriented, with a natural inclination toward leadership and responsibility. This is an excellent time for career advancement, long-term planning, or building something of lasting value. Your discipline and persistence are highlighted, making complex projects more manageable. However, don't let ambition overshadow your emotional needs or relationships. Authority figures may play an important role today - either as mentors or challenges to overcome. Your reputation and public image are particularly important now. Make choices that reflect your highest integrity and long-term vision."
            
        case .aquarius:
            return "The Moon in Aquarius emphasizes your individuality and desire for freedom. You're feeling more innovative and forward-thinking, with ideas that may seem unusual to others but are actually ahead of their time. Group activities, friendships, and humanitarian causes may capture your interest. This is an excellent time for networking, joining communities of like-minded individuals, or working toward social change. Your unique perspective is valuable - don't suppress it to fit in. Technology may play an important role in your day. You might feel emotionally detached, but this objectivity allows you to see situations more clearly and make decisions based on logic rather than emotion."
            
        case .pisces:
            return "The Moon in Pisces heightens your intuition, empathy, and creative imagination. You're more sensitive to the emotional undercurrents around you, picking up on feelings and energies that others might miss. This psychic sensitivity can be both a gift and a challenge - trust your intuitive insights while protecting yourself from absorbing negative emotions. Creative and spiritual activities are especially fulfilling today. Dreams, meditation, and artistic expression can provide important guidance. You may feel more compassionate and willing to help others, but be careful not to sacrifice your own wellbeing in the process. Water, music, and quiet reflection will help you recharge and process your experiences."
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
    func generateWeeklyInsight(for chart: BirthChart, date: Date = Date()) async -> String {
        let transits = calculateCurrentTransits(for: date)
        return await AIInsightService.shared.generateWeeklyInsight(for: chart, transits: transits, date: date)
    }
    
    // MARK: - Monthly Insights (AI-Powered)
    func generateMonthlyInsight(for chart: BirthChart, date: Date = Date()) async -> String {
        let transits = calculateCurrentTransits(for: date)
        return await AIInsightService.shared.generateMonthlyInsight(for: chart, transits: transits, date: date)
    }
    
    // MARK: - Yearly Insights (AI-Powered)
    func generateYearlyInsight(for chart: BirthChart, date: Date = Date()) async -> String {
        let transits = calculateCurrentTransits(for: date)
        return await AIInsightService.shared.generateYearlyInsight(for: chart, transits: transits, date: date)
    }
    
    // MARK: - Cycle Insights (AI-Powered)
    func generateCycleInsight(for chart: BirthChart) async -> String {
        let cycles = calculateCurrentCycles(for: chart)
        return await AIInsightService.shared.generateCycleInsight(for: cycles, chart: chart)
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
    
    // MARK: - Cache Management
    private func isDailyScoresValid(for date: Date) -> Bool {
        guard let cachedScores = cachedDailyScores else { return false }
        return Calendar.current.isDate(cachedScores.date, inSameDayAs: date)
    }
    
    private func isWeeklyScoresValid(for date: Date) -> Bool {
        guard let cachedScores = cachedWeeklyScores else { return false }
        let calendar = Calendar.current
        return calendar.component(.weekOfYear, from: cachedScores.date) == calendar.component(.weekOfYear, from: date) &&
               calendar.component(.year, from: cachedScores.date) == calendar.component(.year, from: date)
    }
    
    private func isMonthlyScoresValid(for date: Date) -> Bool {
        guard let cachedScores = cachedMonthlyScores else { return false }
        let calendar = Calendar.current
        return calendar.component(.month, from: cachedScores.date) == calendar.component(.month, from: date) &&
               calendar.component(.year, from: cachedScores.date) == calendar.component(.year, from: date)
    }
    
    private func isYearlyScoresValid(for date: Date) -> Bool {
        guard let cachedScores = cachedYearlyScores else { return false }
        return Calendar.current.component(.year, from: cachedScores.date) == Calendar.current.component(.year, from: date)
    }
    
    // MARK: - Horoscope Scores Calculation
    func calculateDailyHoroscopeScores(for chart: BirthChart, date: Date = Date()) -> HoroscopeScores {
        // Check cache first
        if isDailyScoresValid(for: date), let cachedScores = cachedDailyScores {
            print("📱 Using cached daily horoscope scores for \(date)")
            return cachedScores
        }
        
        print("🎯 Calculating NEW daily horoscope scores for \(date) using birth chart and current transits")
        let transits = calculateCurrentTransits(for: date)
        let aspects = calculateAspects(for: chart)
        
        // Calculate each specific life area score
        let loveScore = calculateDailyLoveScore(chart: chart, transits: transits, aspects: aspects, date: date)
        let careerScore = calculateDailyCareerScore(chart: chart, transits: transits, aspects: aspects, date: date)
        let wealthScore = calculateDailyWealthScore(chart: chart, transits: transits, aspects: aspects, date: date)
        
        // Overall is the average of life areas - ensures logical consistency
        let overallScore = Int(round(Double(loveScore + careerScore + wealthScore) / 3.0))
        
        let scores = HoroscopeScores(
            overall: overallScore,
            love: loveScore,
            career: careerScore,
            wealth: wealthScore,
            date: date
        )
        
        // Cache the results
        cachedDailyScores = scores
        return scores
    }
    
    func calculateWeeklyHoroscopeScores(for chart: BirthChart, date: Date = Date()) -> HoroscopeScores {
        // Check cache first
        if isWeeklyScoresValid(for: date), let cachedScores = cachedWeeklyScores {
            print("📱 Using cached weekly horoscope scores for \(date)")
            return cachedScores
        }
        
        print("📅 Calculating NEW weekly horoscope scores for \(date) using birth chart and week-ahead transits")
        let transits = calculateCurrentTransits(for: date)
        let aspects = calculateAspects(for: chart)
        
        // Calculate each specific life area score
        let loveScore = calculateWeeklyLoveScore(chart: chart, transits: transits, aspects: aspects, date: date)
        let careerScore = calculateWeeklyCareerScore(chart: chart, transits: transits, aspects: aspects, date: date)
        let wealthScore = calculateWeeklyWealthScore(chart: chart, transits: transits, aspects: aspects, date: date)
        
        // Overall is the average of life areas - ensures logical consistency
        let overallScore = Int(round(Double(loveScore + careerScore + wealthScore) / 3.0))
        
        let scores = HoroscopeScores(
            overall: overallScore,
            love: loveScore,
            career: careerScore,
            wealth: wealthScore,
            date: date
        )
        
        // Cache the results
        cachedWeeklyScores = scores
        return scores
    }
    
    func calculateMonthlyHoroscopeScores(for chart: BirthChart, date: Date = Date()) -> HoroscopeScores {
        // Check cache first
        if isMonthlyScoresValid(for: date), let cachedScores = cachedMonthlyScores {
            print("📱 Using cached monthly horoscope scores for \(date)")
            return cachedScores
        }
        
        print("📅 Calculating NEW monthly horoscope scores for \(date) using birth chart and month-ahead transits")
        let transits = calculateCurrentTransits(for: date)
        let aspects = calculateAspects(for: chart)
        
        // Calculate each specific life area score
        let loveScore = calculateMonthlyLoveScore(chart: chart, transits: transits, aspects: aspects, date: date)
        let careerScore = calculateMonthlyCareerScore(chart: chart, transits: transits, aspects: aspects, date: date)
        let wealthScore = calculateMonthlyWealthScore(chart: chart, transits: transits, aspects: aspects, date: date)
        
        // Overall should be the weighted average of life areas - not a separate calculation
        // This ensures logical consistency (if Love/Career/Wealth are high, Overall is high)
        let overallScore = Int(round(Double(loveScore + careerScore + wealthScore) / 3.0))
        
        let scores = HoroscopeScores(
            overall: overallScore,
            love: loveScore,
            career: careerScore,
            wealth: wealthScore,
            date: date
        )
        
        // Cache the results
        cachedMonthlyScores = scores
        return scores
    }
    
    func calculateYearlyHoroscopeScores(for chart: BirthChart, date: Date = Date()) -> HoroscopeScores {
        // Check cache first
        if isYearlyScoresValid(for: date), let cachedScores = cachedYearlyScores {
            print("📱 Using cached yearly horoscope scores for \(date)")
            return cachedScores
        }
        
        print("📅 Calculating NEW yearly horoscope scores for \(date) using birth chart and year-ahead transits")
        let transits = calculateCurrentTransits(for: date)
        let aspects = calculateAspects(for: chart)
        
        // Calculate each specific life area score
        let loveScore = calculateYearlyLoveScore(chart: chart, transits: transits, aspects: aspects, date: date)
        let careerScore = calculateYearlyCareerScore(chart: chart, transits: transits, aspects: aspects, date: date)
        let wealthScore = calculateYearlyWealthScore(chart: chart, transits: transits, aspects: aspects, date: date)
        
        // Overall is the average of life areas - ensures logical consistency
        let overallScore = Int(round(Double(loveScore + careerScore + wealthScore) / 3.0))
        
        let scores = HoroscopeScores(
            overall: overallScore,
            love: loveScore,
            career: careerScore,
            wealth: wealthScore,
            date: date
        )
        
        // Cache the results
        cachedYearlyScores = scores
        return scores
    }
    
    private func calculateDailyOverallScore(chart: BirthChart, transits: [CelestialBody], aspects: [Aspect], date: Date) -> Int {
        var score = 55 // Slightly optimistic baseline - everyone starts with decent energy
        
        // === NATAL CHART FOUNDATION (affects baseline) ===
        let sunMoonAngle = abs(chart.sun.longitude - chart.moon.longitude)
        let normalizedSunMoon = sunMoonAngle > 180 ? 360 - sunMoonAngle : sunMoonAngle
        
        // Natal sun-moon aspect sets your general life harmony
        if normalizedSunMoon < 8 { // Conjunction - unified personality
            score += 15
        } else if (112...128).contains(normalizedSunMoon) { // Trine - natural harmony
            score += 18
        } else if (52...68).contains(normalizedSunMoon) { // Sextile - cooperative energy
            score += 12
        } else if (82...98).contains(normalizedSunMoon) { // Square - creative tension
            score -= 3 // Less harsh
        } else if (172...188).contains(normalizedSunMoon) { // Opposition - internal polarity
            score -= 5 // Less harsh
        } else {
            // No major aspect - still add something for baseline personality
            score += 5
        }
        
        // === MAJOR TRANSITS (can dramatically shift scores) ===
        
        // Saturn transits - lessons, restrictions, achievements
        if let saturnTransit = transits.first(where: { $0.name == "Saturn" }) {
            let saturnToSun = abs(saturnTransit.longitude - chart.sun.longitude)
            let normalizedSaturn = saturnToSun > 180 ? 360 - saturnToSun : saturnToSun
            
            if normalizedSaturn < 8 { // Saturn return or conjunction - major life restructuring
                score -= 15 // Intense pressure but builds character
            } else if (82...98).contains(normalizedSaturn) { // Square - obstacles and tests
                score -= 20 // Most challenging aspect
            } else if (172...188).contains(normalizedSaturn) { // Opposition - external pressure
                score -= 12 // Difficult but clarifying
            } else if (112...128).contains(normalizedSaturn) { // Trine - earned rewards
                score += 18 // Well-deserved success
            } else if (52...68).contains(normalizedSaturn) { // Sextile - steady progress
                score += 10
            }
        }
        
        // Jupiter transits - expansion, opportunity, optimism
        if let jupiterTransit = transits.first(where: { $0.name == "Jupiter" }) {
            let jupiterToSun = abs(jupiterTransit.longitude - chart.sun.longitude)
            let normalizedJupiter = jupiterToSun > 180 ? 360 - jupiterToSun : jupiterToSun
            
            if normalizedJupiter < 8 { // Jupiter return - major expansion year
                score += 25 // Peak opportunity
            } else if (112...128).contains(normalizedJupiter) { // Trine - flowing abundance
                score += 20
            } else if (52...68).contains(normalizedJupiter) { // Sextile - growth opportunities
                score += 12
            } else if (82...98).contains(normalizedJupiter) { // Square - overconfidence or legal issues
                score -= 8
            } else if (172...188).contains(normalizedJupiter) { // Opposition - excess or conflicts
                score -= 5
            }
        }
        
        // Mars transits - energy, conflict, action
        if let marsTransit = transits.first(where: { $0.name == "Mars" }) {
            let marsToSun = abs(marsTransit.longitude - chart.sun.longitude)
            let normalizedMars = marsToSun > 180 ? 360 - marsToSun : marsToSun
            
            if normalizedMars < 8 { // Mars return - energy surge
                score += 8
            } else if (82...98).contains(normalizedMars) { // Square - conflicts, accidents
                score -= 15 // Dangerous time, requires caution
            } else if (172...188).contains(normalizedMars) { // Opposition - confrontations
                score -= 10
            } else if (112...128).contains(normalizedMars) { // Trine - productive energy
                score += 12
            }
        }
        
        // Moon transit - daily emotional tone
        if let moonTransit = transits.first(where: { $0.name == "Moon" }) {
            let moonToSun = abs(moonTransit.longitude - chart.sun.longitude)
            let normalizedMoon = moonToSun > 180 ? 360 - moonToSun : moonToSun
            
            if normalizedMoon < 8 { // New Moon energy - fresh starts
                score += 8
            } else if (82...98).contains(normalizedMoon) { // First/Last Quarter - tension
                score -= 3
            } else if (172...188).contains(normalizedMoon) { // Full Moon - heightened emotions
                score += 5
            } else if (112...128).contains(normalizedMoon) { // Waxing/Waning Trine
                score += 6
            }
        }
        
        // === CHALLENGING OUTER PLANET TRANSITS ===
        
        // Uranus transits - sudden changes, breakthroughs, upheaval
        if let uranusTransit = transits.first(where: { $0.name == "Uranus" }) {
            let uranusToSun = abs(uranusTransit.longitude - chart.sun.longitude)
            let normalizedUranus = uranusToSun > 180 ? 360 - uranusToSun : uranusToSun
            
            if normalizedUranus < 8 { // Uranus conjunction - life revolution
                score -= 10 // Chaotic but liberating
            } else if (82...98).contains(normalizedUranus) { // Square - shocking changes
                score -= 18 // Very disruptive
            } else if (172...188).contains(normalizedUranus) { // Opposition - external upheaval
                score -= 12
            } else if (112...128).contains(normalizedUranus) { // Trine - positive breakthroughs
                score += 15
            }
        }
        
        // Neptune transits - confusion, spirituality, illusion
        if let neptuneTransit = transits.first(where: { $0.name == "Neptune" }) {
            let neptuneToSun = abs(neptuneTransit.longitude - chart.sun.longitude)
            let normalizedNeptune = neptuneToSun > 180 ? 360 - neptuneToSun : neptuneToSun
            
            if normalizedNeptune < 8 { // Neptune conjunction - ego dissolution
                score -= 12 // Confusing but spiritually transformative
            } else if (82...98).contains(normalizedNeptune) { // Square - deception, addiction
                score -= 15 // Dangerous illusions
            } else if (112...128).contains(normalizedNeptune) { // Trine - spiritual inspiration
                score += 10
            }
        }
        
        // Pluto transits - death/rebirth, power struggles, transformation
        if let plutoTransit = transits.first(where: { $0.name == "Pluto" }) {
            let plutoToSun = abs(plutoTransit.longitude - chart.sun.longitude)
            let normalizedPluto = plutoToSun > 180 ? 360 - plutoToSun : plutoToSun
            
            if normalizedPluto < 8 { // Pluto conjunction - total life transformation
                score -= 20 // Intense but ultimately regenerative
            } else if (82...98).contains(normalizedPluto) { // Square - power struggles
                score -= 25 // Most difficult transit possible
            } else if (172...188).contains(normalizedPluto) { // Opposition - external power conflicts
                score -= 18
            } else if (112...128).contains(normalizedPluto) { // Trine - empowerment
                score += 15
            }
        }
        
        // === PERSONAL DATE VARIATION ===
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let personalVariation = Int((chart.sun.longitude + Double(dayOfYear * 3)).truncatingRemainder(dividingBy: 14)) - 7
        score += personalVariation
        
        // === REALISTIC SCORING RANGES ===
        return max(5, min(95, score)) // Allow genuinely difficult (5-20) and amazing (85-95) days
    }
    
    private func calculateDailyLoveScore(chart: BirthChart, transits: [CelestialBody], aspects: [Aspect], date: Date) -> Int {
        var score = 55 // Slightly optimistic love baseline - everyone has love potential
        
        // === NATAL LOVE FOUNDATION ===
        
        // Venus sign affects how you love and attract
        let venusSign = chart.venus.position.sign
        if [.libra, .taurus].contains(venusSign) { // Venus ruled signs
            score += 15 // Natural grace in love
        } else if [.pisces, .cancer].contains(venusSign) { // Emotional water signs
            score += 12 // Deep emotional connection ability
        } else if [.leo, .sagittarius].contains(venusSign) { // Passionate fire signs
            score += 10 // Magnetic and enthusiastic
        } else if [.virgo, .capricorn].contains(venusSign) { // Practical earth signs
            score += 5 // Loyal but reserved
        } else if [.scorpio].contains(venusSign) { // Intense water
            score += 8 // Magnetic but complicated
        } else if [.aries, .gemini, .aquarius].contains(venusSign) { // Independent signs
            score += 3 // Loves freedom more than romance
        }
        
        // Venus-Mars natal aspect affects passion and attraction
        let venusMarsAngle = abs(chart.venus.longitude - chart.mars.longitude)
        let normalizedVenusMars = venusMarsAngle > 180 ? 360 - venusMarsAngle : venusMarsAngle
        
        if normalizedVenusMars < 8 { // Conjunction - intense magnetism
            score += 12
        } else if (112...128).contains(normalizedVenusMars) { // Trine - natural charm
            score += 15
        } else if (52...68).contains(normalizedVenusMars) { // Sextile - attractive personality
            score += 10
        } else if (82...98).contains(normalizedVenusMars) { // Square - passionate conflicts
            score -= 5
        } else if (172...188).contains(normalizedVenusMars) { // Opposition - relationship tension
            score -= 8
        }
        
        // === TRANSIT INFLUENCES ON LOVE ===
        
        // Venus transits - relationship planet
        if let venusTransit = transits.first(where: { $0.name == "Venus" }) {
            let venusToNatalVenus = abs(venusTransit.longitude - chart.venus.longitude)
            let normalizedVenusTransit = venusToNatalVenus > 180 ? 360 - venusToNatalVenus : venusToNatalVenus
            
            if normalizedVenusTransit < 8 { // Venus return - renewed love
                score += 20 // Major love renewal
            } else if (112...128).contains(normalizedVenusTransit) { // Trine - flowing love
                score += 15
            } else if (52...68).contains(normalizedVenusTransit) { // Sextile - love opportunities
                score += 12
            } else if (82...98).contains(normalizedVenusTransit) { // Square - relationship tests
                score -= 10
            } else if (172...188).contains(normalizedVenusTransit) { // Opposition - relationship clarity
                score -= 5
            }
            
            // Venus to natal Mars - passion activation
            let venusToNatalMars = abs(venusTransit.longitude - chart.mars.longitude)
            let normalizedVenusToMars = venusToNatalMars > 180 ? 360 - venusToNatalMars : venusToNatalMars
            
            if normalizedVenusToMars < 8 || (112...128).contains(normalizedVenusToMars) {
                score += 12 // Passionate attraction
            }
        }
        
        // Mars transits to Venus - sexual chemistry and conflicts
        if let marsTransit = transits.first(where: { $0.name == "Mars" }) {
            let marsToNatalVenus = abs(marsTransit.longitude - chart.venus.longitude)
            let normalizedMarsToVenus = marsToNatalVenus > 180 ? 360 - marsToNatalVenus : marsToNatalVenus
            
            if normalizedMarsToVenus < 8 { // Conjunction - intense attraction
                score += 15 // Very magnetic but possibly overwhelming
            } else if (82...98).contains(normalizedMarsToVenus) { // Square - sexual tension/conflicts
                score -= 12 // Fights and passion
            } else if (172...188).contains(normalizedMarsToVenus) { // Opposition - sexual polarity
                score -= 8
            } else if (112...128).contains(normalizedMarsToVenus) { // Trine - healthy passion
                score += 18 // Perfect sexual harmony
            } else if (52...68).contains(normalizedMarsToVenus) { // Sextile - flirtation
                score += 10
            }
        }
        
        // Jupiter transits to Venus - love expansion and excess
        if let jupiterTransit = transits.first(where: { $0.name == "Jupiter" }) {
            let jupiterToVenus = abs(jupiterTransit.longitude - chart.venus.longitude)
            let normalizedJupiterToVenus = jupiterToVenus > 180 ? 360 - jupiterToVenus : jupiterToVenus
            
            if normalizedJupiterToVenus < 8 { // Conjunction - major love expansion
                score += 22 // Falling in love, engagement, marriage
            } else if (112...128).contains(normalizedJupiterToVenus) { // Trine - joyful love
                score += 18
            } else if (52...68).contains(normalizedJupiterToVenus) { // Sextile - social love opportunities
                score += 12
            } else if (82...98).contains(normalizedJupiterToVenus) { // Square - overindulgence in love
                score -= 5 // Too much of a good thing
            }
        }
        
        // Saturn transits to Venus - serious relationships and restrictions
        if let saturnTransit = transits.first(where: { $0.name == "Saturn" }) {
            let saturnToVenus = abs(saturnTransit.longitude - chart.venus.longitude)
            let normalizedSaturnToVenus = saturnToVenus > 180 ? 360 - saturnToVenus : saturnToVenus
            
            if normalizedSaturnToVenus < 8 { // Conjunction - serious commitment or loneliness
                score -= 10 // Tests love's endurance
            } else if (82...98).contains(normalizedSaturnToVenus) { // Square - relationship obstacles
                score -= 18 // Serious relationship challenges
            } else if (172...188).contains(normalizedSaturnToVenus) { // Opposition - commitment pressure
                score -= 12
            } else if (112...128).contains(normalizedSaturnToVenus) { // Trine - stable mature love
                score += 15 // Committed lasting relationships
            } else if (52...68).contains(normalizedSaturnToVenus) { // Sextile - building solid love
                score += 8
            }
        }
        
        // Uranus transits to Venus - sudden attractions and breakups
        if let uranusTransit = transits.first(where: { $0.name == "Uranus" }) {
            let uranusToVenus = abs(uranusTransit.longitude - chart.venus.longitude)
            let normalizedUranusToVenus = uranusToVenus > 180 ? 360 - uranusToVenus : uranusToVenus
            
            if normalizedUranusToVenus < 8 { // Conjunction - revolutionary love
                score -= 5 // Exciting but unstable
            } else if (82...98).contains(normalizedUranusToVenus) { // Square - sudden breakups
                score -= 20 // Shocking relationship changes
            } else if (172...188).contains(normalizedUranusToVenus) { // Opposition - freedom vs commitment
                score -= 15
            } else if (112...128).contains(normalizedUranusToVenus) { // Trine - exciting unconventional love
                score += 12
            }
        }
        
        // Neptune transits to Venus - romantic illusion and spiritual love
        if let neptuneTransit = transits.first(where: { $0.name == "Neptune" }) {
            let neptuneToVenus = abs(neptuneTransit.longitude - chart.venus.longitude)
            let normalizedNeptuneToVenus = neptuneToVenus > 180 ? 360 - neptuneToVenus : neptuneToVenus
            
            if normalizedNeptuneToVenus < 8 { // Conjunction - idealized love
                score -= 8 // Beautiful but unrealistic
            } else if (82...98).contains(normalizedNeptuneToVenus) { // Square - deception in love
                score -= 15 // Affairs, lies, delusions
            } else if (112...128).contains(normalizedNeptuneToVenus) { // Trine - spiritual romantic love
                score += 12 // Soulmate connections
            }
        }
        
        // Moon transit for daily emotional love tone
        if let moonTransit = transits.first(where: { $0.name == "Moon" }) {
            let moonToVenus = abs(moonTransit.longitude - chart.venus.longitude)
            let normalizedMoonToVenus = moonToVenus > 180 ? 360 - moonToVenus : moonToVenus
            
            if normalizedMoonToVenus < 8 || (112...128).contains(normalizedMoonToVenus) {
                score += 8 // Emotionally receptive to love
            } else if (82...98).contains(normalizedMoonToVenus) {
                score -= 5 // Moody in relationships
            }
        }
        
        // === PERSONAL LOVE CYCLE ===
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let venusPersonalization = Int((chart.venus.longitude + Double(dayOfYear * 5)).truncatingRemainder(dividingBy: 16)) - 8
        score += venusPersonalization
        
        return max(5, min(95, score)) // Allow very low (5-15) and very high (85-95) love scores
    }
    
    private func calculateDailyCareerScore(chart: BirthChart, transits: [CelestialBody], aspects: [Aspect], date: Date) -> Int {
        var score = 55 // Slightly optimistic career baseline - everyone has career potential
        
        // === NATAL CAREER FOUNDATION ===
        
        // Mars sign affects drive, ambition, and energy
        let marsSign = chart.mars.position.sign
        if [.aries, .capricorn, .scorpio].contains(marsSign) { // Cardinal/Fixed power signs
            score += 15 // Natural leadership and drive
        } else if [.leo, .sagittarius].contains(marsSign) { // Fire signs
            score += 12 // Enthusiastic and inspiring
        } else if [.virgo, .taurus].contains(marsSign) { // Practical earth signs
            score += 10 // Methodical and reliable
        } else if [.gemini, .aquarius].contains(marsSign) { // Air signs
            score += 8 // Innovative and networked
        } else if [.libra, .cancer, .pisces].contains(marsSign) { // Gentle signs
            score += 5 // Collaborative but less aggressive
        }
        
        // Sun sign affects leadership style and career identity
        let sunSign = chart.sunSign
        if [.leo, .aries, .capricorn, .scorpio].contains(sunSign) { // Natural leaders
            score += 8
        } else if [.cancer, .libra, .pisces].contains(sunSign) { // People-oriented careers
            score += 5
        }
        
        // Mercury affects communication and intellect in career
        let mercurySign = chart.mercury.position.sign
        if [.gemini, .virgo].contains(mercurySign) { // Mercury ruled signs
            score += 10 // Excellent communication skills
        } else if [.aquarius, .libra, .sagittarius].contains(mercurySign) { // Intellectual air/fire
            score += 8 // Good at big picture thinking
        }
        
        // Saturn natal position affects career discipline and authority
        let saturnSign = chart.saturn.position.sign
        if [.capricorn, .aquarius].contains(saturnSign) { // Saturn ruled signs
            score += 8 // Natural authority and structure
        } else if [.libra].contains(saturnSign) { // Exalted
            score += 6 // Diplomatic leadership
        }
        
        // === MAJOR CAREER TRANSITS ===
        
        // Saturn transits - career structure, authority, tests
        if let saturnTransit = transits.first(where: { $0.name == "Saturn" }) {
            let saturnToSun = abs(saturnTransit.longitude - chart.sun.longitude)
            let normalizedSaturn = saturnToSun > 180 ? 360 - saturnToSun : saturnToSun
            
            if normalizedSaturn < 8 { // Saturn return - major career restructuring
                score -= 10 // Intense career pressure and change
            } else if (82...98).contains(normalizedSaturn) { // Square - career obstacles
                score -= 20 // Major professional challenges
            } else if (172...188).contains(normalizedSaturn) { // Opposition - authority conflicts
                score -= 15 // Boss problems, external pressure
            } else if (112...128).contains(normalizedSaturn) { // Trine - earned recognition
                score += 20 // Well-deserved career success
            } else if (52...68).contains(normalizedSaturn) { // Sextile - steady progress
                score += 12 // Building solid foundation
            }
            
            // Saturn to Mars - action vs discipline
            let saturnToMars = abs(saturnTransit.longitude - chart.mars.longitude)
            let normalizedSaturnMars = saturnToMars > 180 ? 360 - saturnToMars : saturnToMars
            
            if (82...98).contains(normalizedSaturnMars) { // Square - frustrated ambition
                score -= 12 // Blocked energy, delays
            } else if (112...128).contains(normalizedSaturnMars) { // Trine - disciplined action
                score += 15 // Productive, sustained effort
            }
        }
        
        // Jupiter transits - career expansion and opportunities
        if let jupiterTransit = transits.first(where: { $0.name == "Jupiter" }) {
            let jupiterToSun = abs(jupiterTransit.longitude - chart.sun.longitude)
            let normalizedJupiter = jupiterToSun > 180 ? 360 - jupiterToSun : jupiterToSun
            
            if normalizedJupiter < 8 { // Jupiter return - major career expansion
                score += 25 // Promotions, new opportunities
            } else if (112...128).contains(normalizedJupiter) { // Trine - natural success
                score += 20 // Everything flows easily
            } else if (52...68).contains(normalizedJupiter) { // Sextile - growth opportunities
                score += 15 // Networking and learning
            } else if (82...98).contains(normalizedJupiter) { // Square - overconfidence
                score -= 8 // Taking on too much
            }
            
            // Jupiter to Mars - amplified ambition
            let jupiterToMars = abs(jupiterTransit.longitude - chart.mars.longitude)
            let normalizedJupiterMars = jupiterToMars > 180 ? 360 - jupiterToMars : jupiterToMars
            
            if normalizedJupiterMars < 8 || (112...128).contains(normalizedJupiterMars) {
                score += 15 // Successful action and expansion
            }
        }
        
        // Mars transits - energy, initiative, conflicts at work
        if let marsTransit = transits.first(where: { $0.name == "Mars" }) {
            let marsToSun = abs(marsTransit.longitude - chart.sun.longitude)
            let normalizedMars = marsToSun > 180 ? 360 - marsToSun : marsToSun
            
            if normalizedMars < 8 { // Mars return - energy surge
                score += 10 // High energy and initiative
            } else if (82...98).contains(normalizedMars) { // Square - workplace conflicts
                score -= 15 // Arguments, accidents, impulsive decisions
            } else if (172...188).contains(normalizedMars) { // Opposition - external conflicts
                score -= 12 // Competition, confrontation
            } else if (112...128).contains(normalizedMars) { // Trine - productive energy
                score += 15 // Getting things done efficiently
            }
            
            // Mars to natal Mars - action cycle
            let marsToNatalMars = abs(marsTransit.longitude - chart.mars.longitude)
            let normalizedMarsToMars = marsToNatalMars > 180 ? 360 - marsToNatalMars : marsToNatalMars
            
            if (82...98).contains(normalizedMarsToMars) { // Square - frustrated action
                score -= 10 // Blocked initiatives
            } else if (112...128).contains(normalizedMarsToMars) { // Trine - effective action
                score += 12 // Projects move forward smoothly
            }
        }
        
        // Uranus transits - career innovation and disruption
        if let uranusTransit = transits.first(where: { $0.name == "Uranus" }) {
            let uranusToSun = abs(uranusTransit.longitude - chart.sun.longitude)
            let normalizedUranus = uranusToSun > 180 ? 360 - uranusToSun : uranusToSun
            
            if normalizedUranus < 8 { // Conjunction - career revolution
                score -= 8 // Sudden career changes
            } else if (82...98).contains(normalizedUranus) { // Square - sudden disruptions
                score -= 18 // Unexpected job loss or major changes
            } else if (172...188).contains(normalizedUranus) { // Opposition - external disruption
                score -= 12 // Industry changes affecting you
            } else if (112...128).contains(normalizedUranus) { // Trine - innovative breakthroughs
                score += 18 // Technological advancement, innovation
            }
        }
        
        // Mercury transits - communication, contracts, travel
        if let mercuryTransit = transits.first(where: { $0.name == "Mercury" }) {
            let mercuryToSun = abs(mercuryTransit.longitude - chart.sun.longitude)
            let normalizedMercury = mercuryToSun > 180 ? 360 - mercuryToSun : mercuryToSun
            
            if normalizedMercury < 8 || (112...128).contains(normalizedMercury) {
                score += 8 // Good communication day
            } else if (82...98).contains(normalizedMercury) {
                score -= 5 // Communication problems, delays
            }
        }
        
        // === PERSONAL CAREER CYCLE ===
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let careerPersonalization = Int((chart.mars.longitude + chart.sun.longitude + Double(dayOfYear * 4)).truncatingRemainder(dividingBy: 16)) - 8
        score += careerPersonalization
        
        return max(5, min(95, score)) // Allow very low (5-15) and very high (85-95) career scores
    }
    
    private func calculateDailyWealthScore(chart: BirthChart, transits: [CelestialBody], aspects: [Aspect], date: Date) -> Int {
        var score = 55 // Slightly optimistic wealth baseline - everyone has abundance potential
        
        // === NATAL WEALTH FOUNDATION ===
        
        // Jupiter represents abundance, luck, and expansion of resources
        let jupiterSign = chart.jupiter.position.sign
        if [.sagittarius, .pisces].contains(jupiterSign) { // Jupiter ruled signs
            score += 15 // Natural abundance and optimism
        } else if [.cancer].contains(jupiterSign) { // Exalted
            score += 18 // Excellent for emotional and material security
        } else if [.taurus, .leo].contains(jupiterSign) { // Material signs
            score += 12 // Good for accumulating wealth
        } else if [.virgo, .gemini].contains(jupiterSign) { // Mutable earth/air
            score += 8 // Wealth through skills and analysis
        } else if [.capricorn].contains(jupiterSign) { // Fall
            score -= 5 // Must work harder for expansion
        } else if [.libra, .aquarius, .aries, .scorpio].contains(jupiterSign) {
            score += 5 // Moderate wealth potential
        }
        
        // Venus rules money, possessions, and material pleasure
        let venusSign = chart.venus.position.sign
        if [.taurus, .libra].contains(venusSign) { // Venus ruled signs
            score += 12 // Natural ability to attract money
        } else if [.pisces].contains(venusSign) { // Exalted
            score += 10 // Intuitive money sense
        } else if [.capricorn, .virgo].contains(venusSign) { // Practical signs
            score += 8 // Good at managing money
        } else if [.scorpio].contains(venusSign) { // Intense
            score += 6 // Wealth through investments/joint resources
        } else if [.aries, .leo, .sagittarius].contains(venusSign) { // Fire signs
            score += 3 // Generous but spends freely
        }
        
        // Saturn represents wealth through discipline, savings, and long-term building
        let saturnSign = chart.saturn.position.sign
        if [.capricorn, .aquarius].contains(saturnSign) { // Saturn ruled
            score += 8 // Good at building lasting wealth
        } else if [.libra].contains(saturnSign) { // Exalted
            score += 6 // Balanced approach to money
        } else if [.taurus, .virgo].contains(saturnSign) { // Earth signs
            score += 5 // Conservative wealth building
        }
        
        // === MAJOR WEALTH TRANSITS ===
        
        // Jupiter transits - expansion of resources and opportunities
        if let jupiterTransit = transits.first(where: { $0.name == "Jupiter" }) {
            let jupiterToNatalJupiter = abs(jupiterTransit.longitude - chart.jupiter.longitude)
            let normalizedJupiterReturn = jupiterToNatalJupiter > 180 ? 360 - jupiterToNatalJupiter : jupiterToNatalJupiter
            
            if normalizedJupiterReturn < 8 { // Jupiter return (every 12 years)
                score += 30 // Major wealth expansion cycle
            } else if (112...128).contains(normalizedJupiterReturn) { // Trine
                score += 20 // Flowing abundance and opportunity
            } else if (52...68).contains(normalizedJupiterReturn) { // Sextile
                score += 15 // Growth opportunities through effort
            } else if (82...98).contains(normalizedJupiterReturn) { // Square
                score -= 8 // Overconfidence, overspending
            } else if (172...188).contains(normalizedJupiterReturn) { // Opposition
                score -= 5 // Conflicts over resources
            }
            
            // Jupiter to Venus - money and pleasure
            let jupiterToVenus = abs(jupiterTransit.longitude - chart.venus.longitude)
            let normalizedJupiterVenus = jupiterToVenus > 180 ? 360 - jupiterToVenus : jupiterToVenus
            
            if normalizedJupiterVenus < 8 { // Conjunction
                score += 25 // Major money luck, windfalls
            } else if (112...128).contains(normalizedJupiterVenus) { // Trine
                score += 18 // Easy money flow
            } else if (52...68).contains(normalizedJupiterVenus) { // Sextile
                score += 12 // Good financial opportunities
            }
        }
        
        // Saturn transits - wealth restriction, discipline, and long-term building
        if let saturnTransit = transits.first(where: { $0.name == "Saturn" }) {
            let saturnToVenus = abs(saturnTransit.longitude - chart.venus.longitude)
            let normalizedSaturnVenus = saturnToVenus > 180 ? 360 - saturnToVenus : saturnToVenus
            
            if normalizedSaturnVenus < 8 { // Conjunction
                score -= 15 // Financial restrictions and lessons
            } else if (82...98).contains(normalizedSaturnVenus) { // Square
                score -= 20 // Major financial challenges, debts
            } else if (172...188).contains(normalizedSaturnVenus) { // Opposition
                score -= 12 // Money stress from external sources
            } else if (112...128).contains(normalizedSaturnVenus) { // Trine
                score += 15 // Solid wealth building, financial maturity
            } else if (52...68).contains(normalizedSaturnVenus) { // Sextile
                score += 10 // Steady financial progress
            }
            
            // Saturn to Jupiter - abundance vs restriction
            let saturnToJupiter = abs(saturnTransit.longitude - chart.jupiter.longitude)
            let normalizedSaturnJupiter = saturnToJupiter > 180 ? 360 - saturnToJupiter : saturnToJupiter
            
            if (82...98).contains(normalizedSaturnJupiter) { // Square
                score -= 12 // Limited growth, pessimism about money
            } else if (112...128).contains(normalizedSaturnJupiter) { // Trine
                score += 12 // Wise investments, practical abundance
            }
        }
        
        // Uranus transits - sudden financial changes, technology income
        if let uranusTransit = transits.first(where: { $0.name == "Uranus" }) {
            let uranusToVenus = abs(uranusTransit.longitude - chart.venus.longitude)
            let normalizedUranusVenus = uranusToVenus > 180 ? 360 - uranusToVenus : uranusToVenus
            
            if normalizedUranusVenus < 8 { // Conjunction
                score -= 10 // Sudden financial changes (could be gain or loss)
            } else if (82...98).contains(normalizedUranusVenus) { // Square
                score -= 18 // Unexpected financial shocks, losses
            } else if (112...128).contains(normalizedUranusVenus) { // Trine
                score += 15 // Innovative money-making, technology profits
            }
        }
        
        // Pluto transits - wealth transformation, power over resources
        if let plutoTransit = transits.first(where: { $0.name == "Pluto" }) {
            let plutoToVenus = abs(plutoTransit.longitude - chart.venus.longitude)
            let normalizedPlutoVenus = plutoToVenus > 180 ? 360 - plutoToVenus : plutoToVenus
            
            if normalizedPlutoVenus < 8 { // Conjunction
                score -= 12 // Complete financial transformation
            } else if (82...98).contains(normalizedPlutoVenus) { // Square
                score -= 20 // Power struggles over money, major losses/gains
            } else if (112...128).contains(normalizedPlutoVenus) { // Trine
                score += 18 // Powerful wealth accumulation, investments
            }
        }
        
        // Mars transits - energy toward money, spending vs earning
        if let marsTransit = transits.first(where: { $0.name == "Mars" }) {
            let marsToVenus = abs(marsTransit.longitude - chart.venus.longitude)
            let normalizedMarsVenus = marsToVenus > 180 ? 360 - marsToVenus : marsToVenus
            
            if normalizedMarsVenus < 8 || (112...128).contains(normalizedMarsVenus) {
                score += 8 // Active earning, passion for making money
            } else if (82...98).contains(normalizedMarsVenus) {
                score -= 8 // Impulsive spending, money conflicts
            }
        }
        
        // === PERSONAL WEALTH CYCLE ===
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let wealthPersonalization = Int((chart.jupiter.longitude + chart.venus.longitude + Double(dayOfYear * 6)).truncatingRemainder(dividingBy: 18)) - 9
        score += wealthPersonalization
        
        return max(5, min(95, score)) // Allow very low (5-15) and very high (85-95) wealth scores
    }
    
    // MARK: - Weekly Score Calculations
    private func calculateWeeklyOverallScore(chart: BirthChart, transits: [CelestialBody], aspects: [Aspect], date: Date) -> Int {
        var score = 50 // Neutral weekly baseline
        
        // === WEEKLY FOCUS: SLOWER-MOVING PLANETS (More sustained influences) ===
        
        // Jupiter weekly trends - opportunity and expansion
        if let jupiterTransit = transits.first(where: { $0.name == "Jupiter" }) {
            let jupiterToSun = abs(jupiterTransit.longitude - chart.sun.longitude)
            let normalizedJupiter = jupiterToSun > 180 ? 360 - jupiterToSun : jupiterToSun
            
            if normalizedJupiter < 8 { // Jupiter return
                score += 20 // Major weekly expansion
            } else if (112...128).contains(normalizedJupiter) { // Trine
                score += 15 // Flowing weekly growth
            } else if (52...68).contains(normalizedJupiter) { // Sextile
                score += 10 // Weekly opportunities
            } else if (82...98).contains(normalizedJupiter) { // Square
                score -= 5 // Weekly overexpansion
            }
        }
        
        // Saturn weekly structure - discipline and challenges
        if let saturnTransit = transits.first(where: { $0.name == "Saturn" }) {
            let saturnToSun = abs(saturnTransit.longitude - chart.sun.longitude)
            let normalizedSaturn = saturnToSun > 180 ? 360 - saturnToSun : saturnToSun
            
            if normalizedSaturn < 8 { // Saturn conjunction/return
                score -= 12 // Weekly pressure and restructuring
            } else if (82...98).contains(normalizedSaturn) { // Square
                score -= 15 // Weekly obstacles and tests
            } else if (172...188).contains(normalizedSaturn) { // Opposition
                score -= 10 // Weekly external pressure
            } else if (112...128).contains(normalizedSaturn) { // Trine
                score += 12 // Weekly structured success
            } else if (52...68).contains(normalizedSaturn) { // Sextile
                score += 8 // Weekly steady progress
            }
        }
        
        // Uranus weekly disruption - sudden changes over the week
        if let uranusTransit = transits.first(where: { $0.name == "Uranus" }) {
            let uranusToSun = abs(uranusTransit.longitude - chart.sun.longitude)
            let normalizedUranus = uranusToSun > 180 ? 360 - uranusToSun : uranusToSun
            
            if (82...98).contains(normalizedUranus) { // Square
                score -= 12 // Disruptive week
            } else if (112...128).contains(normalizedUranus) { // Trine
                score += 10 // Innovative week
            }
        }
        
        // Mars weekly energy - differs from daily intensity
        if let marsTransit = transits.first(where: { $0.name == "Mars" }) {
            let marsToSun = abs(marsTransit.longitude - chart.sun.longitude)
            let normalizedMars = marsToSun > 180 ? 360 - marsToSun : marsToSun
            
            if (82...98).contains(normalizedMars) { // Square
                score -= 8 // Conflicted week
            } else if (112...128).contains(normalizedMars) { // Trine
                score += 8 // Productive week
            }
        }
        
        // Weekly elemental harmony (sustained mood)
        if let moonTransit = transits.first(where: { $0.name == "Moon" }) {
            let weeklyMoonSign = moonTransit.position.sign
            if weeklyMoonSign.element == chart.sunSign.element {
                score += 6 // Weekly emotional resonance
            }
        }
        
        // Personal weekly variation
        let currentWeek = Calendar.current.component(.weekOfYear, from: date)
        let weeklyPersonalization = Int((chart.sun.longitude + Double(currentWeek * 7)).truncatingRemainder(dividingBy: 16)) - 8
        score += weeklyPersonalization
        
        return max(5, min(95, score))
    }
    
    private func calculateWeeklyLoveScore(chart: BirthChart, transits: [CelestialBody], aspects: [Aspect], date: Date) -> Int {
        var score = 65 // Higher baseline for weekly scores (aligned with daily/monthly)
        
        // === WEEKLY LOVE FOCUS: SUSTAINED RELATIONSHIP PATTERNS ===
        
        // Venus weekly patterns - longer relationship trends
        if let venusTransit = transits.first(where: { $0.name == "Venus" }) {
            let venusToNatalVenus = abs(venusTransit.longitude - chart.venus.longitude)
            let normalizedVenus = venusToNatalVenus > 180 ? 360 - venusToNatalVenus : venusToNatalVenus
            
            if normalizedVenus < 8 { // Venus return (every 8 months)
                score += 18 // Major weekly love renewal
            } else if (112...128).contains(normalizedVenus) { // Trine
                score += 14 // Flowing weekly love energy
            } else if (52...68).contains(normalizedVenus) { // Sextile
                score += 10 // Weekly love opportunities
            } else if (82...98).contains(normalizedVenus) { // Square
                score -= 8 // Weekly relationship tensions
            } else if (172...188).contains(normalizedVenus) { // Opposition
                score -= 5 // Weekly relationship clarity needed
            }
        }
        
        // Jupiter to Venus - weekly love expansion
        if let jupiterTransit = transits.first(where: { $0.name == "Jupiter" }) {
            let jupiterToVenus = abs(jupiterTransit.longitude - chart.venus.longitude)
            let normalizedJupiterVenus = jupiterToVenus > 180 ? 360 - jupiterToVenus : jupiterToVenus
            
            if normalizedJupiterVenus < 8 { // Conjunction
                score += 20 // Weekly love abundance
            } else if (112...128).contains(normalizedJupiterVenus) { // Trine
                score += 15 // Joyful weekly love
            } else if (52...68).contains(normalizedJupiterVenus) { // Sextile
                score += 10 // Weekly social love connections
            }
        }
        
        // Saturn to Venus - weekly relationship structure
        if let saturnTransit = transits.first(where: { $0.name == "Saturn" }) {
            let saturnToVenus = abs(saturnTransit.longitude - chart.venus.longitude)
            let normalizedSaturnVenus = saturnToVenus > 180 ? 360 - saturnToVenus : saturnToVenus
            
            if normalizedSaturnVenus < 8 { // Conjunction
                score -= 8 // Weekly relationship lessons
            } else if (82...98).contains(normalizedSaturnVenus) { // Square
                score -= 15 // Weekly relationship challenges
            } else if (172...188).contains(normalizedSaturnVenus) { // Opposition
                score -= 10 // Weekly commitment pressure
            } else if (112...128).contains(normalizedSaturnVenus) { // Trine
                score += 12 // Weekly stable mature love
            } else if (52...68).contains(normalizedSaturnVenus) { // Sextile
                score += 8 // Weekly relationship building
            }
        }
        
        // Mars to Venus - weekly passion patterns
        if let marsTransit = transits.first(where: { $0.name == "Mars" }) {
            let marsToVenus = abs(marsTransit.longitude - chart.venus.longitude)
            let normalizedMarsVenus = marsToVenus > 180 ? 360 - marsToVenus : marsToVenus
            
            if normalizedMarsVenus < 8 { // Conjunction
                score += 12 // Weekly magnetic attraction
            } else if (82...98).contains(normalizedMarsVenus) { // Square
                score -= 10 // Weekly passion conflicts
            } else if (112...128).contains(normalizedMarsVenus) { // Trine
                score += 15 // Weekly sexual harmony
            } else if (52...68).contains(normalizedMarsVenus) { // Sextile
                score += 8 // Weekly flirtation and chemistry
            }
        }
        
        // Weekly personal love cycle
        let currentWeek = Calendar.current.component(.weekOfYear, from: date)
        let weeklyLovePersonalization = Int((chart.venus.longitude + Double(currentWeek * 5)).truncatingRemainder(dividingBy: 16)) - 8
        score += weeklyLovePersonalization
        
        return max(5, min(95, score))
    }
    
    private func calculateWeeklyCareerScore(chart: BirthChart, transits: [CelestialBody], aspects: [Aspect], date: Date) -> Int {
        var score = 65 // Higher baseline for weekly scores (aligned with daily/monthly)
        
        // === WEEKLY CAREER FOCUS: SUSTAINED PROFESSIONAL PROGRESS ===
        
        // Saturn weekly career structure and authority
        if let saturnTransit = transits.first(where: { $0.name == "Saturn" }) {
            let saturnToSun = abs(saturnTransit.longitude - chart.sun.longitude)
            let normalizedSaturn = saturnToSun > 180 ? 360 - saturnToSun : saturnToSun
            
            if normalizedSaturn < 8 { // Saturn return
                score -= 8 // Weekly career restructuring pressure
            } else if (82...98).contains(normalizedSaturn) { // Square
                score -= 15 // Weekly professional obstacles
            } else if (172...188).contains(normalizedSaturn) { // Opposition
                score -= 10 // Weekly authority conflicts
            } else if (112...128).contains(normalizedSaturn) { // Trine
                score += 18 // Weekly earned recognition
            } else if (52...68).contains(normalizedSaturn) { // Sextile
                score += 12 // Weekly steady career building
            }
            
            // Saturn to Mars - sustained action vs discipline
            let saturnToMars = abs(saturnTransit.longitude - chart.mars.longitude)
            let normalizedSaturnMars = saturnToMars > 180 ? 360 - saturnToMars : saturnToMars
            
            if (82...98).contains(normalizedSaturnMars) { // Square
                score -= 10 // Weekly frustrated ambition
            } else if (112...128).contains(normalizedSaturnMars) { // Trine
                score += 12 // Weekly disciplined productivity
            }
        }
        
        // Jupiter weekly career expansion
        if let jupiterTransit = transits.first(where: { $0.name == "Jupiter" }) {
            let jupiterToSun = abs(jupiterTransit.longitude - chart.sun.longitude)
            let normalizedJupiter = jupiterToSun > 180 ? 360 - jupiterToSun : jupiterToSun
            
            if normalizedJupiter < 8 { // Jupiter return
                score += 20 // Weekly career opportunities
            } else if (112...128).contains(normalizedJupiter) { // Trine
                score += 15 // Weekly natural career success
            } else if (52...68).contains(normalizedJupiter) { // Sextile
                score += 12 // Weekly career growth opportunities
            } else if (82...98).contains(normalizedJupiter) { // Square
                score -= 5 // Weekly career overconfidence
            }
        }
        
        // Mars weekly career energy and initiative
        if let marsTransit = transits.first(where: { $0.name == "Mars" }) {
            let marsToSun = abs(marsTransit.longitude - chart.sun.longitude)
            let normalizedMars = marsToSun > 180 ? 360 - marsToSun : marsToSun
            
            if normalizedMars < 8 { // Mars return
                score += 8 // Weekly energy surge
            } else if (82...98).contains(normalizedMars) { // Square
                score -= 12 // Weekly workplace conflicts
            } else if (172...188).contains(normalizedMars) { // Opposition
                score -= 8 // Weekly career competition
            } else if (112...128).contains(normalizedMars) { // Trine
                score += 12 // Weekly productive action
            } else if (52...68).contains(normalizedMars) { // Sextile
                score += 8 // Weekly initiative opportunities
            }
        }
        
        // Uranus weekly career innovation and disruption
        if let uranusTransit = transits.first(where: { $0.name == "Uranus" }) {
            let uranusToSun = abs(uranusTransit.longitude - chart.sun.longitude)
            let normalizedUranus = uranusToSun > 180 ? 360 - uranusToSun : uranusToSun
            
            if (82...98).contains(normalizedUranus) { // Square
                score -= 12 // Weekly career disruptions
            } else if (112...128).contains(normalizedUranus) { // Trine
                score += 15 // Weekly innovative breakthroughs
            }
        }
        
        // Mercury weekly communication and contracts
        if let mercuryTransit = transits.first(where: { $0.name == "Mercury" }) {
            let mercuryToSun = abs(mercuryTransit.longitude - chart.sun.longitude)
            let normalizedMercury = mercuryToSun > 180 ? 360 - mercuryToSun : mercuryToSun
            
            if normalizedMercury < 8 || (112...128).contains(normalizedMercury) {
                score += 6 // Weekly communication flow
            } else if (82...98).contains(normalizedMercury) {
                score -= 3 // Weekly communication problems
            }
        }
        
        // Weekly personal career cycle
        let currentWeek = Calendar.current.component(.weekOfYear, from: date)
        let weeklyCareerPersonalization = Int((chart.mars.longitude + chart.sun.longitude + Double(currentWeek * 4)).truncatingRemainder(dividingBy: 16)) - 8
        score += weeklyCareerPersonalization
        
        return max(5, min(95, score))
    }
    
    private func calculateWeeklyWealthScore(chart: BirthChart, transits: [CelestialBody], aspects: [Aspect], date: Date) -> Int {
        var score = 65 // Higher baseline for weekly scores (aligned with daily/monthly)
        
        // === WEEKLY WEALTH FOCUS: SUSTAINED FINANCIAL PATTERNS ===
        
        // Jupiter weekly abundance and expansion patterns
        if let jupiterTransit = transits.first(where: { $0.name == "Jupiter" }) {
            let jupiterToNatalJupiter = abs(jupiterTransit.longitude - chart.jupiter.longitude)
            let normalizedJupiter = jupiterToNatalJupiter > 180 ? 360 - jupiterToNatalJupiter : jupiterToNatalJupiter
            
            if normalizedJupiter < 8 { // Jupiter return (every 12 years)
                score += 25 // Weekly wealth expansion period
            } else if (112...128).contains(normalizedJupiter) { // Trine
                score += 18 // Weekly flowing abundance
            } else if (52...68).contains(normalizedJupiter) { // Sextile
                score += 12 // Weekly growth opportunities
            } else if (82...98).contains(normalizedJupiter) { // Square
                score -= 6 // Weekly overexpansion with money
            }
            
            // Jupiter to Venus - weekly money luck
            let jupiterToVenus = abs(jupiterTransit.longitude - chart.venus.longitude)
            let normalizedJupiterVenus = jupiterToVenus > 180 ? 360 - jupiterToVenus : jupiterToVenus
            
            if normalizedJupiterVenus < 8 { // Conjunction
                score += 20 // Weekly financial windfalls
            } else if (112...128).contains(normalizedJupiterVenus) { // Trine
                score += 15 // Weekly easy money flow
            } else if (52...68).contains(normalizedJupiterVenus) { // Sextile
                score += 10 // Weekly financial opportunities
            }
        }
        
        // Saturn weekly wealth discipline and restrictions
        if let saturnTransit = transits.first(where: { $0.name == "Saturn" }) {
            let saturnToVenus = abs(saturnTransit.longitude - chart.venus.longitude)
            let normalizedSaturnVenus = saturnToVenus > 180 ? 360 - saturnToVenus : saturnToVenus
            
            if normalizedSaturnVenus < 8 { // Conjunction
                score -= 12 // Weekly financial restrictions
            } else if (82...98).contains(normalizedSaturnVenus) { // Square
                score -= 18 // Weekly financial challenges
            } else if (172...188).contains(normalizedSaturnVenus) { // Opposition
                score -= 10 // Weekly money stress
            } else if (112...128).contains(normalizedSaturnVenus) { // Trine
                score += 12 // Weekly solid wealth building
            } else if (52...68).contains(normalizedSaturnVenus) { // Sextile
                score += 8 // Weekly steady financial progress
            }
        }
        
        // Uranus weekly financial surprises and changes
        if let uranusTransit = transits.first(where: { $0.name == "Uranus" }) {
            let uranusToVenus = abs(uranusTransit.longitude - chart.venus.longitude)
            let normalizedUranusVenus = uranusToVenus > 180 ? 360 - uranusToVenus : uranusToVenus
            
            if (82...98).contains(normalizedUranusVenus) { // Square
                score -= 15 // Weekly unexpected financial changes
            } else if (112...128).contains(normalizedUranusVenus) { // Trine
                score += 12 // Weekly innovative money-making
            }
        }
        
        // Mars weekly financial energy and spending
        if let marsTransit = transits.first(where: { $0.name == "Mars" }) {
            let marsToVenus = abs(marsTransit.longitude - chart.venus.longitude)
            let normalizedMarsVenus = marsToVenus > 180 ? 360 - marsToVenus : marsToVenus
            
            if normalizedMarsVenus < 8 || (112...128).contains(normalizedMarsVenus) {
                score += 6 // Weekly active earning
            } else if (82...98).contains(normalizedMarsVenus) {
                score -= 6 // Weekly impulsive spending
            }
        }
        
        // Weekly personal wealth cycle
        let currentWeek = Calendar.current.component(.weekOfYear, from: date)
        let weeklyWealthPersonalization = Int((chart.jupiter.longitude + chart.venus.longitude + Double(currentWeek * 6)).truncatingRemainder(dividingBy: 18)) - 9
        score += weeklyWealthPersonalization
        
        return max(5, min(95, score))
    }
    
    // MARK: - Astrological Cycles
    func calculateCurrentCycles(for chart: BirthChart, date: Date = Date()) -> [AstrologicalCycle] {
        print("🔄 Calculating astrological cycles for \(date)")
        let transits = calculateCurrentTransits(for: date)
        var cycles: [AstrologicalCycle] = []
        
        // Calculate significant transit aspects
        cycles.append(contentsOf: calculateTransitCycles(chart: chart, transits: transits))
        
        // Add current lunar cycle info
        if let moonTransit = transits.first(where: { $0.name == "Moon" }) {
            let lunarCycle = calculateLunarCycle(moonTransit: moonTransit, chart: chart)
            cycles.append(lunarCycle)
        }
        
        return cycles
    }
    
    private func calculateTransitCycles(chart: BirthChart, transits: [CelestialBody]) -> [AstrologicalCycle] {
        var cycles: [AstrologicalCycle] = []
        var seenCombinations: Set<String> = []
        
        // Check for significant outer planet transits
        let outerPlanets = transits.filter { ["Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"].contains($0.name) }
        let personalPlanets = [chart.sun, chart.moon, chart.mercury, chart.venus, chart.mars]
        
        for transitPlanet in outerPlanets {
            for natalPlanet in personalPlanets {
                let angle = abs(transitPlanet.longitude - natalPlanet.longitude)
                let normalizedAngle = angle > 180 ? 360 - angle : angle
                
                // Check for major aspects
                if let aspectType = getAspectType(for: normalizedAngle) {
                    // Create unique identifier for this combination
                    let combinationKey = "\(transitPlanet.name)-\(natalPlanet.name)-\(aspectType.rawValue)"
                    
                    // Only add if we haven't seen this combination
                    if !seenCombinations.contains(combinationKey) {
                        let cycle = createCycleFromAspect(
                            transitPlanet: transitPlanet,
                            natalPlanet: natalPlanet,
                            aspectType: aspectType,
                            chart: chart
                        )
                        cycles.append(cycle)
                        seenCombinations.insert(combinationKey)
                    }
                }
            }
        }
        
        // Also check for Venus and Mars transits to Sun/Moon for love and career cycles
        if let venusTransit = transits.first(where: { $0.name == "Venus" }) {
            let venusToSunAngle = abs(venusTransit.longitude - chart.sun.longitude)
            let normalizedVenusAngle = venusToSunAngle > 180 ? 360 - venusToSunAngle : venusToSunAngle
            
            if let aspectType = getAspectType(for: normalizedVenusAngle) {
                let combinationKey = "Venus-Sun-\(aspectType.rawValue)-Love"
                
                // Only add if we haven't seen this Venus-Sun combination already
                if !seenCombinations.contains(combinationKey) && !seenCombinations.contains("Venus-Sun-\(aspectType.rawValue)") {
                    cycles.append(createLoveCycle(aspectType: aspectType, sunSign: chart.sunSign))
                    seenCombinations.insert(combinationKey)
                }
            }
        }
        
        return Array(cycles.prefix(4)) // Limit to most significant cycles
    }
    
    private func calculateLunarCycle(moonTransit: CelestialBody, chart: BirthChart) -> AstrologicalCycle {
        let moonToSunAngle = abs(moonTransit.longitude - chart.sun.longitude)
        let normalizedAngle = moonToSunAngle > 180 ? 360 - moonToSunAngle : moonToSunAngle
        
        let phase: String
        let description: String
        let influence: AstrologicalCycle.CycleInfluence
        
        switch normalizedAngle {
        case 0...15:
            phase = "fresh start (new moon)"
            description = "This is the best time of the month to start new projects, set intentions, or turn the page on what came before. Your emotional and physical energy resets with the new moon, giving you a clean slate. Make a list of what you want to accomplish this lunar cycle. The seeds you plant now - whether literal goals or intentions - have the best chance of growing over the coming weeks. This is your monthly renewal period. Use it to recommit to what matters or pivot in a new direction. Fresh starts are favored when the moon is new."
            influence = .positive
            
        case 75...105:
            phase = "push through resistance"
            description = "You're feeling tension and friction, but this is actually productive energy pushing you to take action. Don't give up on what you started at the new moon - this challenging phase is part of the process. The discomfort you feel is momentum trying to break through resistance. Take action even when you don't feel like it. This is when effort matters most. The temptation to quit is strong, but results come through pushing past this exact point. Channel the tension constructively rather than letting it discourage you. This friction is temporary but necessary for growth."
            influence = .challenging
            
        case 165...195:
            phase = "everything becomes clear (full moon)"
            description = "The full moon illuminates what was hidden. Truth comes out and situations reach their peak. You're able to see things about people, situations, and yourself that weren't visible before. This clarity is powerful - use it to make decisions based on what's now obvious. Relationships and patterns that were unclear become crystal clear. This is the time to release what isn't working now that you can see it plainly. The full moon reveals what needs to be acknowledged or let go. Trust what becomes visible and act on the clarity you're given."
            influence = .transformative
            
        case 255...285:
            phase = "let go and rest"
            description = "This is the time to wrap things up and clear space for the next cycle. Finish what you can and release what you can't complete. The energy is waning, signaling you to rest and recharge rather than start new things. Don't begin anything major during this phase - endings are needed before new beginnings can happen. Use this time to tie up loose ends, clear physical and mental clutter, and prepare for the fresh start coming at the new moon. Your body and mind need the downtime. Honor the natural rhythm of release and rest."
            influence = .neutral
            
        default:
            phase = "lunar flow"
            description = "You're in a normal flow period of the lunar cycle. Your emotions are processing naturally without extreme highs or lows. Trust your feelings as they arise and honor your natural pace. There's no rush to force anything or make major moves right now. This is about staying present with how you feel and allowing things to unfold organically. Your emotional rhythms are steady and reliable during this phase. Use this stability to maintain what you've built and stay attuned to your inner world without drama or urgency."
            influence = .neutral
        }
        
        // Calculate progress based on lunar phase
        let lunarProgress: Double
        switch normalizedAngle {
        case 0...15: lunarProgress = 0.05 // Just starting new moon
        case 75...105: lunarProgress = 0.25 // First quarter
        case 165...195: lunarProgress = 0.5 // Full moon - peak
        case 255...285: lunarProgress = 0.75 // Last quarter
        default: lunarProgress = (normalizedAngle / 360.0) // Proportional to phase
        }
        
        // Get aspect name for display
        let aspectName: String
        if let aspectType = getAspectType(for: normalizedAngle) {
            aspectName = aspectType.word
        } else {
            aspectName = "to" // fallback
        }
        
        return AstrologicalCycle(
            title: phase,
            planetaryAspect: "Moon \(aspectName) Sun",
            duration: "< 3 days",
            description: description,
            influence: influence,
            progressPercentage: lunarProgress
        )
    }
    
    private func getAspectType(for angle: Double) -> AspectType? {
        if angle <= 8 { return .conjunction }
        if (52...68).contains(angle) { return .sextile }
        if (82...98).contains(angle) { return .square }
        if (112...128).contains(angle) { return .trine }
        if (172...188).contains(angle) { return .opposition }
        return nil
    }
    
    private func getAspectSymbol(for angle: Double) -> String {
        if let aspectType = getAspectType(for: angle) {
            return aspectType.symbol
        }
        return "∠" // Generic angle symbol
    }
    
    private func createCycleFromAspect(transitPlanet: CelestialBody, natalPlanet: CelestialBody, aspectType: AspectType, chart: BirthChart) -> AstrologicalCycle {
        let title = generateCycleTitle(transitPlanet: transitPlanet, natalPlanet: natalPlanet, aspectType: aspectType)
        let duration = getCycleDuration(for: transitPlanet.name)
        let description = generateCycleDescription(transitPlanet: transitPlanet, natalPlanet: natalPlanet, aspectType: aspectType, sunSign: chart.sunSign)
        let influence = getCycleInfluence(aspectType: aspectType, transitPlanet: transitPlanet.name)
        let progress = calculateCycleProgress(transitPlanet: transitPlanet, natalPlanet: natalPlanet, aspectType: aspectType)
        
        // Use text word instead of symbol for aspect
        let aspectWord = aspectType.word
        
        return AstrologicalCycle(
            title: title,
            planetaryAspect: "\(transitPlanet.name) \(aspectWord) \(natalPlanet.name)",
            duration: duration,
            description: description,
            influence: influence,
            progressPercentage: progress
        )
    }
    
    private func createLoveCycle(aspectType: AspectType, sunSign: ZodiacSign) -> AstrologicalCycle {
        let isHarsh = aspectType == .square || aspectType == .opposition
        let title = isHarsh ? "dating frustrations (be patient)" : "good time for dating"
        
        let description = isHarsh 
            ? "You're feeling more impatient than usual when it comes to dating and romance. This can lead to coming on too strong or rushing things that need time to develop. Be mindful of how you approach romantic situations during this brief period. Give people space and practice patience with both others and yourself. Don't make major relationship decisions or commitments right now - your judgment might be clouded by impatience. This is only a few days, so focus on self-awareness rather than forcing romantic outcomes. The frustration will pass quickly."
            : "Your charm and natural attractiveness are heightened during this brief but favorable period. This is an excellent time to schedule dates, attend social events, or ask someone out if you've been thinking about it. Romantic connections flow more easily than usual and people are receptive to your advances. Put yourself out there socially and romantically - your timing is good. If you're in a relationship, plan something special together. Your warmth and appeal are enhanced, making this a sweet window for love and connection. Enjoy the boost in romantic energy while it lasts."
        
        return AstrologicalCycle(
            title: title,
            planetaryAspect: "Venus \(aspectType.word) Sun",
            duration: "< 3 days",
            description: description,
            influence: isHarsh ? .challenging : .positive,
            progressPercentage: 0.6 + Double.random(in: 0...0.25) // Fast planet, likely past peak
        )
    }
    
    private func generateCycleTitle(transitPlanet: CelestialBody, natalPlanet: CelestialBody, aspectType: AspectType) -> String {
        // Generate direct, actionable titles
        let isHarsh = aspectType == .square || aspectType == .opposition
        
        switch (transitPlanet.name, natalPlanet.name) {
        // Love & Relationships (Venus combinations)
        case ("Venus", "Sun"), ("Venus", "Moon"), ("Neptune", "Venus"):
            return isHarsh ? "dating frustrations (be patient)" : "good time for dating"
        case ("Venus", "Mars"):
            return isHarsh ? "relationship tension" : "strong attraction energy"
            
        // Communication & Mind (Mercury combinations)
        case ("Mercury", "Sun"), ("Mercury", "Moon"), ("Uranus", "Mercury"):
            return isHarsh ? "miscommunication likely" : "clear thinking"
        case ("Mercury", "Mars"):
            return isHarsh ? "arguments incoming" : "speak your mind"
            
        // Career & Action (Mars, Saturn to Sun/Mars)
        case ("Saturn", "Sun"), ("Saturn", "Mars"):
            return isHarsh ? "work feels hard" : "career progress"
        case ("Mars", "Sun"):
            return isHarsh ? "low energy period" : "high energy"
            
        // Personal Growth (Jupiter combinations)
        case ("Jupiter", "Sun"), ("Jupiter", "Moon"):
            return isHarsh ? "overconfidence alert" : "good luck window"
        case ("Jupiter", "Venus"):
            return isHarsh ? "overspending risk" : "money opportunities"
        case ("Jupiter", "Mercury"):
            return isHarsh ? "too many ideas" : "learning comes easy"
            
        // Transformation (Pluto combinations)
        case ("Pluto", "Sun"), ("Pluto", "Moon"):
            return isHarsh ? "major life changes" : "personal power up"
        case ("Pluto", "Venus"):
            return isHarsh ? "relationship intensity" : "deep connections"
        case ("Pluto", "Mars"):
            return isHarsh ? "power struggles" : "unstoppable drive"
            
        // Uranus transits - Break free & Change
        case ("Uranus", "Venus"):
            return isHarsh ? "relationship surprises" : "exciting social life"
        case ("Uranus", "Moon"):
            return isHarsh ? "emotional ups and downs" : "breakthrough feelings"
        case ("Uranus", "Mars"):
            return isHarsh ? "restless energy" : "bold moves pay off"
        case ("Uranus", "Sun"):
            return isHarsh ? "need for freedom" : "be yourself fully"
            
        // Neptune transits - Spiritual & Intuitive
        case ("Neptune", "Sun"), ("Neptune", "Moon"):
            return isHarsh ? "clarity issues" : "strong intuition"
        case ("Neptune", "Mercury"):
            return isHarsh ? "confusion/deception" : "creative thinking"
        case ("Neptune", "Venus"):
            return isHarsh ? "rose-colored glasses" : "romantic idealism"
            
        // Saturn
        case ("Saturn", "Moon"):
            return isHarsh ? "emotional heaviness" : "emotional maturity"
        case ("Saturn", "Venus"):
            return isHarsh ? "relationship tests" : "commitment ready"
        case ("Saturn", "Mercury"):
            return isHarsh ? "mental blocks" : "structured thinking"
            
        default:
            return isHarsh ? "challenging period" : "favorable period"
        }
    }
    
    private func getCycleDuration(for planetName: String) -> String {
        switch planetName {
        case "Jupiter": return "> 30 days"
        case "Saturn": return "> 30 days"
        case "Uranus": return "> 30 days"
        case "Neptune": return "> 30 days"
        case "Pluto": return "> 30 days"
        case "Venus": return "> 30 days"
        case "Mars": return "> 30 days"
        case "Mercury": return "< 3 days"
        case "Moon": return "< 3 days"
        default: return "> 30 days"
        }
    }
    
    private func generateCycleDescription(transitPlanet: CelestialBody, natalPlanet: CelestialBody, aspectType: AspectType, sunSign: ZodiacSign) -> String {
        // Direct, actionable descriptions
        let isHarsh = aspectType == .square || aspectType == .opposition
        
        switch (transitPlanet.name, natalPlanet.name) {
        // VENUS - Love & Relationships
        case ("Venus", "Sun"), ("Venus", "Moon"):
            if isHarsh {
                return "You're likely feeling more impatient than usual when it comes to romance and relationships. This can lead to coming on too strong or rushing things that need time to develop naturally. Be mindful of how you approach dating situations during this period. Give people space and practice patience with both others and yourself. Avoid making major relationship decisions or commitments right now - your judgment might be clouded by impatience. This is a short phase that will pass in a couple weeks, so focus on self-awareness rather than forcing outcomes."
            } else {
                return "This is an excellent time to put yourself out there romantically and socially. Your natural charm and attractiveness are heightened, making you more magnetic to others. People are drawn to your energy right now. Take advantage of this period by scheduling dates, attending social events, or working on creative projects. If you've been thinking about asking someone out or expressing romantic interest, now is the time. Your timing is good and others are receptive to your advances. Enjoy this boost in confidence and social ease."
            }
        case ("Venus", "Mars"):
            if isHarsh {
                return "You're experiencing increased sexual tension and potential friction in romantic relationships. Your desires might feel more intense, but this can lead to unnecessary conflict if not channeled properly. Avoid starting fights over minor issues or letting small irritations escalate. Instead, redirect this passionate energy into physical activities like working out, or into creative projects that allow for emotional expression. This transit is temporary, so practice restraint in heated moments and focus on constructive outlets for your intensity."
            } else {
                return "Strong attraction energy and heightened passion characterize this period. Your magnetism is at a peak, making this an ideal time for romance, flirting, and expressing your desires. If you've been thinking about making a move on someone, your confidence and timing are aligned right now. This is also great energy for creative projects that require passion and drive. Your ability to attract what you want is enhanced, so be bold in pursuing romantic interests. The chemistry you create now can lead to meaningful connections."
            }
        case ("Venus", "Mercury"):
            if isHarsh {
                return "Communication in relationships might feel slightly off. What you're trying to express about your feelings doesn't quite land the way you intend. Misunderstandings in romantic contexts are possible. Take extra care to clarify what you mean when discussing relationship matters. Your words and feelings might not be as aligned as usual. This is a minor irritation rather than a major problem, but being aware of it helps you avoid unnecessary confusion in your connections."
            } else {
                return "Your ability to express feelings and communicate about relationships is enhanced. This is excellent timing for important conversations about love, values, or what you want in relationships. You can articulate your feelings clearly and charmingly. Good for writing love letters, having the define-the-relationship talk, or expressing appreciation to people you care about. Your words and feelings are aligned, making communication in romantic and social contexts smooth and effective."
            }
        case ("Venus", "Venus"):
            if isHarsh {
                return "You're reassessing what you value in relationships and whether you're getting your needs met. Some dissatisfaction with your love life or social connections might surface. This isn't necessarily bad - it's showing you where your values have evolved. Don't make drastic changes based on temporary dissatisfaction. Use this time to reflect on what you truly want versus what you've settled for. Your values are updating, which can feel uncomfortable but leads to better alignment later."
            } else {
                return "Your sense of values and what brings you pleasure are harmonizing beautifully. This is a lovely time for self-care, enjoying beauty, and treating yourself well. Relationships feel good and you're able to give and receive love freely. Your aesthetic sense is strong - good for decorating, shopping for clothes, or any activity involving beauty and pleasure. You know what you want and you're not afraid to pursue it. Enjoy this period of feeling good about your connections and choices."
            }
            
        // MERCURY - Communication & Thinking
        case ("Mercury", "Sun"), ("Mercury", "Moon"):
            if isHarsh {
                return "Communication challenges are likely during this period. You might find that people misinterpret what you're trying to say, or you may struggle to express yourself clearly. Double-check all important texts and emails before sending them. Take extra time to clarify your meaning in conversations. It's wise to write things down rather than relying on verbal agreements. For particularly important messages or decisions, wait 24 hours before sending or committing. This gives you time to review with fresh eyes. Your thinking might feel scattered or confused, so avoid making major decisions based on current perceptions. This passes quickly."
            } else {
                return "Your mind is exceptionally sharp and clear right now. This is the perfect time for important conversations, negotiations, presentations, or any communication that requires mental clarity. Your ability to articulate your thoughts and ideas is enhanced, making others receptive to what you have to say. Schedule important calls, meetings, or presentations during this period. It's also an excellent time for learning new skills, writing, or any intellectual work. Your mental processing speed is up, so tackle complex problems or projects that require focused thinking. Take advantage of this mental clarity while it lasts."
            }
        case ("Mercury", "Mars"):
            if isHarsh {
                return "Arguments and heated exchanges come more easily than usual. Your words might be sharper or harsher than you intend, leading to conflicts you'll regret later. Before responding in anger, count to ten and consider if what you're about to say will help or hurt the situation. If a conversation becomes heated, take a break and revisit it when emotions have cooled. This isn't the ideal time to 'speak your truth' in confrontational ways - you're likely to be more aggressive than necessary. Channel this mental energy into productive debates or problem-solving rather than personal conflicts."
            } else {
                return "Your wit is quick and your thinking is sharp and decisive. This is excellent energy for speaking up in meetings, making your case, or engaging in productive debates. Your ideas land well with others because you can articulate them clearly and confidently. Great timing for sales calls, negotiating deals, or any situation requiring mental agility and assertiveness. Your ability to think on your feet is enhanced, so don't hesitate to engage in discussions or presentations. Use this mental edge to advance projects or ideas that require clear, confident communication."
            }
        case ("Mercury", "Mercury"):
            if isHarsh {
                return "Your usual way of thinking and communicating is being challenged. You might second-guess how you express yourself or feel like your mental processes aren't working as smoothly as normal. This is actually your mind updating and evolving, though it feels uncomfortable. Don't overthink the overthinking. Give yourself grace if communication feels harder than usual. This mental friction is temporary but leads to better ways of processing and expressing information later."
            } else {
                return "Your mind is refreshed and your communication style feels natural and effective. This is a mental renewal period where your thoughts flow clearly and you express yourself well. Good timing for any intellectual work, writing, learning, or communication that matters to you. Your thinking is aligned with who you're becoming. Take advantage of this mental clarity to tackle projects requiring clear thought and effective communication."
            }
        case ("Mercury", "Venus"):
            if isHarsh {
                return "Slight disconnect between what you think and what you value. Your logic and your heart might be giving you different messages. This minor tension is actually useful - it's showing you where your thoughts and values need integration. Don't force agreement between head and heart. Let them have their conversation. The synthesis that emerges will be more authentic than forcing either side to win."
            } else {
                return "Lovely harmony between your thoughts and your values. You can think clearly about what matters to you and communicate about it effectively. Great for conversations about relationships, money, or anything you care about. Your ability to think and talk about what you value is enhanced. This makes negotiations, relationship discussions, or any communication about what matters to you particularly effective. Your charm and intelligence work together beautifully."
            }
            
        // MARS - Energy & Action
        case ("Mars", "Sun"):
            if isHarsh {
                return "You're experiencing lower energy levels and increased frustration during this period. Your usual drive and confidence might feel depleted, making it harder to assert yourself effectively. Don't push yourself too hard physically - your body needs extra rest right now. Avoid confrontations or competitive situations where you need to be at your best, as you don't have your usual edge or stamina. This is a time for strategic retreat rather than aggressive action. Focus on maintenance rather than starting new initiatives. Conserve your energy and wait for this phase to pass before making major moves or engaging in conflicts. Rest and recuperation serve you better than force."
            } else {
                return "Your energy levels and confidence are peaking right now. This is the ideal time to hit the gym hard, start new projects, or make bold moves you've been contemplating. Your timing is excellent and you have the drive and stamina to back up your ambitions. Take initiative on goals that require courage and sustained effort. Others respond well to your assertiveness during this period. This is your window for physical challenges, starting fitness routines, or tackling projects that require decisive action. Your ability to push through obstacles is enhanced, so don't hesitate to take on challenges that would normally intimidate you."
            }
        case ("Mars", "Mars"):
            if isHarsh {
                return "You're feeling unusually impatient and irritable. Everything feels like it's moving too slowly and you want results immediately. This impatience can lead to rash decisions or unnecessary conflicts if not managed carefully. Practice patience with yourself and others, even when it feels impossible. Don't try to force outcomes or push situations that aren't ready to move forward. Take your aggression out at the gym or through physical activity rather than on people in your life. This is a test of your ability to manage frustration productively. The feeling will pass, but how you handle it now matters for your relationships and goals."
            } else {
                return "This marks a fresh start in terms of your motivation and drive. Your ability to take action and make things happen is renewed. This is the perfect time to begin new fitness routines, start projects you've been putting off, or launch ventures that require sustained energy. Your actions during this period lead to tangible results. You're entering a new cycle of initiative and assertiveness. Take advantage of this motivational boost by committing to goals that matter to you. Your follow-through is strong now, so make commitments you can keep."
            }
        case ("Mars", "Moon"):
            if isHarsh {
                return "Your emotions and your drive are in conflict. You might feel emotionally triggered into reactive behavior or find your feelings are making you more aggressive than usual. There's tension between what you feel and what you want to do about it. Don't act on emotions in the heat of the moment - you'll likely overreact. Give yourself space to feel without immediately acting. This friction between feelings and action is teaching you emotional management. Wait until the intensity passes before taking action on emotional matters."
            } else {
                return "Your emotions and your drive are aligned, giving you courage to act on your feelings. If you've been feeling something strongly, you now have the energy to do something about it. This is excellent for taking action on emotional needs or asserting yourself in personal matters. Your instincts and your ability to act work together well. Trust your gut and follow through. Emotional clarity combined with the courage to act makes this a powerful period for addressing what matters to you personally."
            }
        case ("Mars", "Venus"):
            if isHarsh {
                return "Tension between what you want and how you pursue it. You might be too aggressive in going after pleasure, romance, or what you value. The chase might be overwhelming what you're actually trying to attract. Ease up on the pursuit and let things come to you more naturally. Forcing desire rarely works. This transit asks you to find balance between pursuing what you want and allowing space for it to develop naturally. Passion is high but patience is needed."
            } else {
                return "Perfect alignment between desire and action. What you want and your ability to go after it work beautifully together. This is passionate, motivated energy for pursuing romance, creative projects, or anything you value. Your drive enhances your attractiveness and charm. Take action on desires - your timing and approach are good. This is dynamic energy for both love and creative pursuits. Channel this into making things happen that bring pleasure and fulfillment."
            }
        case ("Mars", "Mercury"):
            if isHarsh {
                return "Mental agitation and argumentative tendencies. Your mind is revved up and ready to fight, which can lead to unnecessary conflicts. Words come out more aggressively than you intend. Your thinking is fast but potentially reckless. Slow down before speaking or deciding. This mental restlessness needs physical outlet - exercise before important conversations. Don't let a racing mind push you into verbal battles you don't actually want. Channel this mental energy into problem-solving rather than arguing."
            } else {
                return "Sharp mind combined with decisive action. You can think quickly and act on your thoughts effectively. This is excellent for any work requiring both mental clarity and physical execution. Great for projects that need both planning and doing. Your ability to think strategically and act boldly is enhanced. Make decisions and implement them. Your mental and physical energies work together productively. Use this to tackle projects requiring both brain and brawn."
            }
            
        // JUPITER - Luck & Growth
        case ("Jupiter", "Sun"), ("Jupiter", "Moon"):
            if isHarsh {
                return "You're feeling more confident than usual, but this can tip into overconfidence if you're not careful. You might be tempted to overpromise on what you can deliver or take on more than you can realistically handle. Avoid gambling or making risky financial decisions based on optimism alone. Your enthusiasm is high, but your judgment about limits and boundaries might be off. Be realistic about your capabilities and don't let excitement cloud your assessment of situations. This phase can lead to overextension if you say yes to everything. Choose your commitments wisely and be honest about what you can actually accomplish."
            } else {
                return "This is one of your luckiest periods, where opportunities seem to appear more easily and things flow in your favor. Your confidence is well-placed and others are receptive to your ambitions. This is ideal timing to apply for jobs you want, ask for raises or promotions, or take calculated risks on ventures that stretch you beyond your comfort zone. Say yes to opportunities that offer growth, even if they feel intimidating. Your ability to expand and succeed is enhanced right now. Good things come more easily during this window, so take advantage of the favorable timing. Trust your instincts about opportunities - they're likely pointing you in the right direction."
            }
        case ("Jupiter", "Venus"):
            if isHarsh {
                return "You're feeling generous and abundant, which can lead to overspending if you're not mindful. The temptation to splurge on luxuries or experiences will be strong. Skip impulse purchases and delay major financial decisions for a few weeks until you have more objectivity. Your social life might also feel expensive as you're drawn to lavish experiences or treating others. Enjoy yourself, but set limits to avoid financial regret later. This is temporary extravagance that seems justified in the moment but might not serve your long-term financial health."
            } else {
                return "Money opportunities and social expansion characterize this period. Your network and social connections are opening doors to new possibilities, both financially and personally. This is good timing to ask for that raise, explore investment opportunities, or expand your income streams. Your charm and likeability are enhanced, making others want to support your success. Network actively and attend social events - you never know which connection might lead to your next opportunity. Your generosity attracts generosity from others. Invest in relationships and opportunities that feel expansive and growth-oriented."
            }
        case ("Jupiter", "Mercury"):
            if isHarsh {
                return "Your mind is overflowing with ideas, but this abundance creates scattered focus. You want to learn everything and start multiple projects simultaneously, which leads to nothing getting finished. Pick ONE thing that matters most and commit to completing it before starting something new. Don't sign up for new courses or training programs until you've finished what you've already started. Your enthusiasm for learning is great, but it needs focus to be productive. Quality over quantity is the lesson here. Resist the temptation to spread yourself intellectually thin."
            } else {
                return "Learning comes exceptionally easily right now. Your mind is absorbing information quickly and making connections between concepts effortlessly. This is an ideal time to take courses, dive into books, or develop new skills. Your understanding is enhanced and you're able to grasp complex topics more readily than usual. Great timing for teaching others or sharing your knowledge, as you can communicate ideas clearly and inspiringly. Explore subjects that interest you - your mind is ready to expand. Study, teach, write, or engage in any intellectual pursuit. Your mental growth potential is maximized."
            }
        case ("Jupiter", "Mars"):
            if isHarsh {
                return "Your energy and confidence are both elevated, but this can lead to overexertion or reckless behavior. Don't overdo workouts or physical activity - your enthusiasm might push you beyond safe limits. Avoid taking unnecessary risks, especially ones that could result in injury. Your judgment about what you can handle physically might be off. Be cautious with impulsive actions that feel exciting in the moment but could have negative consequences. Channel this abundant energy wisely rather than burning out or hurting yourself. Moderation isn't your natural state right now, but it's what's needed."
            } else {
                return "The perfect combination of confidence and action energy. Your drive is high and luck backs up your efforts, creating a powerful window for achievement. Take bold steps on goals that require both courage and sustained effort. Your energy levels are excellent and your timing is good, so don't hold back on initiatives that matter to you. This is the time to go for it - your ability to succeed through decisive action is enhanced. Physical pursuits and ambitious projects both benefit from this dynamic energy. Trust your instincts and act on your convictions. Fortune favors your bold moves right now."
            }
        case ("Jupiter", "Saturn"):
            if isHarsh {
                return "Tension between expansion and contraction, between optimism and realism. You want to grow but feel constrained by responsibilities or limitations. This is actually teaching you sustainable growth - not everything that expands quickly lasts. The friction between wanting more and accepting limits is creating wisdom about realistic ambition. Don't let either extreme win - find the balance between reaching for more and being practical about what's actually achievable. This builds lasting success rather than empty growth."
            } else {
                return "Excellent balance between optimism and realism, between expansion and structure. You can grow in ways that last because you're being both ambitious and practical. This is ideal for long-term planning, building businesses, or any venture requiring both vision and discipline. Your ability to be optimistic while staying grounded creates real, sustainable success. Take advantage of this rare balance - grow with wisdom and structure."
            }
            
        // SATURN - Responsibility & Hard Work
        case ("Saturn", "Sun"), ("Saturn", "Mars"):
            if isHarsh {
                return "Work and responsibilities feel particularly heavy during this period. Authority figures may be testing you, or you're facing significant delays and obstacles in reaching your goals. This is a character-building phase that requires persistence and patience. Don't quit now, even though it feels hard - the lessons you're learning are strengthening your foundation for future success. Results take longer than you'd like, but they will come. This is about proving yourself through sustained effort rather than quick wins. Keep pushing forward methodically. The difficulty is temporary, but the strength you build lasts."
            } else {
                return "Your hard work and discipline are finally paying off. This is a period where recognition, promotions, or tangible career advancement become possible. Others are noticing your consistent effort and reliability. This is ideal timing for building foundations that will serve you long-term. Establish your authority in your field or take on leadership responsibilities. Commit to structures and systems that support your long-term goals. Your ability to be taken seriously and build something lasting is enhanced. Make investments (time, energy, resources) in your future during this favorable window."
            }
        case ("Saturn", "Moon"):
            if isHarsh {
                return "You're experiencing emotional heaviness or a sense of isolation. Your feelings might seem darker or more serious than usual, and you could feel lonely even when surrounded by people. This can be a tough period emotionally. Reach out to friends or family even when you don't feel like it - connection helps. If the heaviness persists or becomes overwhelming, consider seeing a therapist. This phase is teaching you about your emotional needs and boundaries, but it doesn't feel good in the moment. Remember this is temporary. The feelings will lift, but addressing what they're showing you is important."
            } else {
                return "You're developing emotional maturity and stability. Your feelings become more grounded and reliable, helping you make better decisions. This is an excellent time to set healthy boundaries in relationships or establish patterns that support your emotional wellbeing. You're learning to take your emotional needs seriously without being controlled by passing moods. This is about building emotional resilience and learning to parent yourself effectively. The groundwork you lay now for emotional health pays dividends for years. Take your feelings seriously and create structures that honor them."
            }
        case ("Saturn", "Venus"):
            if isHarsh {
                return "Relationships are being tested. Commitment issues, fears about intimacy, or questions about whether you're with the right person may surface. This isn't the time to make permanent decisions like breakups or divorces - you're seeing through a critical lens that might be too harsh. Instead, use this period to work through problems and address what's not working. Couples therapy can be particularly helpful now. The test is whether you can work through difficulties rather than run from them. Reassess after this phase passes. Some relationships won't survive this test, and that's information, but don't act hastily."
            } else {
                return "Serious relationships deepen and strengthen during this period. You're ready for greater commitment and can handle the responsibilities that come with it. This is favorable timing for engagements, defining relationship expectations, or making long-term plans together. You're building something lasting rather than just enjoying surface-level connection. Your ability to be realistic and mature in relationships is enhanced. Take relationships seriously and invest in ones that have real potential. This is about quality and commitment rather than casual connection."
            }
        case ("Saturn", "Mercury"):
            if isHarsh {
                return "You're experiencing mental blocks, self-doubt about your intelligence, or difficulty learning new material. Your mind feels slower or more critical than usual. Push through the resistance and study anyway - this is building mental discipline that will serve you later. Don't let self-doubt stop you from engaging with challenging material. The difficulty is the point - you're developing intellectual rigor and persistence. Your thinking might be more pessimistic or critical, so balance this by noting your progress. This mental challenge is temporary but valuable for long-term intellectual growth."
            } else {
                return "Your thinking is unusually focused and serious, perfect for long-term study, detailed writing, or structured planning. Your concentration is strong and you can handle complex, challenging material. This is ideal for academic work, research, or any mental task requiring sustained attention and discipline. You're able to think through problems methodically and create logical structures. Your communication takes on more authority and people take your ideas seriously. Use this period for intellectual work that requires depth and rigor. Build knowledge and skills that will serve you long-term."
            }
        case ("Saturn", "Jupiter"):
            if isHarsh {
                return "Growth feels blocked or slowed by practical realities. Your ambitions meet resistance from circumstances or limitations. This isn't punishment - it's teaching you sustainable growth. Fast expansion without foundation crumbles. The delays and obstacles are ensuring what you build lasts. Trust the process even when it feels frustrating. Real success requires both vision and structure. This transit is providing the structure, even though it's uncomfortable."
            } else {
                return "Disciplined expansion and structured growth. You can build something that lasts because you're combining optimism with realism. This is excellent for long-term business planning, education that requires commitment, or any ambition that needs both vision and practical execution. Your dreams meet reality in productive ways. Take advantage of this to lay foundations for lasting success."
            }
            
        // URANUS - Sudden Change & Freedom  
        case ("Uranus", "Sun"):
            if isHarsh {
                return "You're experiencing intense restlessness and a strong need for freedom or change. Your identity is evolving in ways that feel uncomfortable, and you might feel trapped by current circumstances. Don't quit your job or make other major life changes impulsively during this phase - these feelings are important signals but need thoughtful action, not reactive decisions. Make changes gradually and deliberately. The discomfort you feel is actually your authentic self trying to emerge. This period is showing you where you've been living according to others' expectations rather than your own truth. Your identity is being updated - that's good, even though it's unsettling."
            } else {
                return "You're experiencing a breakthrough in self-expression and authenticity. This is your time to try something new and different, to express parts of yourself you've kept hidden. Others are surprisingly receptive to your uniqueness right now - they appreciate rather than judge what makes you different. Break free from old patterns that no longer fit who you're becoming. Experiment with new ways of being and presenting yourself. Your courage to be authentic inspires others. This is a liberation period where you get to discover and express more of who you really are."
            }
        case ("Uranus", "Moon"):
            if isHarsh {
                return "Your emotional life feels unpredictable right now, with unexpected mood shifts and ups and downs. Your usual emotional patterns are being disrupted, which can feel destabilizing. Give yourself extra space and grace during this period. Don't make big decisions when you're in an emotional state - wait for stability to return before acting. This disruption is actually freeing you from old emotional patterns that were limiting you, but the process doesn't feel comfortable. The mood swings will stabilize, but what you're learning about your real emotional needs matters. Honor your need for emotional freedom and authenticity."
            } else {
                return "You're having emotional breakthroughs and powerful intuitive hits. Sudden clarity about your feelings and what you truly need emotionally is emerging. Trust your gut instincts right now - they're showing you truth. Your intuition is particularly strong and you're receiving insights about your emotional patterns that help you break free from old limitations. Honor your authentic emotional needs even if they differ from what you thought you needed. This is about emotional liberation and discovering what actually makes you feel secure and fulfilled."
            }
        case ("Uranus", "Venus"):
            if isHarsh {
                return "Unexpected developments in relationships or sudden attractions to people who are different from your usual type. Your values and relationship needs are shifting. Don't blow up stable relationships just because you're craving excitement or novelty - but if changes happen, stay flexible and let them unfold. You're discovering what you truly value versus what you thought you were supposed to value. Sudden attractions might be showing you qualities you need to develop in yourself. This period brings relationship surprises that reveal your evolving needs. Work with the changes rather than resisting them."
            } else {
                return "Exciting social encounters and unique attractions characterize this period. You're meeting new types of people who expand your social world in unexpected ways. Your social life becomes more interesting and diverse. Be open to connections with people who are different from your usual circle - they bring fresh perspectives and opportunities. Your attractiveness to others increases when you're being your authentic self. Unique or unconventional relationships and friendships are favored now. Embrace the social excitement and expanded social network."
            }
        case ("Uranus", "Mars"):
            if isHarsh {
                return "You're experiencing impulsive, reckless energy that wants immediate action and change. Don't make sudden moves you'll regret later, especially if they're motivated by impatience or rebellion. Your desire for freedom and action is strong, but hasty decisions now could create problems you don't want. Channel this restless energy into exercise, creative projects, or productive changes rather than creating drama or conflict. The urge to shake things up is real, but wisdom lies in directing this energy constructively. Take calculated risks rather than impulsive ones. Your courage is high but your judgment might be off."
            } else {
                return "This is perfect energy for bold, innovative action. You have the courage to try new approaches and take calculated risks that others won't. Your willingness to be the pioneer and do things differently opens doors for you. Take action on ideas or projects that require both bravery and innovation. Others respect your courage and originality. This is your time to lead through action rather than follow conventional paths. Trust your instincts about trying new methods or approaches. Your bold moves work out favorably when backed by this breakthrough energy."
            }
        case ("Uranus", "Mercury"):
            return "You're experiencing mental breakthroughs and innovative ideas. Your thinking has shifted outside the box in ways that give you fresh perspectives on old problems. Write these ideas down - they're valuable insights you don't want to lose. This is excellent timing for learning new technologies, methods, or ways of thinking. Your mind is being upgraded with new mental frameworks and understandings. Don't dismiss unconventional ideas that come to you now - they might sound strange but hold real innovation. Study subjects that challenge your usual thinking. Your mental flexibility and originality are peaking."
        case ("Uranus", "Jupiter"):
            if isHarsh {
                return "Restlessness about growth and expansion. You want breakthrough success NOW but might take reckless risks to get it. Your desire for freedom and expansion can lead to impulsive decisions about opportunities. Not every exciting possibility is a good one. This transit tempts you with shortcuts that might not pan out. Be discerning about which opportunities to pursue. The restlessness is real but requires wisdom rather than just action. Breakthrough and growth are possible but need thoughtful rather than impulsive pursuit."
            } else {
                return "Exciting opportunities for growth and expansion through unconventional means. Your willingness to try new approaches opens unexpected doors. This is excellent for innovative ventures, learning cutting-edge subjects, or expanding in ways others haven't considered. Your optimism combines with originality to create real breakthroughs. Say yes to opportunities that are different from the usual path. Your luck runs toward the unconventional during this period. Be bold and experimental with growth opportunities."
            }
        case ("Uranus", "Saturn"):
            if isHarsh {
                return "Intense friction between the need for change and the weight of responsibilities. You want freedom but feel trapped by obligations or circumstances. This is one of the more challenging transits - the tension between structure and liberation can feel unbearable. Don't blow up your life impulsively, but also don't resign yourself to permanent constraint. This is teaching you how to create freedom within responsibility. Find ways to change your circumstances gradually rather than destroying what you've built. The breakthrough comes through patient revolution, not explosive rebellion."
            } else {
                return "Rare ability to restructure your life in innovative ways. You can change established patterns and create new structures that give you more freedom. This is excellent for reorganizing your career, life circumstances, or responsibilities in ways that work better for who you're becoming. Disciplined change and structured innovation are possible. You're able to be both responsible and authentic, both stable and free. Take advantage of this window to rebuild aspects of your life that no longer fit."
            }
            
        // NEPTUNE - Intuition & Confusion
        case ("Neptune", "Sun"), ("Neptune", "Moon"):
            if isHarsh {
                return "You're experiencing confusion about your direction or identity. Things that seemed clear before now feel foggy or uncertain. Don't make major life decisions during this period - your perception is clouded and you're not seeing things accurately. Journal about your feelings and meditate to stay grounded. Wait for clarity to return before taking action on important matters. Avoid escapism through substances, excessive media consumption, or other numbing behaviors - they'll make the confusion worse. This fog is actually dissolving illusions you've been holding onto. What emerges after the fog clears will be more authentic, but you have to wait it out. Trust that clarity will return."
            } else {
                return "Your intuition and creative inspiration are flowing strongly. Trust your gut instincts - they're picking up on subtle truths your rational mind can't access. This is an excellent time to pursue artistic or spiritual interests, as your sensitivity and imagination are heightened. Your empathy and compassion are enhanced, helping you connect with others on a deeper level. Creative projects benefit from this inspired energy. Meditation, spiritual practices, and artistic expression all help you channel this energy productively. Your ability to sense and feel is a gift right now - honor it by engaging with beauty, creativity, and connection."
            }
        case ("Neptune", "Venus"):
            if isHarsh {
                return "You're wearing rose-colored glasses in love and relationships. You might be idealizing someone beyond who they really are, seeing their potential rather than their reality. Be especially careful with new romantic interests during this period - verify that their actions match their words over time. Don't make major relationship commitments based on feelings alone right now. Your perception of people is clouded by wishful thinking. This doesn't mean your feelings aren't real, but your judgment about whether someone is right for you might be off. Take your time and let reality reveal itself before making decisions. Protect yourself from deception or self-deception."
            } else {
                return "Romantic idealism and artistic inspiration flow beautifully during this period. Your heart is open and you're able to love without cynicism. Beautiful connections are possible when you lead with compassion and creativity. This is excellent energy for creating art, music, poetry, or any creative expression that comes from the heart. Spiritual connections in relationships are highlighted - you're able to see the divine in others. Unconditional love feels natural. Your capacity for romance, beauty, and artistic creation is enhanced. Let your heart guide your creative or relationship choices during this inspired period."
            }
        case ("Neptune", "Mercury"):
            if isHarsh {
                return "Confusion, potential deception, or miscommunication are likely during this period. Your usually clear thinking might be foggy or prone to misunderstandings. Read all fine print carefully before signing anything. People might lie to you, or you might misinterpret what they're saying. Get important agreements in writing rather than relying on verbal promises. Your perception and judgment are clouded right now, making you vulnerable to deception or self-deception. Double-check facts before accepting them as true. This is not ideal timing for important decisions requiring clear thinking. Wait for clarity to return before committing to major plans."
            } else {
                return "Your thinking is creative and intuitive rather than purely logical. This is excellent for artistic projects, writing fiction, poetry, or any creative work requiring imagination. Spiritual studies and mystical subjects interest you and make sense in ways they might not usually. Your imagination is vivid and your ability to think in symbols and images is enhanced. Use this for creative rather than analytical work. Let your intuition guide your thinking - it's picking up on things logic can't access. This is about inspired rather than rational thought. Channel this into art, creativity, or exploring spiritual topics."
            }
        case ("Neptune", "Mars"):
            if isHarsh {
                return "Your energy feels low or misdirected. It's hard to know what you really want or where to direct your efforts. Actions you take might not lead to the results you expect. Rest more than usual and don't push yourself physically when your energy is low. Avoid making major moves or starting big projects until you have more clarity about your goals and direction. This is a period of uncertainty about how to assert yourself effectively. The fog will lift and your direction will clarify, but for now, conserve energy and wait for clearer signals. Forcing action when you're uncertain usually leads nowhere productive."
            } else {
                return "Inspired action and creative drive characterize this period. Your energy is best channeled into artistic pursuits, dance, music, spiritual practices, or creative projects. Move with flow rather than force - let intuition guide your actions. Your ability to act on inspiration is enhanced, and pursuing creative or spiritual goals feels natural. This isn't about aggressive action but about graceful, inspired movement toward your goals. Physical activities that combine movement with mindfulness (like yoga, dance, or tai chi) are especially favored. Channel your energy creatively and spiritually rather than competitively. Your inspired actions lead to beautiful results."
            }
        case ("Neptune", "Jupiter"):
            if isHarsh {
                return "Excessive idealism and potential for self-deception about opportunities. Everything seems possible and every opportunity seems blessed, which can lead to poor judgment. Your optimism might be divorced from reality. Be especially careful with financial decisions, spiritual teachers, or opportunities that promise too much. If something seems too good to be true, it probably is. Ground your dreams in practical reality. This transit can create beautiful visions but also delusions. Stay anchored in facts while allowing inspiration."
            } else {
                return "Beautiful blend of faith and optimism. Your spiritual and creative life expands with genuine inspiration. This is excellent for artistic or spiritual pursuits, as your imagination and your faith work together harmoniously. Compassionate opportunities and meaningful connections flow naturally. Your capacity for unconditional love and spiritual understanding is enhanced. This is also favorable for creative projects that require both vision and inspiration. Let your heart and imagination guide you toward beauty and meaning."
            }
        case ("Neptune", "Saturn"):
            if isHarsh {
                return "Tension between dreams and reality, between what you want and what's actually possible. Your ideals meet harsh practical limitations. This can feel disillusioning, but it's actually showing you which dreams are worth pursuing and which need to be released. Not all visions are meant to manifest. This transit separates fantasy from achievable vision. It's uncomfortable but necessary. Let go of impossible dreams while committing to ones that can actually be built in reality. Grounded spirituality emerges from this difficult but valuable process."
            } else {
                return "Rare ability to manifest dreams through disciplined effort. Your visions meet practical structure in productive ways. This is excellent for building spiritual practices, creating art with discipline, or turning ideals into reality through sustained work. You can give form to inspiration and structure to dreams. Use this period to create something lasting from your visions. Your imagination and your discipline work together beautifully. Build the dream rather than just dreaming it."
            }
            
        // PLUTO - Major Transformation
        case ("Pluto", "Sun"), ("Pluto", "Moon"):
            if isHarsh {
                return "You're undergoing major life changes and an intensely transformative period. Your old identity or way of being is dying to make room for something new and more authentic. This is deep, sometimes difficult work that affects you at your core. Consider seeing a therapist to help you process what you're experiencing - this transformation goes beyond what you can easily handle alone. Parts of your life that no longer serve your evolution are ending, and while this feels intense or even frightening, it's necessary. You're being reborn into a more authentic version of yourself. The intensity passes, and you'll emerge significantly stronger and more powerful than before. This is your deepest transformation."
            } else {
                return "Your personal power is increasing dramatically. You're transforming in profound ways and your presence becomes more magnetic and impactful. Others sense your depth and intensity. This is your time to step into leadership and use your power wisely and responsibly. You have the strength to tackle challenges others can't handle. Your ability to transform yourself and situations is enhanced. Use this power constructively rather than manipulatively. You're being given access to deeper reservoirs of strength and influence. How you wield this power matters. Channel it toward meaningful transformation in your life and potentially in others' lives too."
            }
        case ("Pluto", "Venus"):
            if isHarsh {
                return "Relationship dynamics become intensely transformative. Power struggles, jealousy, possessiveness, or control issues surface in ways that demand honest examination. Hidden dynamics in relationships are exposed and must be faced directly. This is uncomfortable but necessary transformation. Issues around intimacy, trust, and vulnerability require honest work. Consider couples counseling if you're in a relationship - these dynamics are deep and benefit from professional help. Some relationships won't survive this transformation, and that's sometimes the right outcome if they're built on unhealthy foundations. Face what's there honestly rather than avoiding the intensity. Transformation is required for relationships to continue."
            } else {
                return "Deep, transformative connections become possible. Attractions you experience now go beyond surface-level - they touch something profound. Relationships intensify in positive ways, with greater intimacy, passion, and depth. This is a particularly passionate period for committed couples who are willing to go deeper emotionally and physically. Your capacity for profound connection is enhanced. Shallow relationships lose appeal while deep ones become more meaningful. This is about transformative love that changes both people. Magnetic attractions and powerful connections characterize this period. Embrace the depth and intensity - it leads to real intimacy."
            }
        case ("Pluto", "Mars"):
            if isHarsh {
                return "Power struggles and control battles emerge in various areas of your life. You want control but circumstances or other people resist. Don't try to force outcomes or win through domination - it backfires during this period. Learning when to let go of what you can't control is the challenge. Your intensity is high and can be overwhelming to others or create conflicts. Channel this intense energy into workouts, major projects, or transformation rather than trying to control people or situations. The intensity you feel needs constructive outlets. Accept what you cannot control and focus your power where you can make real change."
            } else {
                return "Your drive and determination reach maximum levels. You have unstoppable willpower right now - nothing stands in your way when you commit fully. This is the time to tackle your biggest, most ambitious projects or goals. Your ability to persist through any obstacle is enhanced. Use this powerful period to transform areas of your life that require sustained, intense effort. Your capacity to focus your will and make things happen is unmatched. Channel this formidable energy toward meaningful goals. What you commit to now, you can accomplish through sheer force of will and determination. This is your power period for action."
            }
        case ("Pluto", "Mercury"):
            if isHarsh {
                return "Your thinking becomes obsessive or intensely focused on certain topics. Your mind might spiral into dark or consuming thoughts that are hard to escape. Take breaks from intense thinking and don't let yourself get lost in mental loops. Talk things out with someone you trust rather than staying stuck in your head. Your mind needs rest from its own intensity. Obsessive thoughts or paranoid thinking can emerge if you're not careful. This mental intensity passes, but while it's here, manage it by stepping away from the topics that consume you. Balance intense thinking with rest and external connection."
            } else {
                return "Your research and investigation abilities are razor-sharp. You can get to the bottom of complex topics others can't penetrate. Your focus is laser-sharp and your ability to dig deep into subjects is unmatched. This is perfect for research, investigation, psychology, or any field requiring deep analysis. Your mind penetrates beneath surfaces to find hidden truths. Use this period for work requiring concentrated mental effort and the ability to uncover what's hidden. Your thinking is profound rather than superficial. Dive deep into subjects that fascinate you - your capacity to understand complexity is maximized. This is your detective mind at its best."
            }
        case ("Pluto", "Jupiter"):
            if isHarsh {
                return "Power struggles around beliefs, growth, or opportunities. Your ambitions meet forces beyond your control, creating frustration about expansion. This is teaching you that not all growth is meant to happen, and some paths aren't yours to walk. The obstacles aren't punishment - they're redirection toward transformations that actually serve your evolution. Let go of trying to force growth that meets resistance. Trust that what's meant to expand in your life will, and what's blocked might be protecting you from wrong directions."
            } else {
                return "Powerful expansion and transformative growth. Your ability to grow and transform at the same time creates profound positive change. This is excellent for ambitious ventures that require both vision and the courage to go deep. Your capacity for meaningful growth - not just surface expansion - is enhanced. Pursue opportunities that transform you while expanding you. Your power and your optimism work together to create real, lasting success. This is growth with depth and substance."
            }
        case ("Pluto", "Saturn"):
            if isHarsh {
                return "Extremely challenging period where structures break down and responsibilities feel crushing. This is one of the hardest transits - the intensity of transformation meets the weight of reality. Old structures that no longer serve must be destroyed to build new ones, but this process is neither quick nor comfortable. This builds character through endurance of difficulty. Professional help is recommended - a therapist can help you process what feels overwhelming. What emerges from this crucible is authentic power and real authority, but getting there requires facing and moving through genuine hardship."
            } else {
                return "Rare ability to build lasting structures from profound transformation. You can take power and give it form, take transformation and create something enduring from it. This is excellent for building businesses, careers, or life structures that have both depth and staying power. Your discipline meets your capacity for deep change productively. Use this to create something significant that lasts. The foundation you build during this period has genuine substance and transformative power. This is about building empire from authentic strength."
            }
        case ("Pluto", "Uranus"):
            return "Revolutionary transformation and breakthrough change occurring simultaneously. This is intense, unpredictable energy that's dismantling old patterns and creating space for radical authenticity. You're being liberated and transformed at the same time. This can feel chaotic but it's profoundly freeing. Old structures break down to make room for new, more authentic ways of being. Don't resist the changes - they're necessary evolution. This transit asks you to trust the process of simultaneous destruction and liberation. What emerges is more real and more free than what came before."
        case ("Pluto", "Neptune"):
            return "Deep spiritual transformation and dissolution of old ways of seeing reality. Your understanding of life, spirituality, and meaning is being profoundly altered. Old beliefs dissolve to make room for deeper truth. This can feel destabilizing - what you thought you knew about spirituality or meaning might need to be released. Trust the process of spiritual transformation even when it's confusing. What emerges is more authentic faith and deeper understanding. This is about spiritual rebirth, not spiritual death. Let old illusions go so truth can emerge."
            
        // Generic fallback
        default:
            if isHarsh {
                return "Challenging period requiring patience and adaptability. Work through obstacles. This strengthens you. Don't make hasty decisions."
            } else {
                return "Favorable period for growth. Take advantage of opportunities. Things flow more easily now. Make progress on goals."
            }
        }
    }
    
    private func generateGenericCycleDescription(transitPlanet: CelestialBody, natalPlanet: CelestialBody, aspectType: AspectType, sunSign: ZodiacSign) -> String {
        let planetMeanings: [String: String] = [
            "Jupiter": "growth and opportunity",
            "Saturn": "discipline and responsibility", 
            "Uranus": "innovation and awakening",
            "Neptune": "intuition and transcendence",
            "Pluto": "transformation and regeneration",
            "Venus": "love and beauty",
            "Mars": "action and courage"
        ]
        
        let natalMeanings: [String: String] = [
            "Sun": "your core identity",
            "Moon": "your emotional world",
            "Mercury": "your mind and communication",
            "Venus": "your relationships and values",
            "Mars": "your energy and drive"
        ]
        
        let transitMeaning = planetMeanings[transitPlanet.name] ?? "cosmic energy"
        let natalMeaning = natalMeanings[natalPlanet.name] ?? "your nature"
        
        switch aspectType {
        case .conjunction:
            return "You're experiencing an intense merging of \(transitMeaning) with \(natalMeaning). A new cycle begins with powerful potential for transformation. \(sunSign.rawValue), this is your moment to embrace what's being born in your life. Stay present with this powerful shift."
        case .trine:
            return "You're flowing naturally with \(transitMeaning) enhancing \(natalMeaning). Your natural talents are working without resistance. This is a time to embrace ease and let things unfold organically. Trust what comes naturally to you now."
        case .sextile:
            return "You'll find opportunities emerging around \(transitMeaning) that support \(natalMeaning). Gentle progress is available through conscious effort. Take action on the possibilities you're sensing—they're aligned with your path."
        case .square:
            return "You're facing challenges with \(transitMeaning) creating productive tension around \(natalMeaning). \(sunSign.rawValue), this friction is your growth edge. Every obstacle you overcome now builds lasting strength. Persist through the resistance."
        case .opposition:
            return "You're being called to find balance between \(transitMeaning) and \(natalMeaning). This illumination reveals where integration is needed. The tension you feel is showing you what needs to be brought into harmony. Seek the middle path."
        }
    }
    
    private func getCycleInfluence(aspectType: AspectType, transitPlanet: String) -> AstrologicalCycle.CycleInfluence {
        switch aspectType {
        case .conjunction, .trine:
            return .positive
        case .sextile:
            return transitPlanet == "Jupiter" ? .positive : .neutral
        case .square:
            return ["Saturn", "Pluto"].contains(transitPlanet) ? .challenging : .transformative
        case .opposition:
            return .transformative
        }
    }
    
    private func calculateCycleProgress(transitPlanet: CelestialBody, natalPlanet: CelestialBody, aspectType: AspectType) -> Double {
        // Calculate how close the aspect is to exact
        let angle = abs(transitPlanet.longitude - natalPlanet.longitude)
        let normalizedAngle = angle > 180 ? 360 - angle : angle
        let exactAngle = aspectType.angle
        let orb = aspectType.orb
        
        // How far from exact (0 = exact, orb = at edge)
        let distanceFromExact = abs(normalizedAngle - exactAngle)
        
        // Progress: aspects start forming (0%), become exact (50%), then separate (100%)
        // If we're within orb, calculate progress based on planet's motion direction
        if distanceFromExact < orb {
            // If planet is moving forward (positive speed), it's applying (forming) = 0.2-0.5
            // If it's close to exact = 0.4-0.6
            // If moving away (would need ephemeris to know) = 0.6-0.9
            
            if distanceFromExact < 1.0 {
                // Very close to exact - peak of cycle
                return 0.45 + (Double.random(in: 0...0.1))
            } else {
                // Calculate based on how far through the orb
                let orbProgress = distanceFromExact / orb
                // Assuming we're in the applying phase for outer planets
                if ["Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"].contains(transitPlanet.name) {
                    return 0.3 + (orbProgress * 0.3) // 0.3 to 0.6
                } else {
                    // Fast planets - assume further through cycle
                    return 0.5 + (orbProgress * 0.3) // 0.5 to 0.8
                }
            }
        }
        
        // Default fallback
        return 0.4
    }
    
    // MARK: - Monthly Score Calculations
    
    private func calculateMonthlyOverallScore(chart: BirthChart, transits: [CelestialBody], aspects: [Aspect], date: Date) -> Int {
        var score = 50 // Neutral monthly baseline
        
        // === MONTHLY FOCUS: MAJOR LIFE THEME TRANSITS ===
        
        // Saturn monthly themes - life structure and major lessons
        if let saturnTransit = transits.first(where: { $0.name == "Saturn" }) {
            let saturnToSun = abs(saturnTransit.longitude - chart.sun.longitude)
            let normalizedSaturn = saturnToSun > 180 ? 360 - saturnToSun : saturnToSun
            
            if normalizedSaturn < 8 { // Saturn return or conjunction
                score -= 15 // Major monthly life restructuring
            } else if (82...98).contains(normalizedSaturn) { // Square
                score -= 20 // Monthly challenges and obstacles
            } else if (172...188).contains(normalizedSaturn) { // Opposition
                score -= 12 // Monthly external pressure
            } else if (112...128).contains(normalizedSaturn) { // Trine
                score += 20 // Monthly earned achievements
            } else if (52...68).contains(normalizedSaturn) { // Sextile
                score += 12 // Monthly steady progress
            }
        }
        
        // Jupiter monthly expansion - major opportunities and growth
        if let jupiterTransit = transits.first(where: { $0.name == "Jupiter" }) {
            let jupiterToSun = abs(jupiterTransit.longitude - chart.sun.longitude)
            let normalizedJupiter = jupiterToSun > 180 ? 360 - jupiterToSun : jupiterToSun
            
            if normalizedJupiter < 8 { // Jupiter return (every 12 years)
                score += 25 // Major monthly expansion cycle
            } else if (112...128).contains(normalizedJupiter) { // Trine
                score += 20 // Monthly flowing abundance
            } else if (52...68).contains(normalizedJupiter) { // Sextile
                score += 15 // Monthly growth opportunities
            } else if (82...98).contains(normalizedJupiter) { // Square
                score -= 8 // Monthly overexpansion problems
            } else if (172...188).contains(normalizedJupiter) { // Opposition
                score -= 5 // Monthly excess or conflicts
            }
        }
        
        // Uranus monthly revolution - sudden major changes
        if let uranusTransit = transits.first(where: { $0.name == "Uranus" }) {
            let uranusToSun = abs(uranusTransit.longitude - chart.sun.longitude)
            let normalizedUranus = uranusToSun > 180 ? 360 - uranusToSun : uranusToSun
            
            if normalizedUranus < 8 { // Uranus conjunction
                score -= 10 // Monthly life revolution
            } else if (82...98).contains(normalizedUranus) { // Square
                score -= 18 // Monthly shocking disruptions
            } else if (172...188).contains(normalizedUranus) { // Opposition
                score -= 12 // Monthly external upheaval
            } else if (112...128).contains(normalizedUranus) { // Trine
                score += 15 // Monthly positive breakthroughs
            } else if (52...68).contains(normalizedUranus) { // Sextile
                score += 10 // Monthly innovative opportunities
            }
        }
        
        // Neptune monthly themes - spiritual, confusion, inspiration
        if let neptuneTransit = transits.first(where: { $0.name == "Neptune" }) {
            let neptuneToSun = abs(neptuneTransit.longitude - chart.sun.longitude)
            let normalizedNeptune = neptuneToSun > 180 ? 360 - neptuneToSun : neptuneToSun
            
            if normalizedNeptune < 8 { // Neptune conjunction
                score -= 10 // Monthly ego dissolution and confusion
            } else if (82...98).contains(normalizedNeptune) { // Square
                score -= 15 // Monthly deception, addiction, illusion
            } else if (172...188).contains(normalizedNeptune) { // Opposition
                score -= 8 // Monthly reality vs dreams conflict
            } else if (112...128).contains(normalizedNeptune) { // Trine
                score += 12 // Monthly spiritual inspiration
            } else if (52...68).contains(normalizedNeptune) { // Sextile
                score += 8 // Monthly creative intuition
            }
        }
        
        // Pluto monthly transformation - deep psychological changes
        if let plutoTransit = transits.first(where: { $0.name == "Pluto" }) {
            let plutoToSun = abs(plutoTransit.longitude - chart.sun.longitude)
            let normalizedPluto = plutoToSun > 180 ? 360 - plutoToSun : plutoToSun
            
            if normalizedPluto < 8 { // Pluto conjunction
                score -= 20 // Monthly total life transformation
            } else if (82...98).contains(normalizedPluto) { // Square
                score -= 25 // Monthly power struggles and crisis
            } else if (172...188).contains(normalizedPluto) { // Opposition
                score -= 18 // Monthly external power conflicts
            } else if (112...128).contains(normalizedPluto) { // Trine
                score += 18 // Monthly empowerment and regeneration
            } else if (52...68).contains(normalizedPluto) { // Sextile
                score += 12 // Monthly deep positive change
            }
        }
        
        // Mars monthly energy patterns
        if let marsTransit = transits.first(where: { $0.name == "Mars" }) {
            let marsToSun = abs(marsTransit.longitude - chart.sun.longitude)
            let normalizedMars = marsToSun > 180 ? 360 - marsToSun : marsToSun
            
            if normalizedMars < 8 { // Mars return (every 2 years)
                score += 10 // Monthly energy renewal
            } else if (82...98).contains(normalizedMars) { // Square
                score -= 10 // Monthly conflicts and impatience
            } else if (172...188).contains(normalizedMars) { // Opposition
                score -= 8 // Monthly external confrontations
            } else if (112...128).contains(normalizedMars) { // Trine
                score += 12 // Monthly productive energy
            }
        }
        
        // === MONTHLY SEASONAL AND PERSONAL CYCLES ===
        let month = Calendar.current.component(.month, from: date)
        
        // Seasonal energy patterns
        switch month {
        case 1: score += 8 // New Year renewal energy
        case 2: score += 5 // Winter contemplation
        case 3: score += 10 // Spring awakening
        case 4, 5: score += 12 // Growth and expansion months
        case 6: score += 8 // Peak spring energy
        case 7, 8: score += 6 // Summer intensity (can be draining)
        case 9: score += 10 // Harvest and new beginnings
        case 10: score += 8 // Transformation month
        case 11: score += 5 // Deep introspection
        case 12: score += 7 // Completion and reflection
        default: break
        }
        
        // Personal monthly variation based on birth chart
        let monthlyPersonalization = Int((chart.sun.longitude + chart.moon.longitude + Double(month * 30)).truncatingRemainder(dividingBy: 20)) - 10
        score += monthlyPersonalization
        
        return max(5, min(95, score))
    }
    
    private func calculateMonthlyLoveScore(chart: BirthChart, transits: [CelestialBody], aspects: [Aspect], date: Date) -> Int {
        var score = 75 // Base monthly love score
        
        // Venus monthly cycle
        if let venus = transits.first(where: { $0.name == "Venus" }) {
            let venusSignInfo = ZodiacSign.fromDegrees(venus.longitude)
            let venusSign = venusSignInfo.sign
            
            // Venus sign compatibility with natal placements
            if venusSign == chart.sunSign || venusSign == chart.moonSign {
                score += 20 // Perfect alignment
            } else if venusSign.element == chart.sunSign.element {
                score += 15 // Harmonious element
            } else if venusSign.element == chart.moonSign.element {
                score += 12 // Emotional harmony
            }
        }
        
        // 5th house influences (romance)
        let fifthHouseCusp = (getHouseCusp(from: chart, house: 5) ?? 0)
        if let jupiter = transits.first(where: { $0.name == "Jupiter" }) {
            let jupiterTo5thHouse = abs(jupiter.longitude - fifthHouseCusp)
            if jupiterTo5thHouse < 15 {
                score += 12 // Romantic expansion
            }
        }
        
        // Monthly love energy based on season with personalization
        let month = Calendar.current.component(.month, from: date)
        switch month {
        case 2, 6, 10: score += 8 // Romance peak months
        case 4, 5: score += 10 // Spring love energy
        case 12, 1: score += 6 // Winter intimacy
        default: score += 7
        }
        
        // Add Venus-based personalization for love
        let lovePersonalization = (chart.venus.longitude + Double(month * 15)).truncatingRemainder(dividingBy: 12) - 6
        score += Int(lovePersonalization)
        
        return max(5, min(95, score))
    }
    
    private func calculateMonthlyCareerScore(chart: BirthChart, transits: [CelestialBody], aspects: [Aspect], date: Date) -> Int {
        var score = 78 // Base monthly career score
        
        // Saturn monthly influences (career structure)
        if let saturn = transits.first(where: { $0.name == "Saturn" }) {
            let saturnToMC = abs(saturn.longitude - (getHouseCusp(from: chart, house: 10) ?? 0))
            if saturnToMC < 15 || (105...135).contains(saturnToMC) {
                score += 15 // Career advancement
            } else if (75...105).contains(saturnToMC) {
                score += 5 // Steady progress through effort
            }
        }
        
        // Uranus influences (career innovation)
        if let uranus = transits.first(where: { $0.name == "Uranus" }) {
            let uranusToSun = abs(uranus.longitude - chart.sun.longitude)
            if uranusToSun < 8 || (52...68).contains(uranusToSun) {
                score += 12 // Career breakthrough
            }
        }
        
        // Monthly professional energy with personalization
        let month = Calendar.current.component(.month, from: date)
        switch month {
        case 1, 9: score += 12 // New beginning months
        case 3, 4, 10: score += 10 // High productivity
        case 7, 8: score += 5 // Summer slow down
        case 11, 12: score += 8 // Year-end push
        default: score += 7
        }
        
        // Add Mars-based career personalization
        let careerPersonalization = (chart.mars.longitude + Double(month * 20)).truncatingRemainder(dividingBy: 14) - 7
        score += Int(careerPersonalization)
        
        return max(5, min(95, score))
    }
    
    private func calculateMonthlyWealthScore(chart: BirthChart, transits: [CelestialBody], aspects: [Aspect], date: Date) -> Int {
        var score = 76 // Base monthly wealth score
        
        // Jupiter monthly cycle (abundance)
        if let jupiter = transits.first(where: { $0.name == "Jupiter" }) {
            let jupiterTo2ndHouse = abs(jupiter.longitude - (getHouseCusp(from: chart, house: 2) ?? 0))
            if jupiterTo2ndHouse < 15 || (105...135).contains(jupiterTo2ndHouse) {
                score += 18 // Major financial expansion
            } else if (45...75).contains(jupiterTo2ndHouse) {
                score += 12 // Wealth opportunities
            }
            
            // Jupiter to 8th house (investments, shared resources)
            let jupiterTo8thHouse = abs(jupiter.longitude - (getHouseCusp(from: chart, house: 8) ?? 0))
            if jupiterTo8thHouse < 15 {
                score += 10 // Investment gains
            }
        }
        
        // Pluto influences (transformation of resources)
        if let pluto = transits.first(where: { $0.name == "Pluto" }) {
            let plutoTo2ndHouse = abs(pluto.longitude - (getHouseCusp(from: chart, house: 2) ?? 0))
            if plutoTo2ndHouse < 8 {
                score += 8 // Financial transformation
            }
        }
        
        // Monthly wealth cycles with personalization
        let month = Calendar.current.component(.month, from: date)
        switch month {
        case 4, 11: score += 10 // Tax season opportunities
        case 9, 10: score += 12 // Harvest season abundance
        case 1: score += 8 // New year financial planning
        default: score += 6
        }
        
        // Add Jupiter-based wealth personalization
        let wealthPersonalization = (chart.jupiter.longitude + Double(month * 25)).truncatingRemainder(dividingBy: 16) - 8
        score += Int(wealthPersonalization)
        
        return max(5, min(95, score))
    }
    
    // MARK: - Yearly Score Calculations
    
    private func calculateYearlyOverallScore(chart: BirthChart, transits: [CelestialBody], aspects: [Aspect], date: Date) -> Int {
        var score = 85 // Higher base for yearly perspective
        
        // Major generational planets
        if let pluto = transits.first(where: { $0.name == "Pluto" }) {
            let plutoToSun = abs(pluto.longitude - chart.sun.longitude)
            if plutoToSun < 5 || (110...130).contains(plutoToSun) {
                score += 20 // Life transformation year
            } else if (50...70).contains(plutoToSun) {
                score += 12 // Growth through change
            }
        }
        
        if let neptune = transits.first(where: { $0.name == "Neptune" }) {
            let neptuneToSun = abs(neptune.longitude - chart.sun.longitude)
            if neptuneToSun < 5 || (110...130).contains(neptuneToSun) {
                score += 15 // Spiritual awakening year
            }
        }
        
        if let uranus = transits.first(where: { $0.name == "Uranus" }) {
            let uranusToSun = abs(uranus.longitude - chart.sun.longitude)
            if uranusToSun < 5 || (110...130).contains(uranusToSun) {
                score += 18 // Liberation and innovation year
            }
        }
        
        // Year numerology influence with birth chart integration
        let year = Calendar.current.component(.year, from: date)
        let yearDigitSum = String(year).compactMap { Int(String($0)) }.reduce(0, +)
        let yearNumber = yearDigitSum % 9 + 1
        
        // Add birth chart influence on yearly energy
        let birthYear = Calendar.current.component(.year, from: chart.birthData.date)
        let ageInfluence = (year - birthYear) % 12 // 12-year Jupiter cycle
        let personalYearlyInfluence = Int((chart.sun.longitude + Double(ageInfluence * 30)).truncatingRemainder(dividingBy: 25)) - 12
        
        switch yearNumber {
        case 1, 3, 5: score += 8 // Dynamic years
        case 2, 6, 9: score += 10 // Harmonious years
        case 4, 7: score += 6 // Steady building years
        case 8: score += 12 // Achievement year
        default: score += 7
        }
        
        score += personalYearlyInfluence
        return max(5, min(95, score))
    }
    
    private func calculateYearlyLoveScore(chart: BirthChart, transits: [CelestialBody], aspects: [Aspect], date: Date) -> Int {
        var score = 80 // Base yearly love score
        
        // Major love transits for the year
        if let jupiter = transits.first(where: { $0.name == "Jupiter" }) {
            // Jupiter to Venus (love expansion)
            let jupiterToVenus = abs(jupiter.longitude - chart.venus.longitude)
            if jupiterToVenus < 5 || (110...130).contains(jupiterToVenus) {
                score += 25 // Major love expansion year
            } else if (50...70).contains(jupiterToVenus) {
                score += 15 // Love growth opportunities
            }
            
            // Jupiter to 7th house (partnership)
            let jupiterTo7thHouse = abs(jupiter.longitude - (getHouseCusp(from: chart, house: 7) ?? 0))
            if jupiterTo7thHouse < 10 {
                score += 20 // Partnership blessing year
            }
        }
        
        // Saturn to Venus (serious relationships)
        if let saturn = transits.first(where: { $0.name == "Saturn" }) {
            let saturnToVenus = abs(saturn.longitude - chart.venus.longitude)
            if saturnToVenus < 5 {
                score += 10 // Serious commitment year
            }
        }
        
        // Venus return cycles (approximately every 8 months)
        if let venus = transits.first(where: { $0.name == "Venus" }) {
            let venusReturn = abs(venus.longitude - chart.venus.longitude)
            if venusReturn < 15 {
                score += 12 // Venus return year - renewed love
            }
        }
        
        return max(5, min(95, score))
    }
    
    private func calculateYearlyCareerScore(chart: BirthChart, transits: [CelestialBody], aspects: [Aspect], date: Date) -> Int {
        var score = 82 // Base yearly career score
        
        // Saturn career cycles (major professional development)
        if let saturn = transits.first(where: { $0.name == "Saturn" }) {
            let saturnToSun = abs(saturn.longitude - chart.sun.longitude)
            if saturnToSun < 5 || (110...130).contains(saturnToSun) {
                score += 20 // Major career milestone year
            } else if (80...100).contains(saturnToSun) {
                score += 10 // Career challenge leading to growth
            }
            
            // Saturn to MC (professional achievement)
            let saturnToMC = abs(saturn.longitude - (getHouseCusp(from: chart, house: 10) ?? 0))
            if saturnToMC < 5 {
                score += 18 // Career peak year
            }
        }
        
        // Jupiter career expansion
        if let jupiter = transits.first(where: { $0.name == "Jupiter" }) {
            let jupiterToSun = abs(jupiter.longitude - chart.sun.longitude)
            if jupiterToSun < 5 || (110...130).contains(jupiterToSun) {
                score += 15 // Career expansion year
            }
            
            // Jupiter to 10th house
            let jupiterTo10thHouse = abs(jupiter.longitude - (getHouseCusp(from: chart, house: 10) ?? 0))
            if jupiterTo10thHouse < 10 {
                score += 16 // Professional recognition year
            }
        }
        
        // Uranus career innovation
        if let uranus = transits.first(where: { $0.name == "Uranus" }) {
            let uranusToMC = abs(uranus.longitude - (getHouseCusp(from: chart, house: 10) ?? 0))
            if uranusToMC < 5 {
                score += 14 // Career revolution year
            }
        }
        
        return max(5, min(95, score))
    }
    
    private func calculateYearlyWealthScore(chart: BirthChart, transits: [CelestialBody], aspects: [Aspect], date: Date) -> Int {
        var score = 78 // Base yearly wealth score
        
        // Jupiter wealth cycles (major financial growth)
        if let jupiter = transits.first(where: { $0.name == "Jupiter" }) {
            // Jupiter to 2nd house (personal wealth)
            let jupiterTo2ndHouse = abs(jupiter.longitude - (getHouseCusp(from: chart, house: 2) ?? 0))
            if jupiterTo2ndHouse < 8 {
                score += 22 // Major wealth expansion year
            } else if jupiterTo2ndHouse < 15 {
                score += 15 // Financial growth year
            }
            
            // Jupiter to 8th house (investments, inheritance)
            let jupiterTo8thHouse = abs(jupiter.longitude - (getHouseCusp(from: chart, house: 8) ?? 0))
            if jupiterTo8thHouse < 8 {
                score += 18 // Investment boom year
            }
            
            // Jupiter to natal Jupiter (12-year cycle)
            let jupiterReturn = abs(jupiter.longitude - chart.jupiter.longitude)
            if jupiterReturn < 10 {
                score += 16 // Jupiter return - abundance cycle
            }
        }
        
        // Saturn wealth building (long-term financial security)
        if let saturn = transits.first(where: { $0.name == "Saturn" }) {
            let saturnTo2ndHouse = abs(saturn.longitude - (getHouseCusp(from: chart, house: 2) ?? 0))
            if saturnTo2ndHouse < 8 {
                score += 12 // Financial discipline and security year
            }
        }
        
        // Pluto wealth transformation
        if let pluto = transits.first(where: { $0.name == "Pluto" }) {
            let plutoTo2ndHouse = abs(pluto.longitude - (getHouseCusp(from: chart, house: 2) ?? 0))
            if plutoTo2ndHouse < 5 {
                score += 15 // Wealth transformation year
            }
            
            let plutoTo8thHouse = abs(pluto.longitude - (getHouseCusp(from: chart, house: 8) ?? 0))
            if plutoTo8thHouse < 5 {
                score += 12 // Investment metamorphosis year
            }
        }
        
        return max(5, min(95, score))
    }
    
    // MARK: - Timezone Conversion
    private func convertToUTC(date: Date, timeZone: TimeZone) -> Date {
        let offset = timeZone.secondsFromGMT(for: date)
        return date.addingTimeInterval(-TimeInterval(offset))
    }
}