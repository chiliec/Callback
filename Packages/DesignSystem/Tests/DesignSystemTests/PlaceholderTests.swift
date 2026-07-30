import Testing
import SwiftUI
import DesignSystem

@Test func designSystemPackageBuilds() { #expect(true) }

@Test func motionReturnsNilWhenReduceMotion() {
    #expect(DSMotion.animation(.easeOut, reduceMotion: true) == nil)
}

@Test func motionReturnsBaseWhenNotReduceMotion() {
    let base = Animation.easeOut(duration: DSMotion.quick)
    #expect(DSMotion.animation(base, reduceMotion: false) != nil)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func feedbackMappingIsExhaustive() {
    #expect(DSFeedback.selection.sensoryFeedback == .selection)
    #expect(DSFeedback.success.sensoryFeedback == .success)
    #expect(DSFeedback.warning.sensoryFeedback == .warning)
    #expect(DSFeedback.impactLight.sensoryFeedback == .impact(weight: .light))
}
