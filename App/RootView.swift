import SwiftUI
import SwiftData
import AppCore
import DesignSystem

struct RootView: View {
    @Query(sort: \Topic.order) private var topics: [Topic]

    var body: some View {
        NavigationStack {
            List {
                Section("Seeded topics") {
                    ForEach(topics) { topic in
                        HStack {
                            IconTile(systemName: topic.symbolName,
                                     color: DSColor.topic(topic.colorToken))
                            Text(topic.name)
                            Spacer()
                            Text("\(topic.questionCount) Q")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle("Callback")
        }
    }
}
