import AppKit
import ImageIO

@main struct ImageTests {
    static func main() throws {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1800,pixelsHigh:900,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        let png = bitmap.representation(using:.png,properties:[:])!
        let normalized = try LocalImage.normalize(png)
        let source = CGImageSourceCreateWithData(normalized as CFData,nil)!
        let properties = CGImageSourceCopyPropertiesAtIndex(source,0,nil)! as NSDictionary
        assert(properties[kCGImagePropertyPixelWidth] as! Int == 1200)
        assert(properties[kCGImagePropertyPixelHeight] as! Int == 600)
        assert(normalized.count <= 5_000_000)
        assert(LocalImage.display(normalized) != nil)
        do { _ = try LocalImage.normalize(Data("not an image".utf8)); fatalError("Accepted invalid image") } catch { }
        print("PASS: image decode, resize, PNG conversion, caching, and invalid-image rejection")
    }
}
