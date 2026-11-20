import AppKit

final class NotepadDocument: NSDocument, NSTextViewDelegate {
    private var text = ""
    private var encoding: String.Encoding = .utf8
    private var textView: NSTextView!
    private var scrollView: NSScrollView!

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
        tv.backgroundColor = .textBackgroundColor
        tv.textColor = .textColor
        tv.font = Settings.font
        tv.string = text
        tv.delegate = self
        textView = tv

        scrollView.documentView = tv
        window.contentView = scrollView
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
        if menuItem.action == #selector(goToLine(_:)) {
            return true
        }
        return super.validateMenuItem(menuItem)
    }

    // MARK: Text changes

    func textDidChange(_ notification: Notification) {
        text = textView.string
    }
}

/// Shows "Name - Notepad" in the title bar, like Windows Notepad.
final class NotepadWindowController: NSWindowController {
    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        "\(displayName) - Notepad"
    }
}
