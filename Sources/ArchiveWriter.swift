import Foundation

/// Serializes character archive writes on a background queue so large saves (portraits and journal images
/// can make the archive tens of megabytes) never block the interface. Writes are atomic and strictly ordered.
final class ArchiveWriter: @unchecked Sendable {
    private let queue = DispatchQueue(label:"drakebound.archive-writer",qos:.utility)

    static func encode(_ archive:Archive) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        return try encoder.encode(archive)
    }
    static func write(_ archive:Archive,to file:URL) throws {
        try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true)
        try encode(archive).write(to:file,options:.atomic)
    }
    /// Encodes and writes after any earlier queued writes, then reports the outcome from the background queue.
    func enqueue(_ archive:Archive,to file:URL,completion:@escaping @Sendable (Error?) -> Void) {
        queue.async { do { try Self.write(archive,to:file); completion(nil) } catch { completion(error) } }
    }
    /// Builds the bytes on the background queue (so large encodes never block the interface), then writes them atomically
    /// after any earlier queued writes. Used for the compendium, which can be tens of megabytes.
    func enqueue(to file:URL,data produce:@escaping @Sendable () throws -> Data,completion:@escaping @Sendable (Error?) -> Void) {
        queue.async {
            do {
                let data = try produce()
                try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true)
                try data.write(to:file,options:.atomic); completion(nil)
            } catch { completion(error) }
        }
    }
    /// Writes after any earlier queued writes and returns only when the file is on disk.
    func writeAndWait(_ archive:Archive,to file:URL) throws { try queue.sync { try Self.write(archive,to:file) } }
    /// Blocks until every queued write has finished. Call before reading or replacing the archive file directly.
    func flush() { queue.sync {} }
}

/// Archives are plain value types handed to the writer as immutable snapshots.
extension Archive:@unchecked Sendable {}
extension Archive {
    /// True when saving `other` would write the same characters and spell library.
    func hasSameContent(as other:Archive) -> Bool { heroes == other.heroes && library == other.library && compendium == other.compendium }
}
