import SwiftUI
import AppKit

enum AppAppearance: String, CaseIterable {
    case dark, light, system
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? { self == .system ? nil : self == .light ? .light : .dark }
    var native: NSAppearance? { self == .system ? nil : NSAppearance(named:self == .light ? .aqua : .darkAqua) }
    static var selected: AppAppearance { AppAppearance(rawValue:UserDefaults.standard.string(forKey:"appAppearance") ?? "dark") ?? .dark }
}

// Dynamic colors resolve in each window's appearance, including native popovers and sheets.
func appearanceColor(_ name:String, dark:(Double,Double,Double), light:(Double,Double,Double)) -> Color {
    Color(nsColor:NSColor(name:NSColor.Name("Drakebound."+name)) { appearance in
        let values = appearance.bestMatch(from:[.aqua,.darkAqua]) == .darkAqua ? dark : light
        return NSColor(srgbRed:values.0,green:values.1,blue:values.2,alpha:1)
    })
}
let ink = appearanceColor("ink",dark:(0.89,0.90,0.89),light:(0.14,0.18,0.20))
let accent = appearanceColor("accent",dark:(0.43,0.75,0.68),light:(0.12,0.42,0.36))
let paper = appearanceColor("paper",dark:(0.105,0.125,0.14),light:(0.88,0.90,0.88))
let surface = appearanceColor("surface",dark:(0.145,0.165,0.18),light:(0.93,0.94,0.92))
let gold = appearanceColor("gold",dark:(0.88,0.69,0.42),light:(0.49,0.33,0.10))
let sky = appearanceColor("sky",dark:(0.50,0.71,0.88),light:(0.16,0.39,0.60))
let coral = appearanceColor("coral",dark:(0.89,0.54,0.47),light:(0.65,0.26,0.20))
let leaf = appearanceColor("leaf",dark:(0.49,0.76,0.52),light:(0.22,0.43,0.24))
let journalTint = appearanceColor("journal",dark:(0.76,0.61,0.70),light:(0.49,0.31,0.43))

// Text over banner images follows the banner's theme-specific scrim.
let bannerInk = appearanceColor("bannerInk",dark:(1,1,1),light:(0.14,0.18,0.20))
let bannerControls = appearanceColor("bannerControls",dark:(0,0,0),light:(0.93,0.94,0.92))
