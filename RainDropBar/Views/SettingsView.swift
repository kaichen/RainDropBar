//
//  SettingsView.swift
//  RainDropBar
//
//  Created by Kai on 2026-01-02.
//

import SwiftUI

struct SettingsView: View {
    @State private var token: String = TokenManager.shared.token ?? ""
    @State private var showToken = false
    @State private var saved = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    if showToken {
                        TextField("Test Token", text: $token)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("Test Token", text: $token)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Button {
                        showToken.toggle()
                    } label: {
                        Image(systemName: showToken ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }
                
                Text("Get your test token from [raindrop.io/settings/integrations](https://app.raindrop.io/settings/integrations)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("API Token")
            }
            
            Section {
                Button("Save") {
                    TokenManager.shared.token = token.isEmpty ? nil : token
                    saved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        saved = false
                    }
                }
                .disabled(token.isEmpty)
                
                if saved {
                    Text("Saved!")
                        .foregroundStyle(.green)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 200)
    }
}

#Preview {
    SettingsView()
}
