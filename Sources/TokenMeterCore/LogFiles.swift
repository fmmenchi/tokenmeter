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

    /// Complete lines containing `marker` appended after `offset`, and the offset to resume from.
    /// A trailing partial line (still being written) is left for the next call.
    static func newLines(in file: URL, from offset: UInt64, containing marker: Data) -> (lines: [Data], offset: UInt64) {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return ([], offset) }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let start = size < offset ? 0 : offset
        guard (try? handle.seek(toOffset: start)) != nil,
              let data = try? handle.readToEnd(), !data.isEmpty,
              let lastNewline = data.lastIndex(of: UInt8(ascii: "\n")) else { return ([], start) }

        var lines: [Data] = []
        var lineStart = data.startIndex
        while lineStart <= lastNewline {
            let end = data[lineStart...].firstIndex(of: UInt8(ascii: "\n"))!
            let line = data[lineStart..<end]
            if line.range(of: marker) != nil { lines.append(Data(line)) }
            lineStart = data.index(after: end)
        }
        return (lines, start + UInt64(data.distance(from: data.startIndex, to: lastNewline)) + 1)
    }

    static func size(of file: URL) -> UInt64 {
        (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? UInt64) ?? 0
    }
}
