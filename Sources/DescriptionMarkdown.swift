import SwiftUI
import AppKit

struct DescriptionText:View {
    var text:String
    var body:some View {
        Text(DescriptionMarkdown.attributed(text)).font(.system(size:13)).lineSpacing(4).textSelection(.enabled).fixedSize(horizontal:false,vertical:true).frame(maxWidth:.infinity,alignment:.leading)
    }
}

struct MarkdownInput:NSViewRepresentable {
    @Binding var text:String
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context:Context) -> NSScrollView {
        let scroll=NSScrollView();scroll.drawsBackground=false;scroll.hasVerticalScroller=true
        let view=MarkdownTextView(frame:.zero)
        view.isRichText=false;view.importsGraphics=false;view.allowsUndo=true;view.drawsBackground=false
        view.font=NSFont.systemFont(ofSize:12);view.textColor=NSColor(ink);view.insertionPointColor=NSColor(ink)
        view.isAutomaticQuoteSubstitutionEnabled=false;view.isAutomaticDashSubstitutionEnabled=false
        view.isVerticallyResizable=true;view.isHorizontallyResizable=false;view.autoresizingMask = .width
        view.minSize = .zero;view.maxSize=NSSize(width:CGFloat.greatestFiniteMagnitude,height:CGFloat.greatestFiniteMagnitude)
        view.textContainer?.containerSize=NSSize(width:0,height:CGFloat.greatestFiniteMagnitude);view.textContainer?.widthTracksTextView=true
        view.textContainerInset=NSSize(width:2,height:3);view.string=text;view.delegate=context.coordinator;context.coordinator.view=view
        view.setAccessibilityLabel("Description, Markdown supported")
        scroll.documentView=view;return scroll
    }
    func updateNSView(_ scroll:NSScrollView,context:Context) {
        context.coordinator.parent=self
        guard let view=scroll.documentView as? NSTextView,view.string != text else { return }
        let range=view.selectedRange();view.string=text;view.setSelectedRange(NSRange(location:min(range.location,(text as NSString).length),length:0))
    }
    final class Coordinator:NSObject,NSTextViewDelegate {
        var parent:MarkdownInput
        weak var view:NSTextView?
        private var undoObservers:[NSObjectProtocol] = []
        init(_ parent:MarkdownInput) {
            self.parent=parent
            super.init()
            // NSTextView's undo can update its storage without the usual editing delegate callback.
            for name in [Notification.Name.NSUndoManagerDidUndoChange,Notification.Name.NSUndoManagerDidRedoChange] {
                undoObservers.append(NotificationCenter.default.addObserver(forName:name,object:nil,queue:.main) { [weak self] notification in
                    guard let self,let view=self.view,let manager=notification.object as? UndoManager,manager === view.undoManager else { return }
                    self.parent.text=view.string
                })
            }
        }
        deinit { for observer in undoObservers { NotificationCenter.default.removeObserver(observer) } }
        func textDidChange(_ notification:Notification) { if let view=notification.object as? NSTextView { parent.text=view.string } }
    }
}
final class MarkdownTextView:NSTextView {
    override func insertNewline(_ sender:Any?) {
        guard let edit=DescriptionMarkdown.newline(in:string,selection:selectedRange()) else { super.insertNewline(sender);return }
        insertText(edit.text,replacementRange:edit.range)
    }
}
