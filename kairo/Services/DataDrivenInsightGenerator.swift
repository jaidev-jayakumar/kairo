import Foundation

/// Generates crisp, truthful astrological insights based on actual planetary data
/// No fluff, no generic self-help talk - just what the planets are actually doing today
class DataDrivenInsightGenerator {
    static let shared = DataDrivenInsightGenerator()
    
    private init() {}
    
    /// Generate a crisp daily insight based on actual transits
    func generateDailyInsight(chart: BirthChart, transits: [CelestialBody], date: Date) -> String {
        // DAILY INSIGHTS PRIORITY:
        // 1. Moon aspects (changes every few hours) - use when available
        // 2. Moon sign variations (changes every 2.5 days) - PRIMARY daily insight
        // 3. Slower planet aspects (weeks/months) - only if no Moon data
        
        guard let moon = transits.first(where: { $0.name == "Moon" }) else {
            return "A steady day for internal processing. Notice what surfaces without forcing anything."
        }
        
        // Check for Moon aspects first (most dynamic)
        if let moonAspect = findMoonAspects(moon: moon, chart: chart).first {
            return interpretMoonAspect(moonAspect, moon: moon, chart: chart)
        }
        
        // ALWAYS use Moon sign variations for daily insights (changes every 2.5 days)
        // This ensures daily variation even when slower planets are making aspects
        return interpretDailyMoonEnergy(moon, chart: chart, date: date)
    }
    
    // MARK: - Aspect Detection
    
    private func findFastMovingAspects(chart: BirthChart, transits: [CelestialBody]) -> [TransitAspect] {
        var aspects: [TransitAspect] = []
        
        // Check transiting planets to natal planets
        let natalPlanets: [(String, Double)] = [
            ("Sun", chart.sun.longitude),
            ("Moon", chart.moon.longitude),
            ("Mercury", chart.mercury.longitude),
            ("Venus", chart.venus.longitude),
            ("Mars", chart.mars.longitude)
        ]
        
        // DAILY INSIGHTS: Only use fast-moving planets (change within days/weeks)
        // Skip Pluto, Neptune, Uranus (they give same aspect for months)
        let transitPriority = ["Saturn", "Jupiter", "Mars", "Venus", "Mercury"]
        
        for transitName in transitPriority {
            guard let transit = transits.first(where: { $0.name == transitName }) else { continue }
            
            for (natalName, natalLong) in natalPlanets {
                if let aspect = calculateAspect(
                    transitPlanet: transitName,
                    transitLong: transit.longitude,
                    natalPlanet: natalName,
                    natalLong: natalLong
                ) {
                    aspects.append(aspect)
                    // Only return the first significant aspect
                    if aspects.count >= 1 { return aspects }
                }
            }
        }
        
        return aspects
    }
    
    private func findSignificantAspects(chart: BirthChart, transits: [CelestialBody]) -> [TransitAspect] {
        // This is for weekly/monthly insights - includes slow-moving planets
        var aspects: [TransitAspect] = []
        
        // Check transiting planets to natal planets
        let natalPlanets: [(String, Double)] = [
            ("Sun", chart.sun.longitude),
            ("Moon", chart.moon.longitude),
            ("Mercury", chart.mercury.longitude),
            ("Venus", chart.venus.longitude),
            ("Mars", chart.mars.longitude)
        ]
        
        // Priority order for transiting planets (most significant first)
        let transitPriority = ["Pluto", "Neptune", "Uranus", "Saturn", "Jupiter", "Mars", "Venus", "Mercury", "Moon"]
        
        for transitName in transitPriority {
            guard let transit = transits.first(where: { $0.name == transitName }) else { continue }
            
            for (natalName, natalLong) in natalPlanets {
                if let aspect = calculateAspect(
                    transitPlanet: transitName,
                    transitLong: transit.longitude,
                    natalPlanet: natalName,
                    natalLong: natalLong
                ) {
                    aspects.append(aspect)
                    // Only return the first few most significant
                    if aspects.count >= 2 { return aspects }
                }
            }
        }
        
        return aspects
    }
    
    private func calculateAspect(
        transitPlanet: String,
        transitLong: Double,
        natalPlanet: String,
        natalLong: Double
    ) -> TransitAspect? {
        let diff = abs(transitLong - natalLong)
        let angle = diff > 180 ? 360 - diff : diff
        
        // Check for major aspects with tight orbs
        if angle < 8 { // Conjunction
            return TransitAspect(transitPlanet: transitPlanet, natalPlanet: natalPlanet, type: .conjunction, orb: angle)
        } else if abs(angle - 60) < 6 { // Sextile
            return TransitAspect(transitPlanet: transitPlanet, natalPlanet: natalPlanet, type: .sextile, orb: abs(angle - 60))
        } else if abs(angle - 90) < 8 { // Square
            return TransitAspect(transitPlanet: transitPlanet, natalPlanet: natalPlanet, type: .square, orb: abs(angle - 90))
        } else if abs(angle - 120) < 8 { // Trine
            return TransitAspect(transitPlanet: transitPlanet, natalPlanet: natalPlanet, type: .trine, orb: abs(angle - 120))
        } else if abs(angle - 180) < 8 { // Opposition
            return TransitAspect(transitPlanet: transitPlanet, natalPlanet: natalPlanet, type: .opposition, orb: abs(angle - 180))
        }
        
        return nil
    }
    
    // MARK: - Aspect Interpretation
    
    private func interpretAspect(_ aspect: TransitAspect, chart: BirthChart, transits: [CelestialBody]) -> String {
        // Get the specific interpretation based on planets and aspect type
        let key = "\(aspect.transitPlanet)-\(aspect.natalPlanet)-\(aspect.type.rawValue)"
        
        // Saturn aspects - pressure, structure, lessons
        if aspect.transitPlanet == "Saturn" {
            switch (aspect.natalPlanet, aspect.type) {
            case ("Sun", .conjunction), ("Sun", .square):
                return "You're being tested on your core identity. What you're facing now is showing you where you need to grow stronger."
            case ("Sun", .opposition):
                return "External pressure is forcing you to reckon with your responsibilities. Others are holding you accountable."
            case ("Moon", .square), ("Moon", .opposition):
                return "Your emotional needs are clashing with reality. Time to mature how you handle feelings."
            case ("Venus", .square):
                return "Relationship or financial reality check happening. What you want vs what's sustainable is getting real."
            case ("Mars", .square):
                return "Your drive is being blocked. This frustration is teaching you strategy and patience."
            default:
                return "Saturn is demanding maturity. Whatever feels hard right now is shaping your character."
            }
        }
        
        // Jupiter aspects - expansion, luck, opportunity
        if aspect.transitPlanet == "Jupiter" {
            switch (aspect.natalPlanet, aspect.type) {
            case ("Sun", .conjunction), ("Sun", .trine):
                return "Doors are opening. Your confidence is high. This is your moment to expand and take risks."
            case ("Venus", .conjunction), ("Venus", .trine):
                return "Love and money are flowing. Say yes to opportunities in relationships and finances."
            case ("Mars", .trine):
                return "Your actions have momentum behind them. Whatever you initiate now has Jupiter's backing."
            case (_, .square):
                return "Watch for overconfidence. The opportunity is real but don't overextend or overpromise."
            default:
                return "Growth opportunities are available. Trust your instincts but stay grounded."
            }
        }
        
        // Uranus aspects - change, awakening, disruption
        if aspect.transitPlanet == "Uranus" {
            switch (aspect.natalPlanet, aspect.type) {
            case ("Sun", .conjunction), ("Sun", .square):
                return "Your life is being disrupted for a reason. What's breaking apart was restricting your authenticity."
            case ("Moon", .square):
                return "Your emotional patterns are being shaken up. The chaos is pushing you toward freedom."
            case ("Venus", .square), ("Venus", .opposition):
                return "Relationships or values are shifting suddenly. What you want is evolving rapidly."
            default:
                return "Expect the unexpected. Change is liberating you from what was holding you back."
            }
        }
        
        // Pluto aspects - transformation, power, intensity
        if aspect.transitPlanet == "Pluto" {
            switch (aspect.natalPlanet, aspect.type) {
            case ("Sun", .conjunction), ("Sun", .square):
                return "Deep transformation is underway. Old versions of yourself are dying to make room for who you're becoming."
            case ("Moon", .square):
                return "Emotional intensity is off the charts. You're purging old patterns through confronting buried feelings."
            case ("Venus", .square):
                return "Power dynamics in relationships are surfacing. Who has control is being renegotiated."
            default:
                return "Something significant is ending to make space for rebirth. Let go of what's dead."
            }
        }
        
        // Mars aspects - action, conflict, energy
        if aspect.transitPlanet == "Mars" {
            switch (aspect.natalPlanet, aspect.type) {
            case ("Sun", .conjunction):
                return "Your energy is peak. Take bold action on what matters most."
            case ("Sun", .square), ("Mars", .square):
                return "Irritation and impatience are high. Channel frustration into productive action, not conflict."
            case ("Moon", .square):
                return "Emotions are running hot. You might snap at people. Take a beat before reacting."
            case ("Venus", .conjunction):
                return "Passion in relationships is intense. Go after what (or who) you want."
            default:
                return "Drive is high but so is potential for conflict. Use the energy wisely."
            }
        }
        
        // Venus aspects - love, values, money
        if aspect.transitPlanet == "Venus" {
            switch (aspect.natalPlanet, aspect.type) {
            case ("Sun", .conjunction), ("Sun", .trine):
                return "You're magnetic right now. Good time for relationships, creativity, and asking for what you're worth."
            case ("Venus", .conjunction):
                return "Relationship and money clarity hitting. What you value is crystal clear today."
            case ("Moon", .trine):
                return "Emotional and relational harmony. You know what you need and it feels accessible."
            default:
                return "Focus on what you value. Love and money themes are highlighted."
            }
        }
        
        // Mercury aspects - communication, thinking
        if aspect.transitPlanet == "Mercury" {
            switch (aspect.natalPlanet, aspect.type) {
            case ("Sun", .conjunction):
                return "Mental clarity is sharp. Good day for important conversations and decisions."
            case ("Mercury", .conjunction):
                return "Your mind is processing quickly. Communicate, write, plan."
            case (_, .square):
                return "Communication mix-ups likely. Double-check messages and be extra clear."
            default:
                return "Your thoughts are active. Pay attention to what your mind is trying to tell you."
            }
        }
        
        // Moon aspects - emotional tone
        if aspect.transitPlanet == "Moon" {
            switch aspect.type {
            case .conjunction:
                return "New emotional beginning. You're feeling things fresh."
            case .opposition:
                return "Emotional peak. Things that have been building are coming to a head."
            case .square:
                return "Emotional tension. Inner conflict between what you need and what's required."
            default:
                return "Notice how you're feeling. Your emotions are giving you information."
            }
        }
        
        // Generic fallback based on aspect type
        return aspect.type.isHard 
            ? "Tension between \(aspect.transitPlanet.lowercased()) and your natal \(aspect.natalPlanet.lowercased()) is creating friction. This challenge has a purpose."
            : "Flow between transiting \(aspect.transitPlanet.lowercased()) and your \(aspect.natalPlanet.lowercased()) is supporting you. Use it."
    }
    
    // MARK: - Moon-Specific Daily Insights
    
    private func findMoonAspects(moon: CelestialBody, chart: BirthChart) -> [TransitAspect] {
        var aspects: [TransitAspect] = []
        
        let natalPlanets: [(String, Double)] = [
            ("Sun", chart.sun.longitude),
            ("Moon", chart.moon.longitude),
            ("Mercury", chart.mercury.longitude),
            ("Venus", chart.venus.longitude),
            ("Mars", chart.mars.longitude)
        ]
        
        // TIGHT orbs (3°) so Moon aspects are rare and special
        // Moon moves 13°/day, so 3° orb = ~5-6 hours of exact aspect
        // This ensures daily variations show most of the time
        let orb = 3.0
        
        for (natalName, natalLong) in natalPlanets {
            let diff = abs(moon.longitude - natalLong)
            let angle = diff > 180 ? 360 - diff : diff
            
            if angle < orb { // Conjunction
                aspects.append(TransitAspect(transitPlanet: "Moon", natalPlanet: natalName, type: .conjunction, orb: angle))
            } else if abs(angle - 90) < orb { // Square
                aspects.append(TransitAspect(transitPlanet: "Moon", natalPlanet: natalName, type: .square, orb: abs(angle - 90)))
            } else if abs(angle - 120) < orb { // Trine
                aspects.append(TransitAspect(transitPlanet: "Moon", natalPlanet: natalName, type: .trine, orb: abs(angle - 120)))
            } else if abs(angle - 180) < orb { // Opposition
                aspects.append(TransitAspect(transitPlanet: "Moon", natalPlanet: natalName, type: .opposition, orb: abs(angle - 180)))
            }
        }
        
        return aspects
    }
    
    private func interpretMoonAspect(_ aspect: TransitAspect, moon: CelestialBody, chart: BirthChart) -> String {
        // Moon aspects change daily - give specific daily guidance
        switch (aspect.natalPlanet, aspect.type) {
        case ("Sun", .conjunction):
            return "New emotional beginning today as the Moon aligns with your core identity. Your heart and mind are on the same page, making decisions feel clearer and more authentic. Trust what feels right—your intuition is especially accurate now. This is a good time to start something that matters to you."
        case ("Sun", .square):
            return "Internal tension between what you need emotionally and what you want to express. You might feel pulled in different directions, which can be uncomfortable but also illuminating. Give yourself space to feel conflicted without forcing resolution. Sometimes the friction reveals what actually matters."
        case ("Sun", .opposition):
            return "Your emotions are running high and demanding attention today. What you're feeling might contrast sharply with your usual composure or plans. Don't suppress what's coming up—this opposition is bringing important feelings to the surface. Others might push your buttons, but they're just reflecting something you need to acknowledge."
        case ("Sun", .trine):
            return "You're in flow with yourself today. What you need emotionally and what you want to do are naturally aligned, making everything feel easier. This is one of those rare days where you don't have to choose between being true to yourself and being practical. Enjoy the harmony."
            
        case ("Moon", .conjunction):
            return "Emotional reset happening today. Your inner world is being refreshed, bringing new awareness of what you actually need versus what you've been telling yourself you need. Pay attention to what you're feeling—it's showing you something important about where you're headed. This clarity doesn't come often."
        case ("Moon", .square):
            return "Old emotional patterns are surfacing, probably through irritation or frustration with something today. What's bothering you isn't random—it's connected to a deeper habit or fear that's ready to shift. Instead of pushing the feeling away, get curious about what it's trying to teach you."
        case ("Moon", .opposition):
            return "Emotions have peaked. Things that have been building internally are coming to a head, and you can't ignore them anymore. This might feel intense, but it's actually healthy—suppressed feelings eventually demand release. Let yourself feel what's there instead of analyzing it away."
        case ("Moon", .trine):
            return "Emotionally harmonious day where you feel comfortable in your own skin. Your needs and your reality are working together instead of against each other. This is a good day to just be rather than do—you don't need to prove anything or push for anything right now."
            
        case ("Venus", .conjunction):
            return "What you love and what you need emotionally are perfectly aligned today. There's harmony between your values and your feelings, making relationships and creative expression feel natural and fulfilling. Good day for pleasure, connection, and doing things that bring you genuine joy rather than just checking boxes."
        case ("Venus", .square):
            return "Tension between emotional security and what you desire. Part of you wants safety and comfort, while another part craves excitement or change. This conflict is actually revealing where you've been playing it too safe or, conversely, where you've been chasing excitement at the expense of stability. Both needs are valid."
        case ("Venus", .trine):
            return "Love, beauty, and emotional needs are flowing together effortlessly today. Relationships feel easy and fulfilling rather than complicated or demanding. This is a day to appreciate what's working instead of focusing on what needs fixing. Let yourself enjoy simple pleasures without guilt."
            
        case ("Mars", .conjunction):
            return "Emotions are fueling action today—you're ready to fight for what you need. This can be powerful if channeled well, but watch for impulsive reactions that you'll regret later. The key is using this energy to take bold steps toward what matters, not just venting frustration at whoever's nearby. Direct the fire wisely."
        case ("Mars", .square):
            return "Emotional frustration is seeking an outlet, and you might find yourself more irritable or reactive than usual. The people around you aren't actually trying to provoke you—your emotions are just running hot. Before you snap at someone, pause and ask what you're really frustrated about. Channel this into productive action, not conflict."
        case ("Mars", .trine):
            return "Confident emotional expression comes naturally today. You know what you need and you're not afraid to go after it, but it doesn't feel aggressive or pushy—it feels right. This is the energy of healthy assertion where your actions align with your feelings. Good day to initiate difficult conversations or take bold moves."
            
        case ("Mercury", .conjunction):
            return "Your feelings and thoughts are perfectly synced today, making it easier than usual to understand what you're experiencing and put it into words. This is a good day to talk about what you've been processing internally. Whether it's journaling, therapy, or just a deep conversation with someone you trust, communication clarifies things now."
        case ("Mercury", .square):
            return "Head and heart are in conflict. Logic is telling you one thing while your feelings are saying something completely different. Don't try to force them to agree—sit with both perspectives. Sometimes the answer isn't choosing between them, but understanding why they're at odds in the first place."
        case ("Mercury", .trine):
            return "It's unusually easy to articulate what you're feeling today. Your emotions aren't overwhelming your thinking, and your thoughts aren't dismissing your feelings—they're working together. This is a good day for important conversations, especially ones where you need to be both clear and emotionally honest."
            
        default:
            return interpretMoonSign(moon, chart: chart)
        }
    }
    
    private func interpretDailyMoonEnergy(_ moon: CelestialBody, chart: BirthChart, date: Date) -> String {
        let moonSign = moon.position.sign
        let dayOfWeek = Calendar.current.component(.weekday, from: date)
        
        // Add daily variation to Moon sign interpretations
        let variations: [String]
        
        switch moonSign {
        case .aries:
            variations = [
                "Moon in Aries. Your patience is especially thin today, and waiting feels almost physically uncomfortable. Rather than fighting this restless energy, channel it into decisive action on something you've been putting off. Quick, bold moves feel more natural than careful planning right now. Just watch your temper when others move too slowly for your taste.",
                "Moon in Aries. Bold, impulsive moves feel completely natural today—your instincts are sharp and your courage is high. This isn't the time for second-guessing or overthinking; your gut knows what it wants and hesitation will only frustrate you. Trust your initial reactions, but maybe run big decisions past someone level-headed before you act on pure adrenaline.",
                "Moon in Aries. Restless, aggressive energy is coursing through you and needs a physical outlet before it turns into irritability or reckless choices. Exercise, cleaning, or any kind of movement helps discharge the excess fire. Sitting still or waiting around will make you feel trapped and reactive, so give yourself permission to be more physically active than usual."
            ]
        case .taurus:
            variations = [
                "Moon in Taurus. Everything in you is saying to slow down and ground yourself in physical comfort. Your body knows exactly what it needs right now—whether that's rest, good food, nature, or just not being rushed. Listen to those signals instead of overriding them with productivity guilt. Sometimes doing less is exactly the right thing.",
                "Moon in Taurus. Comfort and stability aren't luxuries today—they're emotional necessities. You need predictability, routine, and things that feel solid and reliable. There's nothing wrong with wanting security right now; pushing yourself to be spontaneous or adventurous will just make you feel more unsettled. Lean into what feels safe.",
                "Moon in Taurus. Sensory experiences ground your emotions today more than logic or conversation ever could. Good food, pleasant textures, beautiful surroundings, physical touch—these aren't indulgences, they're how you process what you're feeling. Spend time with people who feel stable and calming, not ones who bring chaos or urgency."
            ]
        case .gemini:
            variations = [
                "Moon in Gemini. Your mind is moving fast and won't shut up, which can feel overwhelming or energizing depending on how you channel it. Let your thoughts out through writing, talking, texting, or learning something new—trying to suppress the mental activity will just make you anxious. Call that friend you haven't talked to in a while; conversation feeds you today.",
                "Moon in Gemini. Curiosity is through the roof and you want to know a little bit about everything rather than focusing deeply on one thing. Follow the interesting threads wherever they lead instead of forcing yourself to concentrate on a single task. Your attention will naturally bounce around, and that's actually productive right now—don't fight your nature today.",
                "Moon in Gemini. Social butterfly energy is high and you're craving variety in your interactions. Multiple short conversations feel more satisfying than one long deep one. Texting three different people, scrolling through ideas, flitting between topics—this isn't distraction, it's how you process information and emotions right now. Let yourself be light and curious."
            ]
        case .cancer:
            variations = [
                "Moon in Cancer. You're extra sensitive today—what usually rolls off your back might cut deeper than expected. This isn't weakness, it's heightened emotional awareness that can actually be useful if you protect your energy. Spend time with people who understand you and avoid ones who dismiss feelings as overreactions. Home and emotional safety matter more than productivity right now.",
                "Moon in Cancer. Home, family, and people who genuinely get you are where you'll find comfort today. You're not in the mood for surface-level interactions or pretending everything is fine when it's not. Seek out the spaces and faces that let you drop the mask completely. Your inner world needs tending, and that's not selfish—it's necessary.",
                "Moon in Cancer. Feelings are running deep, and trying to rationalize them away will only make you feel more disconnected from yourself. Honor what's coming up instead of explaining it into something more acceptable or understandable. Your emotions have their own intelligence that doesn't need to make logical sense to be valid and important."
            ]
        case .leo:
            variations = [
                "Moon in Leo. You need to be seen, celebrated, and appreciated today—not in a superficial way, but genuinely. Don't shrink yourself or downplay your talents to make others comfortable with their own insecurities. Your warmth and confidence actually inspire people when you let them shine through. Be big, be bold, be yourself without apology.",
                "Moon in Leo. Creative expression feels urgent and necessary, not optional. You need to make something, perform something, or share something that reflects who you really are. Make space for it somehow, even if it's just 20 minutes—suppressing this need will leave you feeling flat and uninspired. Your creativity is how you process emotions right now.",
                "Moon in Leo. Your natural warmth and generosity are drawing people to you, and you genuinely enjoy being at the center of things today. Let yourself shine without guilt or self-consciousness. This isn't ego—it's authentic self-expression. When you're fully in your energy, you actually give others permission to do the same."
            ]
        case .virgo:
            variations = [
                "Moon in Virgo. Organizing, cleaning, and fixing things actually calms your nervous system right now. What looks like procrastination might actually be your way of creating order in your internal world by creating it in your external one. Clean your space, organize your files, fix that annoying thing—these small acts of improvement ground you emotionally.",
                "Moon in Virgo. You're noticing every flaw, imperfection, and thing that could be better—in yourself, others, and your environment. This critical eye can be channeled into genuine improvement or it can spiral into paralyzing self-criticism. Choose the former. Fix what you can, accept what you can't, and remember that perfect doesn't exist.",
                "Moon in Virgo. Helping others, solving problems, and being useful feels genuinely satisfying today. Your analytical mind and desire to improve things are gifts when applied with compassion. Just watch that you don't lose yourself completely in service to others. You're allowed to have needs even while you're busy meeting everyone else's."
            ]
        case .libra:
            variations = [
                "Moon in Libra. You need beauty, harmony, and balance around you today—not as superficial decoration but as emotional nourishment. Create it in some small way: rearrange something, put on music that feels right, spend time in a space that's aesthetically pleasing. Your environment directly affects your emotional state more than usual right now.",
                "Moon in Libra. Relationships take center stage, and you're more focused on connection than productivity. Quality time with people you care about feeds you more than checking things off your to-do list. This isn't laziness—it's recognizing that your emotional well-being depends on feeling in harmony with the people around you.",
                "Moon in Libra. Harmony and peace feel essential, but watch that you're not faking it to avoid necessary but uncomfortable conversations. Real balance sometimes requires temporary imbalance—speaking up when you'd rather stay quiet, choosing your own needs when you'd rather accommodate. True harmony can't be built on silent resentment."
            ]
        case .scorpio:
            variations = [
                "Moon in Scorpio. Everything feels more intense today—emotions run deeper, perceptions cut sharper, and surface-level interactions feel completely unsatisfying. You're seeing through people's pretenses and noticing what's really going on beneath the words. This X-ray vision can be isolating, but it's also powerful. Trust what you're sensing, even if you can't prove it.",
                "Moon in Scorpio. Deep, complex emotions are demanding space and refusing to be rushed or simplified. Don't try to resolve them quickly or talk yourself out of what you're feeling. Sit with the intensity instead of running from it—this is how real transformation happens. You're not being dramatic, you're processing something significant.",
                "Moon in Scorpio. Trust and betrayal themes are surfacing, making you more aware of who genuinely has your back versus who just says they do. Pay attention to who earns your vulnerability through consistent actions, not just nice words. Your instinct to be selective about who you let close is wisdom, not paranoia, especially today."
            ]
        case .sagittarius:
            variations = [
                "Moon in Sagittarius. Routine, confinement, and repetitive tasks feel absolutely suffocating today. You need mental or physical space to roam—whether that's a literal adventure, learning something new, or just breaking your usual patterns. Find freedom in whatever way you can, even if it's small. Your spirit needs room to breathe right now.",
                "Moon in Sagittarius. Your natural optimism and bigger-picture vision are especially strong, and you can see possibilities that others are missing. Share your perspective—not everyone has your ability to zoom out and find meaning in chaos. Your enthusiasm isn't naivety, it's a genuine gift that helps people remember what they're working toward.",
                "Moon in Sagittarius. Adventure is calling, even if it's just in small doses—a different route home, a new restaurant, a conversation with a stranger, learning about something unfamiliar. The sameness of daily life feels particularly heavy today. Your spirit thrives on variety and exploration, so give yourself permission to mix things up somehow."
            ]
        case .capricorn:
            variations = [
                "Moon in Capricorn. Emotions feel more controlled and practical today—you're less interested in processing feelings and more focused on what actually needs to get done. Structure, routine, and tangible progress are comforting right now. There's nothing wrong with channeling emotional energy into productivity instead of analysis. Sometimes doing is better than feeling.",
                "Moon in Capricorn. Focus on what's productive and achievable rather than what's emotionally complicated. Your feelings don't need to be resolved right now—they can wait while you handle practical matters. This isn't suppression, it's strategic compartmentalization. You function better when you can see concrete results, so give yourself permission to prioritize that today.",
                "Moon in Capricorn. Responsibility weighs particularly heavy today, and you might feel like you're carrying everything alone. While your strength and reliability are real, remember that asking for help isn't weakness. You don't actually have to do it all yourself, even if you're capable of it. Let someone else carry part of the load."
            ]
        case .aquarius:
            variations = [
                "Moon in Aquarius. You need emotional and mental space from intensity, drama, and heavy feelings. Intellectual detachment isn't coldness—it's self-care when emotions threaten to overwhelm you. Zoom out, observe from a distance, think rather than feel for a while. This perspective helps you process without drowning. Your need for space doesn't make you unfeeling.",
                "Moon in Aquarius. Group projects, community causes, and collective energy feel more nourishing than one-on-one emotional intensity. You're more interested in ideas, innovation, and forward movement than personal drama right now. This isn't avoidance—it's where you find meaning. You connect through shared vision more than shared feelings today.",
                "Moon in Aquarius. Your perspective is genuinely unique and a little outside the norm, which can feel isolating but is actually your strength. Don't normalize yourself or pretend to see things the way everyone else does just to fit in. The world needs people who think differently, and your willingness to be unconventional opens doors others don't even see."
            ]
        case .pisces:
            variations = [
                "Moon in Pisces. Boundaries between you and others blur today, making it easy to absorb people's emotions as if they're your own. Protect your energy intentionally—limit time with emotional vampires and people who drain rather than reciprocate. Your empathy is a gift, but not if it leaves you depleted. You can care without dissolving completely.",
                "Moon in Pisces. Intuition is loud and insistent today, giving you hits about people and situations that you can't logically explain. Trust these impressions even if you can't prove them—your subconscious is picking up on subtle cues that your conscious mind misses. That feeling you have about something is information, not paranoia.",
                "Moon in Pisces. Everything feels dreamlike, emotional, and a bit surreal. Reality can feel too harsh and practical today, so taking breaks into imagination, music, art, or daydreaming isn't escapism—it's how you recharge. You need time in your inner world to balance the demands of the outer one. Let yourself drift."
            ]
        }
        
        // Use day of week to rotate through variations
        let index = dayOfWeek % variations.count
        return variations[index]
    }
    
    private func interpretMoonSign(_ moon: CelestialBody, chart: BirthChart) -> String {
        // This is now just a fallback - we use interpretDailyMoonEnergy instead
        return interpretDailyMoonEnergy(moon, chart: chart, date: Date())
    }
}

// MARK: - Supporting Types

struct TransitAspect {
    let transitPlanet: String
    let natalPlanet: String
    let type: AspectType
    let orb: Double
}

extension AspectType {
    var isHard: Bool {
        self == .square || self == .opposition
    }
    
    var isSoft: Bool {
        self == .trine || self == .sextile
    }
}

