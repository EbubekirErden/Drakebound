import Foundation

/// A portable copy of one complete character, including embedded images and custom mechanics.
/// Shared libraries, other characters, activity and interface preferences are intentionally excluded.
enum CharacterExport {
    static func data(for hero:Hero) throws -> Data {
        let archive=Archive(heroes:[hero],library:[])
        try validate(archive)
        let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
        return try encoder.encode(archive)
    }
}
