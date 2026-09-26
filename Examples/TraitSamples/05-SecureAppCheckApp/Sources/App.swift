import SwiftUI
import FoundationModels
import SystemOneCore
import JevFoundationModels

@main
struct SecureAppCheckApp: App {
    init() {
        if CommandLine.arguments.contains("--cli") {
            // Direct CLI runner for terminal / headless verification
            print("=== 05-SecureAppCheckApp: Native App Check Proxy Demo (CLI) ===")
            _ = ProxyTransport(
                proxyEndpoint: URL(string: "https://simulated-appcheck.local/jevProxy")!,
                credential: .header(name: "X-Firebase-AppCheck", provider: { "valid-app-check-token" }),
                session: {
                    let config = URLSessionConfiguration.ephemeral
                    return URLSession(configuration: config)
                }()
            )
            print("Configured ProxyTransport with X-Firebase-AppCheck header authentication.")
            print("Target: Dual-Mode (Local Emulator & Production Cloud Functions)")
            exit(0)
        }
    }

    var body: some Scene {
        WindowGroup {
            SecureTriageView()
        }
    }
}
