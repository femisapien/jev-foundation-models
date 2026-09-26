import Foundation
import Security

/// Thread-safe contract for securely persisting sensitive credentials.
public protocol KeychainServiceProtocol: Sendable {
    func get(key: String) -> String?
    func set(_ value: String?, for key: String) throws
    func delete(key: String) throws

    var typesafeApiKey: String? { get set }
    var hostedVpcToken: String? { get set }
    var huggingFaceToken: String? { get set }
}

/// Production implementation of `KeychainServiceProtocol` using Apple's Security framework.
/// Includes thread-safe locking and graceful in-memory fallback for unsigned test environments.
/// Conforms to SEC-1: Credentials are never written to UserDefaults.
public final class KeychainService: KeychainServiceProtocol, @unchecked Sendable {
    private let serviceName: String
    private let defaults: UserDefaults
    private let lock = NSLock()
    private static let fallbackLock = NSLock()
    nonisolated(unsafe) private static var sharedFallbackStore: [String: [String: String]] = [:]
    private let persistentKeyPrefix = "ai.typesafe.secure.storage."

    public static let keyTypeSafeAPIKey = "typesafeApiKey"
    public static let keyHostedVPCToken = "hostedVpcToken"
    public static let keyHuggingFaceToken = "huggingFaceToken"

    /// Resets the in-memory fallback store across all service domains or for a specific service.
    /// Used by test suites to guarantee fresh, isolated state.
    public static func resetFallbackStore(for serviceName: String? = nil) {
        fallbackLock.lock()
        defer { fallbackLock.unlock() }
        if let serviceName = serviceName {
            sharedFallbackStore.removeValue(forKey: serviceName)
        } else {
            sharedFallbackStore.removeAll()
        }
    }

    private var inMemoryFallback: [String: String] {
        get {
            Self.fallbackLock.lock()
            defer { Self.fallbackLock.unlock() }
            return Self.sharedFallbackStore[serviceName] ?? [:]
        }
        set {
            Self.fallbackLock.lock()
            defer { Self.fallbackLock.unlock() }
            Self.sharedFallbackStore[serviceName] = newValue
        }
    }

    public init(
        serviceName: String = "ai.typesafe.mailtriage",
        defaults: UserDefaults = .standard
    ) {
        self.serviceName = serviceName
        self.defaults = defaults
        purgeAndMigrateLegacyDefaults()
    }

    /// One-time migration/purge routine (SEC-1) that checks UserDefaults for any legacy keys
    /// prefixed with `ai.typesafe.secure.storage.` and removes them after migrating to Keychain.
    private func purgeAndMigrateLegacyDefaults() {
        let dictionary = defaults.dictionaryRepresentation()
        for (storageKey, value) in dictionary where storageKey.hasPrefix(persistentKeyPrefix) {
            let secretKey = String(storageKey.dropFirst(persistentKeyPrefix.count))
            if let stringValue = value as? String, !stringValue.isEmpty {
                // If not already in Keychain, migrate it
                if get(key: secretKey) == nil {
                    try? set(stringValue, for: secretKey)
                }
            }
            defaults.removeObject(forKey: storageKey)
        }
    }

    public var typesafeApiKey: String? {
        get {
            if serviceName == "ai.typesafe.mailtriage",
               let envKey = ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"],
               !envKey.isEmpty {
                if get(key: Self.keyTypeSafeAPIKey) != envKey {
                    try? set(envKey, for: Self.keyTypeSafeAPIKey)
                }
                return envKey
            }
            if let stored = get(key: Self.keyTypeSafeAPIKey), !stored.isEmpty {
                return stored
            }
            guard serviceName == "ai.typesafe.mailtriage" else {
                return nil
            }
            if let dotEnvKey = BackendConfigurationStore.loadKeyFromDotEnv("TYPESAFE_API_KEY"), !dotEnvKey.isEmpty {
                try? set(dotEnvKey, for: Self.keyTypeSafeAPIKey)
                return dotEnvKey
            }
            return nil
        }
        set { try? set(newValue, for: Self.keyTypeSafeAPIKey) }
    }

    public var hostedVpcToken: String? {
        get { get(key: Self.keyHostedVPCToken) }
        set { try? set(newValue, for: Self.keyHostedVPCToken) }
    }

    public var huggingFaceToken: String? {
        get { get(key: Self.keyHuggingFaceToken) }
        set { try? set(newValue, for: Self.keyHuggingFaceToken) }
    }

    public func persistentStorageKey(for key: String) -> String {
        "\(persistentKeyPrefix)\(key)"
    }

    public func get(key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }

        // 1. Check in-memory fallback first (ephemeral RAM store)
        if let fallback = inMemoryFallback[key], !fallback.isEmpty {
            return fallback
        }

        // 2. Check Keychain strictly via Apple Security Framework (never UserDefaults)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseDataProtectionKeychain as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess,
           let data = item as? Data,
           let string = String(data: data, encoding: .utf8),
           !string.isEmpty {
            inMemoryFallback[key] = string
            return string
        }

        if status == errSecMissingEntitlement {
            // Un-entitled environment (e.g. CLI, test runner, Xcode preview, un-provisioned dev build).
            return inMemoryFallback[key]
        }

        return nil
    }

    public func set(_ value: String?, for key: String) throws {
        lock.lock()
        defer { lock.unlock() }

        guard let value = value, !value.isEmpty else {
            try deleteLocked(key: key)
            return
        }

        // In-memory fallback remains strictly in RAM for ephemeral test/preview environments.
        // SEC-1: NEVER write secrets to UserDefaults.
        inMemoryFallback[key] = value

        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: true
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]

        // 1. Try SecItemUpdate
        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecMissingEntitlement {
            // Un-entitled environment (e.g. CLI, test runner, Xcode preview, un-provisioned dev build).
            // Retain in-memory fallback and return without throwing or touching legacy keychain.
            return
        }

        if updateStatus == errSecSuccess {
            return
        }

        // 2. If update returns errSecItemNotFound (-25300), call SecItemAdd
        if updateStatus == errSecItemNotFound {
            var attributes = query
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

            let addStatus = SecItemAdd(attributes as CFDictionary, nil)
            if addStatus == errSecMissingEntitlement {
                // Un-entitled environment: retain in-memory fallback and return without touching legacy keychain.
                return
            }

            if addStatus == errSecSuccess {
                return
            }

            // 3. If SecItemAdd returns errSecDuplicateItem (-25299), retry SecItemUpdate
            if addStatus == errSecDuplicateItem {
                _ = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
            }
        }
    }

    public func delete(key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        try deleteLocked(key: key)
    }

    private func deleteLocked(key: String) throws {
        inMemoryFallback.removeValue(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: true
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status == errSecMissingEntitlement {
            // Un-entitled environment: removed from inMemoryFallback, return without touching legacy keychain.
            return
        }

        if status != errSecSuccess && status != errSecItemNotFound {
            // Ignore missing item or keychain restriction
        }
    }
}

/// Deterministic in-memory keychain for testing and previews.
public final class MockKeychainService: KeychainServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: String]

    public init(initialStorage: [String: String] = [:]) {
        self.storage = initialStorage
    }

    public var typesafeApiKey: String? {
        get { get(key: KeychainService.keyTypeSafeAPIKey) }
        set { try? set(newValue, for: KeychainService.keyTypeSafeAPIKey) }
    }

    public var hostedVpcToken: String? {
        get { get(key: KeychainService.keyHostedVPCToken) }
        set { try? set(newValue, for: KeychainService.keyHostedVPCToken) }
    }

    public var huggingFaceToken: String? {
        get { get(key: KeychainService.keyHuggingFaceToken) }
        set { try? set(newValue, for: KeychainService.keyHuggingFaceToken) }
    }

    public func get(key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    public func set(_ value: String?, for key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        if let value = value, !value.isEmpty {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }
    }

    public func delete(key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }
}
