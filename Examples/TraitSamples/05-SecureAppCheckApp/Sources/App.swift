import SwiftUI
import FoundationModels
import SystemOneCore
import JevFoundationModels

@main
struct SecureAppCheckApp: App {
    init() {
        if CommandLine.arguments.contains("--cli") {
            // Direct CLI runner for terminal / automated evaluation
            print("=== 05-SecureAppCheckApp: Native App Check Proxy Demo (CLI) ===")

            final class ExitCodeBox: @unchecked Sendable {
                var code: Int32 = 0
            }
            let exitBox = ExitCodeBox()
            let semaphore = DispatchSemaphore(value: 0)

            Task.detached {
                exitBox.code = await Self.runCLI()
                semaphore.signal()
            }

            semaphore.wait()
            exit(exitBox.code)
        }
    }

    var body: some Scene {
        WindowGroup {
            SecureTriageView()
        }
    }

    nonisolated private static func runCLI() async -> Int32 {
        let isEmulator = CommandLine.arguments.contains("--emulator")
        let isLive = CommandLine.arguments.contains("--live")

        let projectID = "my-secure-project"
        let emulatorURL = URL(string: "http://127.0.0.1:5001/\(projectID)/us-central1/jevProxy")!
        let liveURL = URL(string: "https://us-central1-\(projectID).cloudfunctions.net/jevProxy")!

        let targetURL: URL
        let useSimulated: Bool

        if isLive {
            targetURL = liveURL
            useSimulated = false
            print("Target mode: Live Production Gateway")
        } else if isEmulator {
            targetURL = emulatorURL
            useSimulated = false
            print("Target mode: Local Firebase Emulator")
        } else {
            // Auto-detect if emulator is reachable
            if await isEmulatorOnline() {
                targetURL = emulatorURL
                useSimulated = false
                print("Target mode: Auto-detected Local Firebase Emulator")
            } else {
                targetURL = URL(string: "https://simulated-appcheck.local/jevProxy")!
                useSimulated = true
                print("Target mode: Local Emulator offline -> Falling back to Simulated Mock Gateway")
            }
        }

        let transport: any JevTransport
        if useSimulated {
            transport = MockJevTransport { _ in
                SecureTriageCategory.mockGatewayResponse()
            }
        } else {
            transport = ProxyTransport(
                proxyEndpoint: targetURL,
                credential: .header(name: "X-Firebase-AppCheck", provider: { "debug-app-check-token-local" }),
                session: {
                    let config = URLSessionConfiguration.ephemeral
                    config.timeoutIntervalForRequest = 10.0
                    return URLSession(configuration: config)
                }()
            )
        }

        let alertText = "Customer database dump leaked on public forum with session tokens."

        print("Endpoint: \(targetURL.absoluteString)")
        print("Alert: \(alertText)")
        print("Evaluating via LanguageModelSession.choice...")

        do {
            let session = LanguageModelSession(model: JevLanguageModel(transport: transport))
            let choice = try await session.choice(
                "Classify the incoming alert to determine response protocol",
                from: SecureTriageCategory.self,
                state: alertText
            )

            print("\n--- Evaluation Result ---")
            print("Winner: \(choice.value.rawValue)")
            print("Confidence: \(String(format: "%.1f%%", choice.confidence * 100))")
            print("Distribution:")
            for category in SecureTriageCategory.allCases {
                let prob = choice.probability(of: category)
                print("  - \(category.rawValue): \(String(format: "%.2f%%", prob * 100))")
            }
            print("-------------------------\n")
            return 0
        } catch {
            print("\n[ERROR] Evaluation failed: \(error.localizedDescription)\n")
            return 1
        }
    }

    nonisolated private static func isEmulatorOnline(timeout: TimeInterval = 0.5) async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:5001/") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: config)

        do {
            _ = try await session.data(for: request)
            return true
        } catch {
            return false
        }
    }
}
