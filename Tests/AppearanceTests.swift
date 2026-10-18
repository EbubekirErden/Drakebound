import AppKit
import SwiftUI

@main struct AppearanceTests {
    static func rgb(_ color:Color,_ appearance:NSAppearance) -> NSColor {
        var result:NSColor!
        appearance.performAsCurrentDrawingAppearance { result = NSColor(color).usingColorSpace(.sRGB)! }
        return result
    }
    static func contrast(_ a:NSColor,_ b:NSColor) -> Double {
        func lum(_ c:NSColor) -> Double {
            let channels:[Double] = [Double(c.redComponent),Double(c.greenComponent),Double(c.blueComponent)]
            let v:[Double] = channels
                .map { $0 <= 0.04045 ? $0/12.92:pow(($0+0.055)/1.055,2.4) }
            return v[0]*0.2126+v[1]*0.7152+v[2]*0.0722
        }
        let x=lum(a),y=lum(b);return (max(x,y)+0.05)/(min(x,y)+0.05)
    }
    static func main() throws {
        _ = NSApplication.shared
        defer { NSApp.appearance = nil }
        for mode in [AppAppearance.dark,.light] {
            NSApp.appearance = mode.native
            let appearance=mode.native!
            for background in [paper,surface] {
                for foreground in [ink,accent,gold,sky,coral,leaf,journalTint] {
                    let ratio=contrast(rgb(foreground,appearance),rgb(background,appearance))
                    assert(ratio >= 4.5,"Insufficient palette contrast in \(mode): \(ratio)")
                }
            }
            let original=NSMutableAttributedString(string:"Pasted rich note",attributes:[.font:NSFont.boldSystemFont(ofSize:13),.foregroundColor:mode == .dark ? NSColor.black:NSColor.white])
            original.addAttribute(.link,value:URL(string:"https://example.com")!,range:NSRange(location:0,length:6))
            let data=try original.data(from:NSRange(location:0,length:original.length),documentAttributes:[.documentType:NSAttributedString.DocumentType.rtf])
            let rendered=JournalText.read(data,plain:original.string)
            assert(rendered.string == original.string)
            assert(rendered.attribute(.link,at:0,effectiveRange:nil) != nil)
            let foreground=(rendered.attribute(.foregroundColor,at:0,effectiveRange:nil) as! NSColor).usingColorSpace(.sRGB)!
            assert(contrast(foreground,rgb(surface,appearance)) >= 4.5)
            assert(NSFontManager.shared.traits(of:rendered.attribute(.font,at:0,effectiveRange:nil) as! NSFont).contains(.boldFontMask))
            assert(JournalText.read(JournalText.write(rendered),plain:original.string).string == original.string)
        }
        // Render with an explicit SwiftUI scheme even while the app appearance is transitioning.
        NSApp.appearance = NSAppearance(named:.aqua)
        let darkText=JournalText.read(nil,plain:"Same note",dark:true)
        assert((darkText.attribute(.foregroundColor,at:0,effectiveRange:nil) as! NSColor).isEqual(JournalText.color(dark:true)))
        NSApp.appearance = NSAppearance(named:.darkAqua)
        let lightText=JournalText.read(nil,plain:"Same note",dark:false)
        assert((lightText.attribute(.foregroundColor,at:0,effectiveRange:nil) as! NSColor).isEqual(JournalText.color(dark:false)))
        assert(AppAppearance.system.colorScheme == nil && AppAppearance.system.native == nil)
        print("Appearance palettes and rich text contrast passed in Light and Dark; no Store or live files used.")
    }
}
