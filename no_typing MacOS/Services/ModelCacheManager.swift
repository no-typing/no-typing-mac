import Foundation

class ModelCacheManager {
    static let shared = ModelCacheManager()
    private let suiteName = "com.no-typing.model_cache"
    private let userDefaults: UserDefaults
    
    private init() {
        self.userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
    }
    
    // MARK: - API
    
    func saveModels(_ models: [String], for provider: String) {
        userDefaults.set(models, forKey: "cached_models_\(provider)")
    }
    
    func getModels(for provider: String) -> [String] {
        return userDefaults.stringArray(forKey: "cached_models_\(provider)") ?? []
    }
    
    func clearCache(for provider: String? = nil) {
        if let provider = provider {
            userDefaults.removeObject(forKey: "cached_models_\(provider)")
        } else {
            // Clear all
            let dict = userDefaults.dictionaryRepresentation()
            dict.keys.filter { $0.hasPrefix("cached_models_") }.forEach {
                userDefaults.removeObject(forKey: $0)
            }
        }
    }
    
    /// Merges fetched models with predefined ones, removing duplicates
    func mergeModels(predefined: [String], fetched: [String]) -> [String] {
        var result = predefined
        for model in fetched {
            if !result.contains(model) {
                result.append(model)
            }
        }
        return result
    }
}
