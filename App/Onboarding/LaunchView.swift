import SwiftUI
import DesignSystem

struct LaunchView: View {
    var body: some View {
        ZStack {
            DSColor.groupedBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: DSRadius.appIcon, style: .continuous)
                        .fill(DSColor.action)
                        .frame(width: 96, height: 96)
                    Image(systemName: "curlybraces")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text("Callback")
                    .font(DSFont.readerTitle)
                    .foregroundStyle(DSColor.label)
                Text("Get the callback.")
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.secondaryLabel)
            }
        }
    }
}

#Preview {
    LaunchView()
}
