//
//  DebugLogger.swift
//  RainDropBar
//
//  Created by Kai on 2026-01-02.
//

import Foundation

/// Categories for debug logging
enum LogCategory: String {
    case keychain = "KEYCHAIN"
    case swiftdata = "SWIFTDATA"
    case sync = "SYNC"
    case api = "API"
    case app = "APP"
    case ui = "UI"
}

/// Centralized debug logging utility with console and file output
final class DebugLogger {
    static let shared = DebugLogger()
    
    private let fileQueue = DispatchQueue(label: "io.raindrop.RainDropBar.logger", qos: .utility)
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    /// Path to the log file
    var logFilePath: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("RainDropBar", isDirectory: true)
        return appFolder.appendingPathComponent("debug.log")
    }
    
    private init() {
        // Ensure log directory exists
        let logDir = logFilePath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
    }
    
    /// Log a message to console and file
    func log(_ category: LogCategory, _ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let logLine = "[\(timestamp)] [\(category.rawValue)] \(message)"
        
        // Console output
        print(logLine)
        
        // File output (thread-safe)
        fileQueue.async { [weak self] in
            guard let self else { return }
            let lineWithNewline = logLine + "\n"
            if let data = lineWithNewline.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: self.logFilePath.path) {
                    if let handle = try? FileHandle(forWritingTo: self.logFilePath) {
                        try? handle.seekToEnd()
                        try? handle.write(contentsOf: data)
                        try? handle.close()
                    }
                } else {
                    try? data.write(to: self.logFilePath, options: .atomic)
                }
            }
        }
    }
    
    /// Redact a token to show only last 4 characters
    func redactToken(_ token: String) -> String {
        guard token.count > 4 else { return "****" }
        let lastFour = String(token.suffix(4))
        return "****\(lastFour)"
    }
    
    /// Get full contents of the log file
    func getLogContents() -> String {
        do {
            return try String(contentsOf: logFilePath, encoding: .utf8)
        } catch {
            return "Unable to read log file: \(error.localizedDescription)"
        }
    }
    
    /// Clear all logs
    func clearLogs() {
        fileQueue.async { [weak self] in
            guard let self else { return }
            try? FileManager.default.removeItem(at: self.logFilePath)
        }
    }
}

/// Global convenience function for debug logging
func debugLog(_ category: LogCategory, _ message: String) {
    DebugLogger.shared.log(category, message)
}
