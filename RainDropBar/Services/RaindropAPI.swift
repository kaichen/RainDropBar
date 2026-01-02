//
//  RaindropAPI.swift
//  RainDropBar
//
//  Created by Kai on 2026-01-02.
//

import Foundation

struct RaindropAPI {
    private let baseURL = "https://api.raindrop.io/rest/v1"
    private let token: String
    
    init(token: String) {
        self.token = token
    }
    
    // MARK: - Collections
    
    func getCollections() async throws -> [CollectionResponse] {
        let root: CollectionsWrapper = try await request("/collections")
        let children: CollectionsWrapper = try await request("/collections/childrens")
        return root.items + children.items
    }
    
    // MARK: - Raindrops
    
    func getRaindrops(collectionID: Int = 0, page: Int = 0, perPage: Int = 50) async throws -> RaindropsResponse {
        let path = "/raindrops/\(collectionID)?page=\(page)&perpage=\(perPage)"
        return try await request(path)
    }
    
    func getAllRaindrops() async throws -> [RaindropResponse] {
        var allRaindrops: [RaindropResponse] = []
        var page = 0
        
        while true {
            let response = try await getRaindrops(page: page)
            allRaindrops.append(contentsOf: response.items)
            
            if response.items.count < 50 {
                break
            }
            page += 1
        }
        
        return allRaindrops
    }
    
    // MARK: - Private
    
    private func request<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - API Error

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        }
    }
}

// MARK: - Response Types

struct CollectionsWrapper: Decodable {
    let items: [CollectionResponse]
}

struct CollectionResponse: Decodable {
    let id: Int
    let title: String
    let count: Int
    let cover: [String]
    let color: String?
    let parent: ParentRef?
    let sort: Int
    let view: String
    let `public`: Bool
    let expanded: Bool
    let lastUpdate: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, count, cover, color, parent, sort, view
        case `public`, expanded, lastUpdate
    }
    
    struct ParentRef: Decodable {
        let id: Int
        
        enum CodingKeys: String, CodingKey {
            case id = "$id"
        }
    }
}

struct RaindropsResponse: Decodable {
    let items: [RaindropResponse]
    let count: Int
}

struct RaindropResponse: Decodable {
    let id: Int
    let title: String
    let link: String
    let excerpt: String
    let note: String
    let domain: String
    let cover: String
    let type: String
    let tags: [String]
    let important: Bool
    let collection: CollectionRef
    let created: Date
    let lastUpdate: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, link, excerpt, note, domain, cover, type, tags
        case important, collection, created, lastUpdate
    }
    
    struct CollectionRef: Decodable {
        let id: Int
        
        enum CodingKeys: String, CodingKey {
            case id = "$id"
        }
    }
}
