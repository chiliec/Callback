import Testing
import SwiftData
import Foundation
@testable import AppCore

@Test func seededGeneratorIsReproducible() {
    var a = SeededRandomNumberGenerator(seed: 42)
    var b = SeededRandomNumberGenerator(seed: 42)
    let left = (0..<8).map { _ in a.next() }
    let right = (0..<8).map { _ in b.next() }
    #expect(left == right)
}

@Test func seededGeneratorDiffersBySeed() {
    var a = SeededRandomNumberGenerator(seed: 1)
    var b = SeededRandomNumberGenerator(seed: 2)
    #expect(a.next() != b.next())
}
