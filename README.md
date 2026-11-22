# Notepad

A basic Windows-style Notepad for macOS (Swift + AppKit, SwiftPM).

Build and run:

    scripts/build-app.sh --run

Install into /Applications (quits any running copy, replaces it, opens the new one):

    scripts/build-app.sh --install

The app is built to `build/Notepad.app` (compile cache in `~/Library/Caches/NotepadBuild`).

## Features
- Plain text only, Courier New 13pt by default (Format > Font… to change; saved in preferences and kept between launches)
- App icon drawn by `Icon/make-icon.swift` (run `swift Icon/make-icon.swift && iconutil -c icns Icon/Notepad.iconset -o Icon/Notepad.icns` to redraw)
- White editing area that follows Light/Dark Mode automatically
- Status bar (View > Status Bar, ⌘/; remembered): Ln/Col, words and characters ("x of y" for a selection), line ending and encoding — click either of the last two to change how the file saves
- Tabs: tab bar always shown Safari-style with a + button; File > New Tab (⌘N), New Window (⇧⌘N); files opened together join one window
- Drag files onto the text to open them in new tabs
- View > Line Numbers (⌥⌘L; remembered); a wrapped line gets one number
- Spell check: red underlines as you type, right-click for suggestions; Edit > Spelling (⌘; check document, ⌘: panel); auto-correct off by default; both toggles remembered
- Format > Word Wrap (on by default; remembered)
- New / Open / Save / Save As / Print, "unsaved changes" prompt on close
- Title bar shows "Untitled - Notepad"
- Edit: Undo, Cut, Copy, Paste, Find (⌘F), Find Next (⌘G), Replace (⌥⌘F), Go To Line (⌘L), Select All, Time/Date (F5)
- Encodings: UTF-8, UTF-8 with BOM, UTF-16 LE/BE (by BOM), ANSI (Windows-1252). Line endings CRLF/LF/CR detected on open; text is kept as \n inside and converted back on save
- .LOG: a file starting with `.LOG` gets the time and date appended on opening (Windows Notepad trick)

## Testing
`NOTEPAD_SNAPSHOT=out.png build/Notepad.app/Contents/MacOS/Notepad file.txt` renders the front window to a PNG and quits (no Screen Recording permission needed).
