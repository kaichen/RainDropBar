//
//  Raindrop.swift
//  RainDropBar
//
//  Created by Kai on 2026-01-02.
//

import Foundation
import SwiftData

@Model
final class Raindrop {
    @Attribute(.unique) var id: Int
    var title: String
    var link: String
    var excerpt: String
    var note: String
    var domain: String
    var cover: String
    var type: String  // link, article, image, video, document, audio
    var tags: [String]
    var important: Bool
    var collectionID: Int
    var created: Date
    var lastUpdate: Date
    
    init(
        id: Int,
        title: String,
        link: String,
        excerpt: String = "",
        note: String = "",
        domain: String = "",
        cover: String = "",
        type: String = "link",
        tags: [String] = [],
        important: Bool = false,
        collectionID: Int = -1,
        created: Date = Date(),
        lastUpdate: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.link = link
        self.excerpt = excerpt
        self.note = note
        self.domain = domain
        self.cover = cover
        self.type = type
        self.tags = tags
        self.important = important
        self.collectionID = collectionID
        self.created = created
        self.lastUpdate = lastUpdate
    }
}
