import Foundation
import FoundationModels
import SystemOneCore
import LayaOnDevice

// MARK: - Choosable Document Category

enum DocumentCategory: String, Choosable, CaseIterable {
    case invoice = "Invoice"
    case medicalRecord = "Medical Record"
    case legalContract = "Legal Contract"
    case taxForm = "Tax Form"

    var optionIdentifier: String {
        rawValue
    }

    var optionDescription: String? {
        switch self {
        case .invoice:
            return "Commercial invoices, purchase orders, receipts, and billing statements"
        case .medicalRecord:
            return "Clinical notes, patient summaries, lab results, and health prescriptions"
        case .legalContract:
            return "Non-disclosure agreements, service level contracts, and legal terms"
        case .taxForm:
            return "W-2, 1099, tax returns, and government fiscal filings"
        }
    }
}

print("=== 01-OfflineLayaApp: 100% Offline Document Classification ===")
print("Backend: Laya On-Device Core ML Engine (Apple Neural Engine)")
print("Network code linked: 0 bytes (Air-gapped / Local-only)")

func resolveModelURL() -> URL {
    let standardURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/dev.peterfriese.mailtriageapp/Models/LayaDecisionModel.mlmodelc")

    let selectedURL: URL
    if let envPath = ProcessInfo.processInfo.environment["LAYA_MODEL_PATH"], !envPath.isEmpty {
        selectedURL = URL(fileURLWithPath: (envPath as NSString).expandingTildeInPath)
    } else {
        selectedURL = standardURL
    }

    guard FileManager.default.fileExists(atPath: selectedURL.path) else {
        print("""
        ================================================================================
          ⚠️  CONFIGURATION ERROR: COMPILED CORE ML MODEL NOT FOUND
        ================================================================================
          Laya on-device inference requires a compiled Core ML model (.mlmodelc).
          Looked at:
            \(selectedURL.path)

          Remediation:
            export LAYA_MODEL_PATH="/path/to/LayaDecisionModel.mlmodelc"
            # Or place the compiled model at:
            # ~/Library/Application Support/dev.peterfriese.mailtriageapp/Models/LayaDecisionModel.mlmodelc
        ================================================================================
        """)
        exit(1)
    }

    return selectedURL
}

let modelURL = resolveModelURL()
let tokenizer = ModernBERTTokenizer.defaultTokenizer()
let engine: LayaCoreMLEngine
do {
    engine = try LayaCoreMLEngine(modelURL: modelURL, tokenizer: tokenizer)
} catch {
    print("""
    ================================================================================
      ⚠️  CONFIGURATION ERROR: FAILED TO LOAD CORE ML MODEL
    ================================================================================
      Failed to load Core ML model at:
        \(modelURL.path)
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

let model = LayaOnDeviceLanguageModel(engine: engine)
let session = LanguageModelSession(model: model)

let sampleDocument = """
PATIENT MEDICAL SUMMARY
Date: 2026-09-26
Patient: Jane Doe (DOB: 1985-04-12)
Chief Complaint: Acute migraine with visual aura.
Assessment: Stable vitals, prescribed sumatriptan 50mg PRN. Follow up in 2 weeks.
"""

print("\nEvaluating document:\n\(sampleDocument.trimmingCharacters(in: .whitespacesAndNewlines))\n")

let choice = try await session.choice(
    "Classify the document into its primary category",
    from: DocumentCategory.self,
    state: sampleDocument
)

print("Classification Result: \(choice.value.rawValue)")
print("Confidence: \(String(format: "%.1f%%", choice.confidence * 100))")
print("Full Distribution:")
for (category, prob) in choice.distribution.sorted(by: { $0.value > $1.value }) {
    print("  - \(category.rawValue): \(String(format: "%.1f%%", prob * 100))")
}
print("\nEvaluation successfully completed entirely on-device without network access.")
