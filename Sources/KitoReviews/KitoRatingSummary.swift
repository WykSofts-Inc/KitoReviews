//
//  KitoRatingSummary.swift
//  KitoReviews
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// The ratings overview at the top of a reviews screen.
///
/// The histogram form shows the average, stars and total beside animated 5→1 bars; pass a
/// `selection` binding and tapping a bar filters by that star. The categories form leads with a
/// large score and animated bars for aspects like Cleanliness and Location.
///
/// ```swift
/// KitoRatingSummary(stats: stats, selection: $starFilter)
/// KitoRatingSummary(stats: stats, categories: [
///     KitoCategoryScore("Cleanliness", score: 4.9, systemImage: "sparkles"),
///     KitoCategoryScore("Location", score: 4.7, systemImage: "map"),
/// ], badge: "Guest favourite")
/// ```
public struct KitoRatingSummary: View {
    private let stats: KitoRatingStats
    private let categories: [KitoCategoryScore]
    private let badge: String?
    private let selection: Binding<Int?>?
    private let tint: Color?

    /// Average, stars and total beside a 5→1 histogram.
    public init(stats: KitoRatingStats, selection: Binding<Int?>? = nil, tint: Color? = nil) {
        self.stats = stats
        self.categories = []
        self.badge = nil
        self.selection = selection
        self.tint = tint
    }

    /// A large score between laurels, an optional badge and an animated bar per category.
    public init(stats: KitoRatingStats, categories: [KitoCategoryScore], badge: String? = nil, tint: Color? = nil) {
        self.stats = stats
        self.categories = categories
        self.badge = badge
        self.selection = nil
        self.tint = tint
    }

    public var body: some View {
        if categories.isEmpty {
            HistogramSummary(stats: stats, selection: selection, tint: tint)
        } else {
            CategorySummary(stats: stats, categories: categories, badge: badge, tint: tint)
        }
    }
}

// MARK: - Histogram

private struct HistogramSummary: View {
    let stats: KitoRatingStats
    let selection: Binding<Int?>?
    let tint: Color?

    @State private var appeared = false
    @State private var shownAverage: Double = 0
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selected: Int? { selection?.wrappedValue }
    private var accent: Color { tint ?? theme.colors.onSurface }

    var body: some View {
        HStack(alignment: .center, spacing: theme.spacing.xl) {
            VStack(spacing: theme.spacing.xs) {
                Text(String(format: "%.1f", shownAverage))
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: shownAverage))
                    .foregroundStyle(theme.colors.onSurface)
                KitoStarRating(value: stats.average, size: .custom(15), tint: tint)
                Text("\(stats.total.formatted()) \(stats.total == 1 ? "review" : "reviews")")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.onSurface.opacity(0.55))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Average \(KitoRatingMath.accessibilityValue(stats.average)), \(stats.total.formatted()) reviews")

            VStack(spacing: 6) {
                let percentages = stats.percentagesFiveToOne
                ForEach(Array((1...5).reversed().enumerated()), id: \.element) { order, star in
                    bar(star: star, percent: percentages[safe: order] ?? 0, order: order)
                }
            }
        }
        .onAppear(perform: reveal)
        .onChange(of: stats) { _, _ in reveal() }
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func bar(star: Int, percent: Int, order: Int) -> some View {
        let isSelected = selected == star
        let isDimmed = selected != nil && !isSelected
        let fraction = stats.fraction(for: star)
        return Button {
            guard let selection else { return }
            withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                selection.wrappedValue = isSelected ? nil : star
            }
        } label: {
            HStack(spacing: theme.spacing.sm) {
                HStack(spacing: 2) {
                    Text("\(star)").font(theme.typography.caption.weight(.semibold)).monospacedDigit()
                    Image(systemName: "star.fill").font(.system(size: 8, weight: .bold))
                }
                .frame(width: 22, alignment: .leading)
                .foregroundStyle(theme.colors.onSurface.opacity(0.7))

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.colors.surfaceMuted)
                        Capsule()
                            .fill(isSelected ? AnyShapeStyle(accent) : AnyShapeStyle(tint ?? theme.colors.warning))
                            .frame(width: max(appeared ? proxy.size.width * fraction : 0, fraction > 0 ? 6 : 0))
                            .animation(reduceMotion ? nil : .spring(duration: 0.8, bounce: 0.25).delay(Double(order) * 0.07), value: appeared)
                    }
                }
                .frame(height: isSelected ? 10 : 7)

                Text("\(percent)%")
                    .font(theme.typography.caption)
                    .monospacedDigit()
                    .foregroundStyle(theme.colors.onSurface.opacity(0.55))
                    .frame(width: 34, alignment: .trailing)
            }
            .padding(.vertical, 2)
            .opacity(isDimmed ? 0.4 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(KitoReviewPressStyle(scale: 0.98))
        .disabled(selection == nil)
        .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
        .accessibilityValue("\(percent) percent, \(stats.count(for: star).formatted()) reviews")
        .accessibilityHint(selection == nil ? "" : (isSelected ? "Double tap to show all reviews" : "Double tap to show only these reviews"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func reveal() {
        if reduceMotion {
            appeared = true
            shownAverage = stats.average
            return
        }
        appeared = true
        withAnimation(.spring(duration: 0.9)) { shownAverage = stats.average }
    }
}

// MARK: - Categories

private struct CategorySummary: View {
    let stats: KitoRatingStats
    let categories: [KitoCategoryScore]
    let badge: String?
    let tint: Color?

    @State private var appeared = false
    @State private var shownAverage: Double = 0
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color { tint ?? theme.colors.onSurface }

    var body: some View {
        VStack(spacing: theme.spacing.xl) {
            VStack(spacing: theme.spacing.xs) {
                HStack(spacing: theme.spacing.sm) {
                    Image(systemName: "laurel.leading")
                        .font(.system(size: 50, weight: .regular))
                        .rotationEffect(.degrees(appeared ? 0 : 25), anchor: .bottomTrailing)
                    Text(String(format: "%.2f", shownAverage))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: shownAverage))
                    Image(systemName: "laurel.trailing")
                        .font(.system(size: 50, weight: .regular))
                        .rotationEffect(.degrees(appeared ? 0 : -25), anchor: .bottomLeading)
                }
                .foregroundStyle(theme.colors.onSurface)
                .opacity(appeared ? 1 : 0)
                if let badge {
                    Text(badge).font(.title3.weight(.bold)).foregroundStyle(theme.colors.onSurface)
                }
                Text("\(stats.total.formatted()) reviews")
                    .font(theme.typography.label)
                    .foregroundStyle(theme.colors.onSurface.opacity(0.6))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(badge.map { "\($0), " } ?? "")average \(KitoRatingMath.accessibilityValue(stats.average)), \(stats.total.formatted()) reviews")

            VStack(spacing: theme.spacing.md) {
                ForEach(Array(categories.enumerated()), id: \.element.id) { order, category in
                    row(category, order: order)
                    if order < categories.count - 1 { Divider().overlay(theme.colors.border) }
                }
            }
        }
        .onAppear {
            if reduceMotion {
                appeared = true
                shownAverage = stats.average
            } else {
                withAnimation(.spring(duration: 0.7, bounce: 0.35)) { appeared = true }
                withAnimation(.spring(duration: 1.0)) { shownAverage = stats.average }
            }
        }
    }

    private func row(_ category: KitoCategoryScore, order: Int) -> some View {
        let fraction = min(max(category.score / 5, 0), 1)
        return HStack(spacing: theme.spacing.md) {
            if let symbol = category.systemImage {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 26)
                    .foregroundStyle(theme.colors.onSurface.opacity(0.8))
            }
            Text(category.name)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.onSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)
            Spacer(minLength: theme.spacing.sm)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.colors.surfaceMuted)
                    Capsule().fill(accent)
                        .frame(width: appeared ? proxy.size.width * fraction : 0)
                        .animation(reduceMotion ? nil : .spring(duration: 0.9, bounce: 0.2).delay(0.15 + Double(order) * 0.08), value: appeared)
                }
            }
            .frame(width: 72, height: 5)
            Text(String(format: "%.1f", category.score))
                .font(theme.typography.bodyEmphasized)
                .monospacedDigit()
                .frame(width: 30, alignment: .trailing)
                .foregroundStyle(theme.colors.onSurface)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(category.name)
        .accessibilityValue(KitoRatingMath.accessibilityValue(category.score))
    }
}
