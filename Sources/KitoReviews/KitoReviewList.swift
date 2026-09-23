//
//  KitoReviewList.swift
//  KitoReviews
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A scrolling reviews screen: summary, "Write a review", sort menu, filter chips and cards.
///
/// Tapping a histogram bar or a star chip filters; "With photos" and "Verified" narrow further.
/// When nothing matches, an empty state offers to clear the filters.
///
/// ```swift
/// KitoReviewList(reviews: reviews, onWriteReview: { showsComposer = true },
///                onVote: { review, vote in api.vote(review.id, vote) })
/// ```
public struct KitoReviewList: View {
    private let reviews: [KitoReview]
    private let stats: KitoRatingStats
    private let showsSummary: Bool
    private let onWriteReview: (() -> Void)?
    private let onVote: ((KitoReview, KitoHelpfulVote?) -> Void)?
    private let onReport: ((KitoReview, KitoReportReason) -> Void)?
    private let tint: Color?

    @State private var sort: KitoReviewSort
    @State private var filter = KitoReviewFilter()
    @Environment(\.kitoTheme) private var theme

    /// - Parameters:
    ///   - stats: Totals for the summary; computed from `reviews` when `nil` (pass your own when
    ///     `reviews` is only the first page).
    public init(reviews: [KitoReview], stats: KitoRatingStats? = nil, sort: KitoReviewSort = .mostRecent, showsSummary: Bool = true,
                onWriteReview: (() -> Void)? = nil, onVote: ((KitoReview, KitoHelpfulVote?) -> Void)? = nil,
                onReport: ((KitoReview, KitoReportReason) -> Void)? = nil, tint: Color? = nil) {
        self.reviews = reviews
        self.stats = stats ?? KitoRatingStats(reviews: reviews)
        self.showsSummary = showsSummary
        self.onWriteReview = onWriteReview
        self.onVote = onVote
        self.onReport = onReport
        self.tint = tint
        _sort = State(initialValue: sort)
    }

    private var accent: Color { tint ?? theme.colors.onSurface }
    private var visible: [KitoReview] { sort.sorted(filter.apply(to: reviews)) }

    /// The histogram selects one star at a time; the chips can select several.
    private var histogramSelection: Binding<Int?> {
        Binding(
            get: { filter.stars.count == 1 ? filter.stars.first : nil },
            set: { star in filter.stars = star.map { [$0] } ?? [] }
        )
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacing.lg, pinnedViews: [.sectionHeaders]) {
                if showsSummary && stats.total > 0 {
                    KitoRatingSummary(stats: stats, selection: histogramSelection, tint: tint)
                        .padding(theme.spacing.lg)
                        .background(RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous).fill(theme.colors.surface))
                        .padding(.horizontal, theme.spacing.lg)
                }
                if let onWriteReview, !reviews.isEmpty { writeButton(onWriteReview).padding(.horizontal, theme.spacing.lg) }

                Section {
                    if reviews.isEmpty {
                        emptyState(noReviews: true)
                    } else if visible.isEmpty {
                        emptyState(noReviews: false)
                    } else {
                        ForEach(visible) { review in
                            KitoReviewCard(review, onVote: onVote.map { handler in { handler(review, $0) } },
                                           onReport: onReport.map { handler in { handler(review, $0) } }, tint: tint)
                                .padding(.horizontal, theme.spacing.lg)
                                .transition(.asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity), removal: .opacity))
                        }
                    }
                } header: {
                    if !reviews.isEmpty { controls }
                }
            }
            .padding(.vertical, theme.spacing.lg)
            .animation(.spring(duration: 0.45, bounce: 0.2), value: filter)
            .animation(.spring(duration: 0.45, bounce: 0.2), value: sort)
        }
        .background(theme.colors.background)
        .sensoryFeedback(.selection, trigger: filter)
        .sensoryFeedback(.selection, trigger: sort)
    }

    // MARK: Pieces

    private func writeButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("Write a review", systemImage: "square.and.pencil")
                .font(theme.typography.button)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(theme.colors.surface)
                .background(Capsule().fill(accent))
                .contentShape(Capsule())
        }
        .buttonStyle(KitoReviewPressStyle())
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            HStack {
                Text("\(visible.count) \(visible.count == 1 ? "review" : "reviews")")
                    .font(theme.typography.bodyEmphasized.weight(.bold))
                    .contentTransition(.numericText(value: Double(visible.count)))
                    .foregroundStyle(theme.colors.onSurface)
                Spacer()
                Menu {
                    Picker("Sort by", selection: $sort) {
                        ForEach(KitoReviewSort.allCases) { option in
                            Label(option.rawValue, systemImage: option.systemImage).tag(option)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down").font(.caption.weight(.bold))
                        Text(sort.rawValue).font(theme.typography.label)
                    }
                    .foregroundStyle(theme.colors.onSurface)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(theme.colors.surfaceMuted))
                }
                .accessibilityLabel("Sort by \(sort.rawValue)")
            }
            .padding(.horizontal, theme.spacing.lg)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacing.sm) {
                    KitoReviewChip(title: "All", isSelected: !filter.isActive, accent: accent) { filter = KitoReviewFilter() }
                    KitoReviewChip(title: "With photos", systemImage: "photo", isSelected: filter.withPhotosOnly, accent: accent) {
                        filter.withPhotosOnly.toggle()
                    }
                    KitoReviewChip(title: "Verified", systemImage: "checkmark.seal", isSelected: filter.verifiedOnly, accent: accent) {
                        filter.verifiedOnly.toggle()
                    }
                    ForEach((1...5).reversed(), id: \.self) { star in
                        KitoReviewChip(title: "\(star)", systemImage: "star.fill", isSelected: filter.stars.contains(star), accent: accent) {
                            if filter.stars.contains(star) { filter.stars.remove(star) } else { filter.stars.insert(star) }
                        }
                        .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                    }
                }
                .padding(.horizontal, theme.spacing.lg)
                .padding(.vertical, 2)
            }
        }
        .padding(.vertical, theme.spacing.sm)
        .background(theme.colors.background.opacity(0.96))
    }

    private func emptyState(noReviews: Bool) -> some View {
        VStack(spacing: theme.spacing.md) {
            ZStack {
                Circle().fill(theme.colors.surfaceMuted).frame(width: 88, height: 88)
                Image(systemName: noReviews ? "star.bubble" : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(theme.colors.onSurface.opacity(0.7))
                    .symbolEffect(.bounce, value: filter)
            }
            Text(noReviews ? "No reviews yet" : "No reviews match")
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.colors.onSurface)
            Text(noReviews ? "Be the first to share what you think." : "Try fewer filters to see more reviews.")
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.onSurface.opacity(0.6))
                .multilineTextAlignment(.center)
            if noReviews, let onWriteReview {
                writeButton(onWriteReview).frame(maxWidth: 260).padding(.top, theme.spacing.sm)
            } else if !noReviews {
                Button("Clear filters") { filter = KitoReviewFilter() }
                    .font(theme.typography.button)
                    .foregroundStyle(accent)
                    .padding(.top, theme.spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.xxl)
        .padding(.horizontal, theme.spacing.lg)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}
