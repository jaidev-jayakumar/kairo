import Foundation
import AVFoundation

/// Service for handling premium text-to-speech using ElevenLabs API
class ElevenLabsService: NSObject, ObservableObject {
    static let shared = ElevenLabsService()
    
    @Published var isPlaying = false
    @Published var isSynthesizing = false
    
    private let apiKey: String
    private let baseURL = "https://api.elevenlabs.io/v1"
    private var urlSession: URLSession
    private var audioPlayer: AVAudioPlayer?
    
    // Available voices (you can customize these)
    private let availableVoices = [
        Voice(id: "21m00Tcm4TlvDq8ikWAM", name: "Rachel", description: "Calm, warm female voice"),
        Voice(id: "AZnzlk1XvdvUeBnXmlld", name: "Domi", description: "Confident, clear female voice"),
        Voice(id: "EXAVITQu4vr4xnSDxMaL", name: "Bella", description: "Gentle, soothing female voice"),
        Voice(id: "ErXwobaYiN019PkySvjV", name: "Antoni", description: "Deep, wise male voice"),
        Voice(id: "VR6AewLTigWG4xSOukaG", name: "Arnold", description: "Authoritative male voice")
    ]
    
    // Default voice - you can change this to any voice ID from above
    private var selectedVoiceId = "21m00Tcm4TlvDq8ikWAM" // Rachel - warm and mystical
    
    private override init() {
        // Load API key from APIKeys.plist
        if let path = Bundle.main.path(forResource: "APIKeys", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let key = plist["ELEVENLABS_API_KEY"] as? String {
            self.apiKey = key
        } else {
            self.apiKey = ""
            print("⚠️ Warning: Please add ELEVENLABS_API_KEY to APIKeys.plist to enable voice synthesis.")
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.urlSession = URLSession(configuration: config)
        
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Use a more flexible category that works with recording
            try audioSession.setCategory(.playback, 
                                       mode: .spokenAudio, 
                                       options: [.duckOthers, .allowBluetooth, .mixWithOthers])
            
            // Only activate when we actually need to play
            // We'll activate it just before playing audio
        } catch {
            print("⚠️ Failed to setup audio session for playback: \(error)")
        }
    }
    
    // MARK: - Voice Selection
    
    func setVoice(_ voiceId: String) {
        selectedVoiceId = voiceId
    }
    
    func getAvailableVoices() -> [Voice] {
        return availableVoices
    }
    
    // MARK: - Text-to-Speech
    
    func synthesizeAndPlay(text: String) async throws {
        guard !apiKey.isEmpty else {
            throw ElevenLabsError.missingAPIKey
        }
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ElevenLabsError.emptyText
        }
        
        DispatchQueue.main.async {
            self.isSynthesizing = true
        }
        
        do {
            let audioData = try await synthesizeSpeech(text: text)
            await playAudio(data: audioData)
        } catch {
            DispatchQueue.main.async {
                self.isSynthesizing = false
            }
            throw error
        }
    }
    
    private func synthesizeSpeech(text: String) async throws -> Data {
        let url = URL(string: "\(baseURL)/text-to-speech/\(selectedVoiceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        
        let requestBody = SynthesisRequest(
            text: text,
            model_id: "eleven_monolingual_v1",
            voice_settings: VoiceSettings(
                stability: 0.5,
                similarity_boost: 0.5,
                style: 0.3,
                use_speaker_boost: true
            )
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw ElevenLabsError.encodingError
        }
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ElevenLabsError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                // Try to parse error message
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorData["detail"] as? String {
                    throw ElevenLabsError.apiError(httpResponse.statusCode, detail)
                } else {
                    throw ElevenLabsError.apiError(httpResponse.statusCode, "Unknown error")
                }
            }
            
            return data
            
        } catch {
            if error is ElevenLabsError {
                throw error
            } else {
                throw ElevenLabsError.networkError(error)
            }
        }
    }
    
    @MainActor
    private func playAudio(data: Data) async {
        do {
            isSynthesizing = false
            
            // Activate audio session just before playing
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setActive(true)
            } catch {
                print("⚠️ Warning: Failed to activate audio session for playback: \(error)")
                // Continue anyway - might still work
            }
            
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            isPlaying = true
            audioPlayer?.play()
            
        } catch {
            print("⚠️ Failed to play audio: \(error)")
            isPlaying = false
            isSynthesizing = false
        }
    }
    
    // MARK: - Playback Control
    
    func stopPlayback() {
        audioPlayer?.stop()
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
    
    func pausePlayback() {
        audioPlayer?.pause()
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
    
    func resumePlayback() {
        audioPlayer?.play()
        DispatchQueue.main.async {
            self.isPlaying = true
        }
    }
    
    // MARK: - Voice Streaming (for longer texts)
    
    func synthesizeAndStream(text: String) async throws {
        guard !apiKey.isEmpty else {
            throw ElevenLabsError.missingAPIKey
        }
        
        // For streaming, we can split longer texts into chunks
        let chunks = splitTextIntoChunks(text)
        
        for chunk in chunks {
            try await synthesizeAndPlay(text: chunk)
            
            // Wait for current chunk to finish
            while isPlaying || isSynthesizing {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }
    }
    
    private func splitTextIntoChunks(_ text: String, maxLength: Int = 500) -> [String] {
        guard text.count > maxLength else { return [text] }
        
        var chunks: [String] = []
        var currentChunk = ""
        
        let sentences = text.components(separatedBy: ". ")
        
        for sentence in sentences {
            if currentChunk.count + sentence.count > maxLength && !currentChunk.isEmpty {
                chunks.append(currentChunk + ".")
                currentChunk = sentence
            } else {
                if !currentChunk.isEmpty {
                    currentChunk += ". "
                }
                currentChunk += sentence
            }
        }
        
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        return chunks.isEmpty ? [text] : chunks
    }
}

// MARK: - AVAudioPlayerDelegate

extension ElevenLabsService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
        
        // Deactivate audio session to allow recording again
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ Warning: Failed to deactivate audio session after playback: \(error)")
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
        
        // Also deactivate on error
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ Warning: Failed to deactivate audio session after error: \(error)")
        }
        
        if let error = error {
            print("⚠️ Audio player decode error: \(error)")
        }
    }
}

// MARK: - Data Models

struct Voice {
    let id: String
    let name: String
    let description: String
}

struct SynthesisRequest: Codable {
    let text: String
    let model_id: String
    let voice_settings: VoiceSettings
}

struct VoiceSettings: Codable {
    let stability: Double
    let similarity_boost: Double
    let style: Double
    let use_speaker_boost: Bool
}

// MARK: - Error Handling

enum ElevenLabsError: LocalizedError {
    case missingAPIKey
    case emptyText
    case encodingError
    case invalidResponse
    case apiError(Int, String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "ElevenLabs API key is missing. Please add it to APIKeys.plist."
        case .emptyText:
            return "Cannot synthesize empty text."
        case .encodingError:
            return "Failed to encode synthesis request."
        case .invalidResponse:
            return "Invalid response from ElevenLabs API."
        case .apiError(let statusCode, let message):
            return "ElevenLabs API error (\(statusCode)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
