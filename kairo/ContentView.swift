import SwiftUI

struct ContentView: View {
    @State private var isLoading = true
    @State private var showOnboarding = false
    
    var body: some View {
        ZStack {
            if isLoading {
                LaunchScreenView(isLoading: $isLoading)
            } else if showOnboarding {
                OnboardingView(onComplete: {
                    // When onboarding completes, hide it
                    showOnboarding = false
                })
                .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.5), value: isLoading)
        .animation(.easeOut(duration: 0.5), value: showOnboarding)
        .onAppear {
            checkForFirstLaunch()
        }
    }
    
    private func checkForFirstLaunch() {
        Task { @MainActor in
            // Wait for launch screen
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Check if user has completed onboarding (by checking if birth data exists)
            isLoading = false
            
            if !UserDataManager.shared.hasBirthData {
                showOnboarding = true
            }
        }
    }
}

#Preview {
    ContentView()
}
