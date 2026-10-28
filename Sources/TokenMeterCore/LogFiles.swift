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

    static func forEachLine(in file: URL, _ body: (Data) -> Void) {
        guard let data = try? Data(contentsOf: file, options: .mappedIfSafe) else { return }
        for slice in data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true) {
            body(Data(slice))
        }
    }
}
