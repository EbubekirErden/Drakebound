import AppKit
import SwiftUI

@MainActor final class DicePresenter {
    private var panel: NSPanel?
    private var currentID: UUID?
    func show(_ result:RollResult,onDismiss:@escaping ()->Void) {
        dismiss()
        NSApp.activate(ignoringOtherApps:true)
        currentID = result.id
        let panel = NSPanel(contentRect:.zero,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.title = "Dice result"
        panel.appearance = AppAppearance.selected.native
        panel.level = .popUpMenu
        panel.isFloatingPanel = true
        panel.worksWhenModal = true
        panel.hidesOnDeactivate = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.moveToActiveSpace,.fullScreenAuxiliary]
        let host = NSHostingView(rootView:DiceAnimation(roll:result,onDismiss:{ [weak self] in
            guard self?.currentID == result.id else { return }
            self?.dismiss(); onDismiss()
        }).fixedSize().preferredColorScheme(AppAppearance.selected.colorScheme))
        panel.contentView = host
        let size = host.fittingSize
        panel.setContentSize(size)
        let parent = NSApp.mainWindow ?? NSApp.keyWindow
        let screen = parent?.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x:0,y:0,width:1200,height:800)
        let anchor = parent?.frame ?? visible
        panel.setFrameOrigin(NSPoint(x:max(visible.minX+12,min(visible.maxX-size.width-12,anchor.maxX-size.width-22)),y:max(visible.minY+12,min(visible.maxY-size.height-12,anchor.minY+72))))
        self.panel = panel
        panel.orderFrontRegardless()
    }
    func dismiss() { currentID = nil; panel?.orderOut(nil); panel?.contentView = nil; panel?.close(); panel = nil }
}
