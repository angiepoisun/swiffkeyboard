import Foundation

extension Bundle {
    /// `url(forResource:withExtension:)` only looks at the bundle root.
    /// Depending on how the build system materializes a `resources:` folder
    /// from project.yml (flattened files vs. a preserved folder reference),
    /// our word-list files can end up either at the bundle root or nested
    /// under a "Resources" subdirectory. Check both so dictionary loading
    /// doesn't silently come up empty because of that packaging detail.
    func swipeKeysResourceURL(named name: String, withExtension ext: String) -> URL? {
        url(forResource: name, withExtension: ext)
            ?? url(forResource: name, withExtension: ext, subdirectory: "Resources")
    }
}
