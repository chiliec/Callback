import SwiftUI

struct AppTabView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coordinator = coordinator
        TabView(selection: $coordinator.selectedTab) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                NavigationStack { HomeView() }
            }
            .accessibilityIdentifier("home-tab")
            Tab("Topics", systemImage: "books.vertical", value: AppTab.topics) {
                NavigationStack { TopicsView() }
            }
            .accessibilityIdentifier("topics-tab")
            Tab("Practice", systemImage: "scope", value: AppTab.practice) {
                NavigationStack { PracticeView() }
            }
            .accessibilityIdentifier("practice-tab")
            Tab("Profile", systemImage: "person", value: AppTab.profile) {
                NavigationStack { ProfileView() }
            }
            .accessibilityIdentifier("profile-tab")
        }
    }
}
