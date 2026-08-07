import Foundation

enum LineBufferResult: Equatable {
    case needMore
    case line(String)
    case tooLong
}

/// Accumulates bytes for one request until a newline or the 4 KiB cap.
/// Once `tooLong` fires the buffer is done — the caller closes the connection.
struct LineBuffer {
    static let capBytes = 4096

    private var data = Data()
    private(set) var isDone = false

    mutating func append(_ chunk: Data) -> LineBufferResult {
        guard !isDone else { return .tooLong }

        if let newlineIndex = chunk.firstIndex(of: 0x0A) {
            let head = chunk[chunk.startIndex..<newlineIndex]
            guard data.count + head.count <= Self.capBytes else {
                isDone = true
                return .tooLong
            }
            data.append(head)
            isDone = true
            return .line(String(decoding: data, as: UTF8.self))
        }

        guard data.count + chunk.count <= Self.capBytes else {
            isDone = true
            return .tooLong
        }
        data.append(chunk)
        return .needMore
    }
}
