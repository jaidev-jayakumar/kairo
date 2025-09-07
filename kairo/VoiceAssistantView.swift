import SwiftUI
import Speech

struct VoiceAssistantView: View {
    @StateObject private var speechService = SpeechRecognitionService.shared
    @StateObject private var openAIService = OpenAIService.shared
    @StateObject private var elevenLabsService = ElevenLabsService.shared
    
    @State private var isRecording = false
    @State private var isProcessing = false
    @State private var pulseAnimation = false
    @State private var lastTranscription = ""
    @State private var lastResponse = ""
    @State private var showPermissionAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // Clean black background to match app theme
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Minimal header
                headerSection
                
                Spacer()
                
                // Main microphone interface
                microphoneInterface
                
                Spacer()
                
                // Bottom spacing for tab bar
                Spacer().frame(height: 120)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            pulseAnimation = true
            requestPermissions()
        }
        .alert("Permissions Required", isPresented: $showPermissionAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable microphone and speech recognition permissions in Settings to use the voice assistant.")
        }
        .onChange(of: speechService.isRecording) { newValue in
            isRecording = newValue
        }
        .onChange(of: elevenLabsService.isPlaying) { newValue in
            if !newValue && isProcessing {
                isProcessing = false
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("KAIRA")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.top, 20)
            
            // Show last transcription when processing
            if !lastTranscription.isEmpty && isProcessing {
                Text("You asked: \"\(lastTranscription)\"")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .italic()
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Microphone Interface
    private var microphoneInterface: some View {
        VStack(spacing: 40) {
            // Recording status and description
            VStack(spacing: 12) {
                Text(currentStatus)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // Show Kaira description when idle
                if !isRecording && !isProcessing && !elevenLabsService.isPlaying && !elevenLabsService.isSynthesizing {
                    Text("Your personal astrology companion")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 50)
                }
            }
            
            // Interactive audio visualizer (replaces button)
            audioVisualizerSection
            
            // Error message if any
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
    
    // MARK: - Audio Visualizer Section
    private var audioVisualizerSection: some View {
        Button(action: toggleRecording) {
            VStack(spacing: 20) {
                // Main visualizer as interactive element
                BarAudioVisualizer(
                    agentState: currentAgentState,
                    barColor: .white.opacity(0.8),
                    barCount: 7,
                    barCornerRadius: 6,
                    barSpacingFactor: 0.02
                )
                .frame(height: 120)
                .padding(.horizontal, 40)
                .scaleEffect(isRecording ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isRecording)
            }
        }
        .disabled(isProcessing || elevenLabsService.isSynthesizing)
        .opacity((isProcessing || elevenLabsService.isSynthesizing) ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isProcessing)
    }
    
    // MARK: - Current Agent State
    private var currentAgentState: AgentState {
        if elevenLabsService.isSynthesizing {
            return .thinking
        } else if elevenLabsService.isPlaying {
            return .speaking
        } else if isRecording {
            return .listening
        } else {
            return .idle
        }
    }
    
    
    // MARK: - Status Text
    private var currentStatus: String {
        if elevenLabsService.isSynthesizing {
            return "Preparing response..."
        } else if elevenLabsService.isPlaying {
            return "Kaira is speaking..."
        } else if isProcessing {
            return "Analyzing your question..."
        } else if isRecording {
            return "Listening..."
        } else if !speechService.isAuthorized {
            return "Microphone permissions required"
        } else {
            return "Tap to speak with Kaira"
        }
    }
    
    // MARK: - Actions
    private func toggleRecording() {
        // Stop any current playback
        if elevenLabsService.isPlaying {
            elevenLabsService.stopPlayback()
            return
        }
        
        // Don't start new recording if already processing
        if isProcessing || elevenLabsService.isSynthesizing {
            return
        }
        
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        Task {
            do {
                try await speechService.startRecording()
                errorMessage = ""
            } catch {
                errorMessage = error.localizedDescription
                print("Failed to start recording: \(error)")
            }
        }
    }
    
    private func stopRecording() {
        speechService.stopRecording()
        
        // Get the transcription and process it
        let transcription = speechService.lastTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !transcription.isEmpty {
            lastTranscription = transcription
            processVoiceInput(transcription)
        } else {
            errorMessage = "I didn't catch that. Please try again."
        }
    }
    
    private func processVoiceInput(_ text: String) {
        isProcessing = true
        errorMessage = ""
        
        Task {
            do {
                print("🗣️ User said: \(text)")
                
                // Generate AI response using OpenAI with function calling
                let response = try await openAIService.generateResponse(to: text)
                lastResponse = response
                
                print("🤖 AI response: \(response)")
                
                // Synthesize and play the response using ElevenLabs
                try await elevenLabsService.synthesizeAndPlay(text: response)
                
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Sorry, I couldn't process that request: \(error.localizedDescription)"
                    self.isProcessing = false
                }
                print("Voice processing error: \(error)")
            }
        }
    }
    
    private func requestPermissions() {
        Task {
            // Request speech recognition permission
            let speechAuthorized = await speechService.requestAuthorization()
            
            // Request microphone permission
            
            if !speechAuthorized {
                DispatchQueue.main.async {
                    self.showPermissionAlert = true
                }
            }
        }
    }
}

#Preview {
    VoiceAssistantView()
}
