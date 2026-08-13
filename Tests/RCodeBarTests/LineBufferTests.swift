import Foundation
import Testing

@testable import RCodeBar

struct LineBufferTests {
    @Test func returnsLineOnNewline() {
        var buffer = LineBuffer()
        let result = buffer.append(Data("hello\n".utf8))
        #expect(result == .line("hello"))
    }

    @Test func needsMoreWithoutNewline() {
        var buffer = LineBuffer()
        let result = buffer.append(Data("hello".utf8))
        #expect(result == .needMore)
    }

    @Test func accumulatesAcrossChunks() {
        var buffer = LineBuffer()
        #expect(buffer.append(Data("hel".utf8)) == .needMore)
        #expect(buffer.append(Data("lo\n".utf8)) == .line("hello"))
    }

    @Test func cutsConnectionPastFourKiB() {
        var buffer = LineBuffer()
        let oversized = Data(repeating: UInt8(ascii: "a"), count: LineBuffer.capBytes + 1)
        #expect(buffer.append(oversized) == .tooLong)
    }

    @Test func exactlyCapBytesWithoutNewlineFits() {
        var buffer = LineBuffer()
        let exact = Data(repeating: UInt8(ascii: "a"), count: LineBuffer.capBytes)
        #expect(buffer.append(exact) == .needMore)
    }

    @Test func tooLongWhenLineExceedsCapEvenWithNewlinePresent() {
        var buffer = LineBuffer()
        var oversized = Data(repeating: UInt8(ascii: "a"), count: LineBuffer.capBytes + 1)
        oversized.append(0x0A)
        #expect(buffer.append(oversized) == .tooLong)
    }
}
