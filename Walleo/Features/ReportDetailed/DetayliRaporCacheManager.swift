//
//  DetayliRaporCacheManager.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


import Foundation

actor DetayliRaporCacheManager {
    static let shared = DetayliRaporCacheManager()
    
    private var cache: [String: (data: Any, timestamp: Date)] = [:]
    private let cacheValidityDuration: TimeInterval = 300 // 5 dakika
    
    private init() {}
    
    func getCachedData<T>(for key: String, compute: () async throws -> T) async throws -> T {
        // Cache'i kontrol et
        if let cached = cache[key],
           Date().timeIntervalSince(cached.timestamp) < cacheValidityDuration,
           let data = cached.data as? T {
            return data
        }
        
        // Cache'de yoksa veya eskiyse hesapla
        let data = try await compute()
        cache[key] = (data, Date())
        
        return data
    }
    
    func invalidateCache() {
        cache.removeAll()
    }
    
    func invalidateCache(for key: String) {
        cache.removeValue(forKey: key)
    }
}
