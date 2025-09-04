import Foundation
import SwiftUI

class AstrologerAPIService: ObservableObject {
    static let shared = AstrologerAPIService()
    
    private let baseURL = "https://astrologer.p.rapidapi.com/api/v4"
    private let rapidAPIKey = "9deca44fbcmsh17b8b46dccf8c00p101c6bjsn88fe94c44754"
    private let rapidAPIHost = "astrologer.p.rapidapi.com"
    
    private init() {}
    
    struct BirthChartRequest: Codable {
        let subject: Subject
        
        struct Subject: Codable {
            let year: Int
            let month: Int
            let day: Int
            let hour: Int
            let minute: Int
            let longitude: Double
            let latitude: Double
            let city: String
            let nation: String
            let timezone: String
            let name: String
            let zodiac_type: String
            let sidereal_mode: String?
            let perspective_type: String
            let houses_system_identifier: String
            let theme: String
            let language: String
            let wheel_only: Bool
            
            init(birthData: BirthData, name: String = "User", theme: String = "classic", city: String = "New York", nation: String = "US") {
                let calendar = Calendar.current
                let components = calendar.dateComponents(in: birthData.timeZone, from: birthData.date)
                
                self.year = components.year ?? 2000
                self.month = components.month ?? 1
                self.day = components.day ?? 1
                self.hour = components.hour ?? 12
                self.minute = components.minute ?? 0
                self.longitude = birthData.longitude
                self.latitude = birthData.latitude
                self.city = city
                self.nation = nation
                self.timezone = birthData.timeZone.identifier
                self.name = name
                self.zodiac_type = "Tropic"
                self.sidereal_mode = nil
                self.perspective_type = "Apparent Geocentric"
                self.houses_system_identifier = "P"
                self.theme = theme
                self.language = "EN"
                self.wheel_only = false
            }
        }
    }
    
    struct ChartResponse: Codable {
        let chart: String
        let data: ChartData?
        let aspects: [AspectInfo]?
        let status: String?
        
        struct ChartData: Codable {
            let sun: PlanetData?
            let moon: PlanetData?
            let mercury: PlanetData?
            let venus: PlanetData?
            let mars: PlanetData?
            let jupiter: PlanetData?
            let saturn: PlanetData?
            let uranus: PlanetData?
            let neptune: PlanetData?
            let pluto: PlanetData?
            let ascendant: HouseData?
            let first_house: HouseData?
            let second_house: HouseData?
            let third_house: HouseData?
            let fourth_house: HouseData?
            let fifth_house: HouseData?
            let sixth_house: HouseData?
            let seventh_house: HouseData?
            let eighth_house: HouseData?
            let ninth_house: HouseData?
            let tenth_house: HouseData?
            let eleventh_house: HouseData?
            let twelfth_house: HouseData?
        }
        
        struct PlanetData: Codable {
            let abs_pos: Double?
            let sign: String?
            let house: String?
            let retrograde: Bool?
        }
        
        struct HouseData: Codable {
            let abs_pos: Double?
            let sign: String?
        }
        
        struct AspectInfo: Codable {
            let p1_name: String
            let p2_name: String
            let aspect: String
            let orbit: Double
            let p1_abs_pos: Double?
            let p2_abs_pos: Double?
            let aspect_degrees: Double?
            let diff: Double?
            
            // Computed properties for backward compatibility
            var planet1: String { return p1_name }
            var planet2: String { return p2_name }
            var orb: Double { return orbit }
        }
        
        // Legacy computed properties for backward compatibility
        var positions: [String: LegacyPlanetPosition]? {
            guard let data = data else { return nil }
            
            var positions: [String: LegacyPlanetPosition] = [:]
            
            if let sun = data.sun {
                positions["Sun"] = LegacyPlanetPosition(
                    longitude: sun.abs_pos ?? 0,
                    sign: sun.sign ?? "",
                    house: Int(sun.house ?? "1") ?? 1,
                    retrograde: sun.retrograde
                )
            }
            
            if let moon = data.moon {
                positions["Moon"] = LegacyPlanetPosition(
                    longitude: moon.abs_pos ?? 0,
                    sign: moon.sign ?? "",
                    house: Int(moon.house ?? "1") ?? 1,
                    retrograde: moon.retrograde
                )
            }
            
            // Add other planets as needed...
            
            return positions
        }
        
        var houses: [String: LegacyHouseInfo]? {
            guard let data = data else { return nil }
            
            var houses: [String: LegacyHouseInfo] = [:]
            
            if let first = data.first_house {
                houses["1"] = LegacyHouseInfo(
                    longitude: first.abs_pos ?? 0,
                    sign: first.sign ?? ""
                )
            }
            
            // Add other houses as needed...
            
            return houses
        }
    }
    
    // Legacy structures for backward compatibility
    struct LegacyPlanetPosition: Codable {
        let longitude: Double
        let sign: String
        let house: Int
        let retrograde: Bool?
    }
    
    struct LegacyHouseInfo: Codable {
        let longitude: Double
        let sign: String
    }
    
    @MainActor
    func generateBirthChart(for birthData: BirthData, theme: String = "classic", city: String = "User Location", nation: String = "US") async throws -> ChartResponse {
        guard let url = URL(string: "\(baseURL)/birth-chart") else {
            throw APIError.invalidURL
        }
        
        // Validate birth data before making request
        guard validateBirthData(birthData) else {
            throw APIError.encodingError(NSError(domain: "InvalidBirthData", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid birth data provided"]))
        }
        
        let request = BirthChartRequest(subject: BirthChartRequest.Subject(birthData: birthData, name: "User", theme: theme, city: city, nation: nation))
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(rapidAPIKey, forHTTPHeaderField: "X-RapidAPI-Key")
        urlRequest.setValue(rapidAPIHost, forHTTPHeaderField: "X-RapidAPI-Host")
        urlRequest.timeoutInterval = 30.0 // Add timeout
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            urlRequest.httpBody = try encoder.encode(request)
            print("API Request body: \(String(data: urlRequest.httpBody!, encoding: .utf8) ?? "Unable to decode")")
        } catch {
            print("Encoding error: \(error)")
            throw APIError.encodingError(error)
        }
        
        print("Making API request to: \(url)")
        print("Request headers: \(urlRequest.allHTTPHeaderFields ?? [:])")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("ERROR: No HTTP response received")
                throw APIError.invalidResponse
            }
            
            print("API Response status: \(httpResponse.statusCode)")
            print("Response headers: \(httpResponse.allHeaderFields)")
            
            if data.count < 1000 {
                print("API Response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            } else {
                print("API Response data size: \(data.count) bytes (truncated for logging)")
                if let responseString = String(data: data, encoding: .utf8) {
                    let preview = String(responseString.prefix(500))
                    print("Response preview: \(preview)...")
                }
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.httpError(httpResponse.statusCode, errorString)
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(ChartResponse.self, from: data)
            } catch {
                print("Decoding error: \(error)")
                throw APIError.decodingError(error)
            }
            
        } catch let error as APIError {
            print("API Error: \(error)")
            throw error
        } catch {
            print("Network error details: \(error)")
            print("Error type: \(type(of: error))")
            print("Error localizedDescription: \(error.localizedDescription)")
            if let urlError = error as? URLError {
                print("URLError code: \(urlError.code)")
                print("URLError userInfo: \(urlError.userInfo)")
            }
            throw APIError.networkError(error)
        }
    }
    
    private func validateBirthData(_ birthData: BirthData) -> Bool {
        // Check for valid coordinates
        guard birthData.latitude >= -90 && birthData.latitude <= 90 else {
            return false
        }
        
        guard birthData.longitude >= -180 && birthData.longitude <= 180 else {
            return false
        }
        
        // Check for reasonable date (not too far in past/future)
        let currentDate = Date()
        let oneHundredYearsAgo = Calendar.current.date(byAdding: .year, value: -100, to: currentDate) ?? currentDate
        let tenYearsFromNow = Calendar.current.date(byAdding: .year, value: 10, to: currentDate) ?? currentDate
        
        guard birthData.date >= oneHundredYearsAgo && birthData.date <= tenYearsFromNow else {
            return false
        }
        
        return true
    }
    
    @MainActor
    func generateSynastryChart(person1: BirthData, person2: BirthData, theme: String = "classic") async throws -> ChartResponse {
        guard let url = URL(string: "\(baseURL)/synastry-chart") else {
            throw APIError.invalidURL
        }
        
        let requestBody = [
            "subject1": BirthChartRequest.Subject(birthData: person1, name: "Person 1", theme: theme, city: "Location 1", nation: "US"),
            "subject2": BirthChartRequest.Subject(birthData: person2, name: "Person 2", theme: theme, city: "Location 2", nation: "US")
        ]
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(rapidAPIKey, forHTTPHeaderField: "X-RapidAPI-Key")
        urlRequest.setValue(rapidAPIHost, forHTTPHeaderField: "X-RapidAPI-Host")
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw APIError.encodingError(error)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.httpError(httpResponse.statusCode, errorString)
            }
            
            return try JSONDecoder().decode(ChartResponse.self, from: data)
            
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    @MainActor
    func generateTransitChart(birthData: BirthData, transitDate: Date = Date(), theme: String = "classic") async throws -> ChartResponse {
        guard let url = URL(string: "\(baseURL)/transit-chart") else {
            throw APIError.invalidURL
        }
        
        // Create a temporary BirthData for transit time
        let transitBirthData = BirthData(
            date: transitDate,
            latitude: birthData.latitude,
            longitude: birthData.longitude,
            timeZone: birthData.timeZone
        )
        
        let transitSubject = BirthChartRequest.Subject(
            birthData: transitBirthData,
            name: "Current Transits",
            theme: theme,
            city: "Transit Location",
            nation: "US"
        )
        
        let requestBody = [
            "natal": BirthChartRequest.Subject(birthData: birthData, name: "Natal Chart", theme: theme, city: "User Location", nation: "US"),
            "transit": transitSubject
        ]
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(rapidAPIKey, forHTTPHeaderField: "X-RapidAPI-Key")
        urlRequest.setValue(rapidAPIHost, forHTTPHeaderField: "X-RapidAPI-Host")
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw APIError.encodingError(error)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.httpError(httpResponse.statusCode, errorString)
            }
            
            return try JSONDecoder().decode(ChartResponse.self, from: data)
            
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case encodingError(Error)
    case networkError(Error)
    case invalidResponse
    case httpError(Int, String)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let code, let message):
            return "HTTP error \(code): \(message)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}