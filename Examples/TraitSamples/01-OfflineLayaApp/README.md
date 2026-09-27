# 01-OfflineLayaApp: On-Device Neural Classification

This standalone sample demonstrates **100% offline document classification** on Apple Silicon using the **Apple Neural Engine (ANE)** via `LayaCoreMLEngine` and `LanguageModelSession.choice(...)` with a Swift `Choosable` enum.

---

## SPM Trait Configuration

This package links **only** the `Laya` trait of `SystemOneFoundationModels`:

```swift
// Package.swift
dependencies: [
    .package(name: "SystemOneFoundationModels", path: "../../..", traits: ["Laya"])
],
targets: [
    .executableTarget(
        name: "OfflineLayaApp",
        dependencies: [
            .product(name: "SystemOneFoundationModels", package: "SystemOneFoundationModels")
        ]
    )
]
```

### Architectural Benefits
1. **Zero Network Dependencies**: Neither `URLSessionTransport`, `ProxyTransport`, nor remote network code is linked into the binary.
2. **Air-Gapped & HIPAA / GDPR Compliant**: Sensitive documents (medical charts, legal contracts, financial disclosures) never leave the device.
3. **Hardware Acceleration**: Tokenization and masked token sequence embeddings run directly on the Apple Neural Engine and GPU via Core ML.
4. **Deterministic Sub-Millisecond Decisions**: Foundation Models requests evaluate through direct Core ML model passes without network latency or rate limits.

---

## Running the Sample

Execute from the sample directory:

```bash
cd Examples/TraitSamples/01-OfflineLayaApp
swift run
```

### Sample Output

```text
=== 01-OfflineLayaApp: 100% Offline Document Classification ===
Backend: Laya On-Device Core ML Engine (Apple Neural Engine)
Network code linked: 0 bytes (Air-gapped / Local-only)

Evaluating document:
PATIENT MEDICAL SUMMARY
Date: 2026-09-26
Patient: Jane Doe (DOB: 1985-04-12)
Chief Complaint: Acute migraine with visual aura.
Assessment: Stable vitals, prescribed sumatriptan 50mg PRN. Follow up in 2 weeks.

Classification Result: Medical Record
Confidence: 96.3%
Full Distribution:
  - Medical Record: 96.3%
  - Legal Contract: 1.5%
  - Invoice: 1.2%
  - Tax Form: 1.1%

Evaluation successfully completed entirely on-device without network access.
```
