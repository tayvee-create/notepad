# Notepad

A basic Windows-style Notepad for macOS (Swift + AppKit, SwiftPM).

Build and run:

    scripts/build-app.sh --run

The app is built to `build/Notepad.app` (compile cache in `~/Library/Caches/NotepadBuild`).

## Features
- Plain text only, Courier New 13pt by default (Format > Font… to change; saved in preferences and kept between launches)
- App icon drawn by `Icon/make-icon.swift` (run `swift Icon/make-icon.swift && iconutil -c icns Icon/Notepad.iconset -o Icon/Notepad.icns` to redraw)
- White editing area that follows Light/Dark Mode automatically
- Status bar (View > Status Bar, ⌘/; remembered): Ln/Col and character count, "5 of 1,234 characters" when text is selected
- Format > Word Wrap (on by default; remembered)
- New / Open / Save / Save As / Print, "unsaved changes" prompt on close
- Title bar shows "Untitled - Notepad"
- Edit: Undo, Cut, Copy, Paste, Find (⌘F), Find Next (⌘G), Replace (⌥⌘F), Go To Line (⌘L), Select All, Time/Date (F5)
- Opens UTF-8, UTF-16 and Windows-1252 files and saves back in the same encoding
