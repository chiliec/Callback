import SwiftUI

/// Thin wrapper over the platform segmented picker so screens use the real control.
public struct SegmentedFilter<T: Hashable>: View {
    @Binding private var selection: T
    private let options: [(value: T, label: String)]

    public init(selection: Binding<T>, options: [(value: T, label: String)]) {
        self._selection = selection
        self.options = options
    }

    public var body: some View {
        Picker("", selection: $selection) {
            ForEach(options, id: \.value) { option in
                Text(option.label).tag(option.value)
            }
        }
        .pickerStyle(.segmented)
    }
}

private enum PreviewFilter: String, CaseIterable { case all, weak, saved }
#Preview {
    struct Wrapper: View {
        @State var sel: PreviewFilter = .all
        var body: some View {
            SegmentedFilter(selection: $sel, options: [
                (.all, "All"), (.weak, "Weak"), (.saved, "Saved")
            ]).padding()
        }
    }
    return Wrapper()
}
