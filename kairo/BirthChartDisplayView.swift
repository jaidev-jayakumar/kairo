import SwiftUI
import WebKit

struct BirthChartDisplayView: View {
    @StateObject private var apiService = AstrologerAPIService.shared
    @State private var isLoading = false
    @State private var chartSVG: String?
    @State private var errorMessage: String?
    @State private var selectedTheme: ChartTheme = .classic
    @State private var chartType: ChartType = .birthChart
    
    let birthData: BirthData
    
    enum ChartTheme: String, CaseIterable {
        case classic = "classic"
        case light = "light"
        case dark = "dark"
        case darkHighContrast = "dark-high-contrast"
        
        var displayName: String {
            switch self {
            case .classic: return "Classic"
            case .light: return "Light"
            case .dark: return "Dark"
            case .darkHighContrast: return "Dark High Contrast"
            }
        }
    }
    
    enum ChartType: String, CaseIterable {
        case birthChart = "Birth Chart"
        case transitChart = "Current Transits"
        
        var displayName: String { return self.rawValue }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    ChartHeaderView(
                        selectedTheme: $selectedTheme,
                        chartType: $chartType
                    )
                    
                    ChartContentView(
                        isLoading: isLoading,
                        errorMessage: errorMessage,
                        chartSVG: chartSVG,
                        onRetry: loadChart
                    )
                    
                    if chartSVG != nil {
                        ChartInfoView(
                            birthData: birthData,
                            selectedTheme: selectedTheme,
                            chartType: chartType
                        )
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color.black)
            .navigationBarHidden(true)
            .onChange(of: selectedTheme) {
                if chartSVG != nil {
                    loadChart()
                }
            }
            .onChange(of: chartType) {
                if chartSVG != nil {
                    loadChart()
                }
            }
            .onAppear {
                loadChart()
            }
        }
    }
    
    private func loadChart() {
        print("🔄 Starting chart load process")
        print("Birth data: date=\(birthData.date), lat=\(birthData.latitude), lng=\(birthData.longitude)")
        print("Chart type: \(chartType), Theme: \(selectedTheme)")
        
        // Validate birth data before making API call
        guard validateBirthData() else {
            print("❌ Birth data validation failed")
            errorMessage = "Invalid birth data. Please check your birth information in Profile."
            return
        }
        
        print("✅ Birth data validated successfully")
        isLoading = true
        errorMessage = nil
        chartSVG = nil
        
        Task {
            do {
                let response: AstrologerAPIService.ChartResponse
                
                switch chartType {
                case .birthChart:
                    response = try await apiService.generateBirthChart(
                        for: birthData,
                        theme: selectedTheme.rawValue,
                        city: "User Location",
                        nation: "US"
                    )
                case .transitChart:
                    response = try await apiService.generateTransitChart(
                        birthData: birthData,
                        transitDate: Date(),
                        theme: selectedTheme.rawValue
                    )
                }
                
                await MainActor.run {
                    print("📊 Processing API response...")
                    
                    // Validate the response contains valid SVG data
                    if response.chart.isEmpty {
                        print("❌ Received empty chart data from API")
                        self.errorMessage = "Received empty chart data from API"
                        self.isLoading = false
                        return
                    }
                    
                    // Check if the response contains valid SVG
                    let cleanChart = response.chart.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleanChart.contains("<svg") && !cleanChart.contains("<?xml") {
                        print("❌ Received invalid chart format from API")
                        print("Chart data preview: \(String(cleanChart.prefix(200)))")
                        self.errorMessage = "Received invalid chart format from API"
                        self.isLoading = false
                        return
                    }
                    
                    print("✅ Chart data validated successfully")
                    print("Chart size: \(response.chart.count) characters")
                    self.chartSVG = response.chart
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    
                    if let apiError = error as? APIError {
                        switch apiError {
                        case .networkError(let networkError):
                            if networkError.localizedDescription.contains("offline") || networkError.localizedDescription.contains("Internet") {
                                self.errorMessage = "No internet connection. Please check your network and try again."
                            } else {
                                self.errorMessage = "Network error: \(networkError.localizedDescription)"
                            }
                        case .httpError(let code, let message):
                            switch code {
                            case 401:
                                self.errorMessage = "API authentication failed. Please update the app."
                            case 403:
                                self.errorMessage = "API access denied. Check API limits."
                            case 429:
                                self.errorMessage = "Too many requests. Please wait a moment and try again."
                            case 500...599:
                                self.errorMessage = "Server error. Please try again later."
                            default:
                                self.errorMessage = "API error \(code): \(message)"
                            }
                        case .encodingError(_):
                            self.errorMessage = "Invalid birth data format. Please re-enter your birth information."
                        case .decodingError(_):
                            self.errorMessage = "Unable to process API response. Please try again."
                        default:
                            self.errorMessage = "API service error: \(apiError.localizedDescription)"
                        }
                    } else {
                        self.errorMessage = "Unexpected error: \(error.localizedDescription)"
                    }
                    self.isLoading = false
                }
            }
        }
    }
    
    private func validateBirthData() -> Bool {
        // Check for valid coordinates
        guard birthData.latitude >= -90 && birthData.latitude <= 90 else {
            print("Invalid latitude: \(birthData.latitude)")
            return false
        }
        
        guard birthData.longitude >= -180 && birthData.longitude <= 180 else {
            print("Invalid longitude: \(birthData.longitude)")
            return false
        }
        
        // Check for reasonable date (not too far in past/future)
        let currentDate = Date()
        let oneHundredYearsAgo = Calendar.current.date(byAdding: .year, value: -100, to: currentDate) ?? currentDate
        let tenYearsFromNow = Calendar.current.date(byAdding: .year, value: 10, to: currentDate) ?? currentDate
        
        guard birthData.date >= oneHundredYearsAgo && birthData.date <= tenYearsFromNow else {
            print("Invalid birth date: \(birthData.date)")
            return false
        }
        
        return true
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Header Component
struct ChartHeaderView: View {
    @Binding var selectedTheme: BirthChartDisplayView.ChartTheme
    @Binding var chartType: BirthChartDisplayView.ChartType
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Your Astrological Chart")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.white)
            
            Picker("Chart Type", selection: $chartType) {
                ForEach(BirthChartDisplayView.ChartType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            
            HStack {
                Text("Theme:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Picker("Theme", selection: $selectedTheme) {
                    ForEach(BirthChartDisplayView.ChartTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .accentColor(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

// MARK: - Content Component
struct ChartContentView: View {
    let isLoading: Bool
    let errorMessage: String?
    let chartSVG: String?
    let onRetry: () -> Void
    
    var body: some View {
        return Group {
            if isLoading {
                LoadingView()
            } else if let error = errorMessage {
                ErrorView(error: error, onRetry: onRetry)
            } else if let svg = chartSVG {
                SVGImageView(svgString: svg)
                    .frame(height: 400)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
            } else {
                EmptyChartView(onGenerate: onRetry)
            }
        }
    }
}

// MARK: - Loading Component
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            
            Text("Generating your cosmic chart...")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(height: 400)
    }
}

// MARK: - Error Component
struct ErrorView: View {
    let error: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.red.opacity(0.8))
            
            Text("Chart Generation Error")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Button("Try Again") {
                onRetry()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .frame(height: 400)
    }
}

// MARK: - Empty Chart Component
struct EmptyChartView: View {
    let onGenerate: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.6))
            
            Text("No chart available")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(.white.opacity(0.8))
            
            Button("Generate Chart") {
                onGenerate()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .frame(height: 400)
    }
}

// MARK: - Chart Info Component
struct ChartInfoView: View {
    let birthData: BirthData
    let selectedTheme: BirthChartDisplayView.ChartTheme
    let chartType: BirthChartDisplayView.ChartType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Chart Information")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                InfoRow(title: "Birth Date", value: formatDate(birthData.date))
                InfoRow(title: "Birth Time", value: formatTime(birthData.date))
                InfoRow(title: "Coordinates", value: String(format: "%.4f°, %.4f°", birthData.latitude, birthData.longitude))
                InfoRow(title: "Theme", value: selectedTheme.displayName)
                InfoRow(title: "Chart Type", value: chartType.displayName)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

struct SVGImageView: UIViewRepresentable {
    let svgString: String
    
    func makeUIView(context: Context) -> WKWebView {
        print("🔧 Creating WKWebView for SVG display")
        
        let config = WKWebViewConfiguration()
        // Disable all the networking that was causing issues
        config.processPool = WKProcessPool()
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .white
        webView.isOpaque = true
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        
        return webView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ SVG WebView loaded successfully")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ SVG WebView failed: \(error)")
        }
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        print("🎨 Loading SVG directly into WebView (\(svgString.count) characters)")
        
        // Create the absolute minimal HTML wrapper for the SVG
        let svgHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * { margin: 0; padding: 0; }
                html, body { 
                    width: 100%; 
                    height: 100%; 
                    background: white;
                    overflow: hidden;
                }
                svg { 
                    width: 100%; 
                    height: 100%; 
                    display: block;
                }
            </style>
        </head>
        <body>
        \(svgString)
        </body>
        </html>
        """
        
        // Use loadHTMLString with a simple about:blank baseURL to avoid networking
        webView.loadHTMLString(svgHTML, baseURL: URL(string: "about:blank"))
    }
}

#Preview {
    BirthChartDisplayView(birthData: BirthData(
        date: Date(),
        latitude: 40.7128,
        longitude: -74.0060,
        timeZone: TimeZone(identifier: "America/New_York") ?? .current
    ))
}