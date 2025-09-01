import SwiftUI

struct ChatView: View {
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "Welcome, cosmic seeker. What guidance do you need today?", isUser: false)
    ]
    @State private var inputText = ""
    @State private var isTyping = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cosmic Oracle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text("Online")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.05))
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                        
                        if isTyping {
                            TypingIndicator()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 20)
                }
                .onChange(of: messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo(messages.last?.id, anchor: .bottom)
                    }
                }
            }
            
            // Input area
            HStack(spacing: 12) {
                TextField("Ask the cosmos...", text: $inputText)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(inputText.isEmpty ? .white.opacity(0.3) : .white)
                }
                .disabled(inputText.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.black)
        }
        .background(Color.black)
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
            "The stars align in your favor. Trust your intuition as Mercury guides your path forward.",
            "A period of transformation approaches. Embrace the change that the universe offers.",
            "Your energy resonates with Venus today. Love and creativity flow through you.",
            "The moon's influence suggests reflection. Look within for the answers you seek.",
            "Jupiter's expansion touches your life. New opportunities await those who dare."
        ]
        return responses.randomElement() ?? "The cosmos whispers secrets to those who listen."
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
}

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundColor(message.isUser ? .black : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(message.isUser ? Color.white : Color.white.opacity(0.1))
                    )
                
                Text(message.timestamp.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser { Spacer() }
        }
        .padding(.horizontal, 20)
    }
}

struct TypingIndicator: View {
    @State private var animationAmount = 0.0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationAmount)
                    .opacity(animationAmount)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: animationAmount
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
        )
        .onAppear {
            animationAmount = 1.0
        }
    }
}

#Preview {
    ChatView()
}