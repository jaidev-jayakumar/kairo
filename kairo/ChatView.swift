import SwiftUI

struct ChatView: View {
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "Ask the cosmos.", isUser: false)
    ]
    @State private var inputText = ""
    @State private var isTyping = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Minimal header
                VStack(spacing: 8) {
                    Text("COSMIC ORACLE")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.4))
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                        .frame(maxWidth: 100)
                }
                .padding(.top, 40)
                .padding(.bottom, 20)
            
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 32) {
                            ForEach(messages) { message in
                                CosmicMessage(message: message)
                                    .id(message.id)
                            }
                            
                            if isTyping {
                                OracleTyping()
                            }
                        }
                        .padding(.vertical, 40)
                        .padding(.horizontal, 30)
                    }
                    .onChange(of: messages.count) { _ in
                        withAnimation {
                            proxy.scrollTo(messages.last?.id, anchor: .bottom)
                        }
                    }
                }
            
                // Input area
                VStack(spacing: 16) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                    
                    HStack(spacing: 16) {
                        TextField("", text: $inputText)
                            .placeholder(when: inputText.isEmpty) {
                                Text("Ask your question")
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(.white)
                            .accentColor(.white)
                        
                        Button(action: sendMessage) {
                            Text("ASK")
                                .font(.system(size: 12, weight: .medium))
                                .tracking(1)
                                .foregroundColor(inputText.isEmpty ? .white.opacity(0.2) : .white.opacity(0.8))
                        }
                        .disabled(inputText.isEmpty)
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        let userMessage = ChatMessage(text: inputText, isUser: true)
        messages.append(userMessage)
        inputText = ""
        
        isTyping = true
        
        // Simulate AI response
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isTyping = false
            let response = generateCosmicResponse(to: userMessage.text)
            messages.append(ChatMessage(text: response, isUser: false))
        }
    }
    
    func generateCosmicResponse(to question: String) -> String {
        let responses = [
            "The question you ask is not the question you need answered. Saturn's rings remind us that boundaries create beauty.",
            "Your higher self already knows. The delay is in your willingness to listen.",
            "This pattern will repeat until you choose differently. Venus retrograde taught us this.",
            "What feels like resistance is actually redirection. Trust the cosmic timing.",
            "The answer lives in the space between your fear and your desire."
        ]
        return responses.randomElement() ?? "The universe speaks in synchronicities. Pay attention."
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
}

struct CosmicMessage: View {
    let message: ChatMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if message.isUser {
                // User question
                VStack(alignment: .trailing, spacing: 8) {
                    Text("YOU ASKED")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text(message.text)
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.trailing)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                // Oracle response
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 3, height: 3)
                        
                        Text("ORACLE")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(1.5)
                            .foregroundColor(.white.opacity(0.4))
                    }
                    
                    Text(message.text)
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(8)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct OracleTyping: View {
    @State private var opacity: Double = 0.3
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 3, height: 3)
            
            Text("ORACLE IS CONSULTING THE COSMOS")
                .font(.system(size: 10, weight: .medium))
                .tracking(1.5)
                .foregroundColor(.white.opacity(opacity))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                opacity = 0.6
            }
        }
    }
}

// Placeholder modifier extension
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    ChatView()
}