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
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("COSMIC ORACLE")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.white)
            }
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
            // Recording status
            Text(currentStatus)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Main recording button
            recordingButton
            
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
    
    // MARK: - Recording Button
    private var recordingButton: some View {
        ZStack {
            // Outer circle with subtle glow
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                .frame(width: 140, height: 140)
            
            // Main button circle
            Button(action: toggleRecording) {
                ZStack {
                    // Button background
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    // Central indicator
                    if isProcessing {
                        // Processing indicator
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    } else if elevenLabsService.isPlaying {
                        // Speaking indicator
                        Image(systemName: "speaker.wave.2")
                            .font(.title2)
                            .foregroundColor(.white)
                    } else {
                        // Recording indicator
                        Circle()
                            .fill(.white.opacity(isRecording ? 1.0 : 0.6))
                            .frame(width: 12, height: 12)
                            .scaleEffect(isRecording ? 1.5 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: isRecording)
                    }
                }
            }
            .scaleEffect(isRecording ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: isRecording)
            
            // Pulse effect when active
            if isRecording {
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .opacity(pulseAnimation ? 0 : 1)
                    .animation(
                        .easeOut(duration: 2.0)
                        .repeatForever(autoreverses: false),
                        value: pulseAnimation
                    )
            }
        }
        .disabled(isProcessing || elevenLabsService.isSynthesizing)
        .opacity((isProcessing || elevenLabsService.isSynthesizing) ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isProcessing)
    }
    
    // MARK: - Status Text
    private var currentStatus: String {
        if elevenLabsService.isSynthesizing {
            return "Crafting mystical response..."
        } else if elevenLabsService.isPlaying {
            return "The oracle speaks..."
        } else if isProcessing {
            return "Consulting the stars..."
        } else if isRecording {
            return "I'm listening..."
        } else if !speechService.isAuthorized {
            return "Permissions needed to commune with the cosmos"
        } else {
            return "Tap to speak with the cosmic oracle"
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
