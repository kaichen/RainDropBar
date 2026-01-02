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
    
    private init() {}
    
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
        let data = Data(token.utf8)
        
        // Delete existing item first
        delete()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func retrieve() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    private func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
