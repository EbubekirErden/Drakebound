import Foundation
@main struct DescriptionMarkdownTests {
 static func main() {
  func edit(_ s:String,_ at:Int? = nil) -> (range:NSRange,text:String)? { DescriptionMarkdown.newline(in:s,selection:NSRange(location:at ?? (s as NSString).length,length:0)) }
  assert(edit("- first")?.text == "\n- ")
  assert(edit("  * first")?.text == "\n  * ")
  assert(edit("+ café 🐉")?.text == "\n+ ")
  assert(edit("Before\n- first")?.text == "\n- ")
  assert(edit("- ")?.range == NSRange(location:0,length:2))
  assert(edit("Before\n  - ")?.range == NSRange(location:7,length:4))
  assert(edit("- ")?.text == "")
  assert(edit("ordinary text") == nil)
  assert(edit("---") == nil)
  assert(DescriptionMarkdown.newline(in:"- first",selection:NSRange(location:2,length:3)) == nil)
  assert(edit("🐉",50) == nil)
  assert(DescriptionMarkdown.displayLine("- **first**") == "• **first**")
  assert(DescriptionMarkdown.displayLine("Ordinary") == "Ordinary")
  print("PASS: Markdown bullet continuation, empty-list exit, indentation, Unicode, selections and display")
 }
}
