import CoreGraphics

/// Resamples polylines to a fixed number of evenly spaced points so two
/// paths of different raw lengths (a finger swipe vs. an "ideal" path
/// connecting key centers) can be compared point-for-point.
enum PathSampler {
    static func resample(_ points: [CGPoint], to count: Int) -> [CGPoint] {
        guard points.count > 1, count > 1 else {
            return points.isEmpty ? [] : Array(repeating: points[0], count: count)
        }

        var cumulative: [CGFloat] = [0]
        for i in 1..<points.count {
            cumulative.append(cumulative[i - 1] + points[i - 1].distance(to: points[i]))
        }
        let totalLength = cumulative.last ?? 0
        guard totalLength > 0 else {
            return Array(repeating: points[0], count: count)
        }

        var result: [CGPoint] = []
        result.reserveCapacity(count)
        var segmentIndex = 0
        for i in 0..<count {
            let targetDistance = totalLength * CGFloat(i) / CGFloat(count - 1)
            while segmentIndex < cumulative.count - 2 && cumulative[segmentIndex + 1] < targetDistance {
                segmentIndex += 1
            }
            let segStart = cumulative[segmentIndex]
            let segEnd = cumulative[segmentIndex + 1]
            let segLength = segEnd - segStart
            let t = segLength > 0 ? (targetDistance - segStart) / segLength : 0
            let p0 = points[segmentIndex]
            let p1 = points[segmentIndex + 1]
            result.append(CGPoint(x: p0.x + (p1.x - p0.x) * t, y: p0.y + (p1.y - p0.y) * t))
        }
        return result
    }

    /// Builds the "ideal" path a perfect swipe would take through a word's
    /// letters, collapsing consecutive repeats of the same key (double
    /// letters look identical to a glide gesture, e.g. "ll" in "hello").
    static func idealPath(for word: String, keyCenters: [Character: CGPoint]) -> [CGPoint]? {
        var path: [CGPoint] = []
        var lastChar: Character?
        for char in word.lowercased() {
            guard let center = keyCenters[char] else { return nil }
            if char != lastChar {
                path.append(center)
                lastChar = char
            }
        }
        return path.count >= 2 ? path : nil
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
