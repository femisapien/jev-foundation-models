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

actor HybridRouter {
    private let localSession: LanguageModelSession
    private let cloudSession: LanguageModelSession
    private let policy: RoutingPolicy

    init(
        localEngine: LayaCoreMLEngine,
        cloudApiKey: String,
        policy: RoutingPolicy = RoutingPolicy(escalateBelow: 0.80, autoAtOrAbove: 0.80)
    ) {
        self.policy = policy
        let localModel = LayaOnDeviceLanguageModel(engine: localEngine)
        self.localSession = LanguageModelSession(model: localModel)

        let cloudModel = JevLanguageModel(apiKey: cloudApiKey)
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

func resolveModelURL() -> URL? {
    if let envPath = ProcessInfo.processInfo.environment["LAYA_MODEL_PATH"], !envPath.isEmpty {
        let url = URL(fileURLWithPath: (envPath as NSString).expandingTildeInPath)
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return nil
    }

    let standardURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/dev.peterfriese.mailtriageapp/Models/LayaDecisionModel.mlmodelc")
    if FileManager.default.fileExists(atPath: standardURL.path) {
        return standardURL
    }

    return nil
}

var missingPrerequisites: [String] = []
var remediations: [String] = []

let cloudApiKey = ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"]
if cloudApiKey == nil || cloudApiKey?.isEmpty == true {
    missingPrerequisites.append("• TYPESAFE_API_KEY environment variable is missing or empty.")
    remediations.append("export TYPESAFE_API_KEY=\"your-typesafe-api-key\"")
}

let modelURL = resolveModelURL()
if modelURL == nil {
    let standardPath = "~/Library/Application Support/dev.peterfriese.mailtriageapp/Models/LayaDecisionModel.mlmodelc"
    missingPrerequisites.append("• Compiled Core ML model not found at \(standardPath) or LAYA_MODEL_PATH.")
    remediations.append("export LAYA_MODEL_PATH=\"/path/to/LayaDecisionModel.mlmodelc\"")
}

if !missingPrerequisites.isEmpty {
    print("""
    ================================================================================
      ⚠️  CONFIGURATION ERROR: MISSING HYBRID ROUTER PREREQUISITES
    ================================================================================
      The Hybrid Router evaluates requests locally on Apple Neural Engine first,
      escalating to TypeSafe AI Jev in the cloud when confidence falls below 80%.
      Synthetic mocks and fallbacks are not permitted.

      Missing Configuration:
    \(missingPrerequisites.map { "  " + $0 }.joined(separator: "\n"))

      Remediation:
    \(remediations.map { "  " + $0 }.joined(separator: "\n"))
    ================================================================================
    """)
    exit(1)
}

guard let validModelURL = modelURL, let validApiKey = cloudApiKey else {
    exit(1)
}

let tokenizer = ModernBERTTokenizer.defaultTokenizer()
let localEngine: LayaCoreMLEngine
do {
    localEngine = try LayaCoreMLEngine(modelURL: validModelURL, tokenizer: tokenizer)
} catch {
    print("""
    ================================================================================
      ⚠️  CONFIGURATION ERROR: FAILED TO LOAD CORE ML MODEL
    ================================================================================
      Failed to load Core ML model at:
        \(validModelURL.path)
      Underlying error: \(error.localizedDescription)

      Remediation:
        Verify the model was compiled with:
        xcrun coremlc compile LayaDecisionModel.mlpackage <output-dir>
        and set:
        export LAYA_MODEL_PATH="/path/to/LayaDecisionModel.mlmodelc"
    ================================================================================
    """)
    exit(1)
}

let router = HybridRouter(localEngine: localEngine, cloudApiKey: validApiKey)

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
