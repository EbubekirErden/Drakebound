import SwiftUI
import AppKit

extension AppBrand {
    static func showRulesCredits() {
        let controller=NSHostingController(rootView:SRDCredits())
        let window=NSWindow(contentViewController:controller)
        window.title="Included rules & attribution";window.setContentSize(NSSize(width:660,height:540));window.center()
        window.isReleasedWhenClosed=false
        let controllerWindow=NSWindowController(window:window);controllerWindow.showWindow(nil)
        NSApp.activate(ignoringOtherApps:true)
        creditsWindow=controllerWindow
    }
    private static var creditsWindow:NSWindowController?
}
private struct SRDCredits:View {
    private var notice:String {
        guard let url=Bundle.main.resourceURL?.appendingPathComponent("SRD/ATTRIBUTION.txt"),let text=try? String(contentsOf:url,encoding:.utf8) else { return "SRD content is licensed under CC BY 4.0. See https://www.dndbeyond.com/srd." }
        return text
    }
    var body:some View {
        ScrollView { Text(notice).font(.system(size:13)).lineSpacing(4).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading).padding(24) }
    }
}
