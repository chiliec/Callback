import SwiftUI
import SwiftData
import AppCore

@main
struct CallbackApp: App {
    let container: ModelContainer
    @State private var coordinator = AppCoordinator()

    private static let isUITest = ProcessInfo.processInfo.arguments.contains("--uitest")
    private static let placementDone = ProcessInfo.processInfo.arguments.contains("--uitest-placement-done")

    init() {
        do {
            if Self.isUITest {
                container = try AppModelContainer.make(inMemory: true)
                try Self.bootstrapUITest(container, placementDone: Self.placementDone)
            } else {
                container = try AppModelContainer.make()
                try Self.bootstrap(container)
            }
        } catch {
            fatalError("Failed to set up model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(skipSplash: Self.isUITest)
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

    @MainActor
    private static func bootstrapUITest(_ container: ModelContainer, placementDone: Bool) throws {
        let context = container.mainContext
        let bundle = try ContentLoader.decode(try ContentLoader.bundledContentData())
        let profile = UserProfile()
        if placementDone {
            profile.hasCompletedPlacement = true
            profile.readiness = 42
        }
        context.insert(profile)
        ContentLoader.seedIfNeeded(into: context, profile: profile, bundle: bundle)
        try context.save()
    }
}
