//
//  KitoRatingMath.swift
//  KitoReviews
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// How finely a rating input moves.
public enum KitoRatingStep: Equatable, Sendable {
    /// Whole stars: 1, 2, 3…
    case whole
    /// Half stars: 0.5, 1, 1.5…
    case half

    var increment: Double { self == .whole ? 1 : 0.5 }
}

/// The arithmetic behind ratings, shared by every view in the package.
public enum KitoRatingMath {
    /// Rounds to the nearest half: 4.3 → 4.5, 4.2 → 4.0, 4.75 → 5.0.
    public static func roundedToHalf(_ value: Double) -> Double {
        (value * 2).rounded(.toNearestOrAwayFromZero) / 2
    }

    /// Rounds `value` to `step` and clamps it to `0...maximum`.
    public static func snapped(_ value: Double, step: KitoRatingStep, maximum: Int) -> Double {
        let snapped = step == .half ? roundedToHalf(value) : value.rounded(.toNearestOrAwayFromZero)
        return min(max(snapped, 0), Double(maximum))
    }

    /// How much of the symbol at `index` (0-based) is filled for `rating`, from 0 to 1.
    /// For 4.3 the fifth star (index 4) is 0.3 full.
    public static func fillFraction(at index: Int, rating: Double) -> Double {
        min(max(rating - Double(index), 0), 1)
    }

    /// The rating under a finger at `x` across a row `width` points wide with `count` symbols.
    /// Touching anywhere on a symbol selects it (whole) or its nearer half (half); left of the
    /// row gives the minimum of one step.
    public static func rating(atX x: Double, width: Double, count: Int, step: KitoRatingStep) -> Double {
        guard width > 0, count > 0 else { return 0 }
        let position = min(max(x / width, 0), 1) * Double(count)
        let raw = (position / step.increment).rounded(.up) * step.increment
        return min(max(raw, step.increment), Double(count))
    }

    /// "2.1k", "12k", "1.3M" or the plain number below 1,000.
    public static func compactCount(_ count: Int) -> String {
        func format(_ value: Double, _ suffix: String) -> String {
            let rounded = (value * 10).rounded(.down) / 10
            let text = rounded >= 10 || rounded == rounded.rounded(.down)
                ? String(Int(rounded))
                : String(format: "%.1f", rounded)
            return text + suffix
        }
        switch count {
        case ..<1_000: return String(max(count, 0))
        case ..<1_000_000: return format(Double(count) / 1_000, "k")
        default: return format(Double(count) / 1_000_000, "M")
        }
    }

    /// A rating written for display without trailing zeros: 4.8, 4, 4.85.
    public static func formatted(_ rating: Double, fractionDigits: Int = 1) -> String {
        let factor = pow(10, Double(fractionDigits))
        let rounded = (rating * factor).rounded() / factor
        if rounded == rounded.rounded(.down) { return String(Int(rounded)) }
        var text = String(format: "%.\(max(fractionDigits, 0))f", rounded)
        while text.hasSuffix("0") { text.removeLast() }
        return text
    }

    /// What VoiceOver reads: "4 out of 5 stars", "4.5 out of 5 stars".
    public static func accessibilityValue(_ rating: Double, maximum: Int = 5, noun: String = "stars") -> String {
        "\(formatted(rating)) out of \(maximum) \(noun)"
    }
}

/// Totals for a set of ratings: the average, the count and how many gave each star.
public struct KitoRatingStats: Equatable, Sendable {
    /// Number of ratings for each star, index 0 is one star.
    public let counts: [Int]

    /// Counts for five stars down to one, as most apps show them: `[812, 240, 96, 31, 18]`.
    public init(fiveToOne: [Int]) {
        let padded = Array(fiveToOne.prefix(5)) + Array(repeating: 0, count: max(0, 5 - fiveToOne.count))
        counts = padded.reversed().map { max($0, 0) }
    }

    /// Buckets individual ratings; half stars round to the nearest whole star (4.5 → 5).
    public init(ratings: [Double]) {
        var counts = [Int](repeating: 0, count: 5)
        for rating in ratings {
            let star = Int(min(max(rating.rounded(.toNearestOrAwayFromZero), 1), 5))
            counts[star - 1] += 1
        }
        self.counts = counts
    }

    public init(reviews: [KitoReview]) {
        self.init(ratings: reviews.map(\.rating))
    }

    public var total: Int { counts.reduce(0, +) }

    /// The mean, or 0 with no ratings.
    public var average: Double {
        guard total > 0 else { return 0 }
        let sum = counts.enumerated().reduce(0) { $0 + ($1.offset + 1) * $1.element }
        return Double(sum) / Double(total)
    }

    public func count(for star: Int) -> Int {
        (1...5).contains(star) ? counts[star - 1] : 0
    }

    /// The share of ratings with `star` stars, 0…1.
    public func fraction(for star: Int) -> Double {
        total > 0 ? Double(count(for: star)) / Double(total) : 0
    }

    /// Whole-number percentages for 5…1 that always add up to 100 (largest remainder).
    public var percentagesFiveToOne: [Int] {
        guard total > 0 else { return [0, 0, 0, 0, 0] }
        let exact = (1...5).reversed().map { fraction(for: $0) * 100 }
        var floors = exact.map { Int($0.rounded(.down)) }
        let remainder = exact.indices.map { exact[$0] - Double(floors[$0]) }
        let order = exact.indices.sorted { remainder[$0] != remainder[$1] ? remainder[$0] > remainder[$1] : $0 < $1 }
        for index in order.prefix(100 - floors.reduce(0, +)) { floors[index] += 1 }
        return floors
    }
}

/// A score for one aspect, such as Cleanliness 4.9.
public struct KitoCategoryScore: Identifiable, Equatable, Sendable {
    public var id: String { name }
    public var name: String
    public var score: Double
    public var systemImage: String?

    public init(_ name: String, score: Double, systemImage: String? = nil) {
        self.name = name
        self.score = score
        self.systemImage = systemImage
    }
}

/// The feeling behind a star rating, used for labels and faces.
public enum KitoRatingMood: Int, CaseIterable, Sendable {
    case terrible = 1, bad, okay, good, amazing

    /// The mood for a rating; 0 or less has none.
    public init?(rating: Double) {
        guard rating > 0 else { return nil }
        let star = Int(min(max(rating.rounded(.toNearestOrAwayFromZero), 1), 5))
        self.init(rawValue: star)
    }

    public var title: String {
        switch self {
        case .terrible: "Terrible"
        case .bad: "Bad"
        case .okay: "Okay"
        case .good: "Good"
        case .amazing: "Amazing"
        }
    }

    public var emoji: String {
        switch self {
        case .terrible: "😡"
        case .bad: "😕"
        case .okay: "😐"
        case .good: "🙂"
        case .amazing: "😍"
        }
    }

    /// Mouth curve from -1 (frown) to 1 (grin).
    var smile: Double {
        switch self {
        case .terrible: -1
        case .bad: -0.5
        case .okay: 0
        case .good: 0.55
        case .amazing: 1
        }
    }
}

/// Net Promoter Score groups.
public enum KitoNPSCategory: String, CaseIterable, Sendable {
    case detractor, passive, promoter

    /// 0–6 detractor, 7–8 passive, 9–10 promoter.
    public init(score: Int) {
        switch score {
        case ...6: self = .detractor
        case 7...8: self = .passive
        default: self = .promoter
        }
    }

    public var title: String { rawValue.capitalized }

    /// The NPS for a set of 0–10 answers: % promoters minus % detractors, from -100 to 100.
    public static func netPromoterScore(_ scores: [Int]) -> Double {
        guard !scores.isEmpty else { return 0 }
        let promoters = scores.filter { KitoNPSCategory(score: $0) == .promoter }.count
        let detractors = scores.filter { KitoNPSCategory(score: $0) == .detractor }.count
        return Double(promoters - detractors) / Double(scores.count) * 100
    }
}

/// Where a piece of review text stands against its length limits.
public enum KitoTextGuidance: Equatable, Sendable {
    case empty
    case tooShort(remaining: Int)
    case good
    case tooLong(over: Int)

    public init(count: Int, minimum: Int, maximum: Int) {
        if count == 0 {
            self = .empty
        } else if count < minimum {
            self = .tooShort(remaining: minimum - count)
        } else if count > maximum {
            self = .tooLong(over: count - maximum)
        } else {
            self = .good
        }
    }

    public var message: String {
        switch self {
        case .empty: "Tell others what stood out"
        case .tooShort(let remaining): "Add \(remaining) more character\(remaining == 1 ? "" : "s")"
        case .good: "Looking good"
        case .tooLong(let over): "\(over) character\(over == 1 ? "" : "s") over the limit"
        }
    }

    public var isAcceptable: Bool {
        switch self {
        case .good: true
        default: false
        }
    }
}
