//
//  TypeIcon.swift
//  RainDropBar
//
//  Created by Kai on 2026-01-02.
//

import Foundation

enum TypeIcon {
    static func systemName(for type: String) -> String {
        switch type {
        case "article":
            return "doc.text"
        case "image":
            return "photo"
        case "video":
            return "play.rectangle"
        case "document":
            return "doc"
        case "audio":
            return "music.note"
        default: // "link"
            return "link"
        }
    }
}
