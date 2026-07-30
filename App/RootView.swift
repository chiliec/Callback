import SwiftUI

struct RootView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var saveErrorState = SaveErrorState()

    var body: some View {
        ZStack {
            AppTabView()
                .environment(saveErrorState)
            if coordinator.showLaunchSplash {
                LaunchView()
                    .transition(reduceMotion ? .identity : .opacity)
                    .zIndex(1)
            }
        }
        .task {
            if reduceMotion {
                coordinator.showLaunchSplash = false
            } else {
                try? await Task.sleep(for: .milliseconds(1100))
                withAnimation(.easeOut(duration: 0.18)) {
                    coordinator.showLaunchSplash = false
                }
            }
        }
        .saveErrorAlert(saveErrorState)
    }
}
