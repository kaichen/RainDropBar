//
//  TokenManager.swift
//  RainDropBar
//
//  Created by Kai on 2026-01-02.
//

import Foundation
import Security

final class TokenManager {
    static let shared = TokenManager()
    
    private let service = "io.raindrop.RainDropBar"
    private let account = "api_token"
    
    private init() {
        debugLog(.keychain, "TokenManager initialized - service: \(service), account: \(account)")
    }
    
    private func secErrorName(_ status: OSStatus) -> String {
        switch status {
        case errSecSuccess: return "errSecSuccess"
        case errSecItemNotFound: return "errSecItemNotFound"
        case errSecDuplicateItem: return "errSecDuplicateItem"
        case errSecAuthFailed: return "errSecAuthFailed"
        case errSecInteractionRequired: return "errSecInteractionRequired"
        case errSecParam: return "errSecParam"
        case errSecAllocate: return "errSecAllocate"
        default: return "OSStatus(\(status))"
        }
    }
    
    var token: String? {
        get { retrieve() }
        set {
            if let value = newValue {
                save(value)
            } else {
                delete()
            }
        }
    }
    
    var hasToken: Bool {
        token != nil
    }
    
    private func save(_ token: String) {
        let redacted = DebugLogger.shared.redactToken(token)
        debugLog(.keychain, "Saving token (\(redacted))")
        
        let data = Data(token.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        debugLog(.keychain, "Query: service=\(service), account=\(account)")
        
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        debugLog(.keychain, "SecItemUpdate status: \(secErrorName(updateStatus))")
        
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            debugLog(.keychain, "SecItemAdd status: \(secErrorName(addStatus))")
            if addStatus != errSecSuccess {
                debugLog(.keychain, "Keychain save failed: \(secErrorName(addStatus))")
            }
        } else if updateStatus != errSecSuccess {
            debugLog(.keychain, "Keychain update failed: \(secErrorName(updateStatus))")
        }
    }
    
    private func retrieve() -> String? {
        debugLog(.keychain, "Retrieving token")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        debugLog(.keychain, "Query: service=\(service), account=\(account)")
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        debugLog(.keychain, "SecItemCopyMatching status: \(secErrorName(status))")
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let token = String(data: data, encoding: .utf8) else {
                debugLog(.keychain, "Token data conversion failed")
                return nil
            }
            let redacted = DebugLogger.shared.redactToken(token)
            debugLog(.keychain, "Token retrieved successfully (\(redacted))")
            return token
        case errSecItemNotFound:
            debugLog(.keychain, "No token found in keychain")
            return nil
        default:
            debugLog(.keychain, "Keychain retrieve failed: \(secErrorName(status))")
            return nil
        }
    }
    
    private func delete() {
        debugLog(.keychain, "Deleting token")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        debugLog(.keychain, "SecItemDelete status: \(secErrorName(status))")
    }
}
