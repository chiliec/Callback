import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public enum DSFeedback {
    case selection
    case success
    case warning
    case impactLight

    public var sensoryFeedback: SensoryFeedback {
        switch self {
        case .selection:   return .selection
        case .success:     return .success
        case .warning:     return .warning
        case .impactLight: return .impact(weight: .light)
        }
    }
}

extension View {
    @available(iOS 17.0, macOS 14.0, *)
    public func dsSensoryFeedback(_ feedback: DSFeedback, trigger: some Equatable) -> some View {
        self.sensoryFeedback(feedback.sensoryFeedback, trigger: trigger)
    }
}
