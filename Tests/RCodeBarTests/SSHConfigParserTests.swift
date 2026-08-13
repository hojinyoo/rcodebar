import Testing

@testable import RCodeBar

struct SSHConfigParserTests {
    @Test func followsIncludeAndDedupesAcrossFiles() {
        let files: [String: String] = [
            "~/.ssh/config": """
            Include ~/.ssh/config.local
            Include ~/.ssh/config.d/*

            Host *
                 ControlMaster auto
            """,
            "~/.ssh/config.d/remotes": "Host ldev ldev*\n    HostName 198.51.100.10\n",
            "~/.ssh/config.d/servers": """
            Host *_jump
                 ProxyJump jump

            Host ldev*
                 User dev

            Host web*
                 HostName 198.51.100.11
            """,
        ]
        let globResults: [String: [String]] = [
            "~/.ssh/config.local": [],
            "~/.ssh/config.d/*": ["~/.ssh/config.d/remotes", "~/.ssh/config.d/servers"],
        ]

        let hosts = SSHConfigParser.discoverHosts(
            from: "~/.ssh/config",
            readFile: { files[$0] },
            expandGlob: { globResults[$0] ?? [] }
        )

        // "Host *" excluded; "ldev ldev*" -> concrete first token "ldev",
        // deduped against the second file's "ldev*" -> also "ldev";
        // "*_jump" has no concrete or strippable token -> skipped;
        // "web*" -> stripped to "web".
        #expect(hosts == ["ldev", "web"])
    }

    @Test func skipsMissingIncludedFiles() {
        let hosts = SSHConfigParser.discoverHosts(
            from: "~/.ssh/config",
            readFile: { $0 == "~/.ssh/config" ? "Include ~/.ssh/config.d/*\nHost real\n" : nil },
            expandGlob: { $0 == "~/.ssh/config.d/*" ? ["~/.ssh/config.d/missing"] : [] }
        )
        #expect(hosts == ["real"])
    }

    @Test func concreteAliasPrefersFullyConcreteToken() {
        #expect(SSHConfigParser.concreteAlias(from: ["ldev", "ldev*"]) == "ldev")
    }

    @Test func concreteAliasStripsTrailingWildcardWhenNoConcreteToken() {
        #expect(SSHConfigParser.concreteAlias(from: ["web*"]) == "web")
    }

    @Test func concreteAliasSkipsBareWildcard() {
        #expect(SSHConfigParser.concreteAlias(from: ["*"]) == nil)
    }

    @Test func concreteAliasSkipsDoublyWildcardedPattern() {
        #expect(SSHConfigParser.concreteAlias(from: ["*_relay*"]) == nil)
    }

    @Test func concreteAliasSkipsLeadingWildcardPattern() {
        #expect(SSHConfigParser.concreteAlias(from: ["*_jump"]) == nil)
    }
}
