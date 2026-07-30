import SwiftUI

enum AppTab: Int, Hashable {
    case home, topics, practice, profile
}

@Observable final class AppCoordinator {
    var selectedTab: AppTab = .home
    var topicsFilter: TopicFilter = .all
    var showLaunchSplash: Bool = true
    var showPlacement: Bool = false
}
