//
//  KitoStarRating.swift
//  KitoReviews
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// The symbol a rating is drawn with.
public struct KitoRatingSymbol: Equatable, Sendable {
    /// SF Symbol for a filled step.
    public var filled: String
    /// SF Symbol for an empty step; `nil` draws `filled` in a muted colour.
    public var empty: String?
    /// What VoiceOver calls the steps: "4 out of 5 stars".
    public var noun: String
    var palette: Palette

    enum Palette: Sendable { case gold, love, heat, accent }

    public init(filled: String, empty: String? = nil, noun: String = "stars") {
        self.init(filled: filled, empty: empty, noun: noun, palette: .gold)
    }

    init(filled: String, empty: String?, noun: String, palette: Palette) {
        self.filled = filled
        self.empty = empty
        self.noun = noun
        self.palette = palette
    }

    public static let star = KitoRatingSymbol(filled: "star.fill", empty: nil, noun: "stars", palette: .gold)
    public static let heart = KitoRatingSymbol(filled: "heart.fill", empty: nil, noun: "hearts", palette: .love)
    public static let flame = KitoRatingSymbol(filled: "flame.fill", empty: nil, noun: "flames", palette: .heat)
    public static let thumb = KitoRatingSymbol(filled: "hand.thumbsup.fill", empty: nil, noun: "thumbs up", palette: .accent)

    func fill(_ theme: KitoTheme, tint: Color?) -> AnyShapeStyle {
        if let tint { return AnyShapeStyle(tint) }
        switch palette {
        case .gold: return AnyShapeStyle(theme.colors.warning)
        case .love: return AnyShapeStyle(theme.colors.danger)
        case .heat: return AnyShapeStyle(LinearGradient(colors: [theme.colors.danger, theme.colors.warning], startPoint: .top, endPoint: .bottom))
        case .accent: return AnyShapeStyle(theme.colors.primary)
        }
    }

    func solid(_ theme: KitoTheme, tint: Color?) -> Color {
        if let tint { return tint }
        switch palette {
        case .gold: return theme.colors.warning
        case .love, .heat: return theme.colors.danger
        case .accent: return theme.colors.primary
        }
    }
}

/// How big each symbol is.
public enum KitoRatingSize: Equatable, Sendable {
    case small, medium, large
    case custom(CGFloat)

    var points: CGFloat {
        switch self {
        case .small: 14
        case .medium: 22
        case .large: 34
        case .custom(let points): max(points, 6)
        }
    }
}

/// A row of stars (or hearts, flames, thumbs) that shows a rating and, given a binding, sets one.
///
/// Tap a star or drag across the row; each star pops as it fills, with a haptic tick.
/// Display values fill partially, so 4.3 shows the fifth star 30% full.
///
/// ```swift
/// KitoStarRating(rating: $stars)                      // input
/// KitoStarRating(value: 4.3, size: .small)            // display
/// KitoStarRating(rating: $love, step: .half, symbol: .heart)
/// ```
public struct KitoStarRating: View {
    private let binding: Binding<Double>?
    private let fixedValue: Double
    private let maximum: Int
    private let step: KitoRatingStep
    private let size: KitoRatingSize
    private let symbol: KitoRatingSymbol
    private let tint: Color?

    @State private var pops: [Int]
    @State private var delays: [Double]
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.isEnabled) private var isEnabled

    /// An input bound to `rating`, from 0 (unset) to `maximum`.
    public init(rating: Binding<Double>, maximum: Int = 5, step: KitoRatingStep = .whole, size: KitoRatingSize = .large,
                symbol: KitoRatingSymbol = .star, tint: Color? = nil) {
        self.binding = rating
        self.fixedValue = 0
        self.maximum = max(maximum, 1)
        self.step = step
        self.size = size
        self.symbol = symbol
        self.tint = tint
        _pops = State(initialValue: Array(repeating: 0, count: max(maximum, 1)))
        _delays = State(initialValue: Array(repeating: 0, count: max(maximum, 1)))
    }

    /// A read-only rating; decimals fill partially.
    public init(value: Double, maximum: Int = 5, size: KitoRatingSize = .small, symbol: KitoRatingSymbol = .star, tint: Color? = nil) {
        self.binding = nil
        self.fixedValue = value
        self.maximum = max(maximum, 1)
        self.step = .whole
        self.size = size
        self.symbol = symbol
        self.tint = tint
        _pops = State(initialValue: Array(repeating: 0, count: max(maximum, 1)))
        _delays = State(initialValue: Array(repeating: 0, count: max(maximum, 1)))
    }

    private var value: Double { binding?.wrappedValue ?? fixedValue }
    private var isInteractive: Bool { binding != nil && isEnabled }
    private var spacing: CGFloat { size.points * (size.points < 18 ? 0.12 : 0.2) }

    public var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<maximum, id: \.self) { index in
                RatingSymbolCell(
                    symbol: symbol,
                    fraction: KitoRatingMath.fillFraction(at: index, rating: value),
                    size: size.points,
                    fill: symbol.fill(theme, tint: tint),
                    ring: symbol.solid(theme, tint: tint),
                    track: theme.colors.onSurface.opacity(0.13),
                    pop: pops[safe: index] ?? 0,
                    delay: delays[safe: index] ?? 0,
                    animates: !reduceMotion
                )
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.3), value: value)
        .overlay {
            if isInteractive {
                GeometryReader { proxy in
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in set(x: drag.location.x, width: proxy.size.width) }
                        )
                }
            }
        }
        .sensoryFeedback(trigger: value) { old, new in
            guard isInteractive else { return nil }
            return new >= Double(maximum) && old < Double(maximum) ? .impact(weight: .medium, intensity: 0.9) : .selection
        }
        .onChange(of: value) { old, new in popStars(from: old, to: new) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating")
        .accessibilityValue(KitoRatingMath.accessibilityValue(value, maximum: maximum, noun: symbol.noun))
        .kitoIf(isInteractive) { view in
            view.accessibilityAdjustableAction { direction in
                guard let binding else { return }
                switch direction {
                case .increment: binding.wrappedValue = min(binding.wrappedValue + step.increment, Double(maximum))
                case .decrement: binding.wrappedValue = max(binding.wrappedValue - step.increment, 0)
                @unknown default: break
                }
            }
        }
    }

    private func set(x: CGFloat, width: CGFloat) {
        guard let binding else { return }
        let local = layoutDirection == .rightToLeft ? width - x : x
        let new = KitoRatingMath.rating(atX: local, width: width, count: maximum, step: step)
        if new != binding.wrappedValue { binding.wrappedValue = new }
    }

    /// Pops each star that just filled, staggered from the lowest.
    private func popStars(from old: Double, to new: Double) {
        guard binding != nil, !reduceMotion, new > old else { return }
        let first = Int(old.rounded(.up))
        let last = Int(new.rounded(.up)) - 1
        let range = first <= last ? first...last : last...last
        for (order, index) in range.enumerated() where pops.indices.contains(index) {
            delays[index] = Double(order) * 0.06
            pops[index] += 1
        }
    }
}

private struct RatingSymbolCell: View {
    let symbol: KitoRatingSymbol
    let fraction: Double
    let size: CGFloat
    let fill: AnyShapeStyle
    let ring: Color
    let track: Color
    let pop: Int
    let delay: Double
    let animates: Bool

    struct Pop {
        var scale: CGFloat = 1
        var angle: Double = 0
        var ring: CGFloat = 0.4
        var ringOpacity: Double = 0
    }

    var body: some View {
        ZStack {
            Image(systemName: symbol.empty ?? symbol.filled)
                .resizable().scaledToFit()
                .foregroundStyle(track)
            Image(systemName: symbol.filled)
                .resizable().scaledToFit()
                .foregroundStyle(fill)
                .mask(alignment: .leading) {
                    GeometryReader { proxy in
                        Rectangle().frame(width: proxy.size.width * fraction)
                    }
                }
        }
        .frame(width: size, height: size)
        .keyframeAnimator(initialValue: Pop(), trigger: animates ? pop : 0) { content, pop in
            content
                .background {
                    Circle()
                        .stroke(ring, lineWidth: max(size * 0.06, 1))
                        .scaleEffect(pop.ring)
                        .opacity(pop.ringOpacity)
                }
                .scaleEffect(pop.scale)
                .rotationEffect(.degrees(pop.angle))
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                LinearKeyframe(1, duration: max(delay, 0.001))
                SpringKeyframe(1.38, duration: 0.14, spring: .snappy)
                SpringKeyframe(0.92, duration: 0.12)
                SpringKeyframe(1, duration: 0.32, spring: .bouncy)
            }
            KeyframeTrack(\.angle) {
                LinearKeyframe(0, duration: max(delay, 0.001))
                CubicKeyframe(-14, duration: 0.1)
                CubicKeyframe(9, duration: 0.12)
                SpringKeyframe(0, duration: 0.3)
            }
            KeyframeTrack(\.ring) {
                LinearKeyframe(0.4, duration: max(delay, 0.001))
                CubicKeyframe(1.7, duration: 0.42)
            }
            KeyframeTrack(\.ringOpacity) {
                LinearKeyframe(0, duration: max(delay, 0.001))
                LinearKeyframe(0.55, duration: 0.06)
                CubicKeyframe(0, duration: 0.36)
            }
        }
    }
}

/// A compact read-only rating: "★ 4.8 (2.1k)".
///
/// ```swift
/// KitoCompactRating(value: 4.8, count: 2_140)
/// ```
public struct KitoCompactRating: View {
    private let value: Double
    private let count: Int?
    private let symbol: KitoRatingSymbol
    private let tint: Color?
    @Environment(\.kitoTheme) private var theme

    public init(value: Double, count: Int? = nil, symbol: KitoRatingSymbol = .star, tint: Color? = nil) {
        self.value = value
        self.count = count
        self.symbol = symbol
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol.filled)
                .font(.caption.weight(.bold))
                .foregroundStyle(symbol.fill(theme, tint: tint))
            Text(KitoRatingMath.formatted(value))
                .font(theme.typography.label.weight(.bold))
                .foregroundStyle(theme.colors.onSurface)
                .monospacedDigit()
            if let count {
                Text("(\(KitoRatingMath.compactCount(count)))")
                    .font(theme.typography.label)
                    .foregroundStyle(theme.colors.onSurface.opacity(0.55))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rated \(KitoRatingMath.accessibilityValue(value, noun: symbol.noun))"
                            + (count.map { ", \($0.formatted()) ratings" } ?? ""))
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
