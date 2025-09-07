import SwiftUI
import CoreLocation

struct BirthDataInputView: View {
    @State private var birthDate: Date
    @State private var birthTime: Date
    @State private var locationString = "Kochi, Kerala"
    @State private var isGeocoding = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    init(onSave: @escaping (BirthData) -> Void) {
        self.onSave = onSave
        
        // Initialize with a reasonable birth date (e.g., 25 years ago)
        let calendar = Calendar.current
        let defaultBirthDate = calendar.date(byAdding: .year, value: -25, to: Date()) ?? Date()
        self._birthDate = State(initialValue: defaultBirthDate)
        
        // Initialize birth time to 12:00 PM (noon) to avoid AM/PM confusion
        var components = calendar.dateComponents([.year, .month, .day], from: defaultBirthDate)
        components.hour = 12
        components.minute = 0
        let defaultBirthTime = calendar.date(from: components) ?? Date()
        self._birthTime = State(initialValue: defaultBirthTime)
    }
    
    @Environment(\.dismiss) var dismiss
    
    var onSave: (BirthData) -> Void
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Text("Birth Details")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Save") {
                        saveBirthData()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .disabled(isGeocoding)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                
                ScrollView {
                    VStack(spacing: 40) {
                        // Birth Date
                        VStack(alignment: .leading, spacing: 12) {
                            Text("BIRTH DATE")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(1.5)
                                .foregroundColor(.white.opacity(0.4))
                            
                            DatePicker("", selection: $birthDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .accentColor(.white)
                        }
                        
                        // Birth Time
                        VStack(alignment: .leading, spacing: 12) {
                            Text("BIRTH TIME")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(1.5)
                                .foregroundColor(.white.opacity(0.4))
                            
                            DatePicker("", selection: $birthTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .accentColor(.white)
                                .environment(\.timeZone, .current)
                        }
                        
                        // Birth Location
                        VStack(alignment: .leading, spacing: 12) {
                            Text("BIRTH LOCATION")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(1.5)
                                .foregroundColor(.white.opacity(0.4))
                            
                            HStack {
                                TextField("Kochi, Kerala", text: $locationString)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .textFieldStyle(.plain)
                                    .submitLabel(.done)
                                
                                if isGeocoding {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        
                        // Info text
                        Text("Your birth data is used to calculate your unique astrological chart. This information is stored locally on your device.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.top, 20)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 40)
                }
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    
    private func saveBirthDataWithCoordinates(latitude: Double, longitude: Double, timeZone: TimeZone) {
        // Extract date and time components using device's current calendar
        // This ensures we get exactly what the user sees on the DatePicker
        let deviceCalendar = Calendar.current
        let dateComponents = deviceCalendar.dateComponents([.year, .month, .day], from: birthDate)
        let timeComponents = deviceCalendar.dateComponents([.hour, .minute], from: birthTime)
        
        print("🕐 User selected values - Date: \(dateComponents.year!)/\(dateComponents.month!)/\(dateComponents.day!), Time: \(timeComponents.hour!):\(String(format: "%02d", timeComponents.minute!))")
        
        // Now create the birth date/time in the birth location's timezone
        // using the exact time components the user selected
        var birthLocationCalendar = Calendar.current
        birthLocationCalendar.timeZone = timeZone
        
        guard let combinedDate = birthLocationCalendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: timeComponents.hour,
            minute: timeComponents.minute
        )) else {
            alertMessage = "Invalid date or time"
            showingAlert = true
            return
        }
        
        print("🌍 Birth date/time created in \(timeZone.identifier): \(combinedDate)")
        
        let birthData = BirthData(
            date: combinedDate,
            latitude: latitude,
            longitude: longitude,
            timeZone: timeZone,
            locationName: locationString
        )
        
        onSave(birthData)
        dismiss()
    }
    
    private func saveBirthData() {
        isGeocoding = true
        
        // Geocode the location
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(locationString) { placemarks, error in
            isGeocoding = false
            
            if let error = error {
                alertMessage = "Could not find location: \(error.localizedDescription)"
                showingAlert = true
                return
            }
            
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                alertMessage = "Could not find coordinates for this location"
                showingAlert = true
                return
            }
            
            // Get timezone for the birth location
            let birthTimeZone = placemark.timeZone ?? TimeZone(identifier: "Asia/Kolkata") ?? .current
            
            self.saveBirthDataWithCoordinates(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude, 
                timeZone: birthTimeZone
            )
        }
    }
}

#Preview {
    BirthDataInputView { birthData in
        print("Birth data saved: \(birthData)")
    }
}
