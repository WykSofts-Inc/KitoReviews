//
//  KitoRatingInputs.swift
//  KitoReviews
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

// MARK: - Emoji

/// Five faces from 😡 to 😍. The chosen one grows and wobbles; the rest fade to grey.
///
/// ```swift
/// @State private var mood: KitoRatingMood?
/// KitoEmojiRating(selection: $mood)
/// ```
public struct KitoEmojiRating: View {
    @Binding private var selection: KitoRatingMood?
    private let showsLabel: Bool
    private let tint: Color?

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(selection: Binding<KitoRatingMood?>, showsLabel: Bool = true, tint: Color? = nil) {
        _selection = selection
        self.showsLabel = showsLabel
        self.tint = tint
    }

    struct Wobble {
        var scale: CGFloat = 1
        var angle: Double = 0
        var lift: CGFloat = 0
    }

    public var body: some View {
        VStack(spacing: theme.spacing.md) {
            HStack(spacing: 0) {
                ForEach(KitoRatingMood.allCases, id: \.self) { mood in
                    let isSelected = selection == mood
                    Button {
                        withAnimation(.spring(duration: 0.4, bounce: 0.45)) { selection = isSelected ? nil : mood }
                    } label: {
                        Text(mood.emoji)
                            .font(.system(size: 38))
                            .keyframeAnimator(initialValue: Wobble(), trigger: reduceMotion ? nil : (isSelected ? selection : nil)) { face, wobble in
                                face.scaleEffect(wobble.scale).rotationEffect(.degrees(wobble.angle)).offset(y: wobble.lift)
                            } keyframes: { _ in
                                KeyframeTrack(\.scale) {
                                    SpringKeyframe(1.3, duration: 0.14)
                                    SpringKeyframe(1, duration: 0.45, spring: .bouncy)
                                }
                                KeyframeTrack(\.angle) {
                                    CubicKeyframe(-16, duration: 0.1)
                                    CubicKeyframe(12, duration: 0.12)
                                    CubicKeyframe(-6, duration: 0.1)
                                    SpringKeyframe(0, duration: 0.3)
                                }
                                KeyframeTrack(\.lift) {
                                    CubicKeyframe(-10, duration: 0.16)
                                    SpringKeyframe(0, duration: 0.4, spring: .bouncy)
                                }
                            }
                            .scaleEffect(isSelected ? 1.3 : (selection == nil ? 1 : 0.86))
                            .grayscale(selection == nil || isSelected ? 0 : 1)
                            .opacity(selection == nil || isSelected ? 1 : 0.45)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background {
                                if isSelected {
                                    Circle().fill((tint ?? theme.colors.warning).opacity(0.18)).frame(width: 64, height: 64)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            if showsLabel {
                Text(selection?.title ?? "How was it?")
                    .font(theme.typography.bodyEmphasized.weight(.bold))
                    .foregroundStyle(theme.colors.onSurface.opacity(selection == nil ? 0.5 : 1))
                    .id(selection?.title ?? "")
                    .transition(reduceMotion ? .opacity : .push(from: .bottom))
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: selection)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("How was it?")
        .accessibilityValue(selection.map { "\($0.title), \($0.rawValue) out of 5" } ?? "Not rated")
        .accessibilityAdjustableAction { direction in
            let current = selection?.rawValue ?? 0
            switch direction {
            case .increment: selection = KitoRatingMood(rawValue: min(current + 1, 5))
            case .decrement: selection = current <= 1 ? nil : KitoRatingMood(rawValue: current - 1)
            @unknown default: break
            }
        }
    }
}

// MARK: - Thumbs

/// A thumbs up or down.
public enum KitoThumb: Equatable, Sendable {
    case up, down
}

/// Two round buttons for a quick yes / no rating. The chosen thumb fills, flips and bursts.
///
/// ```swift
/// KitoThumbsRating(selection: $thumb, upCount: 128, downCount: 9)
/// ```
public struct KitoThumbsRating: View {
    @Binding private var selection: KitoThumb?
    private let upCount: Int?
    private let downCount: Int?
    private let tint: Color?

    @Environment(\.kitoTheme) private var theme

    /// Counts, when given, are everyone else's votes; the user's vote is added on top.
    public init(selection: Binding<KitoThumb?>, upCount: Int? = nil, downCount: Int? = nil, tint: Color? = nil) {
        _selection = selection
        self.upCount = upCount
        self.downCount = downCount
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: theme.spacing.lg) {
            thumb(.up, count: upCount.map { $0 + (selection == .up ? 1 : 0) })
            thumb(.down, count: downCount.map { $0 + (selection == .down ? 1 : 0) })
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: selection)
    }

    private func thumb(_ kind: KitoThumb, count: Int?) -> some View {
        ThumbButton(kind: kind, isSelected: selection == kind, count: count,
                    color: tint ?? (kind == .up ? theme.colors.success : theme.colors.danger)) {
            withAnimation(.spring(duration: 0.4, bounce: 0.4)) { selection = selection == kind ? nil : kind }
        }
    }
}

private struct ThumbButton: View {
    let kind: KitoThumb
    let isSelected: Bool
    let count: Int?
    let color: Color
    let action: () -> Void

    @State private var taps = 0
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Flip {
        var scale: CGFloat = 1
        var angle: Double = 0
        var ring: CGFloat = 0.8
        var ringOpacity: Double = 0
    }

    var body: some View {
        Button {
            if !isSelected { taps += 1 }
            action()
        } label: {
            VStack(spacing: theme.spacing.sm) {
                ZStack {
                    Circle().fill(isSelected ? color : theme.colors.surfaceMuted)
                    Image(systemName: kind == .up ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(isSelected ? theme.colors.surface : theme.colors.onSurface.opacity(0.55))
                }
                .frame(width: 72, height: 72)
                .keyframeAnimator(initialValue: Flip(), trigger: reduceMotion ? 0 : taps) { content, flip in
                    content
                        .background {
                            Circle().stroke(color, lineWidth: 3).scaleEffect(flip.ring).opacity(flip.ringOpacity)
                        }
                        .scaleEffect(flip.scale)
                        .rotationEffect(.degrees(flip.angle))
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        SpringKeyframe(0.8, duration: 0.1)
                        SpringKeyframe(1.18, duration: 0.16)
                        SpringKeyframe(1, duration: 0.4, spring: .bouncy)
                    }
                    KeyframeTrack(\.angle) {
                        CubicKeyframe(kind == .up ? -24 : 24, duration: 0.16)
                        SpringKeyframe(0, duration: 0.45, spring: .bouncy)
                    }
                    KeyframeTrack(\.ring) {
                        LinearKeyframe(0.8, duration: 0.08)
                        CubicKeyframe(1.6, duration: 0.45)
                    }
                    KeyframeTrack(\.ringOpacity) {
                        LinearKeyframe(0.7, duration: 0.08)
                        CubicKeyframe(0, duration: 0.45)
                    }
                }
                if let count {
                    Text(count.formatted())
                        .font(theme.typography.label.weight(.bold))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(count)))
                        .foregroundStyle(isSelected ? color : theme.colors.onSurface.opacity(0.6))
                }
            }
        }
        .buttonStyle(KitoReviewPressStyle(scale: 0.92))
        .accessibilityLabel(kind == .up ? "Thumbs up" : "Thumbs down")
        .accessibilityValue(count.map { "\($0)" } ?? "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - NPS

/// "How likely are you to recommend us?" from 0 to 10, coloured red through amber to green.
///
/// ```swift
/// KitoNPSScale(score: $score)
/// KitoNPSCategory(score: 9)    // .promoter
/// ```
public struct KitoNPSScale: View {
    @Binding private var score: Int?
    private let lowLabel: String
    private let highLabel: String

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(score: Binding<Int?>, lowLabel: String = "Not likely", highLabel: String = "Very likely") {
        _score = score
        self.lowLabel = lowLabel
        self.highLabel = highLabel
    }

    private var gradient: LinearGradient {
        LinearGradient(colors: [theme.colors.danger, theme.colors.warning, theme.colors.success], startPoint: .leading, endPoint: .trailing)
    }

    public var body: some View {
        VStack(spacing: theme.spacing.sm) {
            GeometryReader { proxy in
                let spacing: CGFloat = 4
                let cell = max((proxy.size.width - spacing * 10) / 11, 1)
                HStack(spacing: spacing) {
                    ForEach(0...10, id: \.self) { value in
                        let isSelected = score == value
                        Button {
                            withAnimation(.spring(duration: 0.35, bounce: 0.45)) { score = isSelected ? nil : value }
                        } label: {
                            Text("\(value)")
                                .font(.system(size: 15, weight: isSelected ? .heavy : .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(isSelected ? Color.white : theme.colors.onSurface.opacity(0.8))
                                .frame(width: cell, height: 44)
                                .background {
                                    gradient
                                        .frame(width: proxy.size.width)
                                        .offset(x: proxy.size.width / 2 - (CGFloat(value) * (cell + spacing) + cell / 2))
                                        .opacity(isSelected ? 1 : (score == nil ? 0.3 : 0.16))
                                }
                                .clipShape(RoundedRectangle(cornerRadius: theme.radii.sm + 2, style: .continuous))
                                .shadow(color: .black.opacity(isSelected ? 0.18 : 0), radius: 6, y: 3)
                                .scaleEffect(isSelected && !reduceMotion ? 1.16 : 1)
                                .offset(y: isSelected && !reduceMotion ? -4 : 0)
                                .zIndex(isSelected ? 1 : 0)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHidden(true)
                    }
                }
            }
            .frame(height: 52)
            HStack {
                Text(lowLabel)
                Spacer()
                if let score {
                    Text(KitoNPSCategory(score: score).title)
                        .font(theme.typography.caption.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(theme.colors.surfaceMuted))
                        .transition(.scale.combined(with: .opacity))
                        .id(KitoNPSCategory(score: score))
                }
                Spacer()
                Text(highLabel)
            }
            .font(theme.typography.caption)
            .foregroundStyle(theme.colors.onSurface.opacity(0.6))
        }
        .sensoryFeedback(.selection, trigger: score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Likelihood to recommend, 0 \(lowLabel.lowercased()), 10 \(highLabel.lowercased())")
        .accessibilityValue(score.map { "\($0) out of 10" } ?? "Not rated")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: score = min((score ?? -1) + 1, 10)
            case .decrement: score = (score ?? 0) <= 0 ? nil : (score ?? 0) - 1
            @unknown default: break
            }
        }
    }
}

// MARK: - Slider

/// A chunky slider with a floating value bubble and a face that follows the value.
///
/// ```swift
/// KitoSliderRating(value: $spice, in: 0...10, step: 1)
/// ```
public struct KitoSliderRating: View {
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let step: Double
    private let showsEmoji: Bool
    private let tint: Color?

    @State private var isDragging = false
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

    public init(value: Binding<Double>, in range: ClosedRange<Double> = 0...10, step: Double = 1, showsEmoji: Bool = true, tint: Color? = nil) {
        _value = value
        self.range = range.lowerBound < range.upperBound ? range : range.lowerBound...(range.lowerBound + 1)
        self.step = max(step, 0.01)
        self.showsEmoji = showsEmoji
        self.tint = tint
    }

    private var fraction: Double { KitoSliderMath.fraction(of: value, in: range) }
    private var fill: AnyShapeStyle {
        if let tint { return AnyShapeStyle(tint) }
        return AnyShapeStyle(LinearGradient(colors: [theme.colors.danger, theme.colors.warning, theme.colors.success], startPoint: .leading, endPoint: .trailing))
    }

    public var body: some View {
        GeometryReader { proxy in
            let thumb: CGFloat = 30
            let usable = max(proxy.size.width - thumb, 1)
            let x = thumb / 2 + usable * fraction
            ZStack(alignment: .leading) {
                Capsule().fill(theme.colors.surfaceMuted).frame(height: 10)
                Rectangle().fill(fill)
                    .frame(width: proxy.size.width, height: 10)
                    .mask(alignment: .leading) { Capsule().frame(width: max(x, 10)) }
                    .clipShape(Capsule())
                Circle()
                    .fill(Color.white)
                    .frame(width: thumb, height: thumb)
                    .shadow(color: .black.opacity(0.22), radius: isDragging ? 8 : 4, y: 2)
                    .overlay(Circle().stroke(theme.colors.border, lineWidth: 0.5))
                    .scaleEffect(isDragging && !reduceMotion ? 1.12 : 1)
                    .offset(x: x - thumb / 2)
                bubble
                    .position(x: x, y: -18)
            }
            .frame(height: thumb)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        if !isDragging { withAnimation(.spring(duration: 0.25)) { isDragging = true } }
                        let local = layoutDirection == .rightToLeft ? proxy.size.width - drag.location.x : drag.location.x
                        let new = KitoSliderMath.value(atX: local - thumb / 2, width: usable, range: range, step: step)
                        if new != value { value = new }
                    }
                    .onEnded { _ in withAnimation(.spring(duration: 0.35, bounce: 0.4)) { isDragging = false } }
            )
        }
        .frame(height: 78)
        .animation(reduceMotion ? nil : .spring(duration: 0.25, bounce: 0.2), value: value)
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating")
        .accessibilityValue("\(KitoRatingMath.formatted(value)) out of \(KitoRatingMath.formatted(range.upperBound))")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + step, range.upperBound)
            case .decrement: value = max(value - step, range.lowerBound)
            @unknown default: break
            }
        }
    }

    private var bubble: some View {
        HStack(spacing: 4) {
            if showsEmoji, let mood = KitoSliderMath.mood(forFraction: fraction) {
                Text(mood.emoji).font(.system(size: 16))
                    .id(mood)
                    .transition(.scale.combined(with: .opacity))
            }
            Text(KitoRatingMath.formatted(value))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: value))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(theme.colors.surface)
        .background(Capsule().fill(theme.colors.onSurface))
        .fixedSize()
        .scaleEffect(isDragging && !reduceMotion ? 1.12 : 1, anchor: .bottom)
    }
}

/// Maths for `KitoSliderRating`.
enum KitoSliderMath {
    static func fraction(of value: Double, in range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(max((value - range.lowerBound) / span, 0), 1)
    }

    static func value(atX x: Double, width: Double, range: ClosedRange<Double>, step: Double) -> Double {
        guard width > 0 else { return range.lowerBound }
        let raw = range.lowerBound + min(max(x / width, 0), 1) * (range.upperBound - range.lowerBound)
        let stepped = step > 0 ? range.lowerBound + ((raw - range.lowerBound) / step).rounded() * step : raw
        return min(max(stepped, range.lowerBound), range.upperBound)
    }

    /// The face for a position along the slider, 0 = terrible, 1 = amazing.
    static func mood(forFraction fraction: Double) -> KitoRatingMood? {
        KitoRatingMood(rating: 1 + min(max(fraction, 0), 1) * 4)
    }
}
