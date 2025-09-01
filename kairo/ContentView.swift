import SwiftUI

struct ContentView: View {
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if isLoading {
                LaunchScreenView(isLoading: $isLoading)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.5), value: isLoading)
    }
}

#Preview {
    ContentView()
}
