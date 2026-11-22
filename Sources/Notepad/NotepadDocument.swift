import AppKit

final class NotepadDocument: NSDocument, NSTextViewDelegate {
    private var text = ""
    private var encoding: TextEncoding = .utf8
    private var lineEnding: LineEnding = .lf
    private var textView: NSTextView!
    private var scrollView: NSScrollView!
    private var statusBar: StatusBar!
    private var ruler: LineNumberRuler!

    override class var autosavesInPlace: Bool { false }
    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool { true }

    // MARK: Window

    override func makeWindowControllers() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.minSize = NSSize(width: 240, height: 160)
        window.tabbingMode = .preferred          // new documents open as tabs
        window.tabbingIdentifier = "NotepadDocument"

        scrollView = NSScrollView(frame: window.contentView!.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        let tv = NotepadTextView(usingTextLayoutManager: false)
        tv.frame = scrollView.bounds
        tv.isRichText = false
        tv.importsGraphics = false
        tv.allowsUndo = true
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = Settings.autoCorrect
        tv.isContinuousSpellCheckingEnabled = Settings.spellCheck
        tv.isGrammarCheckingEnabled = false
        tv.smartInsertDeleteEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        tv.textContainerInset = NSSize(width: 2, height: 2)
        tv.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
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

        ruler = LineNumberRuler(textView: tv, scrollView: scrollView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = Settings.lineNumbers

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
        controller.startTintingTabBar()

        if let last = NSApp.windows.filter({ $0 !== window && $0.isVisible }).last {
            window.setFrameTopLeftPoint(window.cascadeTopLeft(from: NSPoint(x: last.frame.minX, y: last.frame.maxY)))
        } else {
            window.setFrameAutosaveName("NotepadWindow")
            if window.frame.origin == .zero { window.center() }
        }
        statusBar.lineEnding.target = self
        statusBar.lineEnding.action = #selector(chooseLineEnding(_:))
        statusBar.encoding.target = self
        statusBar.encoding.action = #selector(chooseEncoding(_:))

        window.makeFirstResponder(tv)
        tv.setSelectedRange(NSRange(location: 0, length: 0))
        if fileURL != nil, text.hasPrefix(".LOG") { appendLogTimeStamp() }
        updateStatus()
    }

    /// Windows Notepad's .LOG trick: a file starting with .LOG gets the time and date added at the end on opening.
    private func appendLogTimeStamp() {
        let end = (textView.string as NSString).length
        let lead = "\n"   // as Windows: a line break, then the stamp (a blank line if the file already ended with one)
        textView.setSelectedRange(NSRange(location: end, length: 0))
        textView.insertText(lead + Self.timeDateString() + "\n", replacementRange: NSRange(location: end, length: 0))
        textView.scrollRangeToVisible(textView.selectedRange())
    }

    static func timeDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm dd/MM/yyyy"
        return f.string(from: Date())
    }

    private func applyStatusBar(_ show: Bool) {
        guard let content = scrollView?.superview else { return }
        statusBar.isHidden = !show
        let h = show ? StatusBar.height : 0
        scrollView.frame = NSRect(x: 0, y: h, width: content.bounds.width, height: content.bounds.height - h)
        if show { updateStatus() }
    }

    /// Ln/Col, word and character counts (with "x of y" for a selection), line ending and encoding.
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
            i = r.location + 1
            line += 1
        }
        let lineStart = s.lineRange(for: NSRange(location: caret, length: 0)).location
        let col = (s.substring(with: NSRange(location: lineStart, length: caret - lineStart)) as String).count + 1

        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        func n(_ v: Int) -> String { fmt.string(from: NSNumber(value: v)) ?? "\(v)" }
        func words(_ str: String) -> Int {
            var count = 0
            str.enumerateSubstrings(in: str.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in count += 1 }
            return count
        }

        let totalChars = tv.string.count
        let totalWords = words(tv.string)
        let charNoun = totalChars == 1 ? "character" : "characters"
        let wordNoun = totalWords == 1 ? "word" : "words"
        if sel.length > 0 {
            let selected = s.substring(with: sel)
            bar.counts.stringValue = "\(n(words(selected))) of \(n(totalWords)) \(wordNoun), \(n(selected.count)) of \(n(totalChars)) \(charNoun)"
        } else {
            bar.counts.stringValue = "\(n(totalWords)) \(wordNoun), \(n(totalChars)) \(charNoun)"
        }
        bar.position.stringValue = "Ln \(line), Col \(col)"
        bar.lineEnding.setText(lineEnding.rawValue)
        bar.encoding.setText(encoding.rawValue)
    }

    // MARK: Line ending and encoding pickers (status bar)

    @objc func chooseLineEnding(_ sender: NSButton) {
        popUpChoices(LineEnding.allCases.map(\.rawValue), current: lineEnding.rawValue,
                     action: #selector(setLineEnding(_:)), from: sender)
    }

    @objc func chooseEncoding(_ sender: NSButton) {
        popUpChoices(TextEncoding.allCases.map(\.rawValue), current: encoding.rawValue,
                     action: #selector(setEncoding(_:)), from: sender)
    }

    private func popUpChoices(_ titles: [String], current: String, action: Selector, from button: NSButton) {
        let menu = NSMenu()
        var currentItem: NSMenuItem?
        for title in titles {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            if title == current { item.state = .on; currentItem = item }
            menu.addItem(item)
        }
        menu.popUp(positioning: currentItem, at: NSPoint(x: 0, y: button.bounds.height - 2), in: button)
    }

    @objc func setLineEnding(_ sender: NSMenuItem) {
        guard let new = LineEnding(rawValue: sender.title), new != lineEnding else { return }
        lineEnding = new
        updateChangeCount(.changeDone)
        updateStatus()
    }

    @objc func setEncoding(_ sender: NSMenuItem) {
        guard let new = TextEncoding(rawValue: sender.title), new != encoding else { return }
        encoding = new
        updateChangeCount(.changeDone)
        updateStatus()
    }

    /// Open in a tab of the front Notepad window (also when several files open at once).
    override func showWindows() {
        if let window = windowControllers.first?.window, !window.isVisible, window.tabbingMode != .disallowed {
            let isNotepad: (NSWindow) -> Bool = { $0 !== window && $0.isVisible && $0.windowController is NotepadWindowController }
            let host = [NSApp.mainWindow, NSApp.keyWindow].compactMap { $0 }.first(where: isNotepad)
                ?? NSApp.orderedWindows.first(where: isNotepad)
            host?.addTabbedWindow(window, ordered: .above)
        }
        super.showWindows()
        // Safari-style: keep the tab bar (and its + button) showing even with one tab.
        if let window = windowControllers.first?.window,
           let group = window.tabGroup, !group.isTabBarVisible {
            window.toggleTabBar(nil)
        }
        // The tab bar is built lazily, so tint on the next pass.
        DispatchQueue.main.async { [weak self] in
            for w in self?.windowControllers.first?.window?.tabGroup?.windows ?? [] { TabBarTint.apply(to: w) }
        }
    }

    private func applyWordWrap(_ wrap: Bool) {
        guard let tv = textView, let container = tv.textContainer else { return }
        scrollView.hasHorizontalScroller = !wrap
        scrollView.tile()   // settle ruler and scroller sizes first
        let visibleWidth = scrollView.contentView.bounds.width
        if wrap {
            container.widthTracksTextView = true
            tv.isHorizontallyResizable = false
            tv.frame.size.width = visibleWidth
            container.containerSize = NSSize(width: visibleWidth, height: .greatestFiniteMagnitude)
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
        let (decoded, enc) = TextEncoding.decode(data)
        encoding = enc
        lineEnding = LineEnding.detect(in: decoded) ?? .lf
        text = LineEnding.normalise(decoded)
        if let tv = textView {
            tv.string = text
            ruler?.textChanged()
            updateStatus()
        }
    }

    override func data(ofType typeName: String) throws -> Data {
        var current = LineEnding.normalise(textView?.string ?? text)
        if lineEnding != .lf {
            current = current.replacingOccurrences(of: "\n", with: lineEnding.characters)
        }
        guard let data = encoding.encode(current) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteInapplicableStringEncodingError, userInfo: [
                NSLocalizedDescriptionKey: "Some characters in this file can't be saved as \(encoding.rawValue).",
                NSLocalizedRecoverySuggestionErrorKey: "Click \(encoding.rawValue) in the status bar, choose UTF-8, then save again.",
            ])
        }
        return data
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

    @objc func toggleSpellCheck(_ sender: Any?) {
        Settings.spellCheck.toggle()
        for case let doc as NotepadDocument in NSDocumentController.shared.documents {
            doc.textView?.isContinuousSpellCheckingEnabled = Settings.spellCheck
        }
    }

    @objc func toggleAutoCorrect(_ sender: Any?) {
        Settings.autoCorrect.toggle()
        for case let doc as NotepadDocument in NSDocumentController.shared.documents {
            doc.textView?.isAutomaticSpellingCorrectionEnabled = Settings.autoCorrect
        }
    }

    @objc func toggleLineNumbers(_ sender: Any?) {
        Settings.lineNumbers.toggle()
        for doc in NSDocumentController.shared.documents {
            guard let doc = doc as? NotepadDocument else { continue }
            doc.scrollView?.rulersVisible = Settings.lineNumbers
            doc.applyWordWrap(Settings.wordWrap)
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
            guard let doc = doc as? NotepadDocument else { continue }
            doc.textView?.font = newFont
            doc.ruler?.fontChanged()
        }
    }

    @objc func insertTimeDate(_ sender: Any?) {
        textView.insertText(Self.timeDateString(), replacementRange: textView.selectedRange())
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
        if menuItem.action == #selector(setLineEnding(_:)) || menuItem.action == #selector(setEncoding(_:)) {
            return true
        }
        if menuItem.action == #selector(toggleSpellCheck(_:)) {
            menuItem.state = Settings.spellCheck ? .on : .off
            return true
        }
        if menuItem.action == #selector(toggleAutoCorrect(_:)) {
            menuItem.state = Settings.autoCorrect ? .on : .off
            return true
        }
        if menuItem.action == #selector(toggleLineNumbers(_:)) {
            menuItem.state = Settings.lineNumbers ? .on : .off
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
        ruler?.textChanged()
        updateStatus()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        updateStatus()
    }
}

/// Bottom status bar, Windows Notepad style:
/// Ln/Col | words, characters  ......  line ending | encoding (the last two are clickable).
final class StatusBar: NSView {
    static let height: CGFloat = 24
    let position = StatusBar.label()
    let counts = StatusBar.label()
    let lineEnding = StatusButton()
    let encoding = StatusButton()

    private static func label() -> NSTextField {
        let l = NSTextField(labelWithString: "")
        l.font = .systemFont(ofSize: 11)
        l.textColor = .secondaryLabelColor
        l.lineBreakMode = .byTruncatingTail
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private static func separator() -> NSBox {
        let b = NSBox()
        b.boxType = .separator
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        let top = StatusBar.separator()
        let sep1 = StatusBar.separator(), sep2 = StatusBar.separator(), sep3 = StatusBar.separator()
        for v in [top, sep1, sep2, sep3, position, counts, lineEnding, encoding] { addSubview(v) }
        func vertical(_ b: NSBox) -> [NSLayoutConstraint] {
            [b.widthAnchor.constraint(equalToConstant: 1),
             b.topAnchor.constraint(equalTo: topAnchor, constant: 5),
             b.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)]
        }
        NSLayoutConstraint.activate([
            top.topAnchor.constraint(equalTo: topAnchor),
            top.leadingAnchor.constraint(equalTo: leadingAnchor),
            top.trailingAnchor.constraint(equalTo: trailingAnchor),

            position.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            position.centerYAnchor.constraint(equalTo: centerYAnchor),
            sep1.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 130),
            counts.leadingAnchor.constraint(equalTo: sep1.trailingAnchor, constant: 12),
            counts.centerYAnchor.constraint(equalTo: centerYAnchor),
            counts.trailingAnchor.constraint(lessThanOrEqualTo: sep2.leadingAnchor, constant: -8),

            encoding.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            encoding.centerYAnchor.constraint(equalTo: centerYAnchor),
            sep3.trailingAnchor.constraint(equalTo: encoding.leadingAnchor, constant: -6),
            lineEnding.trailingAnchor.constraint(equalTo: sep3.leadingAnchor, constant: -6),
            lineEnding.centerYAnchor.constraint(equalTo: centerYAnchor),
            sep2.trailingAnchor.constraint(equalTo: lineEnding.leadingAnchor, constant: -6),
        ] + vertical(sep1) + vertical(sep2) + vertical(sep3))
        counts.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
    }
}

/// A flat, clickable status bar item that pops up a menu of choices.
final class StatusButton: NSButton {
    init() {
        super.init(frame: .zero)
        isBordered = false
        setButtonType(.momentaryChange)
        translatesAutoresizingMaskIntoConstraints = false
        toolTip = "Click to change"
    }

    required init?(coder: NSCoder) { fatalError() }

    func setText(_ text: String) {
        attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

/// Shows "Name - Notepad" in the title bar, like Windows Notepad.
final class NotepadWindowController: NSWindowController {
    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        "\(displayName) - Notepad"
    }

    /// Tabs show just the file name.
    override func synchronizeWindowTitleWithDocumentName() {
        super.synchronizeWindowTitleWithDocumentName()
        window?.tab.title = document?.displayName ?? "Untitled"
    }

    /// The + button on the tab bar.
    /// Re-tint whenever this tab comes to the front (AppKit may rebuild the tab bar).
    func startTintingTabBar() {
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didBecomeMainNotification, NSWindow.didResizeNotification] {
            NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                TabBarTint.apply(to: self?.window)
            }
        }
    }

    override func newWindowForTab(_ sender: Any?) {
        NSDocumentController.shared.newDocument(sender)
    }
}
