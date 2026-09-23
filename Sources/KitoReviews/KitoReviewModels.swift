//
//  KitoReviewModels.swift
//  KitoReviews
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI

/// One review: who wrote it, how many stars, what they said and how others reacted.
public struct KitoReview: Identifiable, Equatable {
    public var id: String
    public var author: KitoReviewer
    /// The rating, usually 1…5.
    public var rating: Double
    public var title: String?
    public var body: String
    public var date: Date
    public var photos: [KitoReviewPhoto]
    /// Short chips such as "Great value" or "Friendly staff".
    public var tags: [String]
    public var helpfulCount: Int
    public var notHelpfulCount: Int
    /// A verified purchase, stay or visit.
    public var isVerified: Bool
    public var ownerReply: KitoOwnerReply?

    public init(
        id: String = UUID().uuidString,
        author: KitoReviewer,
        rating: Double,
        title: String? = nil,
        body: String,
        date: Date = Date(),
        photos: [KitoReviewPhoto] = [],
        tags: [String] = [],
        helpfulCount: Int = 0,
        notHelpfulCount: Int = 0,
        isVerified: Bool = false,
        ownerReply: KitoOwnerReply? = nil
    ) {
        self.id = id
        self.author = author
        self.rating = rating
        self.title = title
        self.body = body
        self.date = date
        self.photos = photos
        self.tags = tags
        self.helpfulCount = helpfulCount
        self.notHelpfulCount = notHelpfulCount
        self.isVerified = isVerified
        self.ownerReply = ownerReply
    }
}

/// The person behind a review.
public struct KitoReviewer: Equatable {
    public var name: String
    /// A line under the name, e.g. "Local guide · 42 reviews".
    public var subtitle: String?
    public var avatar: Image?

    public init(_ name: String, subtitle: String? = nil, avatar: Image? = nil) {
        self.name = name
        self.subtitle = subtitle
        self.avatar = avatar
    }

    /// Up to two initials: "Achieng O." → "AO", "Zawadi" → "Z".
    public var initials: String {
        let words = name.split(whereSeparator: { $0 == " " || $0 == "-" })
        let letters = words.prefix(2).compactMap { $0.first(where: { $0.isLetter }) }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    public static func == (lhs: KitoReviewer, rhs: KitoReviewer) -> Bool {
        lhs.name == rhs.name && lhs.subtitle == rhs.subtitle && (lhs.avatar == nil) == (rhs.avatar == nil)
    }
}

/// A photo attached to a review.
public struct KitoReviewPhoto: Identifiable, Equatable {
    public enum Source {
        case image(Image)
        case url(URL)
    }

    public var id: String
    public var source: Source
    public var caption: String?

    public init(id: String = UUID().uuidString, _ image: Image, caption: String? = nil) {
        self.id = id
        self.source = .image(image)
        self.caption = caption
    }

    public init(id: String = UUID().uuidString, url: URL, caption: String? = nil) {
        self.id = id
        self.source = .url(url)
        self.caption = caption
    }

    public static func == (lhs: KitoReviewPhoto, rhs: KitoReviewPhoto) -> Bool {
        lhs.id == rhs.id && lhs.caption == rhs.caption
    }
}

/// The business's public answer to a review.
public struct KitoOwnerReply: Equatable {
    /// Who answered, e.g. "Mama Oliech, owner".
    public var name: String
    public var body: String
    public var date: Date

    public init(name: String, body: String, date: Date = Date()) {
        self.name = name
        self.body = body
        self.date = date
    }
}

/// How the current user voted on a review.
public enum KitoHelpfulVote: Equatable, Sendable {
    case helpful
    case notHelpful
}

/// Why a review is being reported.
public enum KitoReportReason: String, CaseIterable, Identifiable, Sendable {
    case spam = "Spam or advertising"
    case offensive = "Offensive or hateful"
    case offTopic = "Off topic"
    case fake = "Not a real experience"
    case privacy = "Shares private information"

    public var id: String { rawValue }
}

/// Helpful / not-helpful counts including the current user's vote.
public struct KitoVoteTally: Equatable, Sendable {
    public var helpful: Int
    public var notHelpful: Int
    public var vote: KitoHelpfulVote?

    public init(helpful: Int, notHelpful: Int, vote: KitoHelpfulVote? = nil) {
        self.helpful = helpful
        self.notHelpful = notHelpful
        self.vote = vote
    }

    /// Taps a vote button: the same vote again clears it, the other one switches.
    public mutating func toggle(_ tapped: KitoHelpfulVote) {
        if vote == .helpful { helpful -= 1 }
        if vote == .notHelpful { notHelpful -= 1 }
        if vote == tapped {
            vote = nil
            return
        }
        vote = tapped
        if tapped == .helpful { helpful += 1 } else { notHelpful += 1 }
    }
}
