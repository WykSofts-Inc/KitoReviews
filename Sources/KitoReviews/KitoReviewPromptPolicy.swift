//
//  KitoReviewPromptPolicy.swift
//  KitoReviews
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// What the app remembers between launches to decide when to ask for a review.
public struct KitoReviewPromptState: Codable, Equatable, Sendable {
    public var installDate: Date
    /// Moments that show the app worked for someone: an order placed, a trip booked.
    public var significantEvents: Int
    public var lastPromptDate: Date?
    public var lastPromptedVersion: String?

    public init(installDate: Date = Date(), significantEvents: Int = 0, lastPromptDate: Date? = nil, lastPromptedVersion: String? = nil) {
        self.installDate = installDate
        self.significantEvents = significantEvents
        self.lastPromptDate = lastPromptDate
        self.lastPromptedVersion = lastPromptedVersion
    }

    public mutating func recordSignificantEvent() {
        significantEvents += 1
    }

    /// Call when the prompt is shown. Starts the cooldown and resets the event count.
    public mutating func recordPrompt(version: String, at date: Date = Date()) {
        lastPromptDate = date
        lastPromptedVersion = version
        significantEvents = 0
    }

    /// Reads saved state, or starts fresh (installed now) if there is none.
    public static func load(from defaults: UserDefaults = .standard, key: String = "kito.reviewPrompt") -> KitoReviewPromptState {
        guard let data = defaults.data(forKey: key),
              let state = try? JSONDecoder().decode(KitoReviewPromptState.self, from: data) else {
            return KitoReviewPromptState()
        }
        return state
    }

    public func save(to defaults: UserDefaults = .standard, key: String = "kito.reviewPrompt") {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: key) }
    }
}

/// The answer from `KitoReviewPromptPolicy`.
public enum KitoReviewPromptDecision: Equatable, Sendable {
    case ask
    case needsMoreEvents(remaining: Int)
    case tooSoonAfterInstall(daysLeft: Int)
    case alreadyAskedThisVersion
    case coolingDown(daysLeft: Int)

    public var shouldAsk: Bool { self == .ask }
}

/// Decides when to show the "Enjoying the app?" prompt: only after enough good moments, a few
/// days after install, at most once per version and never within the cooldown.
public struct KitoReviewPromptPolicy: Equatable, Sendable {
    public var minimumSignificantEvents: Int
    public var minimumDaysSinceInstall: Int
    public var cooldownDays: Int
    public var oncePerVersion: Bool

    public init(minimumSignificantEvents: Int = 3, minimumDaysSinceInstall: Int = 3, cooldownDays: Int = 120, oncePerVersion: Bool = true) {
        self.minimumSignificantEvents = minimumSignificantEvents
        self.minimumDaysSinceInstall = minimumDaysSinceInstall
        self.cooldownDays = cooldownDays
        self.oncePerVersion = oncePerVersion
    }

    /// Checks the rules in order: version, cooldown, install age, then events.
    public func decision(for state: KitoReviewPromptState, currentVersion: String, now: Date = Date()) -> KitoReviewPromptDecision {
        if oncePerVersion, state.lastPromptedVersion == currentVersion {
            return .alreadyAskedThisVersion
        }
        if let last = state.lastPromptDate {
            let elapsed = Self.wholeDays(from: last, to: now)
            if elapsed < cooldownDays { return .coolingDown(daysLeft: cooldownDays - elapsed) }
        }
        let age = Self.wholeDays(from: state.installDate, to: now)
        if age < minimumDaysSinceInstall {
            return .tooSoonAfterInstall(daysLeft: minimumDaysSinceInstall - age)
        }
        if state.significantEvents < minimumSignificantEvents {
            return .needsMoreEvents(remaining: minimumSignificantEvents - state.significantEvents)
        }
        return .ask
    }

    static func wholeDays(from start: Date, to end: Date) -> Int {
        Int((end.timeIntervalSince(start) / 86_400).rounded(.down))
    }
}
