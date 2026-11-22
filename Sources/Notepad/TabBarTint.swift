import AppKit

/// Tints the system tab bar with the app icon's blue gradient.
/// AppKit has no setting for the tab bar's colour, so a see-through gradient view is laid
/// over it. It ignores the mouse, so tabs, the + button and tab dragging work as normal.
enum TabBarTint {
    static func apply(to window: NSWindow?) {
        guard let frameView = window?.contentView?.superview,
              let tabBar = find(className: "NSTabBar", in: frameView) else { return }
        if let existing = tabBar.subviews.last as? TintView { existing.needsDisplay = true; return }
        tabBar.subviews.filter { $0 is TintView }.forEach { $0.removeFromSuperview() }  // keep ours on top
        let tint = TintView(frame: tabBar.bounds)
        tint.autoresizingMask = [.width, .height]
        tabBar.addSubview(tint, positioned: .above, relativeTo: nil)
    }

    private static func find(className: String, in view: NSView) -> NSView? {
        if NSStringFromClass(type(of: view)) == className { return view }
        for sub in view.subviews {
            if let hit = find(className: className, in: sub) { return hit }
        }
        return nil
    }

    final class TintView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }   // clicks go through

        override func draw(_ dirtyRect: NSRect) {
            let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let alpha: CGFloat = dark ? 0.55 : 0.6
            // Same colours as the icon tile: light blue at the top to deeper blue at the bottom.
            let top = NSColor(calibratedRed: 0.55, green: 0.80, blue: 1.0, alpha: alpha)
            let bottom = NSColor(calibratedRed: 0.08, green: 0.33, blue: 0.80, alpha: alpha)
            // Tab bar is flipped or not depending on the OS; draw by explicit top/bottom.
            NSGradient(starting: bottom, ending: top)?.draw(in: bounds, angle: isFlipped ? -90 : 90)
        }
    }
}
