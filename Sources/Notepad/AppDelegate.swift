import AppKit

/// App-wide settings, remembered between launches.
enum Settings {
    static var wordWrap: Bool {
        get { UserDefaults.standard.object(forKey: "wordWrap") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "wordWrap") }
    }
    static var lineNumbers: Bool {
        get { UserDefaults.standard.object(forKey: "lineNumbers") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "lineNumbers") }
    }
    static var statusBar: Bool {
        get { UserDefaults.standard.object(forKey: "statusBar") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "statusBar") }
    }
    static var font: NSFont {
        get {
            let d = UserDefaults.standard
            let name = d.string(forKey: "fontName") ?? "Courier New"
            let size = d.object(forKey: "fontSize") as? Double ?? 13
            return NSFont(name: name, size: size)
                ?? NSFont.userFixedPitchFont(ofSize: size)
                ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
        set {
            UserDefaults.standard.set(newValue.fontName, forKey: "fontName")
            UserDefaults.standard.set(Double(newValue.pointSize), forKey: "fontSize")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = true
        NSApp.mainMenu = buildMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        // Testing aid: NOTEPAD_SNAPSHOT=/path/out.png renders the front window to a PNG and quits.
        if let out = ProcessInfo.processInfo.environment["NOTEPAD_SNAPSHOT"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if let frameView = NSApp.orderedWindows.first?.contentView?.superview,
                   let rep = frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds) {
                    frameView.cacheDisplay(in: frameView.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
                }
                exit(0)
            }
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// File > New Window: a new document in its own window rather than a tab.
    @objc func newWindow(_ sender: Any?) {
        let dc = NSDocumentController.shared
        guard let doc = (try? dc.openUntitledDocumentAndDisplay(false)) as? NotepadDocument else { return }
        doc.makeWindowControllers()
        let window = doc.windowControllers.first?.window
        window?.tabbingMode = .disallowed
        doc.showWindows()
        window?.tabbingMode = .preferred
    }

    // MARK: Menu

    private func item(_ title: String, _ action: Selector?, _ key: String = "",
                      _ mods: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.keyEquivalentModifierMask = mods
        return i
    }

    private func buildMenu() -> NSMenu {
        let main = NSMenu()

        // App menu
        let appMenu = NSMenu()
        appMenu.addItem(item("About Notepad", #selector(NSApplication.orderFrontStandardAboutPanel(_:))))
        appMenu.addItem(.separator())
        let services = NSMenu()
        let servicesItem = item("Services", nil)
        servicesItem.submenu = services
        NSApp.servicesMenu = services
        appMenu.addItem(servicesItem)
        appMenu.addItem(.separator())
        appMenu.addItem(item("Hide Notepad", #selector(NSApplication.hide(_:)), "h"))
        appMenu.addItem(item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]))
        appMenu.addItem(item("Show All", #selector(NSApplication.unhideAllApplications(_:))))
        appMenu.addItem(.separator())
        appMenu.addItem(item("Quit Notepad", #selector(NSApplication.terminate(_:)), "q"))
        add(appMenu, "Notepad", to: main)

        // File
        let file = NSMenu(title: "File")
        file.addItem(item("New Tab", #selector(NSDocumentController.newDocument(_:)), "n"))
        file.addItem(item("New Window", #selector(AppDelegate.newWindow(_:)), "n", [.command, .shift]))
        file.addItem(item("Open…", #selector(NSDocumentController.openDocument(_:)), "o"))
        let recent = NSMenu(title: "Open Recent")
        recent.addItem(item("Clear Menu", #selector(NSDocumentController.clearRecentDocuments(_:))))
        let recentItem = item("Open Recent", nil)
        recentItem.submenu = recent
        file.addItem(recentItem)
        file.addItem(.separator())
        file.addItem(item("Save", #selector(NSDocument.save(_:)), "s"))
        file.addItem(item("Save As…", #selector(NSDocument.saveAs(_:)), "s", [.command, .shift]))
        file.addItem(.separator())
        file.addItem(item("Page Setup…", #selector(NSDocument.runPageLayout(_:)), "p", [.command, .shift]))
        file.addItem(item("Print…", #selector(NSDocument.printDocument(_:)), "p"))
        file.addItem(.separator())
        file.addItem(item("Close", #selector(NSWindow.performClose(_:)), "w"))
        add(file, "File", to: main)

        // Edit
        let edit = NSMenu(title: "Edit")
        edit.addItem(item("Undo", Selector(("undo:")), "z"))
        edit.addItem(item("Redo", Selector(("redo:")), "z", [.command, .shift]))
        edit.addItem(.separator())
        edit.addItem(item("Cut", #selector(NSText.cut(_:)), "x"))
        edit.addItem(item("Copy", #selector(NSText.copy(_:)), "c"))
        edit.addItem(item("Paste", #selector(NSTextView.pasteAsPlainText(_:)), "v"))
        edit.addItem(item("Delete", #selector(NSText.delete(_:))))
        edit.addItem(.separator())
        let find = item("Find…", #selector(NSTextView.performFindPanelAction(_:)), "f")
        find.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
        edit.addItem(find)
        let next = item("Find Next", #selector(NSTextView.performFindPanelAction(_:)), "g")
        next.tag = Int(NSFindPanelAction.next.rawValue)
        edit.addItem(next)
        let prev = item("Find Previous", #selector(NSTextView.performFindPanelAction(_:)), "g", [.command, .shift])
        prev.tag = Int(NSFindPanelAction.previous.rawValue)
        edit.addItem(prev)
        let replace = item("Replace…", #selector(NSTextView.performFindPanelAction(_:)), "f", [.command, .option])
        replace.tag = 12 // NSTextFinder.Action.showReplaceInterface
        edit.addItem(replace)
        edit.addItem(item("Go To Line…", #selector(NotepadDocument.goToLine(_:)), "l"))
        edit.addItem(.separator())
        edit.addItem(item("Select All", #selector(NSText.selectAll(_:)), "a"))
        let timeDate = NSMenuItem(title: "Time/Date", action: #selector(NotepadDocument.insertTimeDate(_:)),
                                  keyEquivalent: String(Character(UnicodeScalar(NSF5FunctionKey)!)))
        timeDate.keyEquivalentModifierMask = []
        edit.addItem(timeDate)
        add(edit, "Edit", to: main)

        // Format
        let format = NSMenu(title: "Format")
        format.addItem(item("Word Wrap", #selector(NotepadDocument.toggleWordWrap(_:)), ""))
        format.addItem(item("Font…", #selector(NotepadDocument.chooseFont(_:)), "t"))
        add(format, "Format", to: main)

        // View
        let view = NSMenu(title: "View")
        view.addItem(item("Status Bar", #selector(NotepadDocument.toggleStatusBar(_:)), "/"))
        view.addItem(item("Line Numbers", #selector(NotepadDocument.toggleLineNumbers(_:)), "l", [.command, .option]))
        view.addItem(.separator())
        add(view, "View", to: main)

        // Window
        let window = NSMenu(title: "Window")
        window.addItem(item("Minimise", #selector(NSWindow.performMiniaturize(_:)), "m"))
        window.addItem(item("Zoom", #selector(NSWindow.performZoom(_:))))
        add(window, "Window", to: main)
        NSApp.windowsMenu = window

        return main
    }

    private func add(_ menu: NSMenu, _ title: String, to main: NSMenu) {
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        i.submenu = menu
        main.addItem(i)
    }
}
