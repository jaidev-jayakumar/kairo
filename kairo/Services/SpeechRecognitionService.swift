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
            
            // Use recording-optimized settings - don't force sample rate
            try audioSession.setCategory(.record, 
                                       mode: .measurement, 
                                       options: [.allowBluetooth, .duckOthers])
            
            // Activate with a delay to prevent RPC timeouts
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Wait for the session to stabilize
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            print("✅ Audio session configured successfully")
            
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
        
        // Use the input format for input nodes - this is the correct format to read
        let nodeFormat = inputNode.inputFormat(forBus: 0)
        print("📱 Node format: \(nodeFormat.sampleRate) Hz, \(nodeFormat.channelCount) ch")
        
        try await installTapWithFormat(nodeFormat: nodeFormat,
                                     inputNode: inputNode,
                                     recognitionRequest: recognitionRequest)
    }
    
    private func installTapWithFormat(nodeFormat: AVAudioFormat,
                                    inputNode: AVAudioInputNode,
                                    recognitionRequest: SFSpeechAudioBufferRecognitionRequest) async throws {
        do {
            inputNode.removeTap(onBus: 0)

            // Match the node's format exactly
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: nodeFormat) { buffer, _ in
                recognitionRequest.append(buffer)
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
