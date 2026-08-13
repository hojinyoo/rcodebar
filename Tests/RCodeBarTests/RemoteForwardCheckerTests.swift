import Testing
@testable import RCodeBar

struct RemoteForwardCheckerTests {
    // Fixture: real `ssh -G <host>` output captured with the RemoteForward wired up.
    private let sshGOutputWithForward = """
    host ldev
    user dev
    hostname 198.51.100.10
    port 22
    controlmaster auto
    remoteforward 47000 [127.0.0.1]:47000
    identityfile ~/.ssh/id_rsa
    """

    private let sshGOutputWithoutForward = """
    host ldev
    user dev
    hostname 198.51.100.10
    port 22
    controlmaster auto
    identityfile ~/.ssh/id_rsa
    """

    @Test func detectsForwardOnMatchingPort() {
        #expect(RemoteForwardChecker.hasForward(in: sshGOutputWithForward, port: 47000))
    }

    @Test func noForwardWhenAbsent() {
        #expect(!RemoteForwardChecker.hasForward(in: sshGOutputWithoutForward, port: 47000))
    }

    @Test func ignoresForwardOnADifferentPort() {
        let output = "remoteforward 8888 [127.0.0.1]:8888\n"
        #expect(!RemoteForwardChecker.hasForward(in: output, port: 47000))
    }

    @Test func emptyOutputHasNoForward() {
        #expect(!RemoteForwardChecker.hasForward(in: "", port: 47000))
    }
}
