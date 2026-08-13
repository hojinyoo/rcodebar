import Foundation
import Testing

@testable import RCodeBar

struct RemoteHostTests {
    @Test func decodesLegacyHostWithoutEnabledFieldAsEnabled() throws {
        let legacyJSON = Data(#"{"alias":"myhost","lastOpenPath":"/home/dev"}"#.utf8)
        let host = try JSONDecoder().decode(RemoteHost.self, from: legacyJSON)
        #expect(host.enabled == true)
        #expect(host.alias == "myhost")
    }

    @Test func effectiveDisplayNameFallsBackToAlias() {
        let host = RemoteHost(alias: "myhost")
        #expect(host.effectiveDisplayName == "myhost")
    }

    @Test func effectiveDisplayNameUsesDisplayNameWhenSet() {
        let host = RemoteHost(alias: "myhost", displayName: "Dev Box")
        #expect(host.effectiveDisplayName == "Dev Box")
    }
}
