//
//  KitoReviews.swift
//  KitoReviews
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

// Small pieces shared by the views in this package.

/// Scales down a little while pressed.
struct KitoReviewPressStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
    }
}

/// A round avatar, or the reviewer's initials on a colour picked from their name.
struct KitoAvatar: View {
    let reviewer: KitoReviewer
    var size: CGFloat = 40
    var isAnonymous = false
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        ZStack {
            if isAnonymous {
                Circle().fill(theme.colors.surfaceMuted)
                Image(systemName: "person.fill").font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(theme.colors.onSurface.opacity(0.45))
            } else if let avatar = reviewer.avatar {
                avatar.resizable().scaledToFill()
            } else {
                Circle().fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                Text(reviewer.initials)
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    /// Two theme colours picked from the name, so each reviewer keeps the same look.
    private var gradient: [Color] {
        let palette = [theme.colors.primary, theme.colors.success, theme.colors.warning, theme.colors.danger]
        let hash = reviewer.name.unicodeScalars.reduce(5_381) { ($0 &* 33 &+ Int($1.value)) & 0xFFFFFF }
        let first = palette[hash % palette.count]
        let second = palette[(hash / palette.count) % palette.count]
        return [first, (hash / palette.count) % palette.count == hash % palette.count ? first.opacity(0.7) : second]
    }
}

/// A capsule chip that fills when selected.
struct KitoReviewChip: View {
    let title: String
    var systemImage: String?
    var isSelected: Bool
    var accent: Color
    var action: () -> Void
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage).font(.caption.weight(.bold))
                        .symbolEffect(.bounce, value: isSelected)
                }
                Text(title).font(theme.typography.label)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? theme.colors.surface : theme.colors.onSurface)
            .background(Capsule().fill(isSelected ? accent : theme.colors.surfaceMuted))
            .overlay(Capsule().stroke(isSelected ? Color.clear : theme.colors.border, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(KitoReviewPressStyle())
        .animation(.spring(duration: 0.3, bounce: 0.35), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Displays a review photo from an image or a URL.
struct KitoReviewPhotoView: View {
    let photo: KitoReviewPhoto
    var contentMode: ContentMode = .fill
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        switch photo.source {
        case .image(let image):
            image.resizable().aspectRatio(contentMode: contentMode)
        case .url(let url):
            AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
                switch phase {
                case .success(let image): image.resizable().aspectRatio(contentMode: contentMode).transition(.opacity)
                case .failure: Image(systemName: "photo").foregroundStyle(theme.colors.onSurface.opacity(0.4))
                default: theme.colors.surfaceMuted
                }
            }
        }
    }
}

extension View {
    /// Applies `transform` only when `condition` is true.
    @ViewBuilder
    func kitoIf<Content: View>(_ condition: Bool, _ transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}
