import SwiftUI
import AppCore

struct TopicDetailView: View {
    let topic: Topic

    var body: some View {
        Text("Topic Detail — Phase 5")
            .navigationTitle(topic.name)
    }
}
