import Foundation
import Testing
@testable import RCodeBar

struct RemoteHostTests {
    @Test func decodesLegacyHostWithoutEnabledFieldAsEnabled() throws {
        let legacyJSON = Data(#"{"alias":"ldev","lastOpenPath":"/home/jovyan"}"#.utf8)
        let host = try JSONDecoder().decode(RemoteHost.self, from: legacyJSON)
        #expect(host.enabled == true)
        #expect(host.alias == "ldev")
    }

    @Test func effectiveDisplayNameFallsBackToAlias() {
        let host = RemoteHost(alias: "ldev")
        #expect(host.effectiveDisplayName == "ldev")
    }

    @Test func effectiveDisplayNameUsesDisplayNameWhenSet() {
        let host = RemoteHost(alias: "ldev", displayName: "Dev Pod")
        #expect(host.effectiveDisplayName == "Dev Pod")
    }
}
