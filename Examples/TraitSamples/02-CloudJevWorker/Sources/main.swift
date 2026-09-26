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

let apiKey = ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"]

let model: JevLanguageModel
if let apiKey, !apiKey.isEmpty {
    print("Mode: Live TypeSafe Cloud API (Key: \(apiKey.prefix(4))...)")
    model = JevLanguageModel(apiKey: apiKey)
} else {
    print("Mode: Deterministic Offline Mock Transport (Set TYPESAFE_API_KEY for live cloud API)")
    let mock = MockJevTransport { request in
        // Return synthetic response based on question type
        var answers: [String: SystemOneAnswer] = [:]
        for (key, question) in request.questions {
            switch question {
            case .noul:
                // High urgency for outage ticket
                answers[key] = SystemOneAnswer(type: "noul", noul: 0.94, confidence: 0.95)
            case .choice:
                // Route to Infrastructure
                answers[key] = SystemOneAnswer(
                    type: "choice",
                    choice: EngineeringTeam.infrastructure.optionIdentifier,
                    confidence: 0.92,
                    probabilities: [
                        EngineeringTeam.infrastructure.optionIdentifier: 0.92,
                        EngineeringTeam.security.optionIdentifier: 0.05,
                        EngineeringTeam.billing.optionIdentifier: 0.02,
                        EngineeringTeam.mobile.optionIdentifier: 0.01
                    ]
                )
            case .score:
                answers[key] = SystemOneAnswer(type: "score", score: 3.0, confidence: 0.90)
            }
        }
        return JevResponse(
            model: "jev-latest",
            answers: answers,
            usage: SystemOneUsage(inputTokens: 48, outputTokens: 2),
            serverDurationMs: 14.8
        )
    }
    model = JevLanguageModel(transport: mock)
}

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
