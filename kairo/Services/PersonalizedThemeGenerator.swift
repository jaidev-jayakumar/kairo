import Foundation

/// Generates personalized themes based on actual planetary transits to user's birth chart
/// No more static rotation - themes match what's really happening in the sky
class PersonalizedThemeGenerator {
    static let shared = PersonalizedThemeGenerator()
    
    private init() {}
    
    // MARK: - Daily Themes (for Today view)
    
    func generateDailyThemes(chart: BirthChart, transits: [CelestialBody], count: Int = 3) -> [String] {
        var themes: [String] = []
        
        // Priority: Find the most significant transits happening TODAY
        let activeTransits = findSignificantDailyTransits(chart: chart, transits: transits)
        
        // Generate themes based on actual transits
        for transit in activeTransits.prefix(count) {
            if let theme = themeForTransit(transit, chart: chart) {
                themes.append(theme)
            }
        }
        
        // Fill remaining with personalized universal themes if needed
        while themes.count < count {
            themes.append(getPersonalizedUniversalTheme(chart: chart, transits: transits, avoid: themes))
        }
        
        return themes
    }
    
    // MARK: - Weekly Themes
    
    func generateWeeklyThemes(chart: BirthChart, transits: [CelestialBody], count: Int = 3) -> [String] {
        var themes: [String] = []
        
        // Find week-long transit patterns
        let weeklyTransits = findWeeklyTransits(chart: chart, transits: transits)
        
        // Generate themes for weekly patterns
        for transit in weeklyTransits.prefix(count) {
            if let theme = weeklyThemeForTransit(transit, chart: chart) {
                themes.append(theme)
            }
        }
        
        // Fill with sign-specific themes if needed
        while themes.count < count {
            themes.append(getPersonalizedWeeklyTheme(chart: chart, transits: transits, avoid: themes))
        }
        
        return themes
    }
    
    // MARK: - Transit Detection
    
    private func findSignificantDailyTransits(chart: BirthChart, transits: [CelestialBody]) -> [PersonalTransit] {
        var significantTransits: [PersonalTransit] = []
        
        // Fast-moving planets (change daily/weekly)
        let fastPlanets = ["Moon", "Mercury", "Venus", "Mars", "Sun"]
        
        for transit in transits where fastPlanets.contains(transit.name) {
            // Check aspects to natal planets
            if let sunAspect = detectAspect(transit.longitude, chart.sun.longitude) {
                significantTransits.append(PersonalTransit(
                    transitPlanet: transit.name,
                    natalPlanet: "Sun",
                    aspect: sunAspect,
                    intensity: getIntensity(transit.name, sunAspect)
                ))
            }
            
            if let moonAspect = detectAspect(transit.longitude, chart.moon.longitude) {
                significantTransits.append(PersonalTransit(
                    transitPlanet: transit.name,
                    natalPlanet: "Moon",
                    aspect: moonAspect,
                    intensity: getIntensity(transit.name, moonAspect)
                ))
            }
            
            if let mercuryAspect = detectAspect(transit.longitude, chart.mercury.longitude) {
                significantTransits.append(PersonalTransit(
                    transitPlanet: transit.name,
                    natalPlanet: "Mercury",
                    aspect: mercuryAspect,
                    intensity: getIntensity(transit.name, mercuryAspect)
                ))
            }
            
            if let venusAspect = detectAspect(transit.longitude, chart.venus.longitude) {
                significantTransits.append(PersonalTransit(
                    transitPlanet: transit.name,
                    natalPlanet: "Venus",
                    aspect: venusAspect,
                    intensity: getIntensity(transit.name, venusAspect)
                ))
            }
            
            if let marsAspect = detectAspect(transit.longitude, chart.mars.longitude) {
                significantTransits.append(PersonalTransit(
                    transitPlanet: transit.name,
                    natalPlanet: "Mars",
                    aspect: marsAspect,
                    intensity: getIntensity(transit.name, marsAspect)
                ))
            }
        }
        
        // Sort by intensity (most significant first)
        return significantTransits.sorted { $0.intensity > $1.intensity }
    }
    
    private func findWeeklyTransits(chart: BirthChart, transits: [CelestialBody]) -> [PersonalTransit] {
        var weeklyTransits: [PersonalTransit] = []
        
        // Include slower planets for weekly themes
        let weeklyPlanets = ["Mars", "Venus", "Mercury", "Jupiter"]
        
        for transit in transits where weeklyPlanets.contains(transit.name) {
            if let sunAspect = detectAspect(transit.longitude, chart.sun.longitude) {
                weeklyTransits.append(PersonalTransit(
                    transitPlanet: transit.name,
                    natalPlanet: "Sun",
                    aspect: sunAspect,
                    intensity: getIntensity(transit.name, sunAspect)
                ))
            }
            
            if let moonAspect = detectAspect(transit.longitude, chart.moon.longitude) {
                weeklyTransits.append(PersonalTransit(
                    transitPlanet: transit.name,
                    natalPlanet: "Moon",
                    aspect: moonAspect,
                    intensity: getIntensity(transit.name, moonAspect)
                ))
            }
        }
        
        return weeklyTransits.sorted { $0.intensity > $1.intensity }
    }
    
    private func detectAspect(_ transitLong: Double, _ natalLong: Double) -> AspectType? {
        let diff = abs(transitLong - natalLong)
        let normalizedDiff = diff > 180 ? 360 - diff : diff
        
        // Check major aspects with orbs
        if normalizedDiff <= 8 { return .conjunction }
        if (172...188).contains(normalizedDiff) { return .opposition }
        if (82...98).contains(normalizedDiff) { return .square }
        if (112...128).contains(normalizedDiff) { return .trine }
        if (52...68).contains(normalizedDiff) { return .sextile }
        
        return nil
    }
    
    private func getIntensity(_ planet: String, _ aspect: AspectType) -> Int {
        let planetWeight: Int = {
            switch planet {
            case "Sun": return 10
            case "Moon": return 9
            case "Mercury": return 7
            case "Venus": return 8
            case "Mars": return 8
            case "Jupiter": return 6
            default: return 5
            }
        }()
        
        let aspectWeight: Int = {
            switch aspect {
            case .conjunction: return 10
            case .opposition: return 9
            case .square: return 8
            case .trine: return 6
            case .sextile: return 5
            }
        }()
        
        return planetWeight + aspectWeight
    }
    
    // MARK: - Theme Generation
    
    private func themeForTransit(_ transit: PersonalTransit, chart: BirthChart) -> String? {
        let key = "\(transit.transitPlanet)-\(transit.natalPlanet)-\(transit.aspect)"
        
        // Transit-specific theme pools
        switch key {
        // MOON TRANSITS (daily emotional themes)
        case "Moon-Sun-conjunction":
            return ["today's about trusting your instincts over everyone else's opinions",
                    "your emotions and identity are aligned - use this clarity",
                    "what you feel today is showing you what you need"].randomElement()
        case "Moon-Sun-opposition":
            return ["your feelings vs your ego - both are valid",
                    "the tension you feel is asking you to grow",
                    "external pressure is revealing something internal"].randomElement()
        case "Moon-Sun-square":
            return ["uncomfortable feelings are just growth in disguise",
                    "your emotions are challenging your identity - that's the point",
                    "friction between what you feel and who you are builds character"].randomElement()
        case "Moon-Sun-trine":
            return ["everything flows easier when you trust yourself",
                    "your emotions support your goals today",
                    "what feels natural right now is exactly what you need"].randomElement()
            
        case "Moon-Moon-conjunction":
            return ["you're emotionally resetting - honor what comes up",
                    "today's feelings are showing you your patterns",
                    "emotional clarity comes through feeling it all"].randomElement()
        case "Moon-Moon-opposition":
            return ["your current emotions vs your habitual reactions",
                    "what worked before might not work now - that's growth",
                    "emotional tension is asking you to evolve"].randomElement()
            
        // VENUS TRANSITS (love, values, connection)
        case "Venus-Sun-conjunction":
            return ["you're magnetic right now - people feel drawn to your energy",
                    "what you value and who you are align perfectly today",
                    "your charm is effortless when you're authentic"].randomElement()
        case "Venus-Sun-square":
            return ["wanting approval vs staying authentic - choose yourself",
                    "relationship tension reveals what needs to change",
                    "being liked matters less than being real"].randomElement()
        case "Venus-Sun-trine":
            return ["love flows when you're unapologetically yourself",
                    "relationships work when you don't force them",
                    "your natural charm attracts the right people"].randomElement()
            
        case "Venus-Moon-conjunction":
            return ["your heart knows who belongs in your life",
                    "emotional and romantic needs finally match up",
                    "trust what your feelings say about people"].randomElement()
        case "Venus-Moon-square":
            return ["what you want vs what you need in relationships",
                    "comfort isn't always growth in love",
                    "familiar patterns might be keeping you stuck"].randomElement()
        case "Venus-Moon-trine":
            return ["your emotions guide you to the right connections",
                    "vulnerability creates intimacy today",
                    "being soft is strength in the right company"].randomElement()
            
        case "Venus-Venus-conjunction":
            return ["you're redefining what you value in relationships",
                    "old patterns in love get a fresh perspective",
                    "your standards are evolving - let them"].randomElement()
        case "Venus-Venus-opposition":
            return ["what you give vs what you get in relationships",
                    "time to reassess who's actually showing up for you",
                    "balance in love requires honesty about needs"].randomElement()
            
        // MARS TRANSITS (action, drive, anger)
        case "Mars-Sun-conjunction":
            return ["your drive is unstoppable right now - use it wisely",
                    "anger is just passion without direction",
                    "take action on what you've been planning"].randomElement()
        case "Mars-Sun-square":
            return ["frustration is momentum trying to break through",
                    "resistance from others pushes you to prove yourself",
                    "conflict reveals where you need stronger boundaries"].randomElement()
        case "Mars-Sun-opposition":
            return ["external challenges test your inner strength",
                    "push back is showing you what matters most",
                    "competition brings out your determination"].randomElement()
        case "Mars-Sun-trine":
            return ["motivation comes naturally - ride this wave",
                    "bold moves pay off when timing's right",
                    "confidence backed by action gets results"].randomElement()
            
        case "Mars-Mars-conjunction":
            return ["you're resetting how you go after what you want",
                    "old anger patterns need new outlets",
                    "channel intensity into building, not burning"].randomElement()
        case "Mars-Mars-square":
            return ["impatience is just energy without focus",
                    "slow progress beats reckless momentum",
                    "pick your battles - not everything needs confrontation"].randomElement()
            
        // MERCURY TRANSITS (communication, thinking)
        case "Mercury-Sun-conjunction":
            return ["your thoughts and identity sync up perfectly",
                    "speak your truth - clarity is on your side",
                    "mental fog clears when you're authentic"].randomElement()
        case "Mercury-Sun-square":
            return ["miscommunication reveals what needs saying",
                    "thinking too much blocks instinct",
                    "the hard conversations matter most"].randomElement()
        case "Mercury-Mercury-conjunction":
            return ["your mind is rewiring how you process things",
                    "old thought patterns get challenged today",
                    "mental clarity comes through confusion first"].randomElement()
        case "Mercury-Moon-conjunction":
            return ["logic and emotion finally agree",
                    "say what you feel - your words have power",
                    "thinking through feelings brings insight"].randomElement()
        case "Mercury-Moon-square":
            return ["what you think vs what you feel - both matter",
                    "over-analyzing kills the message your emotions carry",
                    "sometimes feeling is more honest than thinking"].randomElement()
            
        // JUPITER TRANSITS (expansion, opportunity)
        case "Jupiter-Sun-conjunction":
            return ["doors are opening - walk through them",
                    "confidence meets opportunity today",
                    "expansion requires saying yes to growth"].randomElement()
        case "Jupiter-Sun-trine":
            return ["luck favors the bold right now",
                    "opportunities flow when you trust yourself",
                    "growth feels natural when timing's right"].randomElement()
        case "Jupiter-Sun-square":
            return ["too much of a good thing creates problems",
                    "overconfidence vs realistic assessment",
                    "expansion needs boundaries or it becomes chaos"].randomElement()
            
        default:
            return nil
        }
    }
    
    private func weeklyThemeForTransit(_ transit: PersonalTransit, chart: BirthChart) -> String? {
        let key = "\(transit.transitPlanet)-\(transit.natalPlanet)-\(transit.aspect)"
        
        // Weekly themes (more sustained energy)
        switch key {
        case "Mars-Sun-square":
            return "the obstacles you're facing are strengthening your resolve"
        case "Mars-Sun-opposition":
            return "external resistance reveals your internal power"
        case "Mars-Sun-trine":
            return "your actions align with your goals effortlessly this week"
            
        case "Venus-Sun-square":
            return "relationship dynamics show you what needs shifting"
        case "Venus-Sun-trine":
            return "connections deepen when you show up authentically"
        case "Venus-Moon-square":
            return "comfort vs growth in relationships - choose wisely"
            
        case "Mercury-Sun-square":
            return "communication challenges force necessary conversations"
        case "Mercury-Moon-square":
            return "thoughts vs feelings - integration is the goal"
            
        case "Jupiter-Sun-conjunction":
            return "this week opens doors you didn't know existed"
        case "Jupiter-Sun-trine":
            return "opportunities multiply when you trust the process"
            
        default:
            return nil
        }
    }
    
    // MARK: - Universal Theme Pools (expanded)
    
    private func getPersonalizedUniversalTheme(chart: BirthChart, transits: [CelestialBody], avoid: [String]) -> String {
        let allThemes = getUniversalThemePool(chart: chart, transits: transits)
        
        // Filter out already selected themes
        let available = allThemes.filter { theme in
            !avoid.contains(theme)
        }
        
        return available.randomElement() ?? allThemes.randomElement() ?? "trust what you know about yourself"
    }
    
    private func getPersonalizedWeeklyTheme(chart: BirthChart, transits: [CelestialBody], avoid: [String]) -> String {
        let allThemes = getWeeklyThemePool(chart: chart)
        
        let available = allThemes.filter { theme in
            !avoid.contains(theme)
        }
        
        return available.randomElement() ?? allThemes.randomElement() ?? "this week asks for patience with yourself"
    }
    
    private func getUniversalThemePool(chart: BirthChart, transits: [CelestialBody]) -> [String] {
        var themes: [String] = [
            // Self-awareness
            "your gut knows more than your anxiety does",
            "the thing you're avoiding probably needs attention",
            "past you would be proud of where you are now",
            "your sensitivity picks up what others miss",
            "becoming yourself is uncomfortable but worth it",
            "boundaries are how you protect your energy",
            
            // Growth & Change
            "what feels like falling apart is falling together",
            "discomfort means you're outgrowing old patterns",
            "the mess is part of the process",
            "clarity comes through confusion, not around it",
            "growth doesn't happen in your comfort zone",
            
            // Relationships & Others
            "stop explaining yourself to people who won't listen",
            "not everyone deserves access to the real you",
            "the right people won't make you feel too much",
            "your people will show up - stop forcing it",
            "chemistry isn't compatibility",
            
            // Truth & Authenticity
            "your weirdness is actually your edge",
            "being likeable keeps you small",
            "people-pleasing is self-abandonment",
            "authenticity loses shallow connections and gains real ones",
            "fitting in costs more than it's worth",
            
            // Intuition & Instinct
            "trust what your body is telling you",
            "logic can't override what your gut knows",
            "sometimes walking away is the answer",
            "if it feels off, it probably is",
            "your instincts are pattern recognition, not paranoia",
            
            // Emotions & Feelings
            "feelings aren't facts but they carry information",
            "suppressing emotions doesn't make them disappear",
            "anger usually means a boundary was crossed",
            "anxiety is often excitement without permission",
            "your body keeps score when your mind denies",
            
            // Time & Patience
            "rushing the process breaks the process",
            "everything happens twice - first internally, then externally",
            "you're earlier in the journey than you think",
            "some things can't be forced, only allowed",
            "divine timing feels frustrating until it's perfect",
            
            // Action & Inaction
            "not deciding is still a decision",
            "doing nothing when something's wrong is choosing it",
            "the best time was before, the next best time is now",
            "waiting for perfect keeps you stuck",
            "action creates clarity",
            
            // Self-Worth & Value
            "your worth isn't negotiable",
            "needing validation makes you controllable",
            "self-respect looks like boundaries",
            "you teach people how to treat you",
            "good enough for others isn't good enough for you",
            
            // Fear & Courage
            "fear of change keeps you in wrong places",
            "courage is doing it scared, not fearless",
            "the resistance you feel is fear wearing logic",
            "what you're most afraid of holds what you need",
            "comfort is not the same as safety",
            
            // Perspective & Reality
            "your normal isn't everyone's normal",
            "projection tells you more about them than you",
            "how people treat you reveals them, not you",
            "their version of you isn't your responsibility",
            "closure comes from you, not them"
        ]
        
        // Add sign-specific themes
        themes.append(contentsOf: getSignSpecificThemes(chart.sunSign, chart.moonSign))
        
        return themes
    }
    
    private func getWeeklyThemePool(chart: BirthChart) -> [String] {
        return [
            "this week tests what you say you want",
            "old patterns show up so you can finally release them",
            "what you resist this week is what needs integration",
            "the universe is pushing you out of comfortable discomfort",
            "this week rewards authentic action over perfect planning",
            "relationships mirror what you need to heal",
            "your edge this week is saying what needs saying",
            "progress looks messy before it looks clean",
            "this week asks: are you growing or just coping?",
            "the easy path this week is usually the wrong one",
            "what feels hard now becomes your foundation later",
            "this week forces honesty in areas you've been avoiding",
            "your breakthrough is on the other side of this discomfort",
            "this week separates who you are from who you perform as",
            "the friction you're experiencing is redirecting you"
        ]
    }
    
    private func getSignSpecificThemes(_ sunSign: ZodiacSign, _ moonSign: ZodiacSign) -> [String] {
        var themes: [String] = []
        
        // Add sun sign themes
        switch sunSign {
        case .aries: themes.append("your impatience is momentum waiting to be channeled")
        case .taurus: themes.append("stability becomes stagnation without growth")
        case .gemini: themes.append("your scattered energy is collecting information")
        case .cancer: themes.append("feeling deeply is your superpower, not weakness")
        case .leo: themes.append("needing attention vs needing to be seen - know the difference")
        case .virgo: themes.append("perfectionism protects you from trying")
        case .libra: themes.append("keeping peace while losing yourself isn't balance")
        case .scorpio: themes.append("your intensity scares people who live on the surface")
        case .sagittarius: themes.append("restlessness means you're ready for expansion")
        case .capricorn: themes.append("achievement without self-compassion is just punishment")
        case .aquarius: themes.append("being different is your gift, not your burden")
        case .pisces: themes.append("your empathy needs boundaries to stay a gift")
        }
        
        // Add moon sign themes
        switch moonSign {
        case .aries: themes.append("your emotional directness is honesty, not aggression")
        case .taurus: themes.append("needing security doesn't make you needy")
        case .gemini: themes.append("talking through feelings is valid processing")
        case .cancer: themes.append("protecting your heart made sense once, but when does it open?")
        case .leo: themes.append("your feelings deserve an audience - start with yourself")
        case .virgo: themes.append("analyzing emotions keeps you from feeling them")
        case .libra: themes.append("keeping emotional peace shouldn't cost your peace")
        case .scorpio: themes.append("emotional intensity is depth, not drama")
        case .sagittarius: themes.append("emotional restlessness points toward growth")
        case .capricorn: themes.append("emotions don't need to be useful to be valid")
        case .aquarius: themes.append("detachment protects you from connection")
        case .pisces: themes.append("absorbing others' emotions doesn't help them or you")
        }
        
        return themes
    }
}

// MARK: - Supporting Types

struct PersonalTransit {
    let transitPlanet: String
    let natalPlanet: String
    let aspect: AspectType
    let intensity: Int
}

