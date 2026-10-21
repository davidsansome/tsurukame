# Code review guidelines

Tsurukame is an iOS app (Swift, deployment target iOS 15) for WaniKani, with
a few Go utilities in `utils/`, `proto/` and `similar_kanji/`. Many PRs come
from outside contributors via forks. Reviews should be short and only point
out things worth the author's time to fix.

## What to comment on

Only comment when you can describe a concrete way the change hurts users or
the codebase:

- **Crashes.** Force unwraps, out-of-range indexes, `attribute(at:)` or
  `substring` on possibly-empty strings, `as!` casts, main-thread violations.
  Remember that table items are often created with empty text.
- **Data loss or sync bugs.** Anything that could lose or corrupt the user's
  notes, synonyms, review progress or pending uploads in
  `LocalCachingClient`, or send wrong data to the WaniKani API.
- **Wrong behaviour users would notice.** For example a wrong answer being
  accepted, a review being marked incorrectly, UI state lost on cell reuse or
  scrolling, or broken dark mode.
- **Security and privacy.** Leaking the user's API token or session cookie,
  logging personal data, or sending data to new third-party hosts.
- **Out-of-scope changes.** A visual or behavioural change that affects
  parts of the app beyond what the PR describes, such as editing shared
  colours in `Style.swift`. Mention it once, briefly, and ask whether it's
  intended.
- **Dead code.** Functions, properties, parameters or branches the PR adds
  but never uses, or code the PR makes unreachable. Ask for it to be removed
  rather than merged "for later". Group all dead code in a PR into one
  comment.

## What not to comment on

- Style, formatting, naming or comment wording. SwiftFormat handles style.
- Small duplication, unless it hides a bug.
- Refactoring suggestions or "this belongs somewhere else" architecture
  ideas.
- Edge cases that need unusual input users are unlikely to produce.
- Speculation. If you can't name the input or steps that trigger the
  problem, leave it out.
- Missing tests. The iOS code has few tests and contributors aren't expected
  to add them.

## Format

- Post at most 4 comments per PR, most severe first. Fewer is better, and
  posting nothing is fine if nothing qualifies.
- Each comment says what goes wrong and how to trigger it, in two or three
  sentences, with a suggested fix where it's obvious.
- Be friendly. Many authors are first-time contributors.
