import SwiftUI

// Measure each row at its final column width, then give every cell that row's height.
// This avoids height preferences feeding another layout pass when cards wrap text.
struct EqualHeightGridLayout:Layout {
    var minimumColumnWidth:CGFloat = 240
    var columns:Int? = nil
    var spacing:CGFloat = 8
    private func arrangement(width:CGFloat,subviews:Subviews)->(height:CGFloat,cells:[CGRect]) {
        guard !subviews.isEmpty else { return (0,[]) }
        let count=min(subviews.count,max(1,columns ?? Int((width+spacing)/(minimumColumnWidth+spacing))))
        let cellWidth=max(0,(width-CGFloat(count-1)*spacing)/CGFloat(count))
        var cells:[CGRect]=[],y:CGFloat=0
        for start in stride(from:0,to:subviews.count,by:count) {
            let end=min(start+count,subviews.count)
            let height=(start..<end).map { subviews[$0].sizeThatFits(ProposedViewSize(width:cellWidth,height:nil)).height }.max() ?? 0
            for index in start..<end { cells.append(CGRect(x:CGFloat(index-start)*(cellWidth+spacing),y:y,width:cellWidth,height:height)) }
            y += height+spacing
        }
        return (max(0,y-spacing),cells)
    }
    func sizeThatFits(proposal:ProposedViewSize,subviews:Subviews,cache:inout ())->CGSize {
        let proposed=proposal.width ?? minimumColumnWidth
        let width=proposed.isFinite ? max(1,proposed):minimumColumnWidth
        return CGSize(width:width,height:arrangement(width:width,subviews:subviews).height)
    }
    func placeSubviews(in bounds:CGRect,proposal:ProposedViewSize,subviews:Subviews,cache:inout ()) {
        let cells=arrangement(width:max(1,bounds.width),subviews:subviews).cells
        for index in subviews.indices {
            let cell=cells[index]
            subviews[index].place(at:CGPoint(x:bounds.minX+cell.minX,y:bounds.minY+cell.minY),anchor:.topLeading,proposal:ProposedViewSize(cell.size))
        }
    }
}
