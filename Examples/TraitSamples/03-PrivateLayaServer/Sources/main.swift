import Foundation
import FoundationModels
import SystemOneCore
import LayaFoundationModels

func probeServer(url: URL, timeout: TimeInterval = 2.0) async -> Bool {
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

print("=== 03-PrivateLayaServer: Self-Hosted Enterprise Laya Cluster ===")
print("Architecture: Self-hosted laya-serve cluster")

let defaultURLString = "http://127.0.0.1:8000/v1/systemone"
let serveURLString = ProcessInfo.processInfo.environment["LAYA_SERVE_URL"] ?? defaultURLString
guard let serveURL = URL(string: serveURLString) else {
    print("Invalid LAYA_SERVE_URL: \(serveURLString)")
    exit(1)
}

if !(await probeServer(url: serveURL)) {
    print("""
    ================================================================================
      ⚠️  CONFIGURATION ERROR: LAYA-SERVE UNREACHABLE
    ================================================================================
      Error: laya-serve daemon is not reachable at \(serveURL.absoluteString).

      Remediation:
        laya-serve
        # Or specify a reachable server:
        # export LAYA_SERVE_URL="http://127.0.0.1:8000/v1/systemone"
    ================================================================================
    """)
    exit(1)
}

print("Target Endpoint: \(serveURL.absoluteString)")
let serveTokenEnv = ProcessInfo.processInfo.environment["LAYA_SERVE_TOKEN"]
let endpoint = LayaEndpoint.custom(serveURL)
let model = LayaLanguageModel(
    endpoint: endpoint,
    modelID: "laya-multilingual-v2",
    apiKey: serveTokenEnv
)

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

print("\nRequest dispatched over private laya-serve transport with authentication.")
