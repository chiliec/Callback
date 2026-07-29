import SwiftUI

struct RootView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Callback")
                .font(.system(size: 28, weight: .bold))
            Text("Foundations online")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview { RootView() }
