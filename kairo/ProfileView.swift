import SwiftUI

struct ProfileView: View {
    @State private var notificationsEnabled = true
    @State private var dailyHoroscopeTime = Date()
    @State private var showEditProfile = false
    @State private var userBirthData: BirthData? = nil
    @State private var birthChart: BirthChart? = nil
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                Text("Profile")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.white)
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
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                            
                            Text(formatBirthDate())
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("Location")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        // Zodiac summary
                        if let chart = birthChart {
                            HStack(spacing: 20) {
                                ZodiacInfo(label: "Sun", sign: chart.sunSign.rawValue, symbol: chart.sun.symbol)
                                ZodiacInfo(label: "Moon", sign: chart.moonSign.rawValue, symbol: chart.moon.symbol)
                                ZodiacInfo(label: "Rising", sign: chart.risingSign.rawValue, symbol: chart.risingSign.symbol)
                            }
                        }
                        
                        Button(action: { showEditProfile = true }) {
                            Text("Edit Profile")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.white))
                        }
                    }
                }
                
                // Settings section
                VStack(alignment: .leading, spacing: 20) {
                    Text("Settings")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
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
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                            
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
                            .font(.system(size: 16, weight: .medium))
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
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .background(Color.black)
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
            birthChart = SimplifiedAstrologyService.shared.calculateBirthChart(for: birthData)
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
        return formatter.string(from: birthData.date)
    }
}

struct ZodiacInfo: View {
    let label: String
    let sign: String
    let symbol: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(symbol)
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.8))
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            
            Text(sign)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
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
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.9))
            
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
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.9))
            
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