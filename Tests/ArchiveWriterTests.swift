import Foundation

// Uses only a unique temporary directory; never touches live character data.
@main struct ArchiveWriterTests {
    static func savedName(_ file:URL) throws -> String { try JSONDecoder().decode(Archive.self,from:Data(contentsOf:file)).heroes[0].name }
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("drakebound-writer-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at:directory) }
        precondition(!directory.path.contains("Application Support/Fellowship5e"),"Writer tests must stay in a temporary directory")
        let file = directory.appendingPathComponent("nested/characters.json")
        let writer = ArchiveWriter()

        var hero = Hero.sample; hero.name = "Writer test"
        let first = Archive(heroes:[hero],library:starterSpells)
        try writer.writeAndWait(first,to:file)
        var saved = try savedName(file); precondition(saved == "Writer test","Synchronous write creates directories and persists")
        print("PASS: synchronous write creates directories and persists")

        // Queued writes land in order: the last submission wins even when submitted rapidly.
        let done = DispatchSemaphore(value:0)
        for i in 0..<20 {
            var h = hero; h.name = "Rapid \(i)"
            writer.enqueue(Archive(heroes:[h],library:starterSpells),to:file) { failure in precondition(failure == nil); done.signal() }
        }
        for _ in 0..<20 { done.wait() }
        writer.flush()
        saved = try savedName(file); precondition(saved == "Rapid 19","Queued writes must apply in submission order")
        print("PASS: queued writes apply in order")

        // A synchronous write waits for earlier queued writes instead of being overwritten by them.
        var queued = hero; queued.name = "Queued"
        writer.enqueue(Archive(heroes:[queued],library:starterSpells),to:file) { _ in }
        var final = hero; final.name = "Final"
        try writer.writeAndWait(Archive(heroes:[final],library:starterSpells),to:file)
        writer.flush()
        saved = try savedName(file); precondition(saved == "Final","Foreground save must be the last write")
        print("PASS: foreground write is never overtaken by queued writes")

        // Failures are reported instead of lost.
        let blocked = directory.appendingPathComponent("blocker")
        try Data().write(to:blocked)
        let failed = DispatchSemaphore(value:0); nonisolated(unsafe) var reported = false
        writer.enqueue(first,to:blocked.appendingPathComponent("characters.json")) { failure in reported = failure != nil; failed.signal() }
        failed.wait()
        precondition(reported,"A write failure must reach the completion handler")
        print("PASS: write failures are reported")

        // Background data writes: encoded off the main thread, ordered with other writes, errors reported.
        let blob = directory.appendingPathComponent("extra/compendium.json")
        let wrote = DispatchSemaphore(value:0); nonisolated(unsafe) var blobFailure:Error? = NSError(domain:"unset",code:0)
        writer.enqueue(to:blob,data:{ Data("[1,2,3]".utf8) }) { failure in blobFailure = failure; wrote.signal() }
        wrote.wait()
        let written = try Data(contentsOf:blob)
        precondition(blobFailure == nil && written == Data("[1,2,3]".utf8),"Background data write persists and creates directories")
        struct Boom:Error {}
        nonisolated(unsafe) var produceFailure:Error?
        writer.enqueue(to:blob,data:{ throw Boom() }) { failure in produceFailure = failure; wrote.signal() }
        wrote.wait()
        let kept = try Data(contentsOf:blob)
        precondition(produceFailure is Boom && kept == Data("[1,2,3]".utf8),"A failed encode is reported and leaves the previous file intact")
        print("PASS: background data writes persist, report failures, and keep the previous file on error")

        // Change detection.
        var edited = first; edited.heroes[0].hp += 1
        precondition(first.hasSameContent(as:first) && !first.hasSameContent(as:edited),"Archive comparison detects edits")
        print("PASS: unchanged archives are detected")
        print("ArchiveWriterTests passed.")
    }
}
