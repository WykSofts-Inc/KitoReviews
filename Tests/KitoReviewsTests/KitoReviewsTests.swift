//
//  KitoReviewsTests.swift
//  KitoReviews
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
@testable import KitoReviews

final class KitoRatingMathTests: XCTestCase {
    func testRoundingToHalfStars() {
        XCTAssertEqual(KitoRatingMath.roundedToHalf(4.3), 4.5)
        XCTAssertEqual(KitoRatingMath.roundedToHalf(4.2), 4.0)
        XCTAssertEqual(KitoRatingMath.roundedToHalf(4.75), 5.0)
        XCTAssertEqual(KitoRatingMath.roundedToHalf(4.25), 4.5)
        XCTAssertEqual(KitoRatingMath.roundedToHalf(0.1), 0)
    }

    func testSnappingClampsToTheScale() {
        XCTAssertEqual(KitoRatingMath.snapped(3.4, step: .whole, maximum: 5), 3)
        XCTAssertEqual(KitoRatingMath.snapped(3.4, step: .half, maximum: 5), 3.5)
        XCTAssertEqual(KitoRatingMath.snapped(7, step: .whole, maximum: 5), 5)
        XCTAssertEqual(KitoRatingMath.snapped(-1, step: .half, maximum: 5), 0)
    }

    func testPartialFillFractions() {
        let fills = (0..<5).map { KitoRatingMath.fillFraction(at: $0, rating: 4.3) }
        XCTAssertEqual(fills[0], 1)
        XCTAssertEqual(fills[3], 1)
        XCTAssertEqual(fills[4], 0.3, accuracy: 0.0001)
        XCTAssertEqual(KitoRatingMath.fillFraction(at: 2, rating: 1.5), 0)
        XCTAssertEqual(KitoRatingMath.fillFraction(at: 1, rating: 1.5), 0.5)
    }

    func testDragPositionMapsToRating() {
        // 5 stars across 100pt: each star is 20pt wide.
        XCTAssertEqual(KitoRatingMath.rating(atX: 5, width: 100, count: 5, step: .whole), 1)
        XCTAssertEqual(KitoRatingMath.rating(atX: 41, width: 100, count: 5, step: .whole), 3)
        XCTAssertEqual(KitoRatingMath.rating(atX: 99, width: 100, count: 5, step: .whole), 5)
        XCTAssertEqual(KitoRatingMath.rating(atX: 45, width: 100, count: 5, step: .half), 2.5)
        XCTAssertEqual(KitoRatingMath.rating(atX: 55, width: 100, count: 5, step: .half), 3)
        XCTAssertEqual(KitoRatingMath.rating(atX: -30, width: 100, count: 5, step: .whole), 1, "left of the row is one star")
        XCTAssertEqual(KitoRatingMath.rating(atX: 400, width: 100, count: 5, step: .whole), 5)
        XCTAssertEqual(KitoRatingMath.rating(atX: 10, width: 0, count: 5, step: .whole), 0)
    }

    func testCompactCounts() {
        XCTAssertEqual(KitoRatingMath.compactCount(0), "0")
        XCTAssertEqual(KitoRatingMath.compactCount(999), "999")
        XCTAssertEqual(KitoRatingMath.compactCount(1_000), "1k")
        XCTAssertEqual(KitoRatingMath.compactCount(2_140), "2.1k")
        XCTAssertEqual(KitoRatingMath.compactCount(2_190), "2.1k", "rounds down so it never overstates")
        XCTAssertEqual(KitoRatingMath.compactCount(12_400), "12k")
        XCTAssertEqual(KitoRatingMath.compactCount(1_350_000), "1.3M")
    }

    func testFormattingAndAccessibilityValue() {
        XCTAssertEqual(KitoRatingMath.formatted(4.83), "4.8")
        XCTAssertEqual(KitoRatingMath.formatted(4), "4")
        XCTAssertEqual(KitoRatingMath.formatted(4.917, fractionDigits: 2), "4.92")
        XCTAssertEqual(KitoRatingMath.accessibilityValue(4), "4 out of 5 stars")
        XCTAssertEqual(KitoRatingMath.accessibilityValue(4.5), "4.5 out of 5 stars")
        XCTAssertEqual(KitoRatingMath.accessibilityValue(3, maximum: 5, noun: "hearts"), "3 out of 5 hearts")
    }
}

final class KitoRatingStatsTests: XCTestCase {
    func testAverageAndHistogramFromRatings() {
        let stats = KitoRatingStats(ratings: [5, 5, 4, 3, 1, 4.5])
        XCTAssertEqual(stats.total, 6)
        XCTAssertEqual(stats.count(for: 5), 3, "4.5 rounds up to five")
        XCTAssertEqual(stats.count(for: 4), 1)
        XCTAssertEqual(stats.count(for: 2), 0)
        XCTAssertEqual(stats.count(for: 1), 1)
        XCTAssertEqual(stats.average, (15 + 4 + 3 + 1) / 6.0, accuracy: 0.0001)
        XCTAssertEqual(stats.fraction(for: 5), 0.5)
    }

    func testFiveToOneCountsReverseIntoStarOrder() {
        let stats = KitoRatingStats(fiveToOne: [812, 240, 96, 31, 18])
        XCTAssertEqual(stats.counts, [18, 31, 96, 240, 812])
        XCTAssertEqual(stats.total, 1_197)
        XCTAssertEqual(stats.average, 4.5, accuracy: 0.05)
    }

    func testShortCountsArePadded() {
        let stats = KitoRatingStats(fiveToOne: [10])
        XCTAssertEqual(stats.count(for: 5), 10)
        XCTAssertEqual(stats.count(for: 1), 0)
        XCTAssertEqual(stats.average, 5)
    }

    func testPercentagesAlwaysSumToOneHundred() {
        let stats = KitoRatingStats(fiveToOne: [1, 1, 1, 0, 0])
        XCTAssertEqual(stats.percentagesFiveToOne.reduce(0, +), 100)
        XCTAssertEqual(stats.percentagesFiveToOne, [34, 33, 33, 0, 0])
        XCTAssertEqual(KitoRatingStats(fiveToOne: [812, 240, 96, 31, 18]).percentagesFiveToOne.reduce(0, +), 100)
    }

    func testEmptyStats() {
        let stats = KitoRatingStats(ratings: [])
        XCTAssertEqual(stats.total, 0)
        XCTAssertEqual(stats.average, 0)
        XCTAssertEqual(stats.fraction(for: 5), 0)
        XCTAssertEqual(stats.percentagesFiveToOne, [0, 0, 0, 0, 0])
        XCTAssertEqual(stats.count(for: 9), 0)
    }
}

final class KitoReviewQueryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func review(_ id: String, rating: Double, daysAgo: Double, helpful: Int = 0, notHelpful: Int = 0,
                        photos: Int = 0, verified: Bool = false) -> KitoReview {
        KitoReview(id: id, author: KitoReviewer("Achieng O."), rating: rating, body: "Body", date: now.addingTimeInterval(-daysAgo * 86_400),
                   photos: (0..<photos).map { KitoReviewPhoto(id: "\(id)-\($0)", url: URL(fileURLWithPath: "/tmp/\($0).jpg")) },
                   helpfulCount: helpful, notHelpfulCount: notHelpful, isVerified: verified)
    }

    private lazy var reviews = [
        review("a", rating: 5, daysAgo: 10, helpful: 3),
        review("b", rating: 2, daysAgo: 1, helpful: 9, notHelpful: 8, photos: 2),
        review("c", rating: 4, daysAgo: 5, helpful: 7, verified: true),
        review("d", rating: 5, daysAgo: 2, photos: 1, verified: true),
    ]

    func testSorts() {
        XCTAssertEqual(KitoReviewSort.mostRecent.sorted(reviews).map(\.id), ["b", "d", "c", "a"])
        XCTAssertEqual(KitoReviewSort.highest.sorted(reviews).map(\.id), ["d", "a", "c", "b"], "ties go to the newest")
        XCTAssertEqual(KitoReviewSort.lowest.sorted(reviews).map(\.id), ["b", "c", "d", "a"])
        XCTAssertEqual(KitoReviewSort.mostHelpful.sorted(reviews).map(\.id), ["c", "a", "b", "d"], "net helpful votes")
    }

    func testFilters() {
        XCTAssertEqual(KitoReviewFilter().apply(to: reviews).count, 4)
        XCTAssertFalse(KitoReviewFilter().isActive)
        XCTAssertEqual(KitoReviewFilter(stars: [5]).apply(to: reviews).map(\.id), ["a", "d"])
        XCTAssertEqual(KitoReviewFilter(stars: [2, 4]).apply(to: reviews).map(\.id), ["b", "c"])
        XCTAssertEqual(KitoReviewFilter(withPhotosOnly: true).apply(to: reviews).map(\.id), ["b", "d"])
        XCTAssertEqual(KitoReviewFilter(verifiedOnly: true).apply(to: reviews).map(\.id), ["c", "d"])
        XCTAssertEqual(KitoReviewFilter(stars: [5], withPhotosOnly: true, verifiedOnly: true).apply(to: reviews).map(\.id), ["d"])
        XCTAssertTrue(KitoReviewFilter(stars: [1]).apply(to: reviews).isEmpty)
    }

    func testRelativeDatesAgainstAFixedReference() {
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(KitoReviewDate.relative(now.addingTimeInterval(-20), to: now, locale: locale), "Just now")
        XCTAssertEqual(KitoReviewDate.relative(now.addingTimeInterval(-5 * 60), to: now, locale: locale), "5 minutes ago")
        XCTAssertEqual(KitoReviewDate.relative(now.addingTimeInterval(-3 * 3_600), to: now, locale: locale), "3 hours ago")
        XCTAssertEqual(KitoReviewDate.relative(now.addingTimeInterval(-14 * 86_400), to: now, locale: locale), "2 weeks ago")
        XCTAssertEqual(KitoReviewDate.relative(now.addingTimeInterval(-95 * 86_400), to: now, locale: locale), "3 months ago")
    }
}

final class KitoReviewPromptPolicyTests: XCTestCase {
    private let install = Date(timeIntervalSince1970: 1_790_000_000)
    private func day(_ n: Double) -> Date { install.addingTimeInterval(n * 86_400) }
    private let policy = KitoReviewPromptPolicy(minimumSignificantEvents: 3, minimumDaysSinceInstall: 3, cooldownDays: 120)

    func testWaitsForEventsAndInstallAge() {
        var state = KitoReviewPromptState(installDate: install)
        XCTAssertEqual(policy.decision(for: state, currentVersion: "1.0", now: day(1)), .tooSoonAfterInstall(daysLeft: 2))
        XCTAssertEqual(policy.decision(for: state, currentVersion: "1.0", now: day(4)), .needsMoreEvents(remaining: 3))
        state.recordSignificantEvent()
        state.recordSignificantEvent()
        XCTAssertEqual(policy.decision(for: state, currentVersion: "1.0", now: day(4)), .needsMoreEvents(remaining: 1))
        state.recordSignificantEvent()
        XCTAssertEqual(policy.decision(for: state, currentVersion: "1.0", now: day(4)), .ask)
        XCTAssertTrue(policy.decision(for: state, currentVersion: "1.0", now: day(4)).shouldAsk)
    }

    func testOncePerVersionAndCooldown() {
        var state = KitoReviewPromptState(installDate: install, significantEvents: 5)
        state.recordPrompt(version: "1.0", at: day(10))
        XCTAssertEqual(state.significantEvents, 0, "the count starts over after asking")
        state.significantEvents = 5
        XCTAssertEqual(policy.decision(for: state, currentVersion: "1.0", now: day(300)), .alreadyAskedThisVersion)
        XCTAssertEqual(policy.decision(for: state, currentVersion: "1.1", now: day(40)), .coolingDown(daysLeft: 90))
        XCTAssertEqual(policy.decision(for: state, currentVersion: "1.1", now: day(130)), .ask)
    }

    func testVersionRuleCanBeTurnedOff() {
        let relaxed = KitoReviewPromptPolicy(minimumSignificantEvents: 1, minimumDaysSinceInstall: 0, cooldownDays: 30, oncePerVersion: false)
        let state = KitoReviewPromptState(installDate: install, significantEvents: 1, lastPromptDate: day(0), lastPromptedVersion: "1.0")
        XCTAssertEqual(relaxed.decision(for: state, currentVersion: "1.0", now: day(31)), .ask)
    }

    func testStateRoundTripsThroughUserDefaults() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "KitoReviewsTests"))
        defaults.removePersistentDomain(forName: "KitoReviewsTests")
        let state = KitoReviewPromptState(installDate: install, significantEvents: 2, lastPromptDate: day(3), lastPromptedVersion: "2.0")
        state.save(to: defaults, key: "prompt")
        XCTAssertEqual(KitoReviewPromptState.load(from: defaults, key: "prompt"), state)
        XCTAssertEqual(KitoReviewPromptState.load(from: defaults, key: "missing").significantEvents, 0)
        defaults.removePersistentDomain(forName: "KitoReviewsTests")
    }
}

final class KitoReviewLogicTests: XCTestCase {
    func testMoodLabels() {
        XCTAssertNil(KitoRatingMood(rating: 0))
        XCTAssertEqual(KitoRatingMood(rating: 1)?.title, "Terrible")
        XCTAssertEqual(KitoRatingMood(rating: 2)?.title, "Bad")
        XCTAssertEqual(KitoRatingMood(rating: 3)?.title, "Okay")
        XCTAssertEqual(KitoRatingMood(rating: 4)?.title, "Good")
        XCTAssertEqual(KitoRatingMood(rating: 5)?.title, "Amazing")
        XCTAssertEqual(KitoRatingMood(rating: 4.6), .amazing)
        XCTAssertEqual(KitoRatingMood(rating: 9), .amazing)
        XCTAssertEqual(KitoRatingMood.terrible.emoji, "😡")
    }

    func testNPSBuckets() {
        XCTAssertEqual(KitoNPSCategory(score: 0), .detractor)
        XCTAssertEqual(KitoNPSCategory(score: 6), .detractor)
        XCTAssertEqual(KitoNPSCategory(score: 7), .passive)
        XCTAssertEqual(KitoNPSCategory(score: 8), .passive)
        XCTAssertEqual(KitoNPSCategory(score: 9), .promoter)
        XCTAssertEqual(KitoNPSCategory(score: 10), .promoter)
        XCTAssertEqual(KitoNPSCategory.promoter.title, "Promoter")
    }

    func testNetPromoterScore() {
        XCTAssertEqual(KitoNPSCategory.netPromoterScore([10, 9, 8, 3]), 25)
        XCTAssertEqual(KitoNPSCategory.netPromoterScore([0, 1]), -100)
        XCTAssertEqual(KitoNPSCategory.netPromoterScore([]), 0)
    }

    func testTextGuidance() {
        XCTAssertEqual(KitoTextGuidance(count: 0, minimum: 20, maximum: 500), .empty)
        XCTAssertEqual(KitoTextGuidance(count: 8, minimum: 20, maximum: 500), .tooShort(remaining: 12))
        XCTAssertEqual(KitoTextGuidance(count: 20, minimum: 20, maximum: 500), .good)
        XCTAssertEqual(KitoTextGuidance(count: 503, minimum: 20, maximum: 500), .tooLong(over: 3))
        XCTAssertEqual(KitoTextGuidance.tooShort(remaining: 1).message, "Add 1 more character")
        XCTAssertEqual(KitoTextGuidance.tooShort(remaining: 12).message, "Add 12 more characters")
    }

    func testDraftReadiness() {
        var draft = KitoReviewDraft()
        XCTAssertFalse(draft.canSubmit(minimum: 20, maximum: 500, requiresText: false), "needs a rating")
        draft.rating = 4
        XCTAssertTrue(draft.canSubmit(minimum: 20, maximum: 500, requiresText: false), "stars alone are fine")
        XCTAssertFalse(draft.canSubmit(minimum: 20, maximum: 500, requiresText: true))
        draft.text = "   Great nyama choma   "
        XCTAssertEqual(draft.trimmedText.count, 17)
        XCTAssertFalse(draft.canSubmit(minimum: 20, maximum: 500, requiresText: false), "started text must reach the minimum")
        draft.text = "Great nyama choma and ugali, friendly staff."
        XCTAssertTrue(draft.canSubmit(minimum: 20, maximum: 500, requiresText: true))
        XCTAssertFalse(draft.canSubmit(minimum: 5, maximum: 10, requiresText: false))
    }

    func testDraftTagsToggle() {
        var draft = KitoReviewDraft()
        draft.toggleTag("Great value")
        draft.toggleTag("Clean")
        draft.toggleTag("Great value")
        XCTAssertEqual(draft.tags, ["Clean"])
    }

    func testVoteTally() {
        var tally = KitoVoteTally(helpful: 10, notHelpful: 2)
        tally.toggle(.helpful)
        XCTAssertEqual(tally, KitoVoteTally(helpful: 11, notHelpful: 2, vote: .helpful))
        tally.toggle(.notHelpful)
        XCTAssertEqual(tally, KitoVoteTally(helpful: 10, notHelpful: 3, vote: .notHelpful))
        tally.toggle(.notHelpful)
        XCTAssertEqual(tally, KitoVoteTally(helpful: 10, notHelpful: 2, vote: nil))
        var saved = KitoVoteTally(helpful: 5, notHelpful: 0, vote: .helpful)
        saved.toggle(.helpful)
        XCTAssertEqual(saved.helpful, 4, "clearing a saved vote removes it from the count")
    }

    func testInitials() {
        XCTAssertEqual(KitoReviewer("Achieng O.").initials, "AO")
        XCTAssertEqual(KitoReviewer("zawadi").initials, "Z")
        XCTAssertEqual(KitoReviewer("Brian Kiprotich Mwangi").initials, "BK")
        XCTAssertEqual(KitoReviewer("").initials, "?")
    }

    func testSliderMath() {
        XCTAssertEqual(KitoSliderMath.fraction(of: 5, in: 0...10), 0.5)
        XCTAssertEqual(KitoSliderMath.fraction(of: 20, in: 0...10), 1)
        XCTAssertEqual(KitoSliderMath.value(atX: 37, width: 100, range: 0...10, step: 1), 4)
        XCTAssertEqual(KitoSliderMath.value(atX: 37, width: 100, range: 0...10, step: 0.5), 3.5)
        XCTAssertEqual(KitoSliderMath.value(atX: -5, width: 100, range: 1...5, step: 1), 1)
        XCTAssertEqual(KitoSliderMath.mood(forFraction: 0), .terrible)
        XCTAssertEqual(KitoSliderMath.mood(forFraction: 1), .amazing)
        XCTAssertEqual(KitoSliderMath.mood(forFraction: 0.5), .okay)
    }
}
