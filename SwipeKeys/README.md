# SwipeKeys

A custom iOS keyboard with glide (swipe) typing, built as a container app +
a keyboard extension.

## Project status

Feature-complete as a demo/portfolio custom keyboard extension — not
under active development toward being a daily-driver replacement for the
system keyboard, and deliberately so. Two hard limits make that a fight
we can't win, confirmed while building this:

- **Recent iOS versions already swipe the spacebar to switch between
  installed languages on the stock keyboard** (Settings → General →
  Keyboard → Keyboards → add more than one). That was SwipeKeys' original
  reason to exist — reclaiming the globe key's space — and it's simply
  native now. Anyone who wants that gesture already has it without this
  app.
- Third-party keyboard extensions cannot access Apple's real dictionaries,
  QuickType prediction model, or bulk word-enumeration APIs (see
  "Apple's dictionary" below) — that's a permanent OS sandboxing
  boundary, not something achievable with more engineering. The stock
  keyboard's glide typing and Pinyin input will always out-accuracy this
  one.

What's left here is a genuine working example of the parts that *are*
buildable by a third party: a from-scratch glide-typing engine (path
resampling, shape scoring, frequency ranking, learned corrections),
multi-language QWERTY/AZERTY/QWERTZ layouts, Pinyin composing with a
candidate bar, long-press accent variants, and `UITextChecker`
integration. Bug reports are still worth fixing; chasing dictionary size
or glide precision further isn't, since the ceiling is Apple's private
engine, not this codebase.

## Layout

- **Number row** always on top, then a **QWERTY/AZERTY/QWERTZ letter block**
  depending on the active language (English, Spanish, French, German,
  Chinese Simplified, and Chinese Traditional ship by default).
- **Bottom row**: `123` ↔ symbols toggle, an emoji toggle, a large
  **spacebar**, and return. There is no globe key — **swipe the spacebar
  left or right to cycle the input language**, previewing the target
  language as you drag and committing on release. That reclaims the corner
  the globe key used to sit in.
- Tapping `123` shows a symbols page (with a `#+=` key for a second symbols
  page); the emoji toggle opens a category-tabbed emoji grid with a
  `ABC` key to return to letters.
- **Long-press a letter** for accented/alternate variants (é è ê ë…),
  matching the standard iOS convention — drag across the popup strip to
  pick one, release on the base letter (the default first option) for a
  normal tap. Per-language mappings live in
  `Keyboard/Layout/KeyLetterVariants.swift`. Not offered in Pinyin mode:
  input there is toneless romanization matched against a toneless
  dictionary, so a tone-marked vowel wouldn't match anything.

## Swipe (glide) typing

Dragging a finger across the letters without lifting is captured as a path
and scored against the active language's dictionary (`Keyboard/Engine`):

1. `PathSampler` resamples the raw touch path and, per candidate word, the
   "ideal" path connecting that word's key centers, to the same number of
   points so the two are comparable.
2. `GlideTypingEngine` prunes candidates by starting letter and path length,
   scores the rest by mean point-to-point distance between the two
   resampled paths, and blends in a word-frequency bonus so common words
   win close calls.
3. The top match is inserted automatically; alternates appear in the
   suggestion strip to tap-replace it.

Tap-typing also gets prefix autocomplete from the same dictionary
(`WordFrequencyDictionary`, backed by a `Trie`), and words you type or swipe
often are "learned" (persisted in the shared App Group) and ranked higher
next time.

Word lists in `Keyboard/Resources/*.txt` are small curated demo
dictionaries (a few hundred words per language, `word frequency` per line)
— swap in larger frequency-ranked word lists for production use; the
loader and pruning logic already scale to that.

### Apple's dictionary (`SystemDictionary` / `UITextChecker`)

Third-party keyboards don't get access to Apple's own QuickType prediction
model or the system keyboard's word list — that stays private, with or
without Full Access. What *is* exposed is `UITextChecker`, the same engine
behind system-wide spell-check and autocomplete, and it's what
`Keyboard/Engine/SystemDictionary.swift` wraps:

- Tap-typing suggestions (`refreshSuggestions` in
  `KeyboardViewController`) blend our own `WordFrequencyDictionary`
  completions (which know about your personal learned/corrected words)
  with `UITextChecker.completions(forPartialWordRange:in:language:)` —
  real dictionary coverage well beyond the ~180–570-word curated lists.
- Every "learned" word — from tap-typing, accepting a swipe, or
  correcting one — also calls `UITextChecker.learnWord(_:)`, which writes
  into the device's shared user dictionary. That's system-wide (every
  app's spell-checker benefits, not just this one), which is the honest
  scope of "learning" a third-party keyboard can plug into.
- `UITextChecker` has no bulk "all words starting with X" API, so it
  can't replace the enumerable pool `GlideTypingEngine` scores swipe
  paths against — the curated word lists still do that job. Swipe
  benefits from this indirectly: anything learned via a swipe correction
  also strengthens `UITextChecker`'s suggestions on the next tap-typed
  word.

## Chinese (Pinyin)

Chinese Simplified and Traditional don't type like the Latin languages —
there's no letter-for-letter mapping from a QWERTY key to a Hanzi
character. Instead, both use the exact same QWERTY layout to type
**romanized pinyin** (e.g. "nihao"), and a **candidate bar** turns that
into Hanzi, exactly like a real Pinyin IME:

- Typed pinyin composes in a local buffer shown only in the suggestion
  bar — it never touches the document. This isn't a design choice we could
  relax: `UITextDocumentProxy` (all a third-party keyboard extension gets)
  has no marked/preedit-text API, so no custom iOS keyboard can show
  inline composing text the way the system Pinyin keyboard does. Tapping a
  candidate (or Space, which accepts the top one) inserts the chosen Hanzi
  and clears the buffer; Space does *not* insert a literal space in this
  mode, matching how Chinese text is actually written.
- One pinyin key is often several homophones ("shi" → 是/时/十/事/市…) —
  all of them show up as candidates so you can pick the right character,
  not just the most common one.
- **Swipe typing works here too**: gliding across the pinyin letters (e.g.
  n-i-h-a-o) is scored by `GlideTypingEngine` exactly like a Latin word,
  against `PinyinDictionary` instead of `WordFrequencyDictionary` — both
  conform to a shared `GlideCandidateSource` protocol so the same engine
  serves both without knowing which one it's talking to. A completed glide
  inserts the top Hanzi candidate directly, with homophones/alternates
  offered in the suggestion bar to replace it.
- The bundled `zh-Hans.txt` / `zh-Hant.txt` (tab-separated
  `pinyin  hanzi  frequency`) cover common HSK1–2-level vocabulary plus
  the highest-frequency single characters (~245 entries) — a working
  demo, not a production IME dictionary. The suggestion bar shows every
  matching word for the typed pinyin (scrolls horizontally past ~4
  candidates) the way Apple's own Pinyin keyboard does, and the
  algorithm has no artificial cap on that — but with an order of
  magnitude fewer entries than Apple's built-in dictionary, "every
  matching word" is still a much shorter list. Widening this further is
  a data problem (more curated `pinyin\thanzi\tfrequency` rows), not a
  code one.
- There's no fallback mode for typing literal Latin text (email addresses,
  English words) while a Chinese keyboard is active — real Pinyin IMEs
  usually have an "abc" toggle for that; out of scope here.

## Project layout

```
SwipeKeys/
  project.yml              XcodeGen project spec (generates the .xcodeproj)
  App/                     Container app (SwiftUI) — onboarding + language/settings screen
  AppResources/
    Assets.xcassets          App icon + accent color. Outside App/, included via `sources:` — see below.
  Keyboard/                The keyboard extension (UIKit)
    KeyboardViewController.swift   State machine: shift/caps, mode, active language, text insertion
    Layout/                 Per-language key layouts, symbol pages, emoji categories
    Views/                  KeyboardView, TypingPadView (glide+tap), BottomBarView (spacebar swipe),
                             SuggestionBarView, EmojiPadView, LanguageToastView, KeyButton
    Engine/                 GlideTypingEngine, PathSampler, Trie, WordFrequencyDictionary, PinyinDictionary, GlideCandidateSource
    Resources/               *.txt word lists, included via `sources:` — see below
  Shared/
    AppGroup.swift           Settings shared between the app and the extension via an App Group
```

## Building

This was authored outside of macOS, so the Xcode project itself is
generated rather than hand-committed as a `.pbxproj` (those are fragile to
hand-edit and impossible to verify without Xcode). To build:

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
2. From this directory, run:
   ```
   xcodegen generate
   open SwipeKeys.xcodeproj
   ```
3. In Xcode, select a Development Team for both the `SwipeKeys` and
   `SwipeKeysKeyboard` targets (Signing & Capabilities) — required for the
   shared App Group (`group.com.angieng.swipekeys`) to work. If you use a
   different bundle ID prefix, update it in `project.yml` and in
   `Shared/AppGroup.swift`.
4. Build & run the `SwipeKeys` scheme on a device or simulator running
   iOS 16+.
5. On device: open the SwipeKeys app, follow the on-screen steps to enable
   the keyboard under Settings → General → Keyboard → Keyboards, then
   switch to it from any text field (Full Access is not required — the app
   works entirely through the standard `UITextDocumentProxy` and the shared
   App Group).

## A note on `project.yml`'s `sources:`-only structure

Neither target uses XcodeGen's `resources:` or `entitlements:` target keys,
on purpose. Both used to be declared the standard XcodeGen way (asset
catalog and word-list `.txt` files under `resources:`, the App Group
entitlement under `entitlements:` with `properties:`), and that's the
normal, documented approach — but on at least one real XcodeGen install it
silently produced a `.pbxproj` with **zero** references to any of those
files: no `Assets.car` ever got compiled (app-icon validation failed no
matter what was inside the catalog), and — near-certainly, same
mechanism — the bundled dictionaries were dropped too, which is why glide
typing could detect a swipe path but never produce a word. `xcodegen
generate` reported success and no warnings the whole time.

The fix was to stop asking XcodeGen to generate/manage those files at all:
`AppResources/Assets.xcassets` and `Keyboard/Resources/*.txt` are now
picked up as plain `sources:` entries (XcodeGen auto-categorizes non-code
files it finds there into the resources build phase), and both
entitlements files are wired directly via the `CODE_SIGN_ENTITLEMENTS`
build setting instead of the `entitlements:` key. Every remaining
mechanism in `project.yml` is one we have direct evidence works (Swift
files compile, `INFOPLIST_FILE` is honored). If you reintroduce
`resources:`/`entitlements:` here, verify with `grep -c` against the
generated `project.pbxproj` that the files actually made it in — don't
trust a clean `xcodegen generate` run or Xcode's navigator alone.

## Known limitations (given the scope of a first pass)

- Bundled dictionaries are small demo word lists, not full frequency
  corpora — swipe accuracy on rare words will be poor until you drop in
  bigger lists.
- French/German words containing characters outside the on-screen layout
  (apostrophes, `ß`, hyphens) fall back to tap-typing only; they won't be
  offered as glide candidates.
- The bundled app icon is a placeholder generated for this project —
  swap it for real artwork before shipping.
