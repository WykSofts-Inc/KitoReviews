//
//  KitoReviewCard.swift
//  KitoReviews
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// How a `KitoReviewCard` is laid out.
public enum KitoReviewCardStyle: Equatable, Sendable {
    /// Everything: photos, tags, votes, the owner's reply and a report menu.
    case standard
    /// A dense row for lists and previews.
    case compact
    /// A testimonial quote in a speech bubble.
    case bubble
    /// A fixed-width card for horizontal carousels.
    case carouselCard
}

/// One review, drawn in one of four styles.
///
/// Long text expands with "more", photos open a full-screen viewer, and the helpful buttons
/// bounce and count as you vote.
///
/// ```swift
/// KitoReviewCard(review, onVote: { vote in api.vote(review.id, vote) },
///                onReport: { reason in api.report(review.id, reason) })
/// KitoReviewCard(review, style: .bubble)
/// ```
public struct KitoReviewCard: View {
    private let review: KitoReview
    private let style: KitoReviewCardStyle
    private let lineLimit: Int
    private let onVote: ((KitoHelpfulVote?) -> Void)?
    private let onReport: ((KitoReportReason) -> Void)?
    private let tint: Color?

    @State private var tally: KitoVoteTally
    @State private var reported: KitoReportReason?
    @State private var viewer: PhotoViewerItem?
    @Environment(\.kitoTheme) private var theme

    /// - Parameters:
    ///   - vote: The current user's saved vote, already counted in the review's totals.
    ///   - lineLimit: Lines of text shown before "more".
    public init(_ review: KitoReview, style: KitoReviewCardStyle = .standard, vote: KitoHelpfulVote? = nil, lineLimit: Int = 4,
                onVote: ((KitoHelpfulVote?) -> Void)? = nil, onReport: ((KitoReportReason) -> Void)? = nil, tint: Color? = nil) {
        self.review = review
        self.style = style
        self.lineLimit = max(lineLimit, 1)
        self.onVote = onVote
        self.onReport = onReport
        self.tint = tint
        _tally = State(initialValue: KitoVoteTally(helpful: review.helpfulCount, notHelpful: review.notHelpfulCount, vote: vote))
    }

    private var accent: Color { tint ?? theme.colors.onSurface }
    private var relativeDate: String { KitoReviewDate.relative(review.date) }

    public var body: some View {
        Group {
            switch style {
            case .standard: standard
            case .compact: compact
            case .bubble: bubble
            case .carouselCard: carousel
            }
        }
        .fullScreenCover(item: $viewer) { item in
            KitoPhotoViewer(photos: review.photos, index: item.index)
        }
    }

    // MARK: Styles

    private var standard: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            HStack(alignment: .top, spacing: theme.spacing.md) {
                KitoAvatar(reviewer: review.author, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    nameLine
                    if let subtitle = review.author.subtitle {
                        Text(subtitle)
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.onSurface.opacity(0.55))
                    }
                }
                Spacer(minLength: 0)
                if onReport != nil { reportMenu }
            }
            HStack(spacing: theme.spacing.sm) {
                KitoStarRating(value: review.rating, size: .custom(15), tint: tint)
                Text(relativeDate)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.onSurface.opacity(0.55))
            }
            textBlock
            if !review.photos.isEmpty { photoStrip(size: 76) }
            if !review.tags.isEmpty { tags }
            if let reported { reportedNote(reported) }
            if let reply = review.ownerReply { ownerReply(reply) }
            votes
        }
        .padding(theme.spacing.lg)
        .background(cardBackground)
    }

    private var compact: some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            KitoAvatar(reviewer: review.author, size: 34)
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                HStack(spacing: theme.spacing.xs) {
                    nameLine
                    Spacer(minLength: theme.spacing.xs)
                    Text(relativeDate)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.onSurface.opacity(0.5))
                }
                HStack(spacing: theme.spacing.sm) {
                    KitoStarRating(value: review.rating, size: .custom(12), tint: tint)
                    if !review.photos.isEmpty {
                        Label("\(review.photos.count)", systemImage: "photo.on.rectangle")
                            .font(theme.typography.caption.weight(.semibold))
                            .foregroundStyle(theme.colors.onSurface.opacity(0.55))
                            .accessibilityLabel("\(review.photos.count) photos")
                    }
                }
                ExpandableText(review.title.map { "\($0). \(review.body)" } ?? review.body, lineLimit: min(lineLimit, 2),
                               font: theme.typography.label, color: theme.colors.onSurface.opacity(0.85))
            }
        }
        .padding(.vertical, theme.spacing.sm)
        .accessibilityElement(children: .combine)
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                HStack(alignment: .top) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(accent.opacity(0.9))
                        .accessibilityHidden(true)
                    Spacer()
                    KitoStarRating(value: review.rating, size: .custom(14), tint: tint)
                }
                if let title = review.title {
                    Text(title).font(.title3.weight(.bold)).foregroundStyle(theme.colors.onSurface)
                }
                ExpandableText(review.body, lineLimit: lineLimit + 2, font: .system(.body, design: .serif).italic(),
                               color: theme.colors.onSurface.opacity(0.9))
            }
            .padding(theme.spacing.xl)
            .background(
                BubbleShape(radius: theme.radii.xl, tail: 16)
                    .fill(theme.colors.surface)
                    .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
            )
            .overlay(BubbleShape(radius: theme.radii.xl, tail: 16).stroke(theme.colors.border, lineWidth: 1))
            .padding(.bottom, 16)

            HStack(spacing: theme.spacing.md) {
                KitoAvatar(reviewer: review.author, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    nameLine
                    if let subtitle = review.author.subtitle {
                        Text(subtitle).font(theme.typography.caption).foregroundStyle(theme.colors.onSurface.opacity(0.55))
                    }
                }
            }
            .padding(.leading, theme.spacing.lg)
        }
    }

    private var carousel: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            HStack {
                KitoStarRating(value: review.rating, size: .custom(13), tint: tint)
                Spacer()
                Text(relativeDate).font(theme.typography.caption).foregroundStyle(theme.colors.onSurface.opacity(0.5))
            }
            if let title = review.title {
                Text(title).font(theme.typography.bodyEmphasized.weight(.bold)).lineLimit(1).foregroundStyle(theme.colors.onSurface)
            }
            Text(review.body)
                .font(theme.typography.label)
                .foregroundStyle(theme.colors.onSurface.opacity(0.8))
                .lineLimit(lineLimit)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            Spacer(minLength: 0)
            if !review.photos.isEmpty { photoStrip(size: 48) }
            HStack(spacing: theme.spacing.sm) {
                KitoAvatar(reviewer: review.author, size: 30)
                nameLine
            }
        }
        .padding(theme.spacing.lg)
        .frame(width: 280, height: 280)
        .background(cardBackground)
    }

    // MARK: Pieces

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous)
            .fill(theme.colors.surface)
            .overlay(RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous).stroke(theme.colors.border.opacity(0.8), lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
    }

    private var nameLine: some View {
        HStack(spacing: 4) {
            Text(review.author.name)
                .font(theme.typography.bodyEmphasized.weight(.semibold))
                .foregroundStyle(theme.colors.onSurface)
                .lineLimit(1)
            if review.isVerified {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(theme.colors.success)
                    .accessibilityLabel("Verified")
            }
        }
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            if let title = review.title {
                Text(title).font(theme.typography.bodyEmphasized.weight(.bold)).foregroundStyle(theme.colors.onSurface)
            }
            ExpandableText(review.body, lineLimit: lineLimit, font: theme.typography.body, color: theme.colors.onSurface.opacity(0.85))
        }
    }

    private func photoStrip(size: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacing.sm) {
                ForEach(Array(review.photos.enumerated()), id: \.element.id) { index, photo in
                    Button { viewer = PhotoViewerItem(index: index) } label: {
                        KitoReviewPhotoView(photo: photo)
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: theme.radii.md, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: theme.radii.md, style: .continuous).stroke(theme.colors.border.opacity(0.6), lineWidth: 0.5))
                    }
                    .buttonStyle(KitoReviewPressStyle(scale: 0.94))
                    .accessibilityLabel(photo.caption ?? "Photo \(index + 1) of \(review.photos.count)")
                    .accessibilityHint("Opens the photo")
                }
            }
        }
        .scrollClipDisabled()
    }

    private var tags: some View {
        KitoFlowLayout(spacing: 6) {
            ForEach(review.tags, id: \.self) { tag in
                Text(tag)
                    .font(theme.typography.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .foregroundStyle(theme.colors.onSurface.opacity(0.8))
                    .background(Capsule().fill(theme.colors.surfaceMuted))
            }
        }
    }

    private func ownerReply(_ reply: KitoOwnerReply) -> some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            Capsule().fill(accent.opacity(0.7)).frame(width: 3)
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "arrowshape.turn.up.backward.fill").font(.caption2)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Response from \(reply.name)").font(theme.typography.caption.weight(.bold))
                        Text(KitoReviewDate.relative(reply.date)).font(theme.typography.caption)
                            .foregroundStyle(theme.colors.onSurface.opacity(0.5))
                    }
                }
                .foregroundStyle(theme.colors.onSurface)
                ExpandableText(reply.body, lineLimit: 3, font: theme.typography.label, color: theme.colors.onSurface.opacity(0.8))
            }
        }
        .padding(theme.spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).fill(theme.colors.surfaceMuted))
        .accessibilityElement(children: .combine)
    }

    private var votes: some View {
        HStack(spacing: theme.spacing.sm) {
            Text("Helpful?").font(theme.typography.caption).foregroundStyle(theme.colors.onSurface.opacity(0.55))
            VoteButton(title: "Yes", systemImage: "hand.thumbsup", count: tally.helpful, isOn: tally.vote == .helpful, accent: accent) { vote(.helpful) }
            VoteButton(title: "No", systemImage: "hand.thumbsdown", count: tally.notHelpful, isOn: tally.vote == .notHelpful, accent: accent) { vote(.notHelpful) }
            Spacer(minLength: 0)
        }
    }

    private var reportMenu: some View {
        Menu {
            Section("Report this review") {
                ForEach(KitoReportReason.allCases) { reason in
                    Button(reason.rawValue) {
                        withAnimation(.spring(duration: 0.4, bounce: 0.3)) { reported = reason }
                        onReport?(reason)
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(theme.colors.onSurface.opacity(0.6))
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .accessibilityLabel("More options")
    }

    private func reportedNote(_ reason: KitoReportReason) -> some View {
        Label("Reported as “\(reason.rawValue.lowercased())”. Thanks for letting us know.", systemImage: "flag.fill")
            .font(theme.typography.caption.weight(.semibold))
            .foregroundStyle(theme.colors.danger)
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func vote(_ vote: KitoHelpfulVote) {
        withAnimation(.spring(duration: 0.35, bounce: 0.4)) { tally.toggle(vote) }
        onVote?(tally.vote)
    }
}

// MARK: - Vote button

private struct VoteButton: View {
    let title: String
    let systemImage: String
    let count: Int
    let isOn: Bool
    let accent: Color
    let action: () -> Void

    @State private var taps = 0
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Bounce {
        var scale: CGFloat = 1
        var angle: Double = 0
        var lift: CGFloat = 0
        var plusOpacity: Double = 0
    }

    var body: some View {
        Button {
            if !isOn { taps += 1 }
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isOn ? "\(systemImage).fill" : systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .keyframeAnimator(initialValue: Bounce(), trigger: reduceMotion ? 0 : taps) { icon, bounce in
                        icon
                            .scaleEffect(bounce.scale)
                            .rotationEffect(.degrees(bounce.angle), anchor: .bottomLeading)
                            .overlay(alignment: .top) {
                                Text("+1")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .foregroundStyle(accent)
                                    .offset(y: -8 - bounce.lift)
                                    .opacity(bounce.plusOpacity)
                                    .fixedSize()
                            }
                    } keyframes: { _ in
                        KeyframeTrack(\.scale) {
                            SpringKeyframe(1.45, duration: 0.14, spring: .snappy)
                            SpringKeyframe(1, duration: 0.4, spring: .bouncy)
                        }
                        KeyframeTrack(\.angle) {
                            CubicKeyframe(-22, duration: 0.14)
                            CubicKeyframe(8, duration: 0.14)
                            SpringKeyframe(0, duration: 0.3)
                        }
                        KeyframeTrack(\.lift) {
                            CubicKeyframe(18, duration: 0.6)
                        }
                        KeyframeTrack(\.plusOpacity) {
                            LinearKeyframe(1, duration: 0.08)
                            LinearKeyframe(1, duration: 0.25)
                            CubicKeyframe(0, duration: 0.25)
                        }
                    }
                Text("\(title) · \(count)")
                    .font(theme.typography.caption.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize()
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(count)))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isOn ? theme.colors.surface : theme.colors.onSurface.opacity(0.8))
            .background(Capsule().fill(isOn ? accent : theme.colors.surfaceMuted))
            .contentShape(Capsule())
        }
        .buttonStyle(KitoReviewPressStyle(scale: 0.92))
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        .accessibilityLabel("\(title == "Yes" ? "Helpful" : "Not helpful"), \(count)")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Expandable text

/// Text clipped to `lineLimit` lines with a "more" / "less" toggle when it doesn't fit.
struct ExpandableText: View {
    let text: String
    let lineLimit: Int
    let font: Font
    let color: Color

    @State private var expanded = false
    @State private var fullHeight: CGFloat = 0
    @State private var limitedHeight: CGFloat = 0
    @Environment(\.kitoTheme) private var theme

    init(_ text: String, lineLimit: Int, font: Font, color: Color) {
        self.text = text
        self.lineLimit = lineLimit
        self.font = font
        self.color = color
    }

    private var isTruncated: Bool { fullHeight > limitedHeight + 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(font)
                .foregroundStyle(color)
                .lineLimit(expanded ? nil : lineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    // Measure the text at the limit and in full, at the same width.
                    ZStack {
                        Text(text).font(font).lineLimit(lineLimit).fixedSize(horizontal: false, vertical: true)
                            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { limitedHeight = $0 }
                        Text(text).font(font).fixedSize(horizontal: false, vertical: true)
                            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { fullHeight = $0 }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .hidden()
                }
            if isTruncated {
                Button {
                    withAnimation(.spring(duration: 0.4, bounce: 0.15)) { expanded.toggle() }
                } label: {
                    HStack(spacing: 3) {
                        Text(expanded ? "Less" : "More")
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                    .font(theme.typography.label.weight(.bold))
                    .foregroundStyle(theme.colors.onSurface)
                    .underline()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(expanded ? "Show less" : "Read more")
            }
        }
    }
}

// MARK: - Flow layout

/// Lays chips out left to right, wrapping onto new lines.
struct KitoFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: - Bubble

/// A rounded rectangle with a small tail at the bottom-left.
struct BubbleShape: Shape {
    var radius: CGFloat
    var tail: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
        path.addRoundedRect(in: body, cornerSize: CGSize(width: radius, height: radius), style: .continuous)
        let start = CGPoint(x: body.minX + radius + 10, y: body.maxY - 0.5)
        path.move(to: start)
        path.addQuadCurve(to: CGPoint(x: start.x + tail * 0.2, y: body.maxY + tail), control: CGPoint(x: start.x + 2, y: body.maxY + tail * 0.6))
        path.addQuadCurve(to: CGPoint(x: start.x + tail * 1.6, y: body.maxY - 0.5), control: CGPoint(x: start.x + tail * 0.7, y: body.maxY + tail * 0.4))
        path.closeSubpath()
        return path
    }
}

// MARK: - Photo viewer

struct PhotoViewerItem: Identifiable {
    let index: Int
    var id: Int { index }
}

/// Full-screen paging viewer with pinch to zoom.
struct KitoPhotoViewer: View {
    let photos: [KitoReviewPhoto]
    @State var index: Int
    @State private var zoom: CGFloat = 1
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { offset, photo in
                    KitoReviewPhotoView(photo: photo, contentMode: .fit)
                        .scaleEffect(offset == index ? zoom : 1)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { zoom = min(max($0.magnification, 1), 4) }
                                .onEnded { _ in withAnimation(.spring(duration: 0.35, bounce: 0.3)) { zoom = 1 } }
                        )
                        .tag(offset)
                        .accessibilityLabel(photo.caption ?? "Photo \(offset + 1)")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                HStack {
                    Text("\(index + 1) of \(photos.count)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .contentTransition(.numericText(value: Double(index)))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: Capsule())
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.headline)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Close")
                }
                Spacer()
                if let caption = photos[safe: index]?.caption {
                    Text(caption)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.opacity)
                        .id(index)
                }
            }
            .foregroundStyle(.white)
            .padding()
            .animation(.snappy, value: index)
        }
        .environment(\.colorScheme, .dark)
    }
}
