import SwiftUI

struct AppTabView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coordinator = coordinator
        TabView(selection: $coordinator.selectedTab) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                NavigationStack { HomeView() }
            }
            Tab("Topics", systemImage: "books.vertical", value: AppTab.topics) {
                NavigationStack { TopicsView() }
            }
            Tab("Practice", systemImage: "scope", value: AppTab.practice) {
                NavigationStack { PracticeView() }
            }
            Tab("Profile", systemImage: "person", value: AppTab.profile) {
                NavigationStack { ProfileView() }
            }
        }
    }
}
