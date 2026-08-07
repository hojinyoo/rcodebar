import Testing
@testable import RCodeBar

struct RequestParserTests {
    let whitelist: Set<String> = ["myhost", "otherpod"]

    @Test func acceptsWhitelistedHost() {
        let result = RequestParser.parse("vscode://vscode-remote/ssh-remote+myhost/home/dev/project", whitelist: whitelist)
        #expect(result == .ok(host: "myhost", uri: "vscode://vscode-remote/ssh-remote+myhost/home/dev/project"))
    }

    @Test func rejectsUnknownHost() {
        let result = RequestParser.parse("vscode://vscode-remote/ssh-remote+notregistered/x", whitelist: whitelist)
        #expect(result == .err("unknown host"))
    }

    @Test func rejectsWrongPrefix() {
        let result = RequestParser.parse("http://evil.example/ssh-remote+myhost/x", whitelist: whitelist)
        #expect(result == .err("invalid uri"))
    }

    @Test func rejectsMissingPathAfterHost() {
        let result = RequestParser.parse("vscode://vscode-remote/ssh-remote+myhost", whitelist: whitelist)
        #expect(result == .err("invalid uri"))
    }

    @Test func rejectsEmptyHost() {
        let result = RequestParser.parse("vscode://vscode-remote/ssh-remote+/etc/passwd", whitelist: whitelist)
        #expect(result == .err("invalid uri"))
    }

    @Test func hostMatchIsExact() {
        // "myhost2" must not match the "myhost" whitelist entry.
        let result = RequestParser.parse("vscode://vscode-remote/ssh-remote+myhost2/x", whitelist: whitelist)
        #expect(result == .err("unknown host"))
    }
}
