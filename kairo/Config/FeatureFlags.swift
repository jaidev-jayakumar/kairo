import Foundation

/// Feature flags for controlling app functionality
/// Easy toggle for expensive or experimental features
struct FeatureFlags {
    
    // MARK: - AI Features
    
    /// Enable the entire Kaira voice assistant tab
    /// When disabled, the tab is completely hidden from the app
    /// Cost: ~$0.01/day per user (OpenAI) + $0.15/day if ElevenLabs enabled
    static let enableVoiceAssistant = false
    
    /// Enable ElevenLabs text-to-speech synthesis
    /// Only used if enableVoiceAssistant is true
    /// Cost: ~$0.30 per 1000 characters synthesized
    static let enableElevenLabs = false
    
    /// Enable OpenAI responses for insights
    /// When disabled, uses comprehensive hand-written fallbacks
    /// Cost: ~$0.002 per response (gpt-3.5-turbo)
    static let enableOpenAI = false
    
    // MARK: - Future Flags
    
    /// Enable weekly AI insights (currently enabled by default)
    static let enableWeeklyAIInsights = true
    
    /// Enable monthly AI insights (currently enabled by default)
    static let enableMonthlyAIInsights = true
    
    /// Enable yearly AI insights (currently enabled by default)
    static let enableYearlyAIInsights = true
}

