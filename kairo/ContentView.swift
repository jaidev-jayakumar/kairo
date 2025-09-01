import SwiftUI

struct ContentView: View {
    @State private var isLoading = true
    @State private var showOnboarding = false
    @State private var onboardingComplete = false
    
    var body: some View {
        ZStack {
            if isLoading {
                LaunchScreenView(isLoading: $isLoading)
            } else if showOnboarding && !onboardingComplete {
                OnboardingView(isComplete: $onboardingComplete)
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.5), value: isLoading)
        .animation(.easeOut(duration: 0.5), value: onboardingComplete)
        .onAppear {
            checkForFirstLaunch()
        }
    }
    
    private func checkForFirstLaunch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if !UserDataManager.shared.hasBirthData {
                showOnboarding = true
            }
        }
    }
}

#Preview {
    ContentView()
}
