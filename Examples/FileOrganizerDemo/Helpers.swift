import Foundation
import FoundationModels
import JevFoundationModels

// MARK: - API Key Resolution

/// Resolves the TypeSafe API key from the environment or `.env` file.
public func resolveAPIKey() -> String? {
    if let envVal = ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"], !envVal.isEmpty {
        return envVal
    }

    let searchPaths = [
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".env"),
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath).deletingLastPathComponent().appendingPathComponent(".env")
    ]

    for envURL in searchPaths {
        guard let contents = try? String(contentsOf: envURL, encoding: .utf8) else { continue }
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("#") || trimmed.isEmpty { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 && parts[0].trimmingCharacters(in: .whitespaces) == "TYPESAFE_API_KEY" {
                var val = parts[1].trimmingCharacters(in: .whitespaces)
                if (val.hasPrefix("\"") && val.hasSuffix("\"")) || (val.hasPrefix("'") && val.hasSuffix("'")) {
                    val = String(val.dropFirst().dropLast())
                }
                if !val.isEmpty { return val }
            }
        }
    }
    return nil
}

// MARK: - Visual Tree and Table Formatters

public func printDemoBanner() {
    print("""
    ================================================================================
      Jev & Apple Foundation Models: Dynamic Profile Directory Organizer
      Declarative Session Profiles • System One Multitask Decisions • Zero-Cost Turn Isolation
    ================================================================================
    """)
}

public func printStrategyBanner(strategy: OrganizationStrategy, quarantine: Bool) {
    let modeTitle = strategy == .domain ? "Domain-Specific Categorization" : "Actionable Workflow Triaging"
    print("""

    ================================================================================
      ACTIVE DYNAMIC PROFILE: \(modeTitle.uppercased())
      • Strategy:            \(strategy.rawValue)
      • Sensitive Vault:     \(quarantine ? "ENABLED (Routes credentials to Quarantine_Vault/)" : "DISABLED")
      • Turn Isolation:      isolateCurrentTurn (.historyTransform active)
    ================================================================================
    """)
}

/// Prints an ASCII directory tree representing files and folders.
public func printDirectoryTree(title: String, paths: [String]) {
    print("\n📂 \(title):")

    // Group paths by top-level directory or root
    var tree: [String: [String]] = [:]

    for p in paths.sorted() {
        let components = p.split(separator: "/").map(String.init)
        if components.count == 1 {
            tree["(root)", default: []].append(components[0])
        } else {
            let folder = components.dropLast().joined(separator: "/")
            let file = components.last ?? ""
            tree[folder, default: []].append(file)
        }
    }

    if let rootFiles = tree["(root)"] {
        for file in rootFiles {
            print("  ├── 📄 \(file)")
        }
    }

    let folders = tree.keys.filter { $0 != "(root)" }.sorted()
    for (idx, folder) in folders.enumerated() {
        let isLastFolder = (idx == folders.count - 1)
        let branch = isLastFolder ? "└──" : "├──"
        print("  \(branch) 📁 \(folder)/")

        let files = tree[folder] ?? []
        for (fIdx, file) in files.enumerated() {
            let isLastFile = (fIdx == files.count - 1)
            let fileIndent = isLastFolder ? "      " : "  │   "
            let subBranch = isLastFile ? "└──" : "├──"
            print("\(fileIndent)\(subBranch) 📄 \(file)")
        }
    }
    print("")
}

/// Prints a formatted audit table of all evaluated files with per-file decision latency.
public func printAuditTable(organizedFiles: [OrganizedFile]) {
    print("┌───────────────────────────────────┬──────────────┬──────────────┬───────────┬──────┬───────────┬───────────┬───────────────────────────────┐")
    print("│ File                              │ Domain       │ Workflow     │ Sensitive │ Conf │ Jev Model │ Total E2E │ Destination Path              │")
    print("├───────────────────────────────────┼──────────────┼──────────────┼───────────┼──────┼───────────┼───────────┼───────────────────────────────┤")

    for o in organizedFiles {
        let file = String(o.file.relativePath.prefix(33)).padding(toLength: 33, withPad: " ", startingAt: 0)
        let domain = String(o.decision.domain.rawValue.prefix(12)).padding(toLength: 12, withPad: " ", startingAt: 0)
        let workflow = String(o.decision.workflowStage.rawValue.prefix(12)).padding(toLength: 12, withPad: " ", startingAt: 0)
        let sensitive = (o.decision.isSensitive ? "⚠️  YES" : "   No ").padding(toLength: 9, withPad: " ", startingAt: 0)
        let conf = " \(o.decision.confidenceScore)/3  "
        let jevModel = o.serverDurationMs.map { String(format: "%6.1f ms ", $0) } ?? "    n/a    "
        let totalLatency = String(format: "%6.1f ms ", o.durationMs)
        let dest = String(o.destinationRelativePath.prefix(29)).padding(toLength: 29, withPad: " ", startingAt: 0)

        print("│ \(file) │ \(domain) │ \(workflow) │ \(sensitive) │\(conf)│\(jevModel)│\(totalLatency)│ \(dest) │")
    }

    print("└───────────────────────────────────┴──────────────┴──────────────┴───────────┴──────┴───────────┴───────────┴───────────────────────────────┘")
}

/// Prints aggregate decision latency, throughput, and token consumption metrics.
public func printTelemetrySummary(strategy: OrganizationStrategy, organizedFiles: [OrganizedFile]) {
    guard !organizedFiles.isEmpty else { return }

    let totalDuration = organizedFiles.reduce(0.0) { $0 + $1.durationMs }
    let avgDuration = totalDuration / Double(organizedFiles.count)
    let minDuration = organizedFiles.map(\.durationMs).min() ?? 0.0
    let maxDuration = organizedFiles.map(\.durationMs).max() ?? 0.0

    let serverTimes = organizedFiles.compactMap(\.serverDurationMs)
    let serverComputeLine: String
    let networkOverheadLine: String

    if !serverTimes.isEmpty {
        let avgServerTime = serverTimes.reduce(0.0, +) / Double(serverTimes.count)
        let networkOverhead = max(0.0, avgDuration - avgServerTime)
        serverComputeLine = String(format: "  • Jev Model Compute (Cloud):  %.1f ms / decision (Pure System One model inference)", avgServerTime)
        networkOverheadLine = String(format: "  • Network Transit (RTT):      %.1f ms / request (Trans-Atlantic client ↔ server round-trip)", networkOverhead)
    } else {
        serverComputeLine = "  • Jev Model Compute (Cloud):  n/a"
        networkOverheadLine = "  • Network Transit (RTT):      n/a"
    }

    let totalInputTokens = organizedFiles.reduce(0) { $0 + $1.inputTokens }
    let totalOutputTokens = organizedFiles.reduce(0) { $0 + $1.outputTokens }
    let totalTokens = totalInputTokens + totalOutputTokens
    let avgTokens = Double(totalTokens) / Double(organizedFiles.count)

    print("""

    ================================================================================
      ⚡️ JEV DECISION TELEMETRY & LATENCY BREAKDOWN (\(strategy.rawValue.uppercased()) STRATEGY)
    ================================================================================
      • Files Evaluated:            \(organizedFiles.count)
    \(serverComputeLine)
    \(networkOverheadLine)
      • Total End-to-End Latency:   \(String(format: "%.1f ms / file", avgDuration)) (Wall-clock from prompt to decoded object)
      • Latency Range (Min/Max):    \(String(format: "%.1f ms (min)  —  %.1f ms (max)", minDuration, maxDuration))
      • Token Consumption:          \(totalTokens) tokens (\(totalInputTokens) input, \(totalOutputTokens) output)
      • Average Tokens / File:      \(String(format: "%.1f tokens", avgTokens))
    ================================================================================
    """)
}
