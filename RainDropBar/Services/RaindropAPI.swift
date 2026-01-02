//
//  RaindropAPI.swift
//  RainDropBar
//
//  Created by Kai on 2026-01-02.
//

import Foundation

actor RateLimiter {
    private var lastRequestTime: Date = .distantPast
    private var suspendedUntil: Date?
    private let minInterval: TimeInterval = 0.55
    private let maxRetries = 3
    
    func waitForNextSlot() async throws {
        if let suspendedUntil, Date() < suspendedUntil {
            let waitTime = suspendedUntil.timeIntervalSinceNow
            debugLog(.api, "Rate limited, waiting \(String(format: "%.1f", waitTime))s")
            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        
        let elapsed = Date().timeIntervalSince(lastRequestTime)
        if elapsed < minInterval {
            let waitTime = minInterval - elapsed
            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        
        lastRequestTime = Date()
    }
    
    func handleRateLimitResponse(headers: [AnyHashable: Any]) {
        if let resetTimestamp = headers["X-RateLimit-Reset"] as? String,
           let resetEpoch = Double(resetTimestamp) {
            suspendedUntil = Date(timeIntervalSince1970: resetEpoch)
            debugLog(.api, "Rate limit hit, suspended until \(suspendedUntil!)")
        } else {
            suspendedUntil = Date().addingTimeInterval(60)
            debugLog(.api, "Rate limit hit, suspended for 60s (no reset header)")
        }
    }
    
    func clearSuspension() {
        suspendedUntil = nil
    }
}

struct RaindropAPI {
    private let baseURL = "https://api.raindrop.io/rest/v1"
    private let token: String
    private let rateLimiter = RateLimiter()
    
    init(token: String) {
        self.token = token
    }
    
    func getCollections() async throws -> [CollectionResponse] {
        let root: CollectionsWrapper = try await request("/collections")
        let children: CollectionsWrapper = try await request("/collections/childrens")
        return root.items + children.items
    }
    
    func getRaindrops(
        collectionID: Int = 0,
        page: Int = 0,
        perPage: Int = 50,
        sort: String? = nil
    ) async throws -> RaindropsResponse {
        var components = URLComponents()
        components.path = "/raindrops/\(collectionID)"
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "perpage", value: "\(perPage)")
        ]
        if let sort {
            components.queryItems?.append(URLQueryItem(name: "sort", value: sort))
        }
        let path = components.path + "?" + (components.query ?? "")
        return try await request(path)
    }
    
    func getTotalCount(collectionID: Int = 0) async throws -> Int {
        let response = try await getRaindrops(collectionID: collectionID, page: 0, perPage: 1)
        return response.count ?? response.items.count
    }
    
    private func request<T: Decodable>(_ path: String, retryCount: Int = 0) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        
        try await rateLimiter.waitForNextSlot()
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 429 {
            if retryCount < 3 {
                await rateLimiter.handleRateLimitResponse(headers: httpResponse.allHeaderFields)
                debugLog(.api, "Retrying after rate limit (attempt \(retryCount + 1)/3)")
                return try await self.request(path, retryCount: retryCount + 1)
            }
            throw APIError.rateLimited
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        if (500...599).contains(httpResponse.statusCode) {
            if retryCount < 4 {
                let baseDelay = 0.5 * pow(2.0, Double(retryCount))
                let jitter = Double.random(in: 0...0.3)
                let delay = min(baseDelay + jitter, 10.0)
                debugLog(.api, "Server error \(httpResponse.statusCode), retrying in \(String(format: "%.1f", delay))s (attempt \(retryCount + 1)/4)")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await self.request(path, retryCount: retryCount + 1)
            }
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        await rateLimiter.clearSuspension()
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            debugLog(.api, "Decode failed for \(path): \(error)")
            throw error
        }
    }
}

// MARK: - API Error

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(Int)
    case rateLimited
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .serverError(let code):
            return "Server error: \(code) (retries exhausted)"
        case .rateLimited:
            return "Rate limited by API"
        case .unauthorized:
            return "Invalid or expired API token"
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
    let count: Int?
    let result: Bool?
    
    var itemCount: Int {
        count ?? items.count
    }
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
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        link = try c.decode(String.self, forKey: .link)
        excerpt = try c.decodeIfPresent(String.self, forKey: .excerpt) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        domain = try c.decodeIfPresent(String.self, forKey: .domain) ?? ""
        cover = try c.decodeIfPresent(String.self, forKey: .cover) ?? ""
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? "link"
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        important = try c.decodeIfPresent(Bool.self, forKey: .important) ?? false
        collection = try c.decode(CollectionRef.self, forKey: .collection)
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? Date()
        lastUpdate = try c.decodeIfPresent(Date.self, forKey: .lastUpdate) ?? created
    }
}
