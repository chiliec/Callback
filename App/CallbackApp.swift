import SwiftUI
import SwiftData
import AppCore

@main
struct CallbackApp: App {
    let container: ModelContainer
    @State private var coordinator = AppCoordinator()

    init() {
        do {
            container = try AppModelContainer.make()
            try Self.bootstrap(container)
        } catch {
            fatalError("Failed to set up model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(coordinator)
        }
        .modelContainer(container)
    }

    @MainActor
    private static func bootstrap(_ container: ModelContainer) throws {
        let context = container.mainContext
        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        let profile = profiles.first ?? {
            let p = UserProfile()
            context.insert(p)
            return p
        }()
        let bundle = try ContentLoader.decode(try ContentLoader.bundledContentData())
        ContentLoader.seedIfNeeded(into: context, profile: profile, bundle: bundle)
        try context.save()
    }
}
