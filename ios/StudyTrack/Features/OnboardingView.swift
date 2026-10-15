import SwiftUI

struct OnboardingView: View {
    var body: some View {
        NavigationStack { ProfileSetupForm(onboarding: true) }
            .containerBackground(for: .navigation) { AppCanvas() }
    }
}
