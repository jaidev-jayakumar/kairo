import Foundation
import Speech
import AVFoundation

// MARK: - Error Types

enum SpeechRecognitionError: LocalizedError {
    case authorizationDenied
    case recognizerNotAvailable
    case unableToCreateRequest
    case recognitionFailed(Error)
    case audioEngineError
    case alreadyRecording
    
    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Speech recognition access denied. Please enable it in Settings."
        case .recognizerNotAvailable:
            return "Speech recognizer is not available."
        case .unableToCreateRequest:
            return "Unable to create speech recognition request."
        case .recognitionFailed(let error):
            return "Speech recognition failed: \(error.localizedDescription)"
        case .audioEngineError:
            return "Audio engine error occurred."
        case .alreadyRecording:
            return "Already recording."
        }
    }
}

/// Service for handling speech recognition using Apple's Speech Framework
class SpeechRecognitionService: NSObject, ObservableObject {
    static let shared = SpeechRecognitionService()
    
    @Published var isRecording = false
    @Published var isAuthorized = false
    @Published var lastTranscription = ""
    @Published var error: SpeechRecognitionError?
    
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private override init() {
        super.init()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                DispatchQueue.main.async {
                    self.isAuthorized = authStatus == .authorized
                    continuation.resume(returning: authStatus == .authorized)
                }
            }
        }
    }
    
    private func requestMicrophoneAccess() async throws -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    // MARK: - Recording Control
    
    func startRecording() async throws {
        guard isAuthorized else {
            throw SpeechRecognitionError.authorizationDenied
        }
        
        guard speechRecognizer?.isAvailable == true else {
            throw SpeechRecognitionError.recognizerNotAvailable
        }
        
        // Request microphone access
        let micGranted = try await requestMicrophoneAccess()
        if !micGranted {
            throw SpeechRecognitionError.authorizationDenied
        }
        
        // Cancel any previous task
        stopRecording()
        
        // Configure audio session with robust settings for both device and simulator
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Deactivate any previous session cleanly
            do {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            } catch {
                // Ignore deactivation errors - session might not have been active
            }
            
            // Use speech recognition optimized settings with standard sample rate
            try audioSession.setCategory(.record, 
                                       mode: .spokenAudio,
                                       options: [.allowBluetooth, .duckOthers])
            
            // Set preferred sample rate to 44.1kHz to avoid conflicts
            try audioSession.setPreferredSampleRate(44100)
            // Also set preferred buffer duration for stability
            try audioSession.setPreferredIOBufferDuration(0.02) // 20ms buffer
            
            // Activate with a delay to prevent RPC timeouts
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Wait for the session to stabilize and force refresh
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds for proper init
            
            // Verify the session is properly configured
            let actualSampleRate = audioSession.sampleRate
            let actualChannels = audioSession.inputNumberOfChannels
            print("✅ Audio session configured: \(actualSampleRate) Hz, \(actualChannels) ch")
            
        } catch {
            print("⚠️ Primary audio session setup failed: \(error)")
            
            // Try a simpler fallback configuration
            do {
                try audioSession.setCategory(.record)
                try await Task.sleep(nanoseconds: 100_000_000)
                try audioSession.setActive(true)
                try await Task.sleep(nanoseconds: 100_000_000)
                print("✅ Fallback audio session configured")
            } catch {
                print("❌ All audio session configurations failed: \(error)")
                // Continue anyway - the engine might still work
            }
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.unableToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Start recognition task first
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.lastTranscription = result.bestTranscription.formattedString
                }
                
                if let error = error {
                    print("Speech recognition error: \(error)")
                    self?.error = .recognitionFailed(error)
                    self?.stopRecording()
                }
            }
        }
        
        // Configure audio engine with robust format handling
        try await configureAudioEngine(recognitionRequest: recognitionRequest)
        
        DispatchQueue.main.async {
            self.isRecording = true
            self.error = .none
        }
    }
    
    private func configureAudioEngine(recognitionRequest: SFSpeechAudioBufferRecognitionRequest) async throws {
        let inputNode = audioEngine.inputNode
        
        // Stop and reset audio engine if it's already running
        if audioEngine.isRunning {
            audioEngine.stop()
            inputNode.removeTap(onBus: 0)
            // Small delay to ensure complete cleanup
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Force the audio engine to reset completely
        audioEngine.reset()
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Get fresh input node after reset
        let freshInputNode = audioEngine.inputNode
        let nodeFormat = freshInputNode.inputFormat(forBus: 0)
        print("📱 Node format after reset: \(nodeFormat.sampleRate) Hz, \(nodeFormat.channelCount) ch")
        
        // CRITICAL: Tap format MUST match hardware format exactly
        // Use the actual hardware format for the tap, convert later if needed
        let tapFormat: AVAudioFormat
        if nodeFormat.sampleRate > 0 && nodeFormat.channelCount > 0 {
            tapFormat = nodeFormat
            print("✅ Using hardware format for tap: \(tapFormat.sampleRate) Hz, \(tapFormat.channelCount) ch")
        } else {
            // Fallback only if hardware format is completely invalid
            guard let fallbackFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else {
                throw SpeechRecognitionError.audioEngineError
            }
            tapFormat = fallbackFormat
            print("⚠️ Using fallback format: \(tapFormat.sampleRate) Hz, \(tapFormat.channelCount) ch")
        }
        
        try await installTapWithFormat(nodeFormat: tapFormat,
                                     inputNode: freshInputNode,
                                     recognitionRequest: recognitionRequest)
    }
    
    private func installTapWithFormat(nodeFormat: AVAudioFormat,
                                    inputNode: AVAudioInputNode,
                                    recognitionRequest: SFSpeechAudioBufferRecognitionRequest) async throws {
        do {
            inputNode.removeTap(onBus: 0)

            // Create converter if needed for speech recognition (prefers 16kHz or 44.1kHz)
            let preferredSampleRate: Double = 16000  // Speech recognition optimal rate
            let needsConversion = nodeFormat.sampleRate != preferredSampleRate
            
            var audioConverter: AVAudioConverter?
            var preferredFormat: AVAudioFormat?
            
            if needsConversion {
                preferredFormat = AVAudioFormat(standardFormatWithSampleRate: preferredSampleRate, channels: 1)
                if let prefFormat = preferredFormat {
                    audioConverter = AVAudioConverter(from: nodeFormat, to: prefFormat)
                    print("🔄 Will convert from \(nodeFormat.sampleRate)Hz to \(prefFormat.sampleRate)Hz")
                }
            }

            // Install tap with hardware format, convert in callback if needed
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: nodeFormat) { [weak audioConverter, weak preferredFormat] buffer, _ in
                
                if let converter = audioConverter, let prefFormat = preferredFormat {
                    // Convert the audio format for speech recognition
                    let frameCapacity = AVAudioFrameCount((Double(buffer.frameLength) * prefFormat.sampleRate) / nodeFormat.sampleRate)
                    
                    guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: prefFormat, frameCapacity: frameCapacity) else {
                        recognitionRequest.append(buffer) // Fallback to original
                        return
                    }
                    
                    var error: NSError?
                    let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                        outStatus.pointee = .haveData
                        return buffer
                    }
                    
                    if status == .haveData && error == nil {
                        recognitionRequest.append(convertedBuffer)
                    } else {
                        recognitionRequest.append(buffer) // Fallback to original
                    }
                } else {
                    // No conversion needed
                    recognitionRequest.append(buffer)
                }
            }

            audioEngine.prepare()
            try await Task.sleep(nanoseconds: 50_000_000)
            try audioEngine.start()

            print("✅ Audio engine started with: \(nodeFormat.sampleRate) Hz, \(nodeFormat.channelCount) ch")
        } catch {
            if audioEngine.isRunning { audioEngine.stop() }
            inputNode.removeTap(onBus: 0)
            throw SpeechRecognitionError.audioEngineError
        }
    }
    
    func stopRecording() {
        // Stop audio engine first
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // Clean up recognition components
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Properly deactivate audio session to prevent conflicts
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ Failed to deactivate audio session: \(error)")
            // Continue cleanup anyway
        }
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechRecognitionService: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async {
            if !available {
                self.stopRecording()
            }
        }
    }
}
