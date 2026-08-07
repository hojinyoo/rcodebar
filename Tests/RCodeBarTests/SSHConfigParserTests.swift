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
            "~/.ssh/config.d/bionsight-pods": "Host ldev ldev*\n    HostName 10.244.5.18\n",
            "~/.ssh/config.d/bionsight-servers": """
            Host *_tyr
                 ProxyJump tyr

            Host ldev*
                 User jovyan

            Host cys*
                 HostName 192.168.1.3
            """,
        ]
        let globResults: [String: [String]] = [
            "~/.ssh/config.local": [],
            "~/.ssh/config.d/*": ["~/.ssh/config.d/bionsight-pods", "~/.ssh/config.d/bionsight-servers"],
        ]

        let hosts = SSHConfigParser.discoverHosts(
            from: "~/.ssh/config",
            readFile: { files[$0] },
            expandGlob: { globResults[$0] ?? [] }
        )

        // "Host *" excluded; "ldev ldev*" -> concrete first token "ldev",
        // deduped against the second file's "ldev*" -> also "ldev";
        // "*_tyr" has no concrete or strippable token -> skipped;
        // "cys*" -> stripped to "cys".
        #expect(hosts == ["ldev", "cys"])
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
        #expect(SSHConfigParser.concreteAlias(from: ["cys*"]) == "cys")
    }

    @Test func concreteAliasSkipsBareWildcard() {
        #expect(SSHConfigParser.concreteAlias(from: ["*"]) == nil)
    }

    @Test func concreteAliasSkipsDoublyWildcardedPattern() {
        #expect(SSHConfigParser.concreteAlias(from: ["*_jupy*"]) == nil)
    }

    @Test func concreteAliasSkipsLeadingWildcardPattern() {
        #expect(SSHConfigParser.concreteAlias(from: ["*_tyr"]) == nil)
    }
}
