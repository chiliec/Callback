import SwiftUI

public enum AnswerState: Equatable, Sendable {
    case idle            // not yet answered, tappable
    case correct         // the correct option, after answering
    case wrongPick       // the option the user wrongly picked
    case fadedCorrect    // unrelated correct-position row faded (n/a) — kept for symmetry
    case fadedIncorrect  // other options, faded to 45%
    case selected        // tapped during placement — blue highlight, no verdict
}

public struct OptionRow: View {
    private let label: String       // "A".."D"
    private let text: String
    private let isMonospaced: Bool
    private let state: AnswerState
    private let action: () -> Void

    public init(label: String, text: String, isMonospaced: Bool,
                state: AnswerState, action: @escaping () -> Void) {
        self.label = label
        self.text = text
        self.isMonospaced = isMonospaced
        self.state = state
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(label)
                    .font(DSFont.headline)
                    .foregroundStyle(labelColor)
                    .frame(width: 24, height: 24)
                    .background(labelBackground)
                    .clipShape(Circle())
                Text(text)
                    .font(isMonospaced ? .system(size: 15, design: .monospaced) : DSFont.body)
                    .foregroundStyle(DSColor.label)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(minHeight: DSSpacing.rowMinHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fillColor)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous)
                    .stroke(borderColor, lineWidth: borderColor == .clear ? 0 : 1.5)
            )
            .opacity(isFaded ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
        .animation(.easeInOut(duration: 0.18), value: state)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(accessibilityStateValue)
        .accessibilityAddTraits(state == .correct ? .isSelected : [])
    }

    private var accessibilityStateValue: String {
        switch state {
        case .correct:        return "correct"
        case .wrongPick:      return "incorrect"
        case .selected:       return "selected"
        case .fadedIncorrect, .fadedCorrect, .idle: return ""
        }
    }

    private var isFaded: Bool { state == .fadedIncorrect || state == .fadedCorrect }

    private var fillColor: Color {
        switch state {
        case .correct:   return DSColor.green.opacity(0.12)
        case .wrongPick: return DSColor.red.opacity(0.12)
        case .selected:  return DSColor.actionTint
        default:         return DSColor.fill
        }
    }
    private var borderColor: Color {
        switch state {
        case .correct:   return DSColor.green
        case .wrongPick: return DSColor.red
        case .selected:  return DSColor.action
        default:         return .clear
        }
    }
    private var labelColor: Color {
        switch state {
        case .correct:   return DSColor.greenText
        case .wrongPick: return DSColor.redText
        case .selected:  return DSColor.action
        default:         return DSColor.secondaryLabel
        }
    }
    private var labelBackground: Color {
        switch state {
        case .correct:   return DSColor.green.opacity(0.2)
        case .wrongPick: return DSColor.red.opacity(0.2)
        case .selected:  return DSColor.actionTint
        default:         return DSColor.fill
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        OptionRow(label: "A", text: "struct", isMonospaced: true, state: .correct) {}
        OptionRow(label: "B", text: "class", isMonospaced: true, state: .wrongPick) {}
        OptionRow(label: "C", text: "enum", isMonospaced: true, state: .fadedIncorrect) {}
        OptionRow(label: "D", text: "actor", isMonospaced: true, state: .idle) {}
    }
    .padding()
    .background(DSColor.groupedBackground)
}
