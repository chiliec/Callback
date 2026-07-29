import SwiftUI

enum AppTab: Int, Hashable {
    case home, topics, practice, profile
}

@Observable final class AppCoordinator {
    var selectedTab: AppTab = .home
    var topicsFilter: TopicFilter = .all
}
