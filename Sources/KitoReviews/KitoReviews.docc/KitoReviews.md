# ``KitoReviews``

Star ratings, rating summaries, review cards and lists, a review composer, and a polite App Store review prompt for SwiftUI.

## Overview

KitoReviews covers the full ratings-and-reviews surface of an app. Star ratings
can be tapped or dragged and support half steps and custom symbols. Rating
summaries show an animated histogram you can tap to filter by star. Review
cards and a sortable, filterable review list display what people wrote, and
``KitoReviewComposer`` collects a new review with mood feedback, quick tags, and
photos.

```swift
@State private var rating: Double = 0
@State private var star: Int?

VStack {
    KitoRatingSummary(stats: KitoRatingStats(reviews: reviews), selection: $star)
    KitoStarRating(rating: $rating, step: .half)
}
```

Beyond stars, the package includes emoji, thumbs, Net Promoter Score, and
slider inputs. For App Store reviews, `kitoReviewPrompt(isPresented:appName:icon:tint:onFeedback:)`
shows an "Enjoying the app?" card that sends happy users to the system review
request and unhappy users to a short feedback form, while
``KitoReviewPromptPolicy`` decides when it is appropriate to ask.

Every view reads `@Environment(\.kitoTheme)`, takes an optional `tint`, works in
light and dark mode, respects Reduce Motion, and is labelled for VoiceOver. The
logic types, such as ``KitoRatingMath``, ``KitoRatingStats``, ``KitoReviewSort``,
and ``KitoReviewFilter``, are plain values you can use and test without any UI.

## Topics

### Essentials

- <doc:AskingForReviews>

### Star Ratings

- ``KitoStarRating``
- ``KitoCompactRating``
- ``KitoRatingSymbol``
- ``KitoRatingSize``
- ``KitoRatingStep``

### Summaries

- ``KitoRatingSummary``
- ``KitoRatingStats``
- ``KitoCategoryScore``

### Reviews

- ``KitoReview``
- ``KitoReviewer``
- ``KitoReviewPhoto``
- ``KitoOwnerReply``
- ``KitoReviewCard``
- ``KitoReviewCardStyle``
- ``KitoReviewList``
- ``KitoReviewSort``
- ``KitoReviewFilter``
- ``KitoHelpfulVote``
- ``KitoVoteTally``
- ``KitoReportReason``

### Writing Reviews

- ``KitoReviewComposer``
- ``KitoReviewDraft``
- ``KitoTextGuidance``

### Other Inputs

- ``KitoEmojiRating``
- ``KitoRatingMood``
- ``KitoThumbsRating``
- ``KitoThumb``
- ``KitoNPSScale``
- ``KitoNPSCategory``
- ``KitoSliderRating``

### App Store Review Prompt

- ``KitoReviewPrompt``
- ``KitoReviewPromptPolicy``
- ``KitoReviewPromptState``
- ``KitoReviewPromptDecision``

### Utilities

- ``KitoRatingMath``
- ``KitoReviewDate``
