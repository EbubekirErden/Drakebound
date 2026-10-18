import AppKit

// RTF is optional; the plain description remains the searchable, portable fallback.
enum JournalText {
    static var font:NSFont { .systemFont(ofSize:13) }
    static var color:NSColor { NSColor(calibratedRed:0.89,green:0.90,blue:0.89,alpha:1) }
    static var attributes:[NSAttributedString.Key:Any] {
        let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 4; paragraph.paragraphSpacing = 6
        return [.font:font,.foregroundColor:color,.paragraphStyle:paragraph]
    }
    static func readableFont(_ original:NSFont?) -> NSFont {
        guard let original else { return font }
        let traits = NSFontManager.shared.traits(of:original)
        let size = original.pointSize < 18 ? font.pointSize:original.pointSize
        let base = traits.contains(.fixedPitchFontMask) ? NSFont.monospacedSystemFont(ofSize:size,weight:.regular):NSFont.systemFont(ofSize:size)
        return NSFontManager.shared.convert(base,toHaveTrait:traits.intersection([.boldFontMask,.italicFontMask]))
    }
    static func ensureReadableTypography(_ text:NSMutableAttributedString) {
        let range = NSRange(location:0,length:text.length)
        var fonts:[(NSRange,NSFont)] = []
        text.enumerateAttribute(.font,in:range) { value,part,_ in fonts.append((part,readableFont(value as? NSFont))) }
        for (part,font) in fonts { text.addAttribute(.font,value:font,range:part) }
        var paragraphs:[(NSRange,NSParagraphStyle)] = []
        text.enumerateAttribute(.paragraphStyle,in:range) { value,part,_ in
            let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            style.lineSpacing = max(4,style.lineSpacing)
            style.paragraphSpacing = max(6,style.paragraphSpacing)
            paragraphs.append((part,style))
        }
        for (part,style) in paragraphs { text.addAttribute(.paragraphStyle,value:style,range:part) }
    }
    // Pasted RTF can carry fixed black ink even though the editor uses a dark surface.
    static func readableColor(_ input:NSColor?) -> NSColor {
        guard let input else { return color }
        var rgb:NSColor?
        NSAppearance(named:.darkAqua)!.performAsCurrentDrawingAppearance { rgb = input.usingColorSpace(.sRGB) }
        guard let rgb else { return color }
        let background:[CGFloat] = [0.105,0.125,0.14]
        func luminance(_ values:[CGFloat]) -> CGFloat {
            let linear = values.map { $0 <= 0.04045 ? $0/12.92:pow(($0+0.055)/1.055,2.4) }
            return linear[0]*0.2126+linear[1]*0.7152+linear[2]*0.0722
        }
        let visible = zip([rgb.redComponent,rgb.greenComponent,rgb.blueComponent],background).map { $0*rgb.alphaComponent+$1*(1-rgb.alphaComponent) }
        let foreground = luminance(visible), surface = luminance(background)
        let contrast = (max(foreground,surface)+0.05)/(min(foreground,surface)+0.05)
        return contrast >= 4.5 ? input:color
    }
    static func ensureReadableColors(_ text:NSMutableAttributedString) {
        var changes:[(NSRange,NSColor)] = []
        text.enumerateAttribute(.foregroundColor,in:NSRange(location:0,length:text.length)) { value,range,_ in
            let original = value as? NSColor
            let readable = readableColor(original)
            if original == nil || !readable.isEqual(original) { changes.append((range,readable)) }
        }
        for (range,color) in changes { text.addAttribute(.foregroundColor,value:color,range:range) }
    }
    static func read(_ data:Data?,plain:String) -> NSAttributedString {
        if let data,data.count <= 5_000_000,let text = try? NSAttributedString(data:data,options:[.documentType:NSAttributedString.DocumentType.rtf],documentAttributes:nil),text.string == plain {
            let result = NSMutableAttributedString(attributedString:text)
            result.removeAttribute(.attachment,range:NSRange(location:0,length:result.length))
            ensureReadableColors(result)
            ensureReadableTypography(result)
            return result
        }
        return NSAttributedString(string:plain,attributes:attributes)
    }
    static func write(_ text:NSAttributedString) -> Data? {
        let clean = NSMutableAttributedString(attributedString:text)
        clean.removeAttribute(.attachment,range:NSRange(location:0,length:clean.length))
        ensureReadableColors(clean)
        ensureReadableTypography(clean)
        return try? clean.data(from:NSRange(location:0,length:clean.length),documentAttributes:[.documentType:NSAttributedString.DocumentType.rtf])
    }
    static func link(_ value:String) -> URL? {
        guard let url = URL(string:value.trimmingCharacters(in:.whitespacesAndNewlines)),["https","http","mailto"].contains(url.scheme?.lowercased() ?? ""),url.scheme == "mailto" || !(url.host ?? "").isEmpty else { return nil }
        return url
    }
    static func paragraphs(_ text:String,selection:NSRange) -> NSRange {
        let ns = text as NSString
        let location = min(selection.location,ns.length)
        // A selection ending at the next paragraph's start excludes that paragraph.
        let length = min(selection.length,max(0,ns.length-location))
        return ns.paragraphRange(for:NSRange(location:location,length:length > 0 ? length-1:0))
    }
    static func listPrefix(_ line:String) -> (prefix:String,body:String,next:String)? {
        for marker in ["• ","☐ ","☑ "] where line.hasPrefix(marker) { return (marker,String(line.dropFirst(marker.count)),marker == "☑ " ? "☐ ":marker) }
        guard let regex = try? NSRegularExpression(pattern:"^([0-9]{1,6})\\. "),let match = regex.firstMatch(in:line,range:NSRange(location:0,length:(line as NSString).length)),let number = Int((line as NSString).substring(with:match.range(at:1))) else { return nil }
        let prefix = (line as NSString).substring(with:match.range)
        return (prefix,String(line.dropFirst(prefix.count)),"\(number+1). ")
    }
    static func list(_ text:NSAttributedString,selection:NSRange,kind:String) -> (NSAttributedString,NSRange) {
        let result = NSMutableAttributedString(attributedString:text)
        let range = paragraphs(text.string,selection:selection)
        let selected = text.attributedSubstring(from:range)
        let lines = selected.string.components(separatedBy:"\n")
        var offset = 0; var number = 1
        let replacement = NSMutableAttributedString(string:"")
        let allMarked = lines.contains { !$0.isEmpty } && lines.filter { !$0.isEmpty }.allSatisfy { line in
            guard let prefix = listPrefix(line)?.prefix else { return false }
            return kind == "bullet" ? prefix == "• ":kind == "check" ? prefix == "☐ " || prefix == "☑ ":prefix.first?.isNumber == true
        }
        for (index,line) in lines.enumerated() {
            if index == lines.count-1 && line.isEmpty && index > 0 { break }
            let original = selected.attributedSubstring(from:NSRange(location:offset,length:(line as NSString).length))
            let old = listPrefix(line)
            let bodyStart = old.map { ($0.prefix as NSString).length } ?? 0
            let body = original.attributedSubstring(from:NSRange(location:bodyStart,length:original.length-bodyStart))
            let marker = allMarked ? "":kind == "bullet" ? "• ":kind == "check" ? "☐ ":"\(number). "
            replacement.append(NSAttributedString(string:marker,attributes:original.length > 0 ? original.attributes(at:0,effectiveRange:nil):attributes))
            replacement.append(body)
            if index < lines.count-1 { replacement.append(NSAttributedString(string:"\n",attributes:attributes)) }
            offset += original.length+1; number += 1
        }
        result.replaceCharacters(in:range,with:replacement)
        return (result,NSRange(location:range.location,length:replacement.length))
    }
}
