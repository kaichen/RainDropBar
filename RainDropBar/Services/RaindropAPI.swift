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
    
    func getRecentRaindrops(limit: Int = 1000) async throws -> [RaindropResponse] {
        var results: [RaindropResponse] = []
        var page = 0
        let perPage = 50
        
        debugLog(.api, "Fetching recent raindrops with limit: \(limit)")
        
        while results.count < limit {
            let response = try await getRaindrops(page: page, perPage: perPage)
            results.append(contentsOf: response.items)
            debugLog(.api, "Page \(page): fetched \(response.items.count) items, total: \(results.count)")
            
            if response.items.count < perPage { break }
            page += 1
        }
        
        let finalResults = Array(results.prefix(limit))
        debugLog(.api, "getRecentRaindrops completed: \(finalResults.count) items")
        return finalResults
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
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        await rateLimiter.clearSuspension()
        
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
}
