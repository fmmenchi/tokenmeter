import Foundation

enum LogFiles {
    static func jsonl(under root: URL, modifiedSince: Date) -> [URL] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        guard let walker = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return [] }
        var result: [URL] = []
        for case let url as URL in walker where url.pathExtension == "jsonl" {
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isRegularFile == true, (values?.contentModificationDate ?? .distantPast) >= modifiedSince {
                result.append(url)
            }
        }
        return result
    }

    /// Calls `body` with each complete line that contains any of `markers`, appended after `offset`, and returns the offset to
    /// resume from. The file is read in chunks, so memory does not grow with it: a log can be hundreds of megabytes. A trailing
    /// partial line (still being written) is left for the next call.
    static func scanNewLines(in file: URL, from offset: UInt64, containing markers: [Data], chunk: Int = 4 << 20,
                             _ body: (Data) -> Void) -> UInt64 {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return offset }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let start = size < offset ? 0 : offset
        guard (try? handle.seek(toOffset: start)) != nil else { return start }

        var carry = Data()
        var consumed = start
        while true {
            let piece = autoreleasepool { try? handle.read(upToCount: chunk) }
            guard let piece, !piece.isEmpty else { break }
            carry.append(piece)
            var lineStart = carry.startIndex
            while let end = carry[lineStart...].firstIndex(of: UInt8(ascii: "\n")) {
                let line = carry[lineStart..<end]
                if markers.contains(where: { line.range(of: $0) != nil }) { body(Data(line)) }
                lineStart = carry.index(after: end)
            }
            consumed += UInt64(carry.distance(from: carry.startIndex, to: lineStart))
            carry = Data(carry[lineStart...])
        }
        return consumed
    }

    static func size(of file: URL) -> UInt64 {
        (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? UInt64) ?? 0
    }
}
