import AppKit

// Draw the identity as resolution-independent paths so every Dock size stays crisp.
let folder = CommandLine.arguments[1]
let sidebarMark = CommandLine.arguments.dropFirst(2).contains("--sidebar-mark")
try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale, p = CGFloat(pixels)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x * p, y: y * p) }
        func polygon(_ points: [(CGFloat, CGFloat)]) -> NSBezierPath {
            let path = NSBezierPath()
            path.move(to: point(points[0].0, points[0].1))
            for (x, y) in points.dropFirst() { path.line(to: point(x, y)) }
            path.close()
            return path
        }
        func lines(_ segments: [((CGFloat, CGFloat), (CGFloat, CGFloat))], color: NSColor, width: CGFloat) {
            let path = NSBezierPath()
            for (a, b) in segments {
                path.move(to: point(a.0, a.1)); path.line(to: point(b.0, b.1))
            }
            path.lineWidth = width * p
            path.lineCapStyle = .round; path.lineJoinStyle = .round
            color.setStroke(); path.stroke()
        }
        if !sidebarMark {
        let tile = NSBezierPath(roundedRect: NSRect(x: p * 0.07, y: p * 0.07, width: p * 0.86, height: p * 0.86),
            xRadius: p * 0.19, yRadius: p * 0.19)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
        shadow.shadowBlurRadius = p * 0.03; shadow.shadowOffset = NSSize(width: 0, height: -p * 0.018)
        NSGraphicsContext.saveGraphicsState(); shadow.set()
        NSColor(red: 0.055, green: 0.12, blue: 0.15, alpha: 1).setFill(); tile.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(starting: NSColor(red: 0.13, green: 0.27, blue: 0.29, alpha: 1),
            ending: NSColor(red: 0.035, green: 0.075, blue: 0.11, alpha: 1))!.draw(in: tile, angle: -75)
        NSColor.white.withAlphaComponent(0.13).setStroke()
        tile.lineWidth = max(0.5, p * 0.002); tile.stroke()

        }
        let gold = NSColor(red: 0.91, green: 0.76, blue: 0.47, alpha: 1)
        let cage = polygon([(0.5, 0.835), (0.79, 0.665), (0.79, 0.335),
                            (0.5, 0.165), (0.21, 0.335), (0.21, 0.665)])
        if !sidebarMark { NSColor(red: 0.025, green: 0.075, blue: 0.095, alpha: 0.45).setFill(); cage.fill() }
        cage.lineWidth = p * 0.019; cage.lineJoinStyle = .round
        gold.setStroke(); cage.stroke()

        // The triangular d20 frame reads as a vaulted cage. Bars sit behind the dragon.
        lines([((0.5, 0.835), (0.35, 0.655)), ((0.5, 0.835), (0.65, 0.655)),
               ((0.21, 0.665), (0.35, 0.655)), ((0.79, 0.665), (0.65, 0.655)),
               ((0.35, 0.655), (0.29, 0.365)), ((0.65, 0.655), (0.71, 0.365)),
               ((0.21, 0.335), (0.29, 0.365)), ((0.79, 0.335), (0.71, 0.365)),
               ((0.29, 0.365), (0.5, 0.165)), ((0.71, 0.365), (0.5, 0.165)),
               ((0.29, 0.365), (0.71, 0.365))],
              color: gold.withAlphaComponent(0.7), width: pixels <= 32 ? 0.012 : 0.009)
        if pixels >= 64 {
            lines([((0.35, 0.655), (0.65, 0.655)),
                   ((0.405, 0.745), (0.365, 0.292)), ((0.595, 0.745), (0.635, 0.292))],
                  color: gold.withAlphaComponent(0.24), width: 0.006)
        }

        // A single heraldic dragon: swept wing, horned profile, and coiled tail.
        let dragon = NSBezierPath()
        dragon.move(to: point(0.535, 0.465))
        dragon.curve(to: point(0.49, 0.585), controlPoint1: point(0.475, 0.495), controlPoint2: point(0.465, 0.545))
        dragon.line(to: point(0.365, 0.715))
        dragon.curve(to: point(0.335, 0.465), controlPoint1: point(0.375, 0.625), controlPoint2: point(0.31, 0.555))
        dragon.curve(to: point(0.405, 0.505), controlPoint1: point(0.355, 0.505), controlPoint2: point(0.38, 0.52))
        dragon.line(to: point(0.405, 0.455))
        dragon.curve(to: point(0.465, 0.47), controlPoint1: point(0.425, 0.48), controlPoint2: point(0.45, 0.49))
        dragon.curve(to: point(0.44, 0.385), controlPoint1: point(0.5, 0.425), controlPoint2: point(0.49, 0.405))
        dragon.curve(to: point(0.39, 0.35), controlPoint1: point(0.405, 0.375), controlPoint2: point(0.385, 0.365))
        dragon.curve(to: point(0.58, 0.345), controlPoint1: point(0.395, 0.29), controlPoint2: point(0.545, 0.285))
        dragon.curve(to: point(0.535, 0.465), controlPoint1: point(0.625, 0.405), controlPoint2: point(0.56, 0.435))
        dragon.close()
        // Upright neck flows into the hooked jaw and two backswept horns.
        let neck = NSBezierPath()
        neck.move(to: point(0.50, 0.425))
        neck.curve(to: point(0.535, 0.605), controlPoint1: point(0.575, 0.48), controlPoint2: point(0.48, 0.55))
        neck.line(to: point(0.51, 0.70))
        neck.line(to: point(0.575, 0.655))
        neck.line(to: point(0.61, 0.70))
        neck.line(to: point(0.615, 0.64))
        neck.line(to: point(0.675, 0.595))
        neck.line(to: point(0.665, 0.555))
        neck.line(to: point(0.61, 0.555))
        neck.line(to: point(0.635, 0.535))
        neck.line(to: point(0.585, 0.53))
        neck.curve(to: point(0.565, 0.425), controlPoint1: point(0.565, 0.515), controlPoint2: point(0.61, 0.47))
        neck.close()
        dragon.append(neck.reversed)
        // Dark separation keeps the silhouette readable where it crosses the bars.
        NSColor(red: 0.035, green: 0.10, blue: 0.12, alpha: 1).setStroke()
        dragon.lineWidth = p * 0.022; dragon.lineJoinStyle = .round; dragon.stroke()
        NSGradient(starting: NSColor(red: 0.99, green: 0.88, blue: 0.62, alpha: 1),
            ending: gold)!.draw(in: dragon, angle: -90)
        if pixels >= 64 {
            let curl = NSBezierPath()
            curl.move(to: point(0.422, 0.346))
            curl.curve(to: point(0.537, 0.36), controlPoint1: point(0.47, 0.324), controlPoint2: point(0.535, 0.332))
            curl.curve(to: point(0.505, 0.391), controlPoint1: point(0.542, 0.383), controlPoint2: point(0.525, 0.397))
            curl.lineWidth = p * 0.014; curl.lineCapStyle = .round
            NSColor(red: 0.035, green: 0.10, blue: 0.12, alpha: 1).setStroke(); curl.stroke()
        }
        if pixels >= 32 {
            let eye = polygon([(0.591, 0.605), (0.618, 0.597), (0.597, 0.582)])
            NSColor(red: 0.025, green: 0.10, blue: 0.12, alpha: 1).setFill(); eye.fill()
        }
        if pixels >= 64 {
            lines([((0.375, 0.66), (0.452, 0.51))],
                  color: NSColor(red: 0.32, green: 0.27, blue: 0.15, alpha: 0.65), width: 0.007)
        }
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try rep.representation(using: .png, properties: [:])!.write(
            to: URL(fileURLWithPath: "\(folder)/icon_\(size)x\(size)\(suffix).png"))
    }
}
