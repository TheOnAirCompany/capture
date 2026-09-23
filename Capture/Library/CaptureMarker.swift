import Foundation

/// Marks the files Capture creates with an extended attribute, so the library
/// (and "Erase All") only deal with them, never with files added by hand.
/// The attribute is invisible, and stays when a file is renamed or moved on the same disk.
nonisolated enum CaptureMarker {
    private static let name = "com.theonaircompany.capture"
    private static let value = Array("1".utf8)

    static func mark(_ url: URL) {
        _ = url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return Int32(-1) }
            return setxattr(path, name, value, value.count, 0, 0)
        }
    }

    static func isMarked(_ url: URL) -> Bool {
        url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return false }
            return getxattr(path, name, nil, 0, 0, 0) > 0
        }
    }
}
