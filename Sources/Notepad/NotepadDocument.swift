import AppKit

final class NotepadDocument: NSDocument, NSTextViewDelegate {
    private var text = ""
    private var encoding: String.Encoding = .utf8
    private var textView: NSTextView!
    private var scrollView: NSScrollView!
    private var statusBar: StatusBar!

    override class var autosavesInPlace: Bool { false }
    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool { true }

    // MARK: Window

    override func makeWindowControllers() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.minSize = NSSize(width: 240, height: 160)

        scrollView = NSScrollView(frame: window.contentView!.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        let tv = NSTextView(frame: scrollView.bounds)
        tv.isRichText = false
        tv.importsGraphics = false
        tv.allowsUndo = true
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.isGrammarCheckingEnabled = false
        tv.smartInsertDeleteEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        tv.textContainerInset = NSSize(width: 2, height: 2)
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.autoresizingMask = [.width]
        // System colours: white in Light Mode, dark in Dark Mode, switching live.
        tv.drawsBackground = true
        tv.backgroundColor = .textBackgroundColor
        tv.insertionPointColor = .textColor
        scrollView.backgroundColor = .textBackgroundColor
        tv.font = Settings.font
        tv.string = text
        tv.textColor = .textColor
        tv.typingAttributes[.foregroundColor] = NSColor.textColor
        tv.delegate = self
        textView = tv

        scrollView.documentView = tv

        // Content = text area on top, status bar along the bottom.
        let content = NSView(frame: window.contentView!.bounds)
        statusBar = StatusBar(frame: NSRect(x: 0, y: 0, width: content.bounds.width, height: StatusBar.height))
        statusBar.autoresizingMask = [.width, .maxYMargin]
        content.addSubview(scrollView)
        content.addSubview(statusBar)
        window.contentView = content
        applyStatusBar(Settings.statusBar)
        applyWordWrap(Settings.wordWrap)

        let controller = NotepadWindowController(window: window)
        addWindowController(controller)

        if let last = NSApp.windows.filter({ $0 !== window && $0.isVisible }).last {
            window.setFrameTopLeftPoint(window.cascadeTopLeft(from: NSPoint(x: last.frame.minX, y: last.frame.maxY)))
        } else {
            window.setFrameAutosaveName("NotepadWindow")
            if window.frame.origin == .zero { window.center() }
        }
        window.makeFirstResponder(tv)
        tv.setSelectedRange(NSRange(location: 0, length: 0))
        updateStatus()
    }

    private func applyStatusBar(_ show: Bool) {
        guard let content = scrollView?.superview else { return }
        statusBar.isHidden = !show
        let h = show ? StatusBar.height : 0
        scrollView.frame = NSRect(x: 0, y: h, width: content.bounds.width, height: content.bounds.height - h)
        if show { updateStatus() }
    }

    /// "Ln 3, Col 12" and "1,234 characters" (or "5 of 1,234 characters" with a selection).
    private func updateStatus() {
        guard let tv = textView, let bar = statusBar, !bar.isHidden else { return }
        let s = tv.string as NSString
        let sel = tv.selectedRange()
        let caret = min(sel.location, s.length)

        var line = 1
        var i = 0
        while i < caret {
            let r = s.rangeOfCharacter(from: .newlines, options: [], range: NSRange(location: i, length: caret - i))
            if r.location == NSNotFound { break }
            // Treat \r\n as a single line break.
            if s.character(at: r.location) == 13, r.location + 1 < s.length, s.character(at: r.location + 1) == 10 {
                if r.location + 1 < caret { i = r.location + 2 } else { i = caret; break }
            } else {
                i = r.location + 1
            }
            line += 1
        }
        let lineStart = s.lineRange(for: NSRange(location: caret, length: 0)).location
        let col = (s.substring(with: NSRange(location: lineStart, length: caret - lineStart)) as String).count + 1

        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        let total = tv.string.count
        let totalText = fmt.string(from: NSNumber(value: total)) ?? "\(total)"
        let noun = total == 1 ? "character" : "characters"
        var chars = "\(totalText) \(noun)"
        if sel.length > 0 {
            let selected = s.substring(with: sel).count
            chars = "\(fmt.string(from: NSNumber(value: selected)) ?? "\(selected)") of \(totalText) \(noun)"
        }
        bar.position.stringValue = "Ln \(line), Col \(col)"
        bar.characters.stringValue = chars
    }

    private func applyWordWrap(_ wrap: Bool) {
        guard let tv = textView, let container = tv.textContainer else { return }
        scrollView.hasHorizontalScroller = !wrap
        if wrap {
            container.widthTracksTextView = true
            tv.isHorizontallyResizable = false
            tv.frame.size.width = scrollView.contentSize.width
            container.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        } else {
            container.widthTracksTextView = false
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
            tv.isHorizontallyResizable = true
        }
        tv.layoutManager?.ensureLayout(for: container)
        tv.sizeToFit()
    }

    // MARK: Reading & writing (plain text)

    override func read(from data: Data, ofType typeName: String) throws {
        if let s = String(data: data, encoding: .utf8) {
            text = s; encoding = .utf8
        } else if let s = String(data: data, encoding: .utf16) {
            text = s; encoding = .utf16
        } else if let s = String(data: data, encoding: .windowsCP1252) {
            text = s; encoding = .windowsCP1252
        } else {
            text = String(decoding: data, as: UTF8.self); encoding = .utf8
        }
        textView?.string = text
    }

    override func data(ofType typeName: String) throws -> Data {
        let current = textView?.string ?? text
        return current.data(using: encoding, allowLossyConversion: true) ?? Data()
    }

    override func writableTypes(for saveOperation: NSDocument.SaveOperationType) -> [String] {
        ["public.plain-text"]
    }

    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        savePanel.allowedContentTypes = [.plainText]
        savePanel.allowsOtherFileTypes = true
        savePanel.isExtensionHidden = false
        return true
    }

    // MARK: Printing

    override func printOperation(withSettings printSettings: [NSPrintInfo.AttributeKey: Any]) throws -> NSPrintOperation {
        let info = printInfo
        info.horizontalPagination = .fit
        info.isVerticallyCentered = false
        let width = info.paperSize.width - info.leftMargin - info.rightMargin
        let pv = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 100))
        pv.isRichText = false
        pv.font = Settings.font
        pv.string = textView?.string ?? text
        pv.sizeToFit()
        return NSPrintOperation(view: pv, printInfo: info)
    }

    // MARK: Menu actions

    @objc func toggleWordWrap(_ sender: Any?) {
        Settings.wordWrap.toggle()
        for doc in NSDocumentController.shared.documents {
            (doc as? NotepadDocument)?.applyWordWrap(Settings.wordWrap)
        }
    }

    @objc func toggleStatusBar(_ sender: Any?) {
        Settings.statusBar.toggle()
        for doc in NSDocumentController.shared.documents {
            (doc as? NotepadDocument)?.applyStatusBar(Settings.statusBar)
        }
    }

    @objc func chooseFont(_ sender: Any?) {
        let fm = NSFontManager.shared
        fm.target = self
        fm.action = #selector(fontPicked(_:))
        fm.setSelectedFont(Settings.font, isMultiple: false)
        fm.orderFrontFontPanel(sender)
    }

    @objc func fontPicked(_ sender: NSFontManager) {
        let newFont = sender.convert(Settings.font)
        Settings.font = newFont
        for doc in NSDocumentController.shared.documents {
            (doc as? NotepadDocument)?.textView?.font = newFont
        }
    }

    @objc func insertTimeDate(_ sender: Any?) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm dd/MM/yyyy"
        textView.insertText(f.string(from: Date()), replacementRange: textView.selectedRange())
    }

    @objc func goToLine(_ sender: Any?) {
        guard let window = windowControllers.first?.window else { return }
        let alert = NSAlert()
        alert.messageText = "Go To Line"
        alert.informativeText = "Line number:"
        alert.addButton(withTitle: "Go To")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.stringValue = String(currentLine())
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self, let n = Int(field.stringValue), n >= 1 else { return }
            let s = self.textView.string as NSString
            var line = 1, loc = 0
            while line < n && loc < s.length {
                let r = s.lineRange(for: NSRange(location: loc, length: 0))
                loc = NSMaxRange(r); line += 1
            }
            if line < n { NSSound.beep(); return }
            let target = NSRange(location: loc, length: 0)
            self.textView.setSelectedRange(target)
            self.textView.scrollRangeToVisible(target)
        }
    }

    private func currentLine() -> Int {
        let s = textView.string as NSString
        let end = min(textView.selectedRange().location, s.length)
        var line = 1
        s.enumerateSubstrings(in: NSRange(location: 0, length: end), options: [.byLines, .substringNotRequired]) { _, _, enclosing, _ in
            if NSMaxRange(enclosing) <= end, enclosing.length > 0,
               s.character(at: NSMaxRange(enclosing) - 1) == 10 || s.character(at: NSMaxRange(enclosing) - 1) == 13 {
                line += 1
            }
        }
        return line
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleWordWrap(_:)) {
            menuItem.state = Settings.wordWrap ? .on : .off
            return true
        }
        if menuItem.action == #selector(toggleStatusBar(_:)) {
            menuItem.state = Settings.statusBar ? .on : .off
            return true
        }
        if menuItem.action == #selector(goToLine(_:)) {
            return true
        }
        return super.validateMenuItem(menuItem)
    }

    // MARK: Text changes

    func textDidChange(_ notification: Notification) {
        text = textView.string
        updateStatus()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        updateStatus()
    }
}

/// Bottom status bar: caret position and character count, Windows Notepad style.
final class StatusBar: NSView {
    static let height: CGFloat = 24
    let position = StatusBar.label()
    let characters = StatusBar.label()

    private static func label() -> NSTextField {
        let l = NSTextField(labelWithString: "")
        l.font = .systemFont(ofSize: 11)
        l.textColor = .secondaryLabelColor
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        let gap = NSBox()
        gap.boxType = .separator
        gap.translatesAutoresizingMaskIntoConstraints = false
        for v in [divider, gap, position, characters] { addSubview(v) }
        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: topAnchor),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor),
            position.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            position.centerYAnchor.constraint(equalTo: centerYAnchor),
            gap.leadingAnchor.constraint(equalTo: position.leadingAnchor, constant: 130),
            gap.widthAnchor.constraint(equalToConstant: 1),
            gap.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            gap.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            characters.leadingAnchor.constraint(equalTo: gap.trailingAnchor, constant: 12),
            characters.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
    }
}

/// Shows "Name - Notepad" in the title bar, like Windows Notepad.
final class NotepadWindowController: NSWindowController {
    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        "\(displayName) - Notepad"
    }
}
