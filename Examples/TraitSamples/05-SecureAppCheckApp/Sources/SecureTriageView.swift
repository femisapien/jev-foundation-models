import SwiftUI
import FoundationModels
import SystemOneCore
import JevFoundationModels

// MARK: - Choosable Triage Category

enum SecureTriageCategory: String, Choosable, CaseIterable {
    case dataBreach = "Data Breach / Security"
    case systemOutage = "System Outage"
    case billingDispute = "Billing Dispute"
    case featureRequest = "Feature Request"

    var optionIdentifier: String {
        rawValue
    }

    var optionDescription: String? {
        switch self {
        case .dataBreach:
            return "Potential security leaks, credential exposure, or unauthorized access"
        case .systemOutage:
            return "API degradation, database failure, or service downtime"
        case .billingDispute:
            return "Payment issues, chargebacks, or credit card failures"
        case .featureRequest:
            return "Product improvement ideas and general user feedback"
        }
    }

    static func mockGatewayResponse() -> JevResponse {
        JevResponse(
            model: "jev-latest",
            answers: [
                "choice": SystemOneAnswer(
                    type: "choice",
                    choice: SecureTriageCategory.dataBreach.optionIdentifier,
                    confidence: 0.98,
                    probabilities: [
                        SecureTriageCategory.dataBreach.optionIdentifier: 0.98,
                        SecureTriageCategory.systemOutage.optionIdentifier: 0.01,
                        SecureTriageCategory.billingDispute.optionIdentifier: 0.005,
                        SecureTriageCategory.featureRequest.optionIdentifier: 0.005
                    ]
                )
            ],
            usage: SystemOneUsage(inputTokens: 64, outputTokens: 2),
            serverDurationMs: 18.5
        )
    }
}

// MARK: - Proxy Gateway Environment

enum ProxyEnvironment: String, CaseIterable, Identifiable, Sendable {
    case localEmulator = "Local Emulator (Port 5001)"
    case production = "Production Cloud Functions"
    case simulated = "Simulated Gateway (Offline)"

    var id: String { rawValue }

    func endpoint(projectID: String) -> URL {
        switch self {
        case .localEmulator:
            return URL(string: "http://127.0.0.1:5001/\(projectID)/us-central1/jevProxy")!
        case .production:
            return URL(string: "https://us-central1-\(projectID).cloudfunctions.net/jevProxy")!
        case .simulated:
            return URL(string: "https://simulated-appcheck.local/jevProxy")!
        }
    }
}

// MARK: - Observable View State

@Observable
@MainActor
final class SecureTriageViewModel {
    var projectID: String = "my-secure-project"
    var environment: ProxyEnvironment = .simulated
    var customAppCheckToken: String = "debug-app-check-token-local"
    var inputText: String = "Customer database dump leaked on public forum with session tokens."
    var isEvaluating: Bool = false
    var resultText: String?
    var errorMessage: String?
    var lastServerDurationMs: Double?

    func evaluate() async {
        isEvaluating = true
        errorMessage = nil
        resultText = nil
        lastServerDurationMs = nil

        do {
            let session = try buildSession()
            let choice = try await session.choice(
                "Classify the incoming alert to determine response protocol",
                from: SecureTriageCategory.self,
                state: inputText
            )

            resultText = """
            Category: \(choice.value.rawValue)
            Confidence: \(String(format: "%.1f%%", choice.confidence * 100))
            Gateway: Verified X-Firebase-AppCheck
            """
        } catch {
            errorMessage = error.localizedDescription
        }

        isEvaluating = false
    }

    private func buildSession() throws -> LanguageModelSession {
        let token = customAppCheckToken
        let endpoint = environment.endpoint(projectID: projectID)

        let transport: any JevTransport
        if environment == .simulated {
            transport = MockJevTransport { _ in
                // Simulates backend response after verifying App Check header
                SecureTriageCategory.mockGatewayResponse()
            }
        } else {
            // Native ProxyTransport configured with App Check header
            transport = ProxyTransport(
                proxyEndpoint: endpoint,
                credential: .header(name: "X-Firebase-AppCheck", provider: { token })
            )
        }

        let model = JevLanguageModel(transport: transport)
        return LanguageModelSession(model: model)
    }
}

// MARK: - Native SwiftUI View

public struct SecureTriageView: View {
    @State private var viewModel = SecureTriageViewModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section("Proxy Gateway Configuration") {
                    Picker("Target Environment", selection: $viewModel.environment) {
                        ForEach(ProxyEnvironment.allCases) { env in
                            Text(env.rawValue).tag(env)
                        }
                    }

                    if viewModel.environment != .simulated {
                        TextField("Firebase Project ID", text: $viewModel.projectID)
                    }

                    TextField("App Check Token / Debug Secret", text: $viewModel.customAppCheckToken)
                        .font(.caption)
                }

                Section("Incident Report") {
                    TextEditor(text: $viewModel.inputText)
                        .frame(minHeight: 80)

                    Button {
                        Task {
                            await viewModel.evaluate()
                        }
                    } label: {
                        HStack {
                            if viewModel.isEvaluating {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(viewModel.isEvaluating ? "Verifying & Evaluating..." : "Evaluate via Secure Proxy")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isEvaluating || viewModel.inputText.isEmpty)
                }

                if let result = viewModel.resultText {
                    Section("Verified Triage Result") {
                        Text(result)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                }

                if let error = viewModel.errorMessage {
                    Section("Gateway Error") {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Secure App Check Triage")
        }
        .frame(minWidth: 460, minHeight: 480)
    }
}
