//
//  KitoReviewPrompt.swift
//  KitoReviews
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import StoreKit
import KitoCore

/// The polite pre-prompt: "Enjoying Kito?" Yes asks the system for a review; "Not really"
/// opens a short feedback form instead, so unhappy people talk to you, not the App Store.
///
/// Use `.kitoReviewPrompt(isPresented:appName:onFeedback:)` to present it, and
/// `KitoReviewPromptPolicy` to decide when.
public struct KitoReviewPrompt: View {
    private let appName: String
    private let icon: Image?
    private let tint: Color?
    private let onFeedback: (String) -> Void
    private let onFinish: () -> Void

    private enum Step { case ask, feedback, thanks }

    @State private var step: Step = .ask
    @State private var feedback = ""
    @State private var iconBounce = 0
    @FocusState private var feedbackFocused: Bool
    @Environment(\.kitoTheme) private var theme
    @Environment(\.requestReview) private var requestReview
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - icon: Your app icon; a star is shown without one.
    ///   - onFeedback: Receives what an unhappy user wrote.
    ///   - onFinish: Called when the prompt is done, whatever the answer.
    public init(appName: String, icon: Image? = nil, tint: Color? = nil, onFeedback: @escaping (String) -> Void = { _ in },
                onFinish: @escaping () -> Void) {
        self.appName = appName
        self.icon = icon
        self.tint = tint
        self.onFeedback = onFeedback
        self.onFinish = onFinish
    }

    private var accent: Color { tint ?? theme.colors.onSurface }

    public var body: some View {
        VStack(spacing: theme.spacing.lg) {
            header
            switch step {
            case .ask: askButtons.transition(.opacity.combined(with: .move(edge: .bottom)))
            case .feedback: feedbackForm.transition(.opacity.combined(with: .move(edge: .trailing)))
            case .thanks: thanks.transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(theme.spacing.xl)
        .frame(maxWidth: 420)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(theme.colors.surface)
                .shadow(color: .black.opacity(0.18), radius: 30, y: 14)
        )
        .animation(.spring(duration: 0.45, bounce: 0.25), value: step)
        .onAppear { iconBounce += 1 }
    }

    private var header: some View {
        VStack(spacing: theme.spacing.md) {
            ZStack {
                if let icon {
                    icon.resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [theme.colors.warning, theme.colors.danger], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: step == .feedback ? "bubble.left.and.text.bubble.right.fill" : (step == .thanks ? "heart.fill" : "star.fill"))
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
            .symbolEffect(.bounce, value: reduceMotion ? 0 : iconBounce)
            .accessibilityHidden(true)

            VStack(spacing: theme.spacing.xs) {
                Text(title).font(.title3.weight(.bold)).foregroundStyle(theme.colors.onSurface)
                Text(message)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.onSurface.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .id(step)
            .transition(.opacity)
        }
    }

    private var title: String {
        switch step {
        case .ask: "Enjoying \(appName)?"
        case .feedback: "How can we do better?"
        case .thanks: "Thank you!"
        }
    }

    private var message: String {
        switch step {
        case .ask: "Your answer helps us make \(appName) better."
        case .feedback: "Tell us what got in the way. We read every message."
        case .thanks: "We appreciate you taking the time."
        }
    }

    private var askButtons: some View {
        HStack(spacing: theme.spacing.md) {
            promptButton("Not really", filled: false) {
                step = .feedback
                iconBounce += 1
            }
            promptButton("Yes!", filled: true) {
                requestReview()
                onFinish()
            }
        }
    }

    private var feedbackForm: some View {
        VStack(spacing: theme.spacing.md) {
            TextField("What could be better?", text: $feedback, axis: .vertical)
                .lineLimit(3...6)
                .font(theme.typography.body)
                .focused($feedbackFocused)
                .padding(theme.spacing.md)
                .background(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).fill(theme.colors.surfaceMuted))
                .onAppear { feedbackFocused = true }
            HStack(spacing: theme.spacing.md) {
                promptButton("Not now", filled: false) { onFinish() }
                promptButton("Send", filled: true) {
                    let text = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    feedbackFocused = false
                    onFeedback(text)
                    step = .thanks
                    iconBounce += 1
                    Task {
                        try? await Task.sleep(nanoseconds: 1_400_000_000)
                        onFinish()
                    }
                }
                .opacity(feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
            }
        }
    }

    private var thanks: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 44))
            .foregroundStyle(theme.colors.success)
            .symbolEffect(.bounce, value: step)
            .sensoryFeedback(.success, trigger: step)
            .accessibilityLabel("Feedback sent")
    }

    private func promptButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(theme.typography.button)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(filled ? theme.colors.surface : theme.colors.onSurface)
                .background(Capsule().fill(filled ? accent : theme.colors.surfaceMuted))
                .contentShape(Capsule())
        }
        .buttonStyle(KitoReviewPressStyle())
    }
}

public extension View {
    /// Shows `KitoReviewPrompt` as a card over a dimmed screen while `isPresented` is true.
    ///
    /// ```swift
    /// .kitoReviewPrompt(isPresented: $asksForReview, appName: "Kito") { feedback in
    ///     support.send(feedback)
    /// }
    /// ```
    func kitoReviewPrompt(isPresented: Binding<Bool>, appName: String, icon: Image? = nil, tint: Color? = nil,
                          onFeedback: @escaping (String) -> Void = { _ in }) -> some View {
        modifier(KitoReviewPromptModifier(isPresented: isPresented, appName: appName, icon: icon, tint: tint, onFeedback: onFeedback))
    }
}

private struct KitoReviewPromptModifier: ViewModifier {
    @Binding var isPresented: Bool
    let appName: String
    let icon: Image?
    let tint: Color?
    let onFeedback: (String) -> Void
    @Environment(\.kitoTheme) private var theme

    func body(content: Content) -> some View {
        content.overlay {
            ZStack {
                if isPresented {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { isPresented = false }
                        .transition(.opacity)
                        .accessibilityHidden(true)
                    KitoReviewPrompt(appName: appName, icon: icon, tint: tint, onFeedback: onFeedback) { isPresented = false }
                        .padding(theme.spacing.xl)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.85).combined(with: .opacity).combined(with: .offset(y: 40)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                        .accessibilityAddTraits(.isModal)
                }
            }
            .animation(.spring(duration: 0.5, bounce: 0.3), value: isPresented)
        }
    }
}
