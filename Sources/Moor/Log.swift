import Foundation

/// Appends to ~/Library/Logs/Moor.log. A plain file, because reading the system log needs an admin account.
let log = FileLog()

final class FileLog {
    private static let maxSize = 1_000_000

    private let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Moor.log")
    private let queue = DispatchQueue(label: "Moor.log")
    private let formatter = ISO8601DateFormatter()

    func notice(_ message: String) {
        let line = "\(formatter.string(from: Date())) \(message)\n"
        queue.async { [url] in
            let fm = FileManager.default
            let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            if size > Self.maxSize {
                try? fm.removeItem(at: url)
            }
            if !fm.fileExists(atPath: url.path) {
                fm.createFile(atPath: url.path, contents: nil)
            }
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        }
    }
}
