# Asking for Reviews

Decide when to ask for an App Store review, and ask politely.

## Overview

Asking for a review too early, or too often, annoys people and wastes the
limited number of system review requests. KitoReviews separates the decision
from the presentation: ``KitoReviewPromptPolicy`` decides whether now is a good
moment, and ``KitoReviewPrompt`` asks.

### Record what the app remembers

``KitoReviewPromptState`` stores the install date, a count of significant
events, and when and for which version the prompt was last shown. Load it,
record a significant event whenever the app has clearly worked for someone,
such as an order placed or a trip booked, and save it again. By default it is
kept in `UserDefaults.standard`.

```swift
var state = KitoReviewPromptState.load()
state.recordSignificantEvent()
state.save()
```

### Ask the policy

A ``KitoReviewPromptPolicy`` combines a minimum number of significant events, a
minimum number of days since install, a cooldown between prompts, and an
optional once-per-version rule. Its `decision(for:currentVersion:now:)` method
returns a ``KitoReviewPromptDecision``, which explains why the answer is no, for
example `.coolingDown(daysLeft:)`, or reports `shouldAsk` when it is time.

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
```

Call `recordPrompt(version:at:)` whenever the prompt is shown. It starts the
cooldown and resets the event count.

### Show the prompt

Attach `kitoReviewPrompt(isPresented:appName:icon:tint:onFeedback:)` to a view.
It shows an "Enjoying the app?" card over a dimmed screen. "Yes" calls the
system `requestReview` action; "Not really" opens a short feedback form, so
unhappy users reach you rather than the App Store.

```swift
content.kitoReviewPrompt(isPresented: $asking, appName: "Kito") { feedback in
    support.send(feedback)
}
```

To place the card yourself, use ``KitoReviewPrompt`` directly and dismiss it in
its `onFinish` closure.
