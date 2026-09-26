import Foundation
import FoundationModels
import SystemOneCore
import JevFoundationModels

// MARK: - Choosable Engineering Team

enum EngineeringTeam: String, Choosable, CaseIterable {
    case infrastructure = "Infrastructure & SRE"
    case security = "Security Operations"
    case billing = "Billing & Payments"
    case mobile = "Mobile & Frontend"

    var optionIdentifier: String {
        rawValue
    }

    var optionDescription: String? {
        switch self {
        case .infrastructure:
            return "Server outages, Kubernetes clusters, database failovers, network routing"
        case .security:
            return "Credential leaks, unauthorized access attempts, vulnerability disclosures"
        case .billing:
            return "Subscription renewals, invoice disputes, Stripe webhook failures"
        case .mobile:
            return "iOS/Android client crashes, UI rendering glitches, app store release issues"
        }
    }
}

print("=== 02-CloudJevWorker: Lightning-Fast Cloud Ticket Triage ===")
print("Backend: TypeSafe AI Jev Decision API (System One Cloud)")
print("Binary footprint: Ultra-lean (Zero Core ML, PyTorch, or weights linked)")

guard let apiKey = ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"], !apiKey.isEmpty else {
    print("""
    ================================================================================
      ⚠️  CONFIGURATION ERROR: MISSING TYPESAFE_API_KEY
    ================================================================================
      This example application requires a valid TypeSafe AI API key to evaluate
      real System One decision models in the cloud. Synthetic mock bypasses are
      not permitted.

      Remediation:
        export TYPESAFE_API_KEY="your-typesafe-api-key"
    ================================================================================
    """)
    exit(1)
}

print("Mode: Live TypeSafe Cloud API (Key: \(apiKey.prefix(4))...)")
let model = JevLanguageModel(apiKey: apiKey)
let session = LanguageModelSession(model: model)

let ticket = """
INCIDENT #89412
Title: Production Postgres read-replica pool exhausted in us-east-1
Reported By: Datadog Alert Bot
Details: P99 query latency climbed from 12ms to 4200ms. Connection poolers reporting 100% saturation.
Multiple API endpoints returning HTTP 500 to customer requests. Immediate remediation needed.
"""

print("\n--- Incoming Ticket ---")
print(ticket.trimmingCharacters(in: .whitespacesAndNewlines))
print("-----------------------\n")

print("Evaluating triage decisions via LanguageModelSession...")

// 1. Evaluate urgency probability
let isUrgent = try await session.probability(
    of: "Is this incident an active production emergency requiring immediate on-call escalation?",
    state: ticket
)

// 2. Select responsible engineering team
let teamChoice = try await session.choice(
    "Assign the incident to the appropriate engineering team",
    from: EngineeringTeam.self,
    state: ticket
)

print("\n=== Triage Decisions ===")
print("• Urgent P0 Outage Probability: \(String(format: "%.1f%%", isUrgent * 100)) (\(isUrgent > 0.85 ? "🚨 CRITICAL ESCALATION" : "Standard Priority"))")
print("• Assigned Team: \(teamChoice.value.rawValue)")
print("• Routing Confidence: \(String(format: "%.1f%%", teamChoice.confidence * 100))")
print("• Alternative Candidate Probabilities:")
for (team, prob) in teamChoice.distribution.sorted(by: { $0.value > $1.value }) {
    print("    - \(team.rawValue): \(String(format: "%.1f%%", prob * 100))")
}
print("\nEvaluation successfully completed via Jev Foundation Models.")
