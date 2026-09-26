import Foundation
import FoundationModels
import SystemOneCore
import LayaFoundationModels

// MARK: - Mock URLProtocol for Offline / Demo Fallback

final class MockLayaServeProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _responseBody: Data = {
        """
        {
            "model": "laya-multilingual-v2",
            "answers": {
                "score": {
                    "type": "score",
                    "score": 3.4,
                    "confidence": 0.94,
                    "probabilities": {
                        "0": 0.01,
                        "1": 0.04,
                        "2": 0.15,
                        "3": 0.65,
                        "4": 0.15
                    },
                    "legend": {
                        "0": "Informational",
                        "1": "Low Risk",
                        "2": "Moderate Risk",
                        "3": "High Risk",
                        "4": "Critical Vulnerability"
                    }
                }
            },
            "usage": { "input_tokens": 128, "output_tokens": 5 },
            "server_duration_ms": 11.2
        }
        """.data(using: .utf8)!
    }()

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://laya.internal-vpc.net:8443/v1/systemone")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json",
                "x-envoy-upstream-service-time": "11.2"
            ]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.lock.withLock { Self._responseBody })
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

print("=== 03-PrivateLayaServer: Self-Hosted Enterprise Laya Cluster ===")
print("Architecture: Private VPC Kubernetes cluster running `laya-serve`")
print("Target Endpoint: Custom internal DNS with TLS and Bearer Token Auth")

let serveURLEnv = ProcessInfo.processInfo.environment["LAYA_SERVE_URL"]
let serveTokenEnv = ProcessInfo.processInfo.environment["LAYA_SERVE_TOKEN"]

let endpoint: LayaEndpoint
let model: LayaLanguageModel

if let serveURLEnv, let url = URL(string: serveURLEnv) {
    print("Mode: Live VPC Cluster (\(url.absoluteString))")
    endpoint = .custom(url)
    model = LayaLanguageModel(
        endpoint: endpoint,
        modelID: "laya-multilingual-v2",
        apiKey: serveTokenEnv
    )
} else {
    print("Mode: Simulated VPC Cluster (Set LAYA_SERVE_URL to connect to a live cluster)")
    let defaultVPCURL = URL(string: "https://laya.internal-vpc.net:8443/v1/systemone")!
    endpoint = .custom(defaultVPCURL)

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockLayaServeProtocol.self]
    let mockSession = URLSession(configuration: config)

    model = LayaLanguageModel(
        endpoint: endpoint,
        modelID: "laya-multilingual-v2",
        apiKey: "vpc-k8s-service-account-token",
        session: mockSession
    )
}

let session = LanguageModelSession(model: model)

let vulnerabilityReport = """
SECURITY SCAN REPORT
Target: /api/v2/checkout/payment_tokens
Finding: Unchecked SQL concatenation in dynamic search query parameter 'filter'.
Trace: User-supplied 'sort_order' string concatenated directly into prepared statement builder without sanitization.
Exploitation Risk: Potential full read access to 'tenants_billing_vault' table.
CVSS Vector: CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:N
"""

print("\n--- Vulnerability Finding ---")
print(vulnerabilityReport.trimmingCharacters(in: .whitespacesAndNewlines))
print("-----------------------------\n")

print("Evaluating rubric severity score via private laya-serve cluster...")

let severityRubric = [
    "Informational",
    "Low Risk",
    "Moderate Risk",
    "High Risk",
    "Critical Vulnerability"
]

let scoreResult = try await session.score(
    "Score the severity of this vulnerability according to the enterprise risk rubric",
    levels: severityRubric,
    state: vulnerabilityReport
)

print("\n=== Laya-Serve Evaluation Result ===")
print("• Weighted Rubric Score: \(String(format: "%.2f", scoreResult.value)) / \(severityRubric.count - 1).00")
print("• Most Likely Level: \(scoreResult.mostLikelyLevel) (Index \(scoreResult.mostLikelyIndex))")
print("• Evaluation Confidence: \(String(format: "%.1f%%", scoreResult.confidence * 100))")
print("• Probability Distribution across Rubric Levels:")
for (idx, level) in severityRubric.enumerated() {
    let prob = idx < scoreResult.probabilities.count ? scoreResult.probabilities[idx] : 0.0
    print("    Level \(idx) [\(level)]: \(String(format: "%.1f%%", prob * 100))")
}

print("\nRequest dispatched over private VPC transport with internal authentication.")
