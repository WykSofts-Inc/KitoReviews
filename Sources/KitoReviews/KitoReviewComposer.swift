//
//  KitoReviewComposer.swift
//  KitoReviews
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import PhotosUI
import KitoCore

/// What someone wrote in `KitoReviewComposer`.
public struct KitoReviewDraft: Equatable {
    public var rating: Int
    public var tags: [String]
    public var text: String
    public var photos: [UIImage]
    public var isAnonymous: Bool

    public init(rating: Int = 0, tags: [String] = [], text: String = "", photos: [UIImage] = [], isAnonymous: Bool = false) {
        self.rating = rating
        self.tags = tags
        self.text = text
        self.photos = photos
        self.isAnonymous = isAnonymous
    }

    /// The text without leading or trailing whitespace.
    public var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    public func guidance(minimum: Int, maximum: Int) -> KitoTextGuidance {
        KitoTextGuidance(count: trimmedText.count, minimum: minimum, maximum: maximum)
    }

    /// Needs a rating; text is optional unless `requiresText`, but any text must fit the limits.
    public func canSubmit(minimum: Int, maximum: Int, requiresText: Bool) -> Bool {
        guard (1...5).contains(rating) else { return false }
        let guidance = guidance(minimum: minimum, maximum: maximum)
        if guidance == .empty { return !requiresText }
        return guidance.isAcceptable
    }

    /// Adds `tag`, or removes it if it's already there.
    public mutating func toggleTag(_ tag: String) {
        if let index = tags.firstIndex(of: tag) { tags.remove(at: index) } else { tags.append(tag) }
    }
}

/// A single-sheet review form: stars with a face that changes mood, quick tags, text with
/// length guidance, photos, an anonymous switch and a celebratory "thanks" once posted.
///
/// Present it in a sheet; Cancel and Done dismiss it.
///
/// ```swift
/// .sheet(isPresented: $writing) {
///     KitoReviewComposer(subject: "Mama Oliech Restaurant", authorName: "Wycliff N") { draft in
///         await api.post(draft)
///     }
/// }
/// ```
public struct KitoReviewComposer: View {
    private let subject: String?
    private let subtitle: String?
    private let customTags: [String]?
    private let minimumCharacters: Int
    private let maximumCharacters: Int
    private let requiresText: Bool
    private let maximumPhotos: Int
    private let allowsAnonymous: Bool
    private let authorName: String?
    private let tint: Color?
    private let onSubmit: (KitoReviewDraft) async -> Void

    @State private var draft: KitoReviewDraft
    @State private var rating: Double
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isPosting = false
    @State private var isDone = false
    @FocusState private var textFocused: Bool
    @Environment(\.kitoTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - subject: What's being reviewed, e.g. "Mama Oliech Restaurant".
    ///   - tags: Quick chips; `nil` offers praise for 4–5 stars and problems for 1–3.
    ///   - maximumPhotos: 0 hides the photo row.
    ///   - authorName: Shown as "Posting as …" and in the thank-you.
    public init(subject: String? = nil, subtitle: String? = nil, rating: Int = 0, tags: [String]? = nil,
                minimumCharacters: Int = 20, maximumCharacters: Int = 500, requiresText: Bool = false,
                maximumPhotos: Int = 5, allowsAnonymous: Bool = true, authorName: String? = nil, tint: Color? = nil,
                onSubmit: @escaping (KitoReviewDraft) async -> Void) {
        self.subject = subject
        self.subtitle = subtitle
        self.customTags = tags
        self.minimumCharacters = max(minimumCharacters, 0)
        self.maximumCharacters = max(maximumCharacters, max(minimumCharacters, 1))
        self.requiresText = requiresText
        self.maximumPhotos = max(maximumPhotos, 0)
        self.allowsAnonymous = allowsAnonymous
        self.authorName = authorName
        self.tint = tint
        self.onSubmit = onSubmit
        let start = min(max(rating, 0), 5)
        _draft = State(initialValue: KitoReviewDraft(rating: start))
        _rating = State(initialValue: Double(start))
    }

    private var accent: Color { tint ?? theme.colors.onSurface }
    private var mood: KitoRatingMood? { KitoRatingMood(rating: rating) }
    private var guidance: KitoTextGuidance { draft.guidance(minimum: minimumCharacters, maximum: maximumCharacters) }
    private var canSubmit: Bool { !isPosting && draft.canSubmit(minimum: minimumCharacters, maximum: maximumCharacters, requiresText: requiresText) }

    private var tags: [String] {
        if let customTags { return customTags }
        guard let mood else { return [] }
        return mood.rawValue >= 4
            ? ["Great value", "Friendly staff", "Clean", "Fast service", "Great location", "Would return"]
            : ["Too slow", "Overpriced", "Not clean", "Rude staff", "Not as described", "Noisy"]
    }

    public var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            if isDone {
                ComposerSuccess(name: draft.isAnonymous ? nil : authorName, accent: accent) { dismiss() }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                form.transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.5, bounce: 0.25), value: isDone)
        .onChange(of: rating) { _, new in
            draft.rating = Int(new)
            let allowed = Set(tags)
            draft.tags.removeAll { !allowed.contains($0) }
        }
        .onChange(of: pickerItems) { _, items in Task { await loadPhotos(items) } }
    }

    // MARK: Form

    private var form: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.onSurface)
                Spacer()
                Text("Write a review").font(theme.typography.bodyEmphasized.weight(.bold)).foregroundStyle(theme.colors.onSurface)
                Spacer()
                Button("Cancel") {}.font(theme.typography.body).hidden().accessibilityHidden(true)
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.vertical, theme.spacing.md)

            ScrollView {
                VStack(spacing: theme.spacing.xl) {
                    ratingBlock
                    if !tags.isEmpty {
                        tagBlock.transition(.move(edge: .top).combined(with: .opacity))
                    }
                    textBlock
                    if maximumPhotos > 0 { photoBlock }
                    if allowsAnonymous { anonymousBlock }
                }
                .padding(.horizontal, theme.spacing.lg)
                .padding(.bottom, theme.spacing.xl)
                .animation(.spring(duration: 0.45, bounce: 0.25), value: mood)
            }
            .scrollDismissesKeyboard(.interactively)

            submitBar
        }
    }

    private var ratingBlock: some View {
        VStack(spacing: theme.spacing.md) {
            if let subject {
                VStack(spacing: 2) {
                    Text(subject).font(.title3.weight(.bold)).foregroundStyle(theme.colors.onSurface).multilineTextAlignment(.center)
                    if let subtitle {
                        Text(subtitle).font(theme.typography.label).foregroundStyle(theme.colors.onSurface.opacity(0.55))
                    }
                }
            }
            KitoMoodFace(mood: mood)
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text(mood?.title ?? "Tap a star to rate")
                .font(mood == nil ? theme.typography.body : .title2.weight(.bold))
                .foregroundStyle(theme.colors.onSurface.opacity(mood == nil ? 0.55 : 1))
                .contentTransition(.interpolate)
                .id(mood?.title ?? "none")
                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .push(from: .bottom), removal: .push(from: .bottom)))
                .animation(.spring(duration: 0.35, bounce: 0.3), value: mood)
                .accessibilityHidden(true)
            KitoStarRating(rating: $rating, size: .custom(40), tint: tint)
                .accessibilityLabel("Your rating")
        }
        .padding(.top, theme.spacing.sm)
    }

    private var tagBlock: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            sectionTitle((mood?.rawValue ?? 5) >= 4 ? "What did you love?" : "What went wrong?")
            KitoFlowLayout(spacing: theme.spacing.sm) {
                ForEach(tags, id: \.self) { tag in
                    KitoReviewChip(title: tag, systemImage: draft.tags.contains(tag) ? "checkmark" : nil,
                                   isSelected: draft.tags.contains(tag), accent: accent) {
                        draft.toggleTag(tag)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sensoryFeedback(.selection, trigger: draft.tags)
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            sectionTitle("Your review")
            ZStack(alignment: .topLeading) {
                if draft.text.isEmpty {
                    Text("What stood out? What could be better?")
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.onSurface.opacity(0.4))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .accessibilityHidden(true)
                }
                TextEditor(text: $draft.text)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.onSurface)
                    .scrollContentBackground(.hidden)
                    .focused($textFocused)
                    .frame(minHeight: 120)
                    .accessibilityLabel("Your review")
            }
            .padding(theme.spacing.sm)
            .background(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).fill(theme.colors.surface))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous)
                    .stroke(textFocused ? accent : theme.colors.border, lineWidth: textFocused ? 1.5 : 1)
            )
            .animation(.easeOut(duration: 0.2), value: textFocused)

            HStack(spacing: theme.spacing.sm) {
                GuidanceRing(progress: Double(draft.trimmedText.count) / Double(max(minimumCharacters, 1)), color: guidanceColor)
                    .frame(width: 16, height: 16)
                Text(guidance.message)
                    .font(theme.typography.caption.weight(.semibold))
                    .foregroundStyle(guidanceColor)
                    .contentTransition(.interpolate)
                Spacer()
                Text("\(draft.trimmedText.count)/\(maximumCharacters)")
                    .font(theme.typography.caption)
                    .monospacedDigit()
                    .foregroundStyle(theme.colors.onSurface.opacity(0.5))
            }
            .animation(.snappy, value: guidance)
            .accessibilityElement(children: .combine)
        }
    }

    private var guidanceColor: Color {
        switch guidance {
        case .empty: theme.colors.onSurface.opacity(0.5)
        case .tooShort: theme.colors.warning
        case .good: theme.colors.success
        case .tooLong: theme.colors.danger
        }
    }

    private var photoBlock: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            sectionTitle("Photos")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacing.sm) {
                    if draft.photos.count < maximumPhotos {
                        PhotosPicker(selection: $pickerItems, maxSelectionCount: maximumPhotos, matching: .images) {
                            VStack(spacing: 6) {
                                Image(systemName: "camera.fill").font(.system(size: 20, weight: .semibold))
                                Text(draft.photos.isEmpty ? "Add photos" : "Add more").font(theme.typography.caption.weight(.semibold))
                            }
                            .foregroundStyle(theme.colors.onSurface.opacity(0.7))
                            .frame(width: 86, height: 86)
                            .background(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).fill(theme.colors.surfaceMuted))
                            .overlay(
                                RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous)
                                    .strokeBorder(theme.colors.border, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            )
                        }
                        .accessibilityLabel("Add photos")
                    }
                    ForEach(Array(draft.photos.enumerated()), id: \.offset) { index, photo in
                        Image(uiImage: photo)
                            .resizable().scaledToFill()
                            .frame(width: 86, height: 86)
                            .clipShape(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    withAnimation(.spring(duration: 0.35, bounce: 0.3)) { removePhoto(at: index) }
                                } label: {
                                    Image(systemName: "xmark").font(.system(size: 10, weight: .heavy))
                                        .foregroundStyle(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(.black.opacity(0.6)))
                                }
                                .padding(5)
                                .accessibilityLabel("Remove photo \(index + 1)")
                            }
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
        .animation(.spring(duration: 0.4, bounce: 0.3), value: draft.photos.count)
    }

    private var anonymousBlock: some View {
        HStack(spacing: theme.spacing.md) {
            KitoAvatar(reviewer: KitoReviewer(authorName ?? "You"), size: 38, isAnonymous: draft.isAnonymous)
            VStack(alignment: .leading, spacing: 2) {
                Text("Post anonymously").font(theme.typography.bodyEmphasized).foregroundStyle(theme.colors.onSurface)
                Text(draft.isAnonymous ? "Shown as “Anonymous”" : "Posting as \(authorName.map { "“\($0)”" } ?? "you")")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.onSurface.opacity(0.55))
                    .contentTransition(.interpolate)
            }
            Spacer()
            Toggle("Post anonymously", isOn: $draft.isAnonymous.animation(.spring(duration: 0.35)))
                .labelsHidden()
                .tint(accent)
        }
        .padding(theme.spacing.md)
        .background(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).fill(theme.colors.surface))
    }

    private var submitBar: some View {
        Button {
            Task { await submit() }
        } label: {
            ZStack {
                if isPosting {
                    ProgressView().tint(theme.colors.surface)
                } else {
                    Text("Post review").font(theme.typography.button)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundStyle(theme.colors.surface)
            .background(Capsule().fill(accent.opacity(canSubmit || isPosting ? 1 : 0.3)))
            .contentShape(Capsule())
        }
        .buttonStyle(KitoReviewPressStyle())
        .disabled(!canSubmit)
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.md)
        .background(theme.colors.background)
        .animation(.snappy, value: canSubmit)
        .accessibilityHint(canSubmit ? "" : "Choose a rating first")
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(theme.typography.bodyEmphasized.weight(.bold)).foregroundStyle(theme.colors.onSurface)
    }

    // MARK: Actions

    private func submit() async {
        guard canSubmit else { return }
        textFocused = false
        isPosting = true
        var final = draft
        final.text = draft.trimmedText
        await onSubmit(final)
        isPosting = false
        isDone = true
    }

    private func removePhoto(at index: Int) {
        guard draft.photos.indices.contains(index) else { return }
        draft.photos.remove(at: index)
        if pickerItems.indices.contains(index) { pickerItems.remove(at: index) }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        for item in items.prefix(maximumPhotos) {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                images.append(image)
            }
        }
        withAnimation(.spring(duration: 0.4, bounce: 0.3)) { draft.photos = images }
    }
}

// MARK: - Guidance ring

private struct GuidanceRing: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .flipsForRightToLeftLayoutDirection(true) // Circle doesn't mirror but rotation does; keeps the start at the top in RTL
            if progress >= 1 {
                Image(systemName: "checkmark").font(.system(size: 7, weight: .black)).foregroundStyle(color)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: progress)
    }
}

// MARK: - Success

private struct ComposerSuccess: View {
    let name: String?
    let accent: Color
    let onDone: () -> Void

    @State private var shown = false
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            Spacer()
            ZStack {
                ForEach(0..<14, id: \.self) { index in
                    let angle = Double(index) / 14 * 2 * .pi
                    let colors = [theme.colors.warning, theme.colors.success, theme.colors.primary, theme.colors.danger]
                    Capsule()
                        .fill(colors[index % colors.count])
                        .frame(width: 6, height: index.isMultiple(of: 2) ? 14 : 9)
                        .rotationEffect(.radians(angle + .pi / 2))
                        .offset(x: cos(angle) * (shown ? 92 : 30), y: sin(angle) * (shown ? 92 : 30))
                        .opacity(shown ? 0 : 1)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.9).delay(0.15), value: shown)
                }
                Circle()
                    .fill(theme.colors.success)
                    .frame(width: 110, height: 110)
                    .scaleEffect(shown ? 1 : 0.3)
                    .shadow(color: theme.colors.success.opacity(0.4), radius: 20, y: 8)
                CheckShape()
                    .trim(from: 0, to: shown ? 1 : 0)
                    .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                    .frame(width: 46, height: 36)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.4).delay(0.25), value: shown)
            }
            .frame(height: 200)
            VStack(spacing: theme.spacing.xs) {
                Text(name.map { "Thanks, \($0.split(separator: " ").first.map(String.init) ?? $0)!" } ?? "Thanks for your review!")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.colors.onSurface)
                Text("Your review helps others choose well.")
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.onSurface.opacity(0.6))
            }
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)
            Spacer()
            Button(action: onDone) {
                Text("Done").font(theme.typography.button)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .foregroundStyle(theme.colors.surface)
                    .background(Capsule().fill(accent))
            }
            .buttonStyle(KitoReviewPressStyle())
            .padding(.horizontal, theme.spacing.lg)
            .padding(.bottom, theme.spacing.lg)
        }
        .sensoryFeedback(.success, trigger: shown)
        .onAppear {
            if reduceMotion { shown = true } else { withAnimation(.spring(duration: 0.6, bounce: 0.45)) { shown = true } }
        }
        .accessibilityElement(children: .contain)
    }
}

struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

// MARK: - Mood face

/// A drawn face whose mouth, eyes and brows morph between moods.
struct KitoMoodFace: View {
    let mood: KitoRatingMood?

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Wobble {
        var scale: CGFloat = 1
        var angle: Double = 0
    }

    private var smile: Double { mood?.smile ?? 0 }

    private var colors: [Color] {
        switch mood {
        case nil: [theme.colors.surfaceMuted, theme.colors.surfaceMuted]
        case .terrible: [theme.colors.danger, theme.colors.danger.opacity(0.8)]
        case .bad: [theme.colors.warning, theme.colors.danger]
        case .okay: [theme.colors.warning, theme.colors.warning.opacity(0.85)]
        case .good: [theme.colors.success.opacity(0.85), theme.colors.warning]
        case .amazing: [theme.colors.success, theme.colors.success.opacity(0.8)]
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let ink = mood == nil ? theme.colors.onSurface.opacity(0.35) : Color.black.opacity(0.75)
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().fill(.white.opacity(0.22)).frame(width: size * 0.5).offset(x: -size * 0.16, y: -size * 0.2).blur(radius: size * 0.08))
                    .clipShape(Circle())
                    .shadow(color: (colors.first ?? .clear).opacity(mood == nil ? 0 : 0.35), radius: size * 0.12, y: size * 0.06)
                HStack(spacing: size * 0.2) {
                    ForEach([-1.0, 1.0], id: \.self) { side in
                        VStack(spacing: size * 0.04) {
                            Capsule()
                                .fill(ink)
                                .frame(width: size * 0.17, height: size * 0.045)
                                .rotationEffect(.degrees(side * max(-smile, 0) * 24))
                                .opacity(smile < 0 ? 1 : 0)
                            Capsule()
                                .fill(ink)
                                .frame(width: size * 0.1, height: size * (smile > 0.9 ? 0.05 : 0.14))
                        }
                    }
                }
                .offset(y: -size * 0.1)
                MouthShape(smile: smile)
                    .stroke(ink, style: StrokeStyle(lineWidth: size * 0.055, lineCap: .round))
                    .frame(width: size * 0.42, height: size * 0.18)
                    .offset(y: size * 0.2)
            }
            .frame(width: size, height: size)
        }
        .keyframeAnimator(initialValue: Wobble(), trigger: reduceMotion ? nil : mood) { face, wobble in
            face.scaleEffect(wobble.scale).rotationEffect(.degrees(wobble.angle))
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                SpringKeyframe(1.12, duration: 0.15)
                SpringKeyframe(1, duration: 0.45, spring: .bouncy)
            }
            KeyframeTrack(\.angle) {
                CubicKeyframe(-8, duration: 0.1)
                CubicKeyframe(6, duration: 0.12)
                CubicKeyframe(-3, duration: 0.1)
                SpringKeyframe(0, duration: 0.25)
            }
        }
        .animation(.spring(duration: 0.45, bounce: 0.35), value: mood)
    }
}

/// A mouth whose curve animates from a frown (-1) to a grin (1).
struct MouthShape: Shape {
    var smile: Double

    var animatableData: Double {
        get { smile }
        set { smile = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let edgeY = rect.midY - CGFloat(smile) * rect.height * 0.4
        let controlY = rect.midY + CGFloat(smile) * rect.height * 0.9
        path.move(to: CGPoint(x: rect.minX, y: edgeY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: edgeY), control: CGPoint(x: rect.midX, y: controlY))
        return path
    }
}
