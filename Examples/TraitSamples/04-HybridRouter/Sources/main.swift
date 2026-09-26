import Foundation
import FoundationModels
import SystemOneCore
import LayaOnDevice
import JevFoundationModels

// MARK: - Choosable Priority

enum ActionPriority: String, Choosable, CaseIterable {
    case routine = "Routine"
    case elevated = "Elevated"
    case urgent = "Urgent"

    var optionIdentifier: String {
        rawValue
    }

    var optionDescription: String? {
        switch self {
        case .routine:
            return "General inquiries, minor cosmetic issues, non-blocking requests"
        case .elevated:
            return "Single-user workflow blockage, degraded performance, intermittent glitches"
        case .urgent:
            return "Total service outage, data corruption, severe revenue loss or security breach"
        }
    }
}

// MARK: - Hybrid Router Orchestrator

final class EvaluationContext: @unchecked Sendable {
    private let lock = NSLock()
    private var _text: String = ""

    func set(text: String) {
        lock.withLock { _text = text }
    }

    func currentText() -> String {
        lock.withLock { _text }
    }
}

actor HybridRouter {
    private let localSession: LanguageModelSession
    private let cloudSession: LanguageModelSession
    private let policy: RoutingPolicy
    private let context = EvaluationContext()

    init(policy: RoutingPolicy = RoutingPolicy(escalateBelow: 0.80, autoAtOrAbove: 0.80)) {
        self.policy = policy
        let contextRef = self.context

        // 1. Configure Local Laya on-device engine
        let tokenizer = ModernBERTTokenizer.defaultTokenizer()
        let localEngine = LayaCoreMLEngine(tokenizer: tokenizer) { sequence in
            // Simulate ANE inference: high certainty for clear outage, low certainty for ambiguous text
            let text = contextRef.currentText()
            if text.contains("500 Internal Server Error") {
                // Clear outage: sorted keys ["Elevated", "Routine", "Urgent"] -> index 2 (Urgent) high
                return [-1.0, -1.0, 4.5]
            } else {
                // Ambiguous input: flat logits resulting in low confidence (near uniform distribution)
                return [1.0, 1.2, 0.9]
            }
        }
        let localModel = LayaOnDeviceLanguageModel(engine: localEngine)
        self.localSession = LanguageModelSession(model: localModel)

        // 2. Configure Cloud Jev engine
        let cloudApiKey = ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"]
        let cloudModel: JevLanguageModel
        if let cloudApiKey, !cloudApiKey.isEmpty {
            cloudModel = JevLanguageModel(apiKey: cloudApiKey)
        } else {
            let mock = MockJevTransport { request in
                JevResponse(
                    model: "jev-latest",
                    answers: [
                        "choice": SystemOneAnswer(
                            type: "choice",
                            choice: ActionPriority.routine.optionIdentifier,
                            confidence: 0.93,
                            probabilities: [
                                ActionPriority.routine.optionIdentifier: 0.93,
                                ActionPriority.elevated.optionIdentifier: 0.05,
                                ActionPriority.urgent.optionIdentifier: 0.02
                            ]
                        )
                    ],
                    usage: SystemOneUsage(inputTokens: 32, outputTokens: 2),
                    serverDurationMs: 16.4
                )
            }
            cloudModel = JevLanguageModel(transport: mock)
        }
        self.cloudSession = LanguageModelSession(model: cloudModel)
    }

    struct RouteResult: Sendable {
        let text: String
        let resolvedPriority: ActionPriority
        let confidence: Double
        let tier: String
        let latencyEstimate: String
    }

    func classify(text: String) async throws -> RouteResult {
        context.set(text: text)

        // Step 1: Evaluate locally on Apple Neural Engine
        let localChoice = try await localSession.choice(
            "Determine the triage priority",
            from: ActionPriority.self,
            state: text
        )

        // Step 2: Check confidence against routing policy threshold (0.80)
        let decision = policy.decide(confidence: localChoice.confidence)

        if decision == .auto {
            return RouteResult(
                text: text,
                resolvedPriority: localChoice.value,
                confidence: localChoice.confidence,
                tier: "On-Device (Apple Neural Engine)",
                latencyEstimate: "< 2ms (0 bytes sent, $0 cloud cost)"
            )
        } else {
            // Step 3: Confidence < 0.80 -> Escalate to cloud Jev
            let cloudChoice = try await cloudSession.choice(
                "Determine the triage priority",
                from: ActionPriority.self,
                state: text
            )

            return RouteResult(
                text: text,
                resolvedPriority: cloudChoice.value,
                confidence: cloudChoice.confidence,
                tier: "Cloud Jev (Escalated: Local confidence \(String(format: "%.1f%%", localChoice.confidence * 100)) < 80%)",
                latencyEstimate: "~30ms round-trip"
            )
        }
    }
}

// MARK: - Main Execution

print("=== 04-HybridRouter: Local-First Intelligent Confidence Routing ===")
print("Architecture: Multi-trait execution linking on-device ANE + cloud Jev")
print("Policy: Local Laya evaluated first; escalates to Cloud Jev when confidence < 80%\n")

let router = HybridRouter()

let scenarioA = "URGENT: 500 Internal Server Error when processing credit card transactions. 14 customers failed."
let scenarioB = "Noticed a slight formatting typo in the staging documentation footer, but not sure if it matters."

print("--- Scenario A: Clear Outage Alert ---")
let resultA = try await router.classify(text: scenarioA)
print("Input: \"\(resultA.text)\"")
print("Decision Tier: \(resultA.tier)")
print("Priority: \(resultA.resolvedPriority.rawValue)")
print("Confidence: \(String(format: "%.1f%%", resultA.confidence * 100))")
print("Latency: \(resultA.latencyEstimate)\n")

print("--- Scenario B: Ambiguous / Borderline Note ---")
let resultB = try await router.classify(text: scenarioB)
print("Input: \"\(resultB.text)\"")
print("Decision Tier: \(resultB.tier)")
print("Priority: \(resultB.resolvedPriority.rawValue)")
print("Confidence: \(String(format: "%.1f%%", resultB.confidence * 100))")
print("Latency: \(resultB.latencyEstimate)\n")

print("Hybrid edge-to-cloud evaluation completed successfully.")
