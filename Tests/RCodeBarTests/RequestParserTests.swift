import Testing
@testable import RCodeBar

struct RequestParserTests {
    let whitelist: Set<String> = ["ldev", "other"]

    @Test func acceptsWhitelistedHost() {
        let result = RequestParser.parse("vscode://vscode-remote/ssh-remote+ldev/home/dev/project", whitelist: whitelist)
        #expect(result == .ok(host: "ldev", uri: "vscode://vscode-remote/ssh-remote+ldev/home/dev/project"))
    }

    @Test func rejectsUnknownHost() {
        let result = RequestParser.parse("vscode://vscode-remote/ssh-remote+notregistered/x", whitelist: whitelist)
        #expect(result == .err("unknown host"))
    }

    @Test func rejectsWrongPrefix() {
        let result = RequestParser.parse("http://evil.example/ssh-remote+ldev/x", whitelist: whitelist)
        #expect(result == .err("invalid uri"))
    }

    @Test func rejectsMissingPathAfterHost() {
        let result = RequestParser.parse("vscode://vscode-remote/ssh-remote+ldev", whitelist: whitelist)
        #expect(result == .err("invalid uri"))
    }

    @Test func rejectsEmptyHost() {
        let result = RequestParser.parse("vscode://vscode-remote/ssh-remote+/etc/passwd", whitelist: whitelist)
        #expect(result == .err("invalid uri"))
    }

    @Test func hostMatchIsExact() {
        // "ldev2" must not match the "ldev" whitelist entry.
        let result = RequestParser.parse("vscode://vscode-remote/ssh-remote+ldev2/x", whitelist: whitelist)
        #expect(result == .err("unknown host"))
    }
}
