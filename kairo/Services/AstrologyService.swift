import Foundation
import SwissEphemeris

class AstrologyService {
    static let shared = AstrologyService()
    
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
        
        // Calculate houses
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
    func calculatePlanetPositionAt(planet: SwissEphemeris.Planet, date: Date) -> CelestialBody? {
        return calculatePlanet(planet, date: date)
    }
    
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
    func generateWeeklyInsight(for chart: BirthChart) async -> String {
        let transits = calculateCurrentTransits()
        return await AIInsightService.shared.generateWeeklyInsight(for: chart, transits: transits)
    }
    
    // MARK: - Monthly Insights (AI-Powered)
    func generateMonthlyInsight(for chart: BirthChart) async -> String {
        let transits = calculateCurrentTransits()
        return await AIInsightService.shared.generateMonthlyInsight(for: chart, transits: transits)
    }
    
    // MARK: - Yearly Insights (AI-Powered)
    func generateYearlyInsight(for chart: BirthChart) async -> String {
        let transits = calculateCurrentTransits()
        return await AIInsightService.shared.generateYearlyInsight(for: chart, transits: transits)
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
        let transits = calculateCurrentTransits()
        let aspects = calculateAspects(for: chart)
        
        // Calculate each score based on SPECIFIC DATE's astrological factors
        let overallScore = calculateDailyOverallScore(chart: chart, transits: transits, aspects: aspects, date: date)
        let loveScore = calculateDailyLoveScore(chart: chart, transits: transits, aspects: aspects, date: date)
        let careerScore = calculateDailyCareerScore(chart: chart, transits: transits, aspects: aspects, date: date)
        let wealthScore = calculateDailyWealthScore(chart: chart, transits: transits, aspects: aspects, date: date)
        
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
        let transits = calculateCurrentTransits()
        let aspects = calculateAspects(for: chart)
        
        // Calculate each score based on SPECIFIC WEEK'S astrological factors
        let overallScore = calculateWeeklyOverallScore(chart: chart, transits: transits, aspects: aspects, date: date)
        let loveScore = calculateWeeklyLoveScore(chart: chart, transits: transits, aspects: aspects, date: date)
        let careerScore = calculateWeeklyCareerScore(chart: chart, transits: transits, aspects: aspects, date: date)
        let wealthScore = calculateWeeklyWealthScore(chart: chart, transits: transits, aspects: aspects, date: date)
        
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
        let transits = calculateCurrentTransits()
        let aspects = calculateAspects(for: chart)
        
        // Calculate each score based on SPECIFIC MONTH'S astrological factors
        let overallScore = calculateMonthlyOverallScore(chart: chart, transits: transits, aspects: aspects, date: date)
        let loveScore = calculateMonthlyLoveScore(chart: chart, transits: transits, aspects: aspects, date: date)
        let careerScore = calculateMonthlyCareerScore(chart: chart, transits: transits, aspects: aspects, date: date)
        let wealthScore = calculateMonthlyWealthScore(chart: chart, transits: transits, aspects: aspects, date: date)
        
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
        let transits = calculateCurrentTransits()
        let aspects = calculateAspects(for: chart)
        
        // Calculate each score based on SPECIFIC YEAR'S astrological factors
        let overallScore = calculateYearlyOverallScore(chart: chart, transits: transits, aspects: aspects, date: date)
        let loveScore = calculateYearlyLoveScore(chart: chart, transits: transits, aspects: aspects, date: date)
        let careerScore = calculateYearlyCareerScore(chart: chart, transits: transits, aspects: aspects, date: date)
        let wealthScore = calculateYearlyWealthScore(chart: chart, transits: transits, aspects: aspects, date: date)
        
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
        var score = 50 // Neutral baseline - true middle ground
        
        // === NATAL CHART FOUNDATION (affects baseline) ===
        let sunMoonAngle = abs(chart.sun.longitude - chart.moon.longitude)
        let normalizedSunMoon = sunMoonAngle > 180 ? 360 - sunMoonAngle : sunMoonAngle
        
        // Natal sun-moon aspect sets your general life harmony
        if normalizedSunMoon < 8 { // Conjunction - unified personality
            score += 12
        } else if (112...128).contains(normalizedSunMoon) { // Trine - natural harmony
            score += 15
        } else if (52...68).contains(normalizedSunMoon) { // Sextile - cooperative energy
            score += 8
        } else if (82...98).contains(normalizedSunMoon) { // Square - creative tension
            score -= 5
        } else if (172...188).contains(normalizedSunMoon) { // Opposition - internal polarity
            score -= 8
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
        var score = 50 // Neutral love baseline
        
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
        var score = 50 // Neutral career baseline
        
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
        var score = 50 // Neutral wealth baseline
        
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
        var score = 50 // Neutral weekly love baseline
        
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
        var score = 50 // Neutral weekly career baseline
        
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
        var score = 50 // Neutral weekly wealth baseline
        
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
    func calculateCurrentCycles(for chart: BirthChart) -> [AstrologicalCycle] {
        print("🔄 Calculating current astrological cycles and aspects")
        let transits = calculateCurrentTransits()
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
        
        // Check for significant outer planet transits
        let outerPlanets = transits.filter { ["Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"].contains($0.name) }
        let personalPlanets = [chart.sun, chart.moon, chart.mercury, chart.venus, chart.mars]
        
        for transitPlanet in outerPlanets {
            for natalPlanet in personalPlanets {
                let angle = abs(transitPlanet.longitude - natalPlanet.longitude)
                let normalizedAngle = angle > 180 ? 360 - angle : angle
                
                // Check for major aspects
                if let aspectType = getAspectType(for: normalizedAngle) {
                    let cycle = createCycleFromAspect(
                        transitPlanet: transitPlanet,
                        natalPlanet: natalPlanet,
                        aspectType: aspectType
                    )
                    cycles.append(cycle)
                }
            }
        }
        
        // Also check for Venus and Mars transits to Sun/Moon for love and career cycles
        if let venusTransit = transits.first(where: { $0.name == "Venus" }) {
            let venusToSunAngle = abs(venusTransit.longitude - chart.sun.longitude)
            let normalizedVenusAngle = venusToSunAngle > 180 ? 360 - venusToSunAngle : venusToSunAngle
            
            if let aspectType = getAspectType(for: normalizedVenusAngle) {
                cycles.append(createLoveCycle(aspectType: aspectType))
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
            phase = "New Moon Energy"
            description = "Perfect time for new beginnings and setting intentions. Your emotional and identity are aligned."
            influence = .positive
            
        case 75...105:
            phase = "First Quarter Tension"
            description = "Dynamic energy that pushes you to take action. Use this creative tension constructively."
            influence = .challenging
            
        case 165...195:
            phase = "Full Moon Illumination"
            description = "Time of heightened awareness and emotional clarity. Relationships and patterns become visible."
            influence = .transformative
            
        case 255...285:
            phase = "Last Quarter Release"
            description = "Perfect time to let go of what no longer serves you. Clear space for new growth."
            influence = .neutral
            
        default:
            phase = "Lunar Flow"
            description = "Gentle lunar energy supporting your natural rhythms and emotional processing."
            influence = .neutral
        }
        
        return AstrologicalCycle(
            title: phase,
            planetaryAspect: "Moon \(getAspectSymbol(for: normalizedAngle)) Sun",
            duration: "< 3 days",
            description: description,
            influence: influence
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
    
    private func createCycleFromAspect(transitPlanet: CelestialBody, natalPlanet: CelestialBody, aspectType: AspectType) -> AstrologicalCycle {
        let title = generateCycleTitle(transitPlanet: transitPlanet, natalPlanet: natalPlanet, aspectType: aspectType)
        let duration = getCycleDuration(for: transitPlanet.name)
        let description = generateCycleDescription(transitPlanet: transitPlanet, natalPlanet: natalPlanet, aspectType: aspectType)
        let influence = getCycleInfluence(aspectType: aspectType, transitPlanet: transitPlanet.name)
        
        return AstrologicalCycle(
            title: title,
            planetaryAspect: "\(transitPlanet.name) \(aspectType.symbol) \(natalPlanet.name)",
            duration: duration,
            description: description,
            influence: influence
        )
    }
    
    private func createLoveCycle(aspectType: AspectType) -> AstrologicalCycle {
        let titles = [
            "Heart Opening", "Romantic Alignment", "Love's Gentle Touch", "Attraction Amplified"
        ]
        let title = titles.randomElement() ?? "Venus Influence"
        
        return AstrologicalCycle(
            title: title,
            planetaryAspect: "Venus \(aspectType.symbol) Sun",
            duration: "> 30 days",
            description: "Venus energy enhances your attractiveness and ability to connect with others on a heart level.",
            influence: aspectType == .square || aspectType == .opposition ? .challenging : .positive
        )
    }
    
    private func generateCycleTitle(transitPlanet: CelestialBody, natalPlanet: CelestialBody, aspectType: AspectType) -> String {
        let titles: [String: [String]] = [
            "Jupiter": ["Expand Your Horizons", "Growth Opportunity", "Lucky Break Ahead", "Abundance Flows"],
            "Saturn": ["Build Foundation", "Lesson in Discipline", "Structure Your Goals", "Wisdom Through Challenge"],
            "Uranus": ["Break Free", "Revolutionary Change", "Unexpected Breakthrough", "Innovation Required"],
            "Neptune": ["Spiritual Awakening", "Intuitive Insights", "Dream Into Reality", "Mystical Connection"],
            "Pluto": ["Deep Transformation", "Phoenix Rising", "Power Shift", "Soul Evolution"]
        ]
        
        let planetTitles = titles[transitPlanet.name] ?? ["Cosmic Influence"]
        return planetTitles.randomElement() ?? "Planetary Alignment"
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
    
    private func generateCycleDescription(transitPlanet: CelestialBody, natalPlanet: CelestialBody, aspectType: AspectType) -> String {
        // Create specific, unique descriptions for each planet-planet combination
        // Generate cycle description based on specific planetary combinations
        
        switch (transitPlanet.name, natalPlanet.name, aspectType) {
        // Uranus combinations
        case ("Uranus", "Mercury", .sextile):
            return "Revolutionary thinking emerges as Uranus awakens new perspectives in your mind. Breakthrough insights about communication, technology, or learning are highlighted. Your mental processes are being upgraded."
            
        case ("Uranus", "Venus", .sextile):
            return "Unexpected developments in relationships or creative endeavors bring exciting possibilities. You're attracting unconventional beauty and unique connections. Embrace the unusual in love and art."
            
        case ("Uranus", "Mercury", .conjunction):
            return "A lightning bolt of innovation strikes your thinking patterns. Revolutionary ideas demand expression. Your communication style undergoes a dramatic transformation that opens new possibilities."
            
        case ("Uranus", "Venus", .conjunction):
            return "Sudden attractions or creative breakthroughs electrify your world. Traditional relationship patterns are being revolutionized. Expect the unexpected in matters of the heart."
            
        case ("Uranus", "Sun", .square):
            return "Your individuality clashes with external pressures for conformity. This tension catalyzes authentic self-expression. Break free from limiting identities that no longer serve you."
            
        case ("Uranus", "Moon", .opposition):
            return "Emotional independence battles with security needs. This push-pull dynamic reveals where you've been playing it too safe. Trust your intuitive urges for freedom."
            
        // Saturn combinations  
        case ("Saturn", "Sun", .trine):
            return "Disciplined effort yields lasting recognition and achievement. Your authority and leadership skills are being refined through practical experience. Build something that will endure."
            
        case ("Saturn", "Mars", .square):
            return "Obstacles test your determination and force you to develop patience. Each challenge is strengthening your character and teaching strategic thinking. Persist through resistance."
            
        case ("Saturn", "Venus", .sextile):
            return "Commitment and structure bring stability to relationships and finances. Mature love is favored over superficial attractions. Invest in what has lasting value."
            
        // Jupiter combinations
        case ("Jupiter", "Sun", .conjunction):
            return "A year of expansion, opportunity, and increased confidence begins. Your natural talents are magnified and recognized. Think bigger than you ever have before."
            
        case ("Jupiter", "Mercury", .trine):
            return "Learning accelerates and communication becomes more persuasive. Publishing, teaching, or travel opportunities arise. Your ideas have broader reach and impact."
            
        case ("Jupiter", "Venus", .sextile):
            return "Generosity in love and creativity brings abundance. Social connections expand your horizons. Beautiful experiences and romantic opportunities flourish."
            
        // Neptune combinations
        case ("Neptune", "Sun", .square):
            return "Illusions about your identity are dissolving, creating temporary confusion but ultimate clarity. Surrender ego-driven goals that lack spiritual authenticity."
            
        case ("Neptune", "Mercury", .conjunction):
            return "Intuitive perception blends with logical thinking, enhancing creativity and psychic sensitivity. Dreams and symbols carry important messages. Trust your hunches."
            
        case ("Neptune", "Venus", .trine):
            return "Unconditional love and artistic inspiration flow naturally. Romantic idealism is beautifully expressed. Spiritual partnership or creative collaboration is highlighted."
            
        // Pluto combinations
        case ("Pluto", "Sun", .conjunction):
            return "A profound identity transformation begins that will reshape your entire life direction. Death of old self enables birth of authentic power. Embrace the metamorphosis."
            
        case ("Pluto", "Mars", .square):
            return "Power struggles reveal where you need to transform your approach to conflict and assertion. Channel intense energy into constructive change rather than destruction."
            
        case ("Pluto", "Venus", .opposition):
            return "Relationships undergo deep transformation as hidden dynamics surface. Possessiveness and control issues require honest examination. Love evolves or ends."
            
        // Generic fallbacks for less common combinations
        default:
            return generateGenericCycleDescription(transitPlanet: transitPlanet, natalPlanet: natalPlanet, aspectType: aspectType)
        }
    }
    
    private func generateGenericCycleDescription(transitPlanet: CelestialBody, natalPlanet: CelestialBody, aspectType: AspectType) -> String {
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
            return "\(transitPlanet.name) merges with \(natalMeaning), creating intense focus on \(transitMeaning). A new cycle begins with powerful potential for transformation."
        case .trine:
            return "\(transitPlanet.name) harmonizes with \(natalMeaning), bringing easy access to \(transitMeaning). Natural talents flow without resistance."
        case .sextile:
            return "\(transitPlanet.name) supports \(natalMeaning) through opportunities involving \(transitMeaning). Gentle progress through conscious effort."
        case .square:
            return "\(transitPlanet.name) challenges \(natalMeaning), creating productive tension around \(transitMeaning). Growth through overcoming obstacles."
        case .opposition:
            return "\(transitPlanet.name) illuminates \(natalMeaning) by highlighting themes of \(transitMeaning). Balance and integration are required."
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