import SwiftUI
import SwiftData
import AppCore
import DesignSystem

struct ReviewEntry: Identifiable, Hashable {
    let item: ReviewItem
    let question: Question
    let topic: Topic
    var id: String { item.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ReviewEntry, rhs: ReviewEntry) -> Bool { lhs.id == rhs.id }
}

struct ReviewQueueView: View {
    @Query private var answers: [AnswerRecord]
    @Query(sort: \Question.id) private var questions: [Question]
    @Query(sort: \Topic.order) private var topics: [Topic]
    @State private var filter: ReviewFilter = .all
    @State private var reviewActive = false
    @Environment(AppCoordinator.self) private var coordinator

    private var entries: [ReviewEntry] {
        let questionMap = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0) })
        let topicMap    = Dictionary(uniqueKeysWithValues: topics.map { ($0.id, $0) })
        return ReviewQueue.build(from: answers, filter: filter).compactMap { item in
            guard let q = questionMap[item.questionID],
                  let t = topicMap[item.topicID] else { return nil }
            return ReviewEntry(item: item, question: q, topic: t)
        }
    }

    var body: some View {
        List {
            ForEach(entries) { entry in
                ReviewRow(entry: entry)
                    .listRowInsets(.init(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
        }
        .navigationTitle("Review")
        // Inline, not large: the pinned `.safeAreaInset(edge: .top)` below
        // swallows the large-title row, leaving an empty strip where "Review"
        // should be. Same pairing, same fix as `TopicsView`.
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if entries.isEmpty {
                ReviewEmptyView()
            }
        }
        .safeAreaInset(edge: .top) {
            SegmentedFilter(
                selection: $filter,
                options: [(.all, "All"), (.wrong, "Wrong"), (.flagged, "Flagged")]
            )
            .padding(.horizontal, DSSpacing.listInset)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .safeAreaInset(edge: .bottom) {
            if !entries.isEmpty {
                Button("Review \(entries.count) questions") {
                    reviewActive = true
                }
                .font(DSFont.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(DSColor.action)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.button, style: .continuous))
                .padding(DSSpacing.sessionInset)
                .background(.bar)
                .accessibilityIdentifier("start-review-button")
            }
        }
        .navigationDestination(isPresented: $reviewActive) {
            ReviewItemView(entries: entries, onDone: { reviewActive = false })
        }
        .background(DSColor.groupedBackground.ignoresSafeArea())
    }
}

// MARK: - ReviewRow

private struct ReviewRow: View {
    let entry: ReviewEntry

    var body: some View {
        HStack(spacing: 12) {
            IconTile(systemName: entry.topic.symbolName,
                     color: DSColor.topic(entry.topic.colorToken))
            VStack(alignment: .leading, spacing: 4) {
                Text(inlineMarkdown: entry.question.prompt)
                    .lineLimit(1)
                    .font(DSFont.body)
                Text(entry.topic.name)
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.secondaryLabel)
            }
            Spacer()
            HStack(spacing: 6) {
                if entry.item.wasWrong {
                    Text("wrong")
                        .font(DSFont.badge)
                        .foregroundStyle(DSColor.redText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(DSColor.red.opacity(0.12))
                        .clipShape(Capsule())
                }
                if entry.item.isFlagged {
                    Image(systemName: "flag.fill")
                        .font(DSFont.badge)
                        .foregroundStyle(DSColor.orange)
                }
            }
        }
        .frame(minHeight: DSSpacing.rowMinHeight)
    }
}

// MARK: - ReviewEmptyView

struct ReviewEmptyView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(DSColor.green)
            Text("All clear")
                .font(DSFont.headline)
            Text("You've reviewed every wrong and flagged question.")
                .font(DSFont.footnote)
                .foregroundStyle(DSColor.secondaryLabel)
                .multilineTextAlignment(.center)
            Button("Start a drill") {
                coordinator.selectedTab = .practice
            }
            .font(DSFont.headline)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(DSColor.actionTint)
            .foregroundStyle(DSColor.action)
            .clipShape(Capsule())
        }
        .padding(32)
    }
}
