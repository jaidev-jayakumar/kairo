import Foundation

class UserDataManager {
    static let shared = UserDataManager()
    private let userDefaults = UserDefaults.standard
    private let birthDataKey = "userBirthData"
    
    private init() {}
    
    // Save birth data
    func saveBirthData(_ birthData: BirthData) {
        if let encoded = try? JSONEncoder().encode(birthData) {
            userDefaults.set(encoded, forKey: birthDataKey)
        }
    }
    
    // Retrieve birth data
    func getBirthData() -> BirthData? {
        guard let data = userDefaults.data(forKey: birthDataKey),
              let birthData = try? JSONDecoder().decode(BirthData.self, from: data) else {
            return nil
        }
        return birthData
    }
    
    // Check if birth data exists
    var hasBirthData: Bool {
        return getBirthData() != nil
    }
    
    // Clear birth data
    func clearBirthData() {
        userDefaults.removeObject(forKey: birthDataKey)
    }
}