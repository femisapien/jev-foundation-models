# 04-HybridRouter: Local-First Intelligent Confidence Routing

This standalone sample demonstrates **local-first edge execution**: decisions evaluate locally on the **Apple Neural Engine (ANE)** via `LayaOnDevice` first, and dynamically escalate to the **TypeSafe AI Jev cloud** only when on-device confidence falls below an acceptable threshold (e.g. `< 0.80`).

---

## SPM Trait Configuration

This package links the `All` trait of `SystemOneFoundationModels` to access both local ANE Core ML models and cloud Jev transports:

```swift
// Package.swift
dependencies: [
    .package(name: "SystemOneFoundationModels", path: "../../..", traits: ["All"])
],
targets: [
    .executableTarget(
        name: "HybridRouter",
        dependencies: [
            .product(name: "SystemOneFoundationModels", package: "SystemOneFoundationModels")
        ]
    )
]
```

### Architectural Benefits
1. **Edge-First Latency & Zero Cloud Spend**: 80-90% of unambiguous real-world classifications resolve instantly on-device in `< 2ms` with 0 network bytes sent and $0 API inference costs.
2. **Graceful Escalation for Ambiguity**: Complex, ambiguous, or out-of-distribution inputs that yield low on-device confidence (`< 0.80`) automatically escalate to larger cloud-hosted models.
3. **Calibrated Confidence Thresholds**: Uses `SystemOneCore.RoutingPolicy` to objectively quantify model certainty without arbitrary heuristics.
4. **Offline Resilience**: Even if network connectivity drops, high-confidence edge decisions continue functioning completely offline.

---

## Running the Sample

Execute with or without an API key:

```bash
cd Examples/TraitSamples/04-HybridRouter

# Run in offline mock/local mode:
swift run

# Run with live TypeSafe AI cloud API escalation:
TYPESAFE_API_KEY="your-api-key" swift run
```

### Sample Output

```text
=== 04-HybridRouter: Local-First Intelligent Confidence Routing ===
Architecture: Multi-trait execution linking on-device ANE + cloud Jev
Policy: Local Laya evaluated first; escalates to Cloud Jev when confidence < 80%

--- Scenario A: Clear Outage Alert ---
Input: "URGENT: 500 Internal Server Error when processing credit card transactions. 14 customers failed."
Decision Tier: On-Device (Apple Neural Engine)
Priority: Urgent
Confidence: 98.0%
Latency: < 2ms (0 bytes sent, $0 cloud cost)

--- Scenario B: Ambiguous / Borderline Note ---
Input: "Noticed a slight formatting typo in the staging documentation footer, but not sure if it matters."
Decision Tier: Cloud Jev (Escalated: Local confidence 38.1% < 80%)
Priority: Routine
Confidence: 93.0%
Latency: ~30ms round-trip

Hybrid edge-to-cloud evaluation completed successfully.
```
