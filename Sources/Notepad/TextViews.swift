import AppKit

/// The editing view. Dropping files on it opens them (in new tabs) instead of inserting their paths.
final class NotepadTextView: NSTextView {
    private func droppedFileURLs(_ info: NSDraggingInfo) -> [URL] {
        let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                       options: [.urlReadingFileURLsOnly: true]) as? [URL]
        return urls ?? []
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedFileURLs(sender).isEmpty ? super.draggingEntered(sender) : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedFileURLs(sender).isEmpty ? super.draggingUpdated(sender) : .copy
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        droppedFileURLs(sender).isEmpty ? super.prepareForDragOperation(sender) : true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = droppedFileURLs(sender)
        guard !urls.isEmpty else { return super.performDragOperation(sender) }
        // Make this window the target so the files open as tabs here.
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        for url in urls where !url.hasDirectoryPath {
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
                if let error { NSApp.presentError(error) }
            }
        }
        return true
    }
}

/// Line numbers down the left of the text. Wrapped lines get one number, on their first row.
final class LineNumberRuler: NSRulerView {
    private weak var textView: NSTextView?
    private var lineStarts: [Int] = [0]   // character offset where each line begins

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        recount()

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(redraw),
                                               name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        textView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(redraw),
                                               name: NSView.frameDidChangeNotification, object: textView)
    }

    required init(coder: NSCoder) { fatalError() }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func redraw() { needsDisplay = true }

    /// Call after the text changes.
    func textChanged() {
        recount()
        needsDisplay = true
    }

    /// Call after the font changes.
    func fontChanged() {
        updateThickness()
        needsDisplay = true
    }

    private var numberFont: NSFont {
        let base = textView?.font ?? Settings.font
        return NSFont(descriptor: base.fontDescriptor, size: max(9, base.pointSize * 0.85)) ?? base
    }

    private func recount() {
        guard let s = textView?.string as NSString? else { return }
        var starts = [0]
        var i = 0
        let len = s.length
        while i < len {
            let c = s.character(at: i)
            if c == 10 {                                   // \n
                starts.append(i + 1)
            } else if c == 13 {                            // \r or \r\n
                if i + 1 < len, s.character(at: i + 1) == 10 { i += 1 }
                starts.append(i + 1)
            }
            i += 1
        }
        lineStarts = starts
        updateThickness()
    }

    private func updateThickness() {
        let digits = max(3, String(lineStarts.count).count)
        let w = ("8" as NSString).size(withAttributes: [.font: numberFont]).width
        let thickness = ceil(CGFloat(digits) * w + 18)
        if abs(ruleThickness - thickness) > 0.5 { ruleThickness = thickness }
    }

    /// Index of the line containing character offset `loc` (binary search).
    private func lineIndex(for loc: Int) -> Int {
        var lo = 0, hi = lineStarts.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if lineStarts[mid] <= loc { lo = mid } else { hi = mid - 1 }
        }
        return lo
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.textBackgroundColor.setFill()
        bounds.fill()
        NSColor.separatorColor.setFill()
        NSRect(x: bounds.maxX - 1, y: bounds.minY, width: 1, height: bounds.height).fill()
        drawHashMarksAndLabels(in: dirtyRect)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let tv = textView, let lm = tv.layoutManager, let tc = tv.textContainer,
              let sv = scrollView else { return }
        let s = tv.string as NSString
        let visible = sv.contentView.bounds
        let attrs: [NSAttributedString.Key: Any] = [.font: numberFont, .foregroundColor: NSColor.secondaryLabelColor]
        let numberHeight = ("8" as NSString).size(withAttributes: attrs).height

        func drawNumber(_ n: Int, fragmentRect: NSRect) {
            let yInText = fragmentRect.minY + tv.textContainerOrigin.y
            let y = convert(NSPoint(x: 0, y: yInText), from: tv).y
            let label = String(n) as NSString
            let size = label.size(withAttributes: attrs)
            let top = y + (fragmentRect.height - numberHeight) / 2
            label.draw(at: NSPoint(x: ruleThickness - size.width - 8, y: top), withAttributes: attrs)
        }

        if s.length > 0 {
            let glyphs = lm.glyphRange(forBoundingRect: visible, in: tc)
            let chars = lm.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            var line = lineIndex(for: chars.location)
            while line < lineStarts.count {
                let start = lineStarts[line]
                if start >= s.length { break }               // empty last line: handled below
                if start > NSMaxRange(chars) { break }
                let glyph = lm.glyphIndexForCharacter(at: start)
                let frag = lm.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
                drawNumber(line + 1, fragmentRect: frag)
                line += 1
            }
        }
        // The empty line after a final line break (or an empty document).
        let lastStart = lineStarts.last ?? 0
        if lastStart >= s.length {
            var frag = lm.extraLineFragmentRect
            if frag.height == 0 {
                frag = NSRect(x: 0, y: 0, width: 0, height: lm.defaultLineHeight(for: tv.font ?? Settings.font))
            }
            drawNumber(lineStarts.count, fragmentRect: frag)
        }
    }
}
