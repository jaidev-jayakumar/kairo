import SwiftUI

struct TestAstrologyView: View {
    @State private var testResult = "Testing..."
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Astrology Service Test")
                .font(.title)
            
            Text(testResult)
                .font(.body)
                .padding()
            
            Button("Run Test") {
                runTest()
            }
        }
        .padding()
        .onAppear {
            runTest()
        }
    }
    
    func runTest() {
        let testBirthData = BirthData(
            date: Date(timeIntervalSince1970: 598023482), // Feb 20, 1995
            latitude: 37.7749,
            longitude: -122.4194
        )
        
        if let chart = AstrologyService.shared.calculateBirthChart(for: testBirthData) {
            testResult = """
            ✅ Success!
            Sun: \(chart.sun.formattedPosition)
            Moon: \(chart.moon.formattedPosition)
            Rising: \(chart.formattedAscendant)
            """
        } else {
            testResult = "❌ Failed to calculate birth chart"
        }
    }
}

#Preview {
    TestAstrologyView()
}