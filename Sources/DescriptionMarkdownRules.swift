import Foundation

// Keep the stored description as plain Markdown; list editing never rewrites other paragraphs.
enum DescriptionMarkdown {
    static func newline(in text:String,selection:NSRange) -> (range:NSRange,text:String)? {
        let source=text as NSString
        guard selection.length == 0,selection.location <= source.length else { return nil }
        let before=source.substring(to:selection.location) as NSString
        let start=before.range(of:"\n",options:.backwards).location
        let offset=start == NSNotFound ? 0:start+1
        let line=source.substring(with:NSRange(location:offset,length:selection.location-offset))
        let indentation=String(line.prefix { $0 == " " || $0 == "\t" })
        let body=String(line.dropFirst(indentation.count))
        guard body.hasPrefix("- ") || body.hasPrefix("* ") || body.hasPrefix("+ ") else { return nil }
        let marker=String(body.prefix(2))
        if body.dropFirst(2).trimmingCharacters(in:.whitespaces).isEmpty {
            return (NSRange(location:offset,length:selection.location-offset),"")
        }
        return (selection,"\n"+indentation+marker)
    }
    static func attributed(_ text:String) -> AttributedString {
        let visible=text.components(separatedBy:"\n").map(displayLine).joined(separator:"\n")
        return (try? AttributedString(markdown:visible,options:.init(interpretedSyntax:.inlineOnlyPreservingWhitespace))) ?? AttributedString(visible)
    }
    static func displayLine(_ line:String) -> String {
        let trimmed=line.trimmingCharacters(in:.whitespaces)
        if ["- ","* ","+ "].contains(where:{ trimmed.hasPrefix($0) }) { return "• "+trimmed.dropFirst(2) }
        return line
    }
}

