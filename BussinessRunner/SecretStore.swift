import Foundation
import Security

enum SecretStore {
    static let keychainService = "BussinessRunner"
    static let keychainAccount = "CURSOR_API_KEY"
    static let envKey = "CURSOR_API_KEY"

    static func loadAPIKey() -> String? {
        if let keychain = readKeychain(), !keychain.isEmpty {
            return keychain
        }
        for url in candidateEnvFiles() {
            if let value = readEnvFile(url) {
                try? saveToKeychain(value)
                return value
            }
        }
        if let env = ProcessInfo.processInfo.environment[envKey], !env.isEmpty {
            try? saveToKeychain(env)
            return env
        }
        return nil
    }

    static func save(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SecretError.empty }
        try saveToKeychain(trimmed)
    }

    static func masked(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else { return "••••" }
        return "\(trimmed.prefix(5))…\(trimmed.suffix(4))"
    }

    static func candidateEnvFiles() -> [URL] {
        var urls: [URL] = []
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        urls.append(cwd.appendingPathComponent(".env"))
        urls.append(URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("dev/BussinessRunner/.env"))
        if let exe = Bundle.main.executableURL {
            var dir = exe.deletingLastPathComponent()
            for _ in 0..<6 {
                urls.append(dir.appendingPathComponent(".env"))
                dir.deleteLastPathComponent()
            }
        }
        var unique: [URL] = []
        var seen = Set<String>()
        for url in urls {
            let path = url.standardizedFileURL.path
            if seen.insert(path).inserted {
                unique.append(url)
            }
        }
        return unique
    }

    private static func readEnvFile(_ url: URL) -> String? {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        for line in raw.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[0] == envKey else { continue }
            var value = parts[1].trimmingCharacters(in: .whitespaces)
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            return value.isEmpty ? nil : value
        }
        return nil
    }

    private static func readKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationUI as String: "fail"
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, let value = String(data: data, encoding: .utf8), !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func saveToKeychain(_ value: String) throws {
        let data = Data(value.utf8)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(base as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw SecretError.keychain(addStatus) }
        } else if status != errSecSuccess {
            throw SecretError.keychain(status)
        }
    }

    enum SecretError: LocalizedError {
        case empty
        case keychain(OSStatus)

        var errorDescription: String? {
            switch self {
            case .empty: return "Ключ пустой."
            case .keychain(let status): return "Keychain: \(status)"
            }
        }
    }
}
