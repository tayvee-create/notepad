import Foundation

/// File encodings, named as Windows Notepad names them.
enum TextEncoding: String, CaseIterable {
    case utf8 = "UTF-8"
    case utf8BOM = "UTF-8 with BOM"
    case utf16LE = "UTF-16 LE"
    case utf16BE = "UTF-16 BE"
    case ansi = "ANSI"

    /// Works out the encoding from a byte-order mark, else UTF-8, else ANSI (Windows-1252).
    static func decode(_ data: Data) -> (String, TextEncoding) {
        let b = [UInt8](data.prefix(3))
        if b.count >= 3, b[0] == 0xEF, b[1] == 0xBB, b[2] == 0xBF {
            return (String(decoding: data.dropFirst(3), as: UTF8.self), .utf8BOM)
        }
        if b.count >= 2, b[0] == 0xFF, b[1] == 0xFE {
            return (String(data: Data(data.dropFirst(2)), encoding: .utf16LittleEndian) ?? "", .utf16LE)
        }
        if b.count >= 2, b[0] == 0xFE, b[1] == 0xFF {
            return (String(data: Data(data.dropFirst(2)), encoding: .utf16BigEndian) ?? "", .utf16BE)
        }
        if let s = String(data: data, encoding: .utf8) { return (s, .utf8) }
        if let s = String(data: data, encoding: .windowsCP1252) { return (s, .ansi) }
        return (String(decoding: data, as: UTF8.self), .utf8)
    }

    /// nil when the text has characters this encoding can't hold (only possible for ANSI).
    func encode(_ s: String) -> Data? {
        switch self {
        case .utf8: return Data(s.utf8)
        case .utf8BOM: return Data([0xEF, 0xBB, 0xBF]) + Data(s.utf8)
        case .utf16LE: return s.data(using: .utf16LittleEndian).map { Data([0xFF, 0xFE]) + $0 }
        case .utf16BE: return s.data(using: .utf16BigEndian).map { Data([0xFE, 0xFF]) + $0 }
        case .ansi: return s.data(using: .windowsCP1252, allowLossyConversion: false)
        }
    }
}

/// Line break styles. Text is kept with \n inside the app and converted when saving.
enum LineEnding: String, CaseIterable {
    case crlf = "Windows (CRLF)"
    case lf = "Unix (LF)"
    case cr = "Macintosh (CR)"

    var characters: String {
        switch self {
        case .crlf: return "\r\n"
        case .lf: return "\n"
        case .cr: return "\r"
        }
    }

    /// The most common line break in the text, or nil if it has none.
    static func detect(in s: String) -> LineEnding? {
        var crlf = 0, lf = 0, cr = 0
        let u = Array(s.utf16)
        var i = 0
        while i < u.count {
            if u[i] == 13 {
                if i + 1 < u.count, u[i + 1] == 10 { crlf += 1; i += 1 } else { cr += 1 }
            } else if u[i] == 10 {
                lf += 1
            }
            i += 1
        }
        if crlf + lf + cr == 0 { return nil }
        if crlf >= lf && crlf >= cr { return .crlf }
        return lf >= cr ? .lf : .cr
    }

    /// Turns every kind of line break into \n.
    static func normalise(_ s: String) -> String {
        // Check code units: Swift treats "\r\n" as one Character, so s.contains("\r") misses it.
        guard s.utf16.contains(13) else { return s }
        return s.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }
}
