# KitoReviews

Ratings and reviews for SwiftUI: star ratings you tap or drag, rating summaries with animated
histograms, review cards, a sortable review list, a review composer, emoji / thumbs / NPS / slider
inputs, and a polite "Enjoying the app?" prompt with a policy for when to show it. Part of the
[Kito](https://github.com/WykSofts-Inc/KitoDevKit) ecosystem.

Every view reads `@Environment(\.kitoTheme)`, takes an optional `tint`, works in light and dark,
respects Reduce Motion and is labelled for VoiceOver (the star rating is an adjustable element:
"4 out of 5 stars").

## Star ratings

```swift
@State private var rating: Double = 0

KitoStarRating(rating: $rating)                                   // tap or drag; stars pop as they fill
KitoStarRating(rating: $rating, step: .half, size: .custom(40))   // half stars
KitoStarRating(value: 4.3, size: .small)                          // display: the fifth star is 30% full
KitoStarRating(rating: $love, symbol: .heart)                     // .star, .heart, .flame, .thumb
KitoStarRating(value: 3.5, symbol: KitoRatingSymbol(filled: "moon.fill", noun: "moons"))
KitoCompactRating(value: 4.8, count: 2_140)                       // ★ 4.8 (2.1k)
```

## Summaries

```swift
@State private var star: Int?

KitoRatingSummary(stats: KitoRatingStats(reviews: reviews), selection: $star)   // tap a bar to filter
KitoRatingSummary(stats: KitoRatingStats(fiveToOne: [214, 22, 3, 0, 1]), categories: [
    KitoCategoryScore("Cleanliness", score: 4.9, systemImage: "sparkles"),
    KitoCategoryScore("Location", score: 4.7, systemImage: "map"),
], badge: "Guest favourite")
```

## Review cards and lists

```swift
let review = KitoReview(
    author: KitoReviewer("Achieng O.", subtitle: "Local guide · 48 reviews"),
    rating: 5, title: "Best tilapia in Kilimani", body: "…",
    date: twoWeeksAgo, photos: [KitoReviewPhoto(url: photoURL)], tags: ["Great value"],
    helpfulCount: 42, isVerified: true,
    ownerReply: KitoOwnerReply(name: "Chef Wairimu", body: "Asante sana!")
)

KitoReviewCard(review, onVote: { vote in … }, onReport: { reason in … })   // "2 weeks ago", "more", photo viewer
KitoReviewCard(review, style: .compact)        // .standard, .compact, .bubble, .carouselCard

KitoReviewList(reviews: reviews, onWriteReview: { writing = true })        // sort, filter chips, empty state
```

## Writing a review

```swift
.sheet(isPresented: $writing) {
    KitoReviewComposer(subject: "Jiko Kilimani", subtitle: "Kilimani, Nairobi", authorName: "Wycliff N") { draft in
        await api.post(draft)     // draft.rating, .tags, .text, .photos, .isAnonymous
    }
}
```

The face above the stars changes mood from Terrible to Amazing, quick tags switch between praise
and problems, the text shows how many characters are left, and posting ends with a thank-you.

## Other inputs

```swift
KitoEmojiRating(selection: $mood)                          // KitoRatingMood?
KitoThumbsRating(selection: $thumb, upCount: 128, downCount: 9)
KitoNPSScale(score: $score)                                // 0–10, "Not likely" … "Very likely"
KitoSliderRating(value: $spice, in: 0...10, step: 1)
KitoNPSCategory(score: 9)                                  // .promoter
KitoNPSCategory.netPromoterScore(answers)                  // -100…100
```

## Asking for an App Store review

```swift
@State private var asking = false
let policy = KitoReviewPromptPolicy(minimumSignificantEvents: 3, minimumDaysSinceInstall: 3,
                                    cooldownDays: 120, oncePerVersion: true)

func orderPlaced() {
    var state = KitoReviewPromptState.load()
    state.recordSignificantEvent()
    if policy.decision(for: state, currentVersion: appVersion).shouldAsk {
        state.recordPrompt(version: appVersion)
        asking = true
    }
    state.save()
}

content.kitoReviewPrompt(isPresented: $asking, appName: "Kito") { feedback in
    support.send(feedback)
}
```

"Yes!" calls the system `requestReview`; "Not really" opens a short feedback form instead.

## Logic without UI

`KitoRatingMath` (half-star rounding, partial fill, touch position to rating, "2.1k"),
`KitoRatingStats` (average, histogram, percentages that add to 100), `KitoReviewSort`,
`KitoReviewFilter`, `KitoReviewDate.relative(_:to:)`, `KitoRatingMood`, `KitoTextGuidance` and
`KitoReviewPromptPolicy` are plain values you can use and test on their own.

## Installation

```swift
.package(url: "https://github.com/WykSofts-Inc/KitoReviews.git", from: "0.1.0")
```

## License

MIT — see [LICENSE](LICENSE).
