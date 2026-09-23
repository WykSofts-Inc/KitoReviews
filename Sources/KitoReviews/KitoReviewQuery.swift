//
//  KitoReviewQuery.swift
//  KitoReviews
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// The orders a review list offers.
public enum KitoReviewSort: String, CaseIterable, Identifiable, Sendable {
    case mostRecent = "Most recent"
    case highest = "Highest rated"
    case lowest = "Lowest rated"
    case mostHelpful = "Most helpful"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .mostRecent: "clock"
        case .highest: "arrow.up"
        case .lowest: "arrow.down"
        case .mostHelpful: "hand.thumbsup"
        }
    }

    /// Sorts reviews; ties fall back to the newest first, then the id, so the order is stable.
    public func sorted(_ reviews: [KitoReview]) -> [KitoReview] {
        reviews.sorted { lhs, rhs in
            switch self {
            case .mostRecent: break
            case .highest: if lhs.rating != rhs.rating { return lhs.rating > rhs.rating }
            case .lowest: if lhs.rating != rhs.rating { return lhs.rating < rhs.rating }
            case .mostHelpful:
                let left = lhs.helpfulCount - lhs.notHelpfulCount, right = rhs.helpfulCount - rhs.notHelpfulCount
                if left != right { return left > right }
            }
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.id < rhs.id
        }
    }
}

/// Which reviews a list shows. Empty `stars` means every star.
public struct KitoReviewFilter: Equatable, Sendable {
    public var stars: Set<Int>
    public var withPhotosOnly: Bool
    public var verifiedOnly: Bool

    public init(stars: Set<Int> = [], withPhotosOnly: Bool = false, verifiedOnly: Bool = false) {
        self.stars = stars
        self.withPhotosOnly = withPhotosOnly
        self.verifiedOnly = verifiedOnly
    }

    public var isActive: Bool { !stars.isEmpty || withPhotosOnly || verifiedOnly }

    public func includes(_ review: KitoReview) -> Bool {
        let star = Int(min(max(review.rating.rounded(.toNearestOrAwayFromZero), 1), 5))
        if !stars.isEmpty && !stars.contains(star) { return false }
        if withPhotosOnly && review.photos.isEmpty { return false }
        if verifiedOnly && !review.isVerified { return false }
        return true
    }

    public func apply(to reviews: [KitoReview]) -> [KitoReview] {
        reviews.filter(includes)
    }
}

/// Friendly review dates.
public enum KitoReviewDate {
    /// "Just now", "5 minutes ago", "2 weeks ago", "3 months ago", relative to `reference`.
    public static func relative(_ date: Date, to reference: Date = Date(), locale: Locale = .current) -> String {
        let seconds = reference.timeIntervalSince(date)
        if abs(seconds) < 60 { return "Just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .numeric
        return formatter.localizedString(for: date, relativeTo: reference)
    }
}
