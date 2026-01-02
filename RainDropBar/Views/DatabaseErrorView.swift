//
//  DatabaseErrorView.swift
//  RainDropBar
//
//  Created by Kai on 2026-01-02.
//

import SwiftUI

struct DatabaseErrorView: View {
    let onReset: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)
            
            Text("Database Error")
                .font(.headline)
            
            Text("Unable to initialize local storage. This may be due to a corrupted database or permissions issue.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Reset Database", role: .destructive) {
                onReset()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(width: 280, height: 200)
        .padding()
    }
}
