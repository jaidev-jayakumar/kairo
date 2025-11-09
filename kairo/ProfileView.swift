import SwiftUI

struct ProfileView: View {
    @State private var notificationsEnabled = true
    @State private var dailyHoroscopeTime = Date()
    @State private var showEditProfile = false
    @State private var userBirthData: BirthData? = nil
    @State private var birthChart: BirthChart? = nil
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Ambient coral/pink gradient overlays
            RadialGradient(
                colors: [
                    Color(hex: "FF8A8A")?.opacity(0.08) ?? .pink.opacity(0.08),
                    Color(hex: "FF6B6B")?.opacity(0.04) ?? .red.opacity(0.04),
                    Color.black.opacity(0)
                ],
                center: .top,
                startRadius: 100,
                endRadius: 700
            )
            .ignoresSafeArea()
            
            // Subtle glow
            LinearGradient(
                colors: [
                    Color(hex: "FFBABA")?.opacity(0.04) ?? .pink.opacity(0.04),
                    Color.black.opacity(0)
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                Text("profile")
                    .font(.system(size: 26, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.92))
                    .kerning(0.3)
                    .shadow(color: .white.opacity(0.08), radius: 12, x: 0, y: 0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 20)
                
                // User info card
                AstroCard {
                    VStack(spacing: 20) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple.opacity(0.6), .blue.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Text(getInitials())
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 8) {
                            Text(getInitials())
                                .font(.system(size: 20, weight: .regular, design: .monospaced))
                                .foregroundColor(.white)
                                .kerning(0.3)
                            
                            Text(formatBirthDate())
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                                .kerning(0.2)
                            
                            Text(formatBirthLocation())
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                                .kerning(0.2)
                        }
                        
                        // Zodiac summary
                        if let chart = birthChart {
                            HStack(spacing: 30) {
                                ZodiacInfo(label: "Sun", sign: chart.sunSign)
                                ZodiacInfo(label: "Moon", sign: chart.moonSign)
                                ZodiacInfo(label: "Rising", sign: chart.risingSign)
                            }
                            .padding(.horizontal, 10)
                        }
                        
                        Button(action: { showEditProfile = true }) {
                            Text("Edit Profile")
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .foregroundColor(.black)
                                .kerning(0.2)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.white))
                        }
                    }
                }
                
                // Settings section
                VStack(alignment: .leading, spacing: 20) {
                    Text("Settings")
                        .font(.system(size: 18, weight: .regular, design: .monospaced))
                        .foregroundColor(.white.opacity(0.92))
                        .kerning(0.3)
                    
                    // Notifications
                    SettingRow(
                        icon: "bell",
                        title: "Daily Horoscope",
                        toggle: $notificationsEnabled
                    )
                    
                    // Time picker
                    if notificationsEnabled {
                        HStack {
                            Image(systemName: "clock")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 28)
                            
                            Text("Delivery Time")
                                .font(.system(size: 15, weight: .regular, design: .monospaced))
                                .foregroundColor(.white.opacity(0.88))
                                .kerning(0.2)
                            
                            Spacer()
                            
                            DatePicker("", selection: $dailyHoroscopeTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                                .colorScheme(.dark)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                    
                    // Other settings
                    SettingLink(icon: "questionmark.circle", title: "Help & Support")
                    SettingLink(icon: "shield", title: "Privacy Policy")
                    SettingLink(icon: "star", title: "Rate Us")
                    SettingLink(icon: "square.and.arrow.up", title: "Share App")
                }
                
                // Sign out
                Button(action: {}) {
                    HStack {
                        Image(systemName: "arrow.left.square")
                            .font(.system(size: 20))
                        
                        Text("Sign Out")
                            .font(.system(size: 15, weight: .regular, design: .monospaced))
                            .kerning(0.2)
                    }
                    .foregroundColor(.red.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.top, 20)
                
                // App version
                Text("Kairo v1.0.0")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .kerning(0.2)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        }
        .onAppear {
            loadUserData()
        }
        .sheet(isPresented: $showEditProfile) {
            BirthDataInputView { birthData in
                UserDataManager.shared.saveBirthData(birthData)
                loadUserData()
            }
        }
    }
    
    private func loadUserData() {
        userBirthData = UserDataManager.shared.getBirthData()
        if let birthData = userBirthData {
            birthChart = AstrologyService.shared.calculateBirthChart(for: birthData)
        }
    }
    
    private func getInitials() -> String {
        // In a real app, this would come from user's name
        return "ME"
    }
    
    private func formatBirthDate() -> String {
        guard let birthData = userBirthData else {
            return "No birth data"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy • h:mm a"
        // Use the birth location's timezone to display the correct time
        formatter.timeZone = birthData.timeZone
        return formatter.string(from: birthData.date)
    }
    
    private func formatBirthLocation() -> String {
        guard let birthData = userBirthData else {
            return "No location data"
        }
        
        // Safely unwrap and check location name
        guard let locationName = birthData.locationName,
              !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Location"
        }
        
        return locationName
    }
}

struct ZodiacInfo: View {
    let label: String
    let sign: ZodiacSign
    
    var body: some View {
        VStack(spacing: 8) {
            contextualIcon
            
            Text(label)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .kerning(0.3)
            
            Text(sign.rawValue)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .kerning(0.2)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var contextualIcon: some View {
        Image(systemName: contextualIconName)
            .font(.system(size: 24, weight: .light))
            .foregroundColor(.white.opacity(0.9))
    }
    
    private var contextualIconName: String {
        switch label.lowercased() {
        case "sun": return "sun.max"
        case "moon": return "moon"
        case "rising": return "arrow.up"
        default: return "star"
        }
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    @Binding var toggle: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 28)
            
            Text(title)
                .font(.system(size: 15, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.88))
                .kerning(0.2)
            
            Spacer()
            
            Toggle("", isOn: $toggle)
                .toggleStyle(SwitchToggleStyle(tint: .white))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct SettingLink: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 28)
            
            Text(title)
                .font(.system(size: 15, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.88))
                .kerning(0.2)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

#Preview {
    ProfileView()
}
