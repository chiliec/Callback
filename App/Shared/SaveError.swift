import SwiftUI

@Observable final class SaveErrorState {
    var message: String?
}

extension View {
    func saveErrorAlert(_ state: SaveErrorState) -> some View {
        alert("Couldn't Save", isPresented: Binding(
            get: { state.message != nil },
            set: { if !$0 { state.message = nil } }
        )) {
            Button("OK") { state.message = nil }
        } message: {
            Text(state.message ?? "")
        }
    }
}
