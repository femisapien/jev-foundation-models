# 03-PrivateLayaServer: Self-Hosted Enterprise Cluster

This standalone sample demonstrates connecting an Apple Foundation Models client directly to an internal, self-hosted **`laya-serve`** cluster in a private VPC using **`LayaLanguageModel`**, **`LayaHTTPBackend`**, and **`session.score(...)`**.

---

## SPM Trait Configuration

This package links **only** the `LayaServe` trait of `SystemOneFoundationModels`:

```swift
// Package.swift
dependencies: [
    .package(name: "SystemOneFoundationModels", path: "../../..", traits: ["LayaServe"])
],
targets: [
    .executableTarget(
        name: "PrivateLayaServer",
        dependencies: [
            .product(name: "SystemOneFoundationModels", package: "SystemOneFoundationModels")
        ]
    )
]
```

### Architectural Benefits
1. **Air-Gapped Cloud / VPC Isolation**: Traffic never transits the public internet. Endpoints resolve over private DNS (e.g. `laya.internal-vpc.net`) within AWS VPC, GCP VPC, or Kubernetes clusters.
2. **Zero Third-Party SaaS Reliance**: Full data sovereignty; prompts and document contexts stay entirely on company-owned infrastructure.
3. **Custom Authentication & Mutual TLS**: Supports internal bearer tokens (e.g. Kubernetes Service Account JWTs, Vault tokens) and customized `URLSession` configurations for enterprise root certificates and mTLS.
4. **Calibrated Continuous Scoring**: Uses `LanguageModelSession.score(...)` to evaluate multi-level ordinal rubrics (e.g. CVSS risk levels) with calibrated probability distributions.

---

## Running the Sample

Execute in simulated mode or against a real internal endpoint:

```bash
cd Examples/TraitSamples/03-PrivateLayaServer

# Run in simulated VPC mode:
swift run

# Run against a live internal laya-serve cluster:
LAYA_SERVE_URL="https://laya.internal-vpc.net:8443/v1/systemone" \
LAYA_SERVE_TOKEN="Bearer eyJhbGciOi..." \
swift run
```

### Sample Output

```text
=== 03-PrivateLayaServer: Self-Hosted Enterprise Laya Cluster ===
Architecture: Private VPC Kubernetes cluster running `laya-serve`
Target Endpoint: Custom internal DNS with TLS and Bearer Token Auth
Mode: Simulated VPC Cluster (Set LAYA_SERVE_URL to connect to a live cluster)

--- Vulnerability Finding ---
SECURITY SCAN REPORT
Target: /api/v2/checkout/payment_tokens
Finding: Unchecked SQL concatenation in dynamic search query parameter 'filter'.
Trace: User-supplied 'sort_order' string concatenated directly into prepared statement builder without sanitization.
Exploitation Risk: Potential full read access to 'tenants_billing_vault' table.
CVSS Vector: CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:N
-----------------------------

Evaluating rubric severity score via private laya-serve cluster...

=== Laya-Serve Evaluation Result ===
• Weighted Rubric Score: 3.40 / 4.00
• Most Likely Level: High Risk (Index 3)
• Evaluation Confidence: 94.0%
• Probability Distribution across Rubric Levels:
    Level 0 [Informational]: 1.0%
    Level 1 [Low Risk]: 4.0%
    Level 2 [Moderate Risk]: 15.0%
    Level 3 [High Risk]: 65.0%
    Level 4 [Critical Vulnerability]: 15.0%

Request dispatched over private VPC transport with internal authentication.
```
