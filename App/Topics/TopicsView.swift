import SwiftUI
import SwiftData
import AppCore
import DesignSystem

struct TopicsView: View {
    @Query(sort: \Topic.order) private var topics: [Topic]
    @Environment(AppCoordinator.self) private var coordinator
    @State private var searchText = ""

    private var filtered: [Topic] {
        topics.filter { topic in
            let matchesSearch = searchText.isEmpty ||
                topic.name.localizedCaseInsensitiveContains(searchText)
            let matchesFilter: Bool
            switch coordinator.topicsFilter {
            case .all:   matchesFilter = true
            case .weak:  matchesFilter = topic.isWeak
            case .saved: matchesFilter = topic.isSaved
            }
            return matchesSearch && matchesFilter
        }
    }

    private func topics(for section: TopicSection) -> [Topic] {
        filtered.filter { $0.section == section }
    }

    var body: some View {
        @Bindable var coordinator = coordinator
        List {
            ForEach(TopicSection.allCases, id: \.self) { section in
                let rows = self.topics(for: section)
                if !rows.isEmpty {
                    Section(header: SectionHeader(section.displayName)) {
                        ForEach(rows, id: \.id) { topic in
                            let globalIndex = filtered.firstIndex(where: { $0.id == topic.id }) ?? 0
                            NavigationLink(value: topic) {
                                TopicRow(topic: topic)
                            }
                            .accessibilityIdentifier("topic-row-\(globalIndex)")
                        }
                    }
                }
            }
        }
        .overlay {
            if coordinator.topicsFilter == .saved && filtered.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bookmark.circle")
                        .font(.system(size: 52))
                        .foregroundStyle(DSColor.secondaryLabel)
                    Text("No saved topics")
                        .font(DSFont.headline)
                    Text("Bookmark topics you want to revisit.")
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.secondaryLabel)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
            }
        }
        .navigationTitle("Topics")
        // Inline, not large: the pinned `.safeAreaInset(edge: .top)` below swallows
        // the large-title row, leaving an empty strip where "Topics" should be.
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .navigationDestination(for: Topic.self) { topic in
            TopicDetailView(topic: topic)
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                Text("\(filtered.count) topics · \(filtered.reduce(0) { $0 + $1.questionCount }) questions")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DSSpacing.listInset)
                    .padding(.top, 4)
                SegmentedFilter(
                    selection: $coordinator.topicsFilter,
                    options: [(.all, "All"), (.weak, "Weak"), (.saved, "Saved")]
                )
                .padding(.horizontal, DSSpacing.listInset)
                .padding(.vertical, 8)
            }
            .background(.bar)
        }
        .background(DSColor.groupedBackground.ignoresSafeArea())
    }
}

// MARK: - TopicRow

struct TopicRow: View {
    let topic: Topic

    var body: some View {
        HStack(spacing: 12) {
            IconTile(systemName: topic.symbolName,
                     color: DSColor.topic(topic.colorToken))
            Text(topic.name)
                .font(DSFont.body)
            Spacer()
            if topic.isSaved {
                Image(systemName: "bookmark.fill")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.action)
            }
            Text("\(topic.mastery)%")
                .font(DSFont.footnote)
                .foregroundStyle(topic.isWeak ? DSColor.orangeText : DSColor.secondaryLabel)
                .monospacedDigit()
        }
        .frame(minHeight: DSSpacing.rowMinHeight)
    }
}

// MARK: - TopicSection display name

private extension TopicSection {
    var displayName: String {
        switch self {
        case .fundamentals: return "Fundamentals"
        case .frameworks:   return "Frameworks"
        case .craft:        return "Craft"
        }
    }
}

#Preview {
    NavigationStack {
        TopicsView()
    }
    .modelContainer(try! AppModelContainer.make(inMemory: true))
    .environment(AppCoordinator())
}
