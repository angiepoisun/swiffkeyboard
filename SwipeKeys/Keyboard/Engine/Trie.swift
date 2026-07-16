import Foundation

/// Minimal prefix trie used for tap-typing autocomplete and for pruning the
/// glide-typing candidate set by starting letter / prefix.
final class Trie {
    private final class Node {
        var children: [Character: Node] = [:]
        var words: [String] = [] // words terminating exactly at this node (usually one)
    }

    private let root = Node()

    func insert(_ word: String) {
        var node = root
        for char in word.lowercased() {
            if let next = node.children[char] {
                node = next
            } else {
                let next = Node()
                node.children[char] = next
                node = next
            }
        }
        node.words.append(word)
    }

    /// All inserted words that start with `prefix`.
    func words(withPrefix prefix: String) -> [String] {
        var node = root
        for char in prefix.lowercased() {
            guard let next = node.children[char] else { return [] }
            node = next
        }
        return collect(from: node)
    }

    private func collect(from node: Node) -> [String] {
        var results = node.words
        for child in node.children.values {
            results.append(contentsOf: collect(from: child))
        }
        return results
    }
}
