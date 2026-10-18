import AppKit
import ImageIO
import UniformTypeIdentifiers

enum LocalImage {
    static let cache = NSCache<NSData,NSImage>()
    static func display(_ data: Data?) -> NSImage? {
        guard let data else { return nil }
        let key = data as NSData
        if let image = cache.object(forKey:key) { return image }
        guard let image = NSImage(data:data) else { return nil }
        cache.countLimit = 40; cache.setObject(image,forKey:key); return image
    }
    static func normalize(_ data: Data) throws -> Data {
        guard data.count <= 25_000_000, let source = CGImageSourceCreateWithData(data as CFData,nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:1200] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output,UTType.png.identifier as CFString,1,nil) else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination,image,nil)
        guard CGImageDestinationFinalize(destination), output.length <= 5_000_000 else { throw CocoaError(.fileWriteOutOfSpace) }
        return output as Data
    }
    @MainActor static func choose() throws -> Data? {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.image]; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let size = try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
        guard size <= 25_000_000 else { throw CocoaError(.fileReadTooLarge) }
        return try normalize(Data(contentsOf:url))
    }
}
