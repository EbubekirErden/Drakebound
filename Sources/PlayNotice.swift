import SwiftUI

struct PlayNotice:Identifiable {
    var id = UUID()
    var title:String
    var detail:String? = nil
    var heroID:UUID? = nil
    var activityID:UUID? = nil
    var reviewImport = false
}

extension Store {
    func notify(_ title:String,detail:String? = nil,heroID:UUID? = nil,activityID:UUID? = nil,reviewImport:Bool = false) {
        notice = PlayNotice(title:title,detail:detail,heroID:heroID,activityID:activityID,reviewImport:reviewImport)
    }
    var canUndoNotice:Bool {
        guard let notice,let id = notice.activityID,notice.heroID == selected,
              let hero = heroes.first(where:{ $0.id == selected }) else { return false }
        return canUndoActivity && activity.next(for:hero.id)?.id == id && activity.canUndo(hero)
    }
    func undoNotice() {
        captureActivity()
        guard canUndoNotice else { notice = nil; return }
        notice = nil
        undoActivity()
    }
}

struct PlayNoticeView:View {
    @ObservedObject var store:Store
    var notice:PlayNotice
    @State private var details = false
    var body:some View {
        HStack(spacing:12) {
            Image(systemName:"checkmark.circle.fill").foregroundStyle(accent)
            Text(notice.title).font(.system(size:12,weight:.medium)).fixedSize(horizontal:false,vertical:true)
            if store.canUndoNotice {
                Button("Undo") { store.undoNotice() }.buttonStyle(.plain).foregroundStyle(accent).fontWeight(.semibold)
            }
            if notice.reviewImport,notice.heroID == store.selected {
                Button("View review") { store.navigate(to:"Journal");store.notice = nil }.buttonStyle(.plain).foregroundStyle(accent)
            }
            if let detail = notice.detail {
                Button("Details") { details = true }.buttonStyle(.plain).foregroundStyle(accent)
                    .popover(isPresented:$details) {
                        ScrollView { Text(detail).font(.system(size:12)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading).padding(16) }.frame(width:340,height:180)
                    }
            }
            Button { store.notice = nil } label: { Image(systemName:"xmark").font(.system(size:10)) }
                .buttonStyle(.plain).accessibilityLabel("Dismiss notification")
        }.font(.system(size:12)).padding(12).background(surface,in:RoundedRectangle(cornerRadius:10))
            .overlay(RoundedRectangle(cornerRadius:10).stroke(ink.opacity(0.12)))
            .shadow(color:.black.opacity(0.12),radius:8,y:3).frame(maxWidth:560)
            .accessibilityElement(children:.contain)
            .task(id:details) {
                guard !details else { return }
                do { try await Task.sleep(nanoseconds:8_000_000_000) } catch { return }
                if store.notice?.id == notice.id && !details { store.notice = nil }
            }
    }
}
