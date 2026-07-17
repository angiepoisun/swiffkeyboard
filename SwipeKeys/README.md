# SwipeKeys

A custom iOS keyboard with glide (swipe) typing, built as a container app +
a keyboard extension.

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
  `pinyin  hanzi  frequency`) cover common HSK1–2-level vocabulary (~180
  entries) — a working demo, not a production IME dictionary.
- There's no fallback mode for typing literal Latin text (email addresses,
  English words) while a Chinese keyboard is active — real Pinyin IMEs
  usually have an "abc" toggle for that; out of scope here.

## Project layout

```
SwipeKeys/
  project.yml              XcodeGen project spec (generates the .xcodeproj)
  App/                     Container app (SwiftUI) — onboarding + language/settings screen
  AppResources/
    Assets.xcassets          App icon + accent color. Deliberately kept outside App/ — see below.
  Keyboard/                The keyboard extension (UIKit)
    KeyboardViewController.swift   State machine: shift/caps, mode, active language, text insertion
    Layout/                 Per-language key layouts, symbol pages, emoji categories
    Views/                  KeyboardView, TypingPadView (glide+tap), BottomBarView (spacebar swipe),
                             SuggestionBarView, EmojiPadView, LanguageToastView, KeyButton
    Engine/                 GlideTypingEngine, PathSampler, Trie, WordFrequencyDictionary, PinyinDictionary, GlideCandidateSource
    Resources/               *.txt word lists, bundled into the extension
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

## A note on `AppResources/Assets.xcassets`

The asset catalog lives outside `App/` on purpose. Earlier it sat at
`App/Assets.xcassets`, excluded from the `App` target's `sources:` entry
and separately declared under `resources:` — the standard XcodeGen pattern
for asset catalogs. In practice that overlap (same folder referenced by
both an excluded-from `sources` path and a `resources` path) caused
XcodeGen to silently drop the catalog from the generated project entirely
— it wouldn't even show up in Xcode's navigator, so no `Assets.car` ever
got compiled and app-icon validation failed no matter what was inside the
catalog. Moving it to a sibling folder that no `sources` entry ever scans
removes the overlap and the ambiguity with it. Don't move it back under
`App/` without re-testing that XcodeGen actually includes it.

## Known limitations (given the scope of a first pass)

- Bundled dictionaries are small demo word lists, not full frequency
  corpora — swipe accuracy on rare words will be poor until you drop in
  bigger lists.
- French/German words containing characters outside the on-screen layout
  (apostrophes, `ß`, hyphens) fall back to tap-typing only; they won't be
  offered as glide candidates.
- No custom app icon has been supplied (`AppIcon.appiconset` is empty) —
  add one before shipping.
