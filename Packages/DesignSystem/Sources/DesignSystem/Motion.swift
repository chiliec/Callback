import SwiftUI

public enum DSMotion {
    public static let quick: Double = 0.18
    public static let standard: Double = 0.25
    public static let emphasis: Double = 0.35

    /// Returns `nil` when `reduceMotion` is true, otherwise returns the base animation.
    public static func animation(_ base: Animation?, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : base
    }
}
