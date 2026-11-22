import AppKit

/// Paints the title bar (the strip with the window name and the traffic lights) with the
/// app icon's blue gradient. AppKit has no setting for this, so a gradient view is slotted
/// into the title bar just above its own background and below the title and buttons.
/// The tab bar underneath is left in the normal system grey.
enum TitleBarTint {
    static func apply(to window: NSWindow?) {
        guard let frameView = window?.contentView?.superview,
              let titlebar = find("NSTitlebarView", in: frameView),
              let background = titlebar.subviews.first(where: { name($0) == "NSTitlebarBackgroundView" })
        else { return }

        // Title strip = the title bar minus the tab bar accessory along its bottom.
        let accessoryHeight = titlebar.subviews
            .filter { $0.subviews.contains { name($0) == "NSTitlebarAccessoryContainerView" } }
            .map(\.frame.height).max() ?? 0
        let strip = NSRect(x: 0, y: accessoryHeight, width: titlebar.bounds.width,
                           height: titlebar.bounds.height - accessoryHeight)

        if let existing = titlebar.subviews.first(where: { $0 is GradientView }) {
            if existing.frame != strip { existing.frame = strip }
            existing.needsDisplay = true
            return
        }
        // Sit above the background and its blur layer, below the title text and buttons.
        let index = titlebar.subviews.firstIndex(of: background)!
        let next = titlebar.subviews.dropFirst(index + 1).first
        let anchor = (next?.layer.map { "\(type(of: $0))" } == "CABackdropLayer") ? next! : background
        let gradient = GradientView(frame: strip)
        gradient.autoresizingMask = [.width, .minYMargin]
        titlebar.addSubview(gradient, positioned: .above, relativeTo: anchor)
    }

    private static func name(_ v: NSView) -> String { NSStringFromClass(type(of: v)) }

    private static func find(_ className: String, in view: NSView) -> NSView? {
        if name(view) == className { return view }
        for sub in view.subviews {
            if let hit = find(className, in: sub) { return hit }
        }
        return nil
    }

    final class GradientView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }   // dragging the window still works

        override func draw(_ dirtyRect: NSRect) {
            let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            // Icon colours: light blue at the top to deeper blue at the bottom; kept light
            // enough in Light Mode for the black title text, navy in Dark Mode for white text.
            let top = dark ? NSColor(calibratedRed: 0.17, green: 0.38, blue: 0.72, alpha: 1)
                           : NSColor(calibratedRed: 0.66, green: 0.85, blue: 1.0, alpha: 1)
            let bottom = dark ? NSColor(calibratedRed: 0.05, green: 0.18, blue: 0.46, alpha: 1)
                              : NSColor(calibratedRed: 0.36, green: 0.62, blue: 0.94, alpha: 1)
            NSGradient(starting: bottom, ending: top)?.draw(in: bounds, angle: isFlipped ? -90 : 90)
        }
    }
}
