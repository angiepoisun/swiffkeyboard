import CoreGraphics
import Foundation

/// Turns a raw finger-swipe path across the letter keys into ranked word
/// candidates, the way Swype/Gboard-style "glide typing" works:
///
/// 1. Prune the dictionary to words whose first letter is near the path's
///    start, then to those whose *own* ideal-path length (see step 2) is in
///    the same ballpark as the raw swipe's length — not a generic per-letter
///    estimate, since words with widely-spaced letters (e.g. "keyboard")
///    naturally have long ideal paths despite being ordinary-length words.
/// 2. For each surviving candidate, build the "ideal" path a perfect swipe
///    through its letters would take (see `PathSampler.idealPath`).
/// 3. Resample both paths to the same number of points and score by mean
///    distance between corresponding points — smaller is a better shape
///    match.
/// 4. Blend the shape score with word frequency (so common short words like
///    "the" can beat an obscure word with a marginally tighter shape match)
///    and return the best few.
enum GlideTypingEngine {
    struct Candidate {
        let word: String
        let score: Double // lower is better
    }

    private static let resampleCount = 32
    private static let maxResults = 5

    /// - Parameters:
    ///   - rawPath: the raw touch points captured during the swipe, in the
    ///     same coordinate space as `keyCenters`.
    ///   - keyCenters: center point of every glideable key currently on
    ///     screen (lowercase character -> center).
    ///   - source: the active language's candidate source — a word list for
    ///     Latin languages, a pinyin dictionary for Chinese. Returned
    ///     strings are that source's *keys* (a word for Latin, a
    ///     romanization for Pinyin), not necessarily what gets inserted.
    static func candidates(
        forPath rawPath: [CGPoint],
        keyCenters: [Character: CGPoint],
        source: any GlideCandidateSource
    ) -> [String] {
        guard rawPath.count >= 2, let start = rawPath.first, let end = rawPath.last else { return [] }

        guard let startLetter = nearestKey(to: start, in: keyCenters) else { return [] }
        let pathLength = totalLength(rawPath)
        let averageKeySpacing = averageSpacing(of: keyCenters)
        let endLetter = nearestKey(to: end, in: keyCenters)

        let pool = source.candidateKeys(startingWith: startLetter)
        guard !pool.isEmpty else { return [] }

        let sampledUserPath = PathSampler.resample(rawPath, to: resampleCount)

        var scored: [Candidate] = []
        for word in pool {
            guard let ideal = PathSampler.idealPath(for: word, keyCenters: keyCenters) else { continue }

            // 1. Prune: compare the raw swipe's length against *this
            // candidate's own* ideal-path length, not a generic estimate
            // based on average key spacing. A generic per-letter estimate
            // silently excludes any word whose letters happen to be spread
            // far apart on the keyboard (e.g. "keyboard": k-e-y-b-o-a-r-d
            // zigzags corner to corner) — its true path is long even though
            // the word itself isn't, so an estimate that assumes "long path
            // implies many letters" wrongly rules it out before scoring.
            // Comparing against the word's own geometry has no such bias.
            let idealLength = totalLength(ideal)
            if idealLength > 0 {
                let ratio = pathLength / idealLength
                guard ratio > 0.3, ratio < 3.2 else { continue }
            }

            if let endLetter, word.count > 2, let lastChar = word.lowercased().last, lastChar != endLetter {
                // Soft filter: skip keys that clearly end far from where
                // the finger lifted, unless the key is very short.
                if keyCenters[lastChar]?.distance(to: end) ?? 0 > averageKeySpacing * 2.2 {
                    continue
                }
            }
            let sampledIdeal = PathSampler.resample(ideal, to: resampleCount)
            let shapeDistance = meanDistance(sampledUserPath, sampledIdeal)
            let normalizedShape = averageKeySpacing > 0 ? shapeDistance / averageKeySpacing : shapeDistance
            let frequency = max(source.frequency(ofKey: word), 1)
            // log-scaled frequency bonus so very common keys win close calls.
            let frequencyBonus = log(Double(frequency) + 1) * 0.18
            let score = normalizedShape - frequencyBonus
            scored.append(Candidate(word: word, score: score))
        }

        return scored
            .sorted { $0.score < $1.score }
            .prefix(maxResults)
            .map { $0.word }
    }

    /// Rough "what did the finger actually trace" fallback for when nothing
    /// in `source` scored well enough to return — small dictionaries (like
    /// the bundled Pinyin word list) miss far more swipes than a full-size
    /// English list does, and silently doing nothing on a completed swipe
    /// reads as the keyboard being broken. Walks the resampled path and
    /// collapses it to the sequence of distinct nearest keys, the same way
    /// a word's ideal path is built, just in reverse.
    static func tracedLetters(forPath rawPath: [CGPoint], keyCenters: [Character: CGPoint]) -> String {
        guard !keyCenters.isEmpty, rawPath.count > 1 else { return "" }
        var result = ""
        var lastChar: Character?
        for point in PathSampler.resample(rawPath, to: 20) {
            guard let nearest = nearestKey(to: point, in: keyCenters) else { continue }
            if nearest != lastChar {
                result.append(nearest)
                lastChar = nearest
            }
        }
        return result
    }

    private static func nearestKey(to point: CGPoint, in keyCenters: [Character: CGPoint]) -> Character? {
        keyCenters.min { lhs, rhs in
            lhs.value.distance(to: point) < rhs.value.distance(to: point)
        }?.key
    }

    private static func totalLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }
        var length: CGFloat = 0
        for i in 1..<points.count {
            length += points[i - 1].distance(to: points[i])
        }
        return length
    }

    private static func averageSpacing(of keyCenters: [Character: CGPoint]) -> CGFloat {
        let points = Array(keyCenters.values)
        guard points.count > 1 else { return 1 }
        var total: CGFloat = 0
        var count = 0
        for i in 0..<points.count {
            var nearest: CGFloat = .greatestFiniteMagnitude
            for j in 0..<points.count where j != i {
                nearest = min(nearest, points[i].distance(to: points[j]))
            }
            if nearest.isFinite {
                total += nearest
                count += 1
            }
        }
        return count > 0 ? total / CGFloat(count) : 1
    }

    private static func meanDistance(_ a: [CGPoint], _ b: [CGPoint]) -> CGFloat {
        guard a.count == b.count, !a.isEmpty else { return .greatestFiniteMagnitude }
        var total: CGFloat = 0
        for i in 0..<a.count {
            total += a[i].distance(to: b[i])
        }
        return total / CGFloat(a.count)
    }
}
