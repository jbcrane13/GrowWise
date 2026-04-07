import Foundation
import GrowWiseModels
import os

private let logger = Logger(subsystem: "com.growwise", category: "PerenualAPI")

// MARK: - Perenual API Response Models

/// Paginated list response from `/api/v2/species-list`
public struct PerenualListResponse: Codable, Sendable {
    public let data: [PerenualSpeciesSummary]
    public let total: Int
    public let perPage: Int
    public let currentPage: Int
    public let lastPage: Int

    enum CodingKeys: String, CodingKey {
        case data, total
        case perPage = "per_page"
        case currentPage = "current_page"
        case lastPage = "last_page"
    }
}

/// Summary item from the species list endpoint
public struct PerenualSpeciesSummary: Codable, Sendable, Identifiable {
    public let id: Int
    public let commonName: String
    public let scientificName: [String]
    public let otherName: [String]?
    public let family: String?
    public let genus: String?
    public let defaultImage: PerenualImage?

    enum CodingKeys: String, CodingKey {
        case id
        case commonName = "common_name"
        case scientificName = "scientific_name"
        case otherName = "other_name"
        case family, genus
        case defaultImage = "default_image"
    }
}

/// Full detail response from `/api/v2/species/details/{id}`
public struct PerenualSpeciesDetail: Codable, Sendable {
    public let id: Int
    public let commonName: String
    public let scientificName: [String]
    public let otherName: [String]?
    public let family: String?
    public let origin: [String]?
    public let type: String?
    public let cycle: String?
    public let watering: String?
    public let wateringGeneralBenchmark: PerenualWateringBenchmark?
    public let sunlight: [String]?
    public let pruningMonth: [String]?
    public let hardiness: PerenualHardiness?
    public let growthRate: String?
    public let careLevel: String?
    public let maintenance: String?
    public let droughtTolerant: Bool?
    public let saltTolerant: Bool?
    public let thorny: Bool?
    public let invasive: Bool?
    public let tropical: Bool?
    public let indoor: Bool?
    public let flowers: Bool?
    public let floweringSeason: String?
    public let fruits: Bool?
    public let edibleFruit: Bool?
    public let leaf: Bool?
    public let edibleLeaf: Bool?
    public let medicinal: Bool?
    public let poisonousToHumans: Bool?
    public let poisonousToPets: Bool?
    public let description: String?
    public let defaultImage: PerenualImage?
    public let dimensions: [PerenualDimension]?
    public let soil: [String]?
    public let pestSusceptibility: PerenualPestSusceptibility?
    public let attracts: [String]?
    public let propagation: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case commonName = "common_name"
        case scientificName = "scientific_name"
        case otherName = "other_name"
        case family, origin, type, cycle, watering
        case wateringGeneralBenchmark = "watering_general_benchmark"
        case sunlight
        case pruningMonth = "pruning_month"
        case hardiness
        case growthRate = "growth_rate"
        case careLevel = "care_level"
        case maintenance
        case droughtTolerant = "drought_tolerant"
        case saltTolerant = "salt_tolerant"
        case thorny, invasive, tropical, indoor, flowers
        case floweringSeason = "flowering_season"
        case fruits
        case edibleFruit = "edible_fruit"
        case leaf
        case edibleLeaf = "edible_leaf"
        case medicinal
        case poisonousToHumans = "poisonous_to_humans"
        case poisonousToPets = "poisonous_to_pets"
        case description
        case defaultImage = "default_image"
        case dimensions, soil
        case pestSusceptibility = "pest_susceptibility"
        case attracts, propagation
    }
}

/// pest_susceptibility can be an array of strings OR a single value/empty
public enum PerenualPestSusceptibility: Codable, Sendable {
    case list([String])
    case empty

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let arr = try? container.decode([String].self) {
            self = .list(arr)
        } else {
            self = .empty
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .list(let arr): try container.encode(arr)
        case .empty: try container.encode([String]())
        }
    }

    public var values: [String] {
        switch self {
        case .list(let arr): arr
        case .empty: []
        }
    }
}

public struct PerenualImage: Codable, Sendable {
    public let originalUrl: String?
    public let regularUrl: String?
    public let mediumUrl: String?
    public let smallUrl: String?
    public let thumbnail: String?

    enum CodingKeys: String, CodingKey {
        case originalUrl = "original_url"
        case regularUrl = "regular_url"
        case mediumUrl = "medium_url"
        case smallUrl = "small_url"
        case thumbnail
    }

    /// Best available image URL, preferring medium → regular → small → thumbnail → original
    public var bestURL: String? {
        mediumUrl ?? regularUrl ?? smallUrl ?? thumbnail ?? originalUrl
    }
}

public struct PerenualWateringBenchmark: Codable, Sendable {
    public let value: String?
    public let unit: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // value can come as string or number
        if let str = try? container.decode(String.self, forKey: .value) {
            value = str.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        } else if let num = try? container.decode(Int.self, forKey: .value) {
            value = String(num)
        } else {
            value = nil
        }
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
    }

    enum CodingKeys: String, CodingKey {
        case value, unit
    }
}

public struct PerenualHardiness: Codable, Sendable {
    public let min: String?
    public let max: String?
}

public struct PerenualDimension: Codable, Sendable {
    public let type: String?
    public let minValue: Double?
    public let maxValue: Double?
    public let unit: String?

    enum CodingKeys: String, CodingKey {
        case type
        case minValue = "min_value"
        case maxValue = "max_value"
        case unit
    }
}

// MARK: - Perenual API Service

@MainActor
@Observable
public final class PerenualAPIService {
    // MARK: - State

    public private(set) var isLoading = false
    public private(set) var lastError: String?

    // In-memory cache to avoid redundant API calls within a session
    private var detailCache: [Int: PerenualSpeciesDetail] = [:]
    private var listCache: [String: PerenualListResponse] = [:]

    // MARK: - Configuration

    private static let baseURL = "https://perenual.com/api/v2"
    private static let keychainKey = "perenual_api_key"

    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.urlCache = URLCache(
            memoryCapacity: 10 * 1024 * 1024,
            diskCapacity: 50 * 1024 * 1024
        )
        self.session = URLSession(configuration: config)
    }

    // MARK: - API Key Management

    /// Store the API key securely in Keychain
    public static func storeAPIKey(_ key: String) {
        do {
            try KeychainService.shared.storeString(key, for: keychainKey)
            logger.info("Perenual API key stored in Keychain")
        } catch {
            logger.error("Failed to store Perenual API key: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Retrieve the API key from Keychain
    public static func getAPIKey() -> String? {
        do {
            return try KeychainService.shared.retrieveString(for: keychainKey)
        } catch {
            logger.error("Failed to retrieve Perenual API key: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Check if an API key is configured
    public static var hasAPIKey: Bool {
        getAPIKey() != nil
    }

    // MARK: - Species List

    /// Search or browse the species list
    /// - Parameters:
    ///   - query: Optional search query (e.g. "tomato")
    ///   - page: Page number (1-based)
    ///   - indoor: Filter for indoor plants only
    ///   - edible: Filter for edible plants only
    ///   - cycle: Filter by lifecycle (e.g. "perennial", "annual")
    ///   - watering: Filter by watering needs (e.g. "frequent", "average", "minimum")
    ///   - sunlight: Filter by sunlight (e.g. "full_sun", "part_shade")
    ///   - hardiness: Filter by USDA hardiness zone (e.g. "7")
    public func fetchSpeciesList(
        query: String? = nil,
        page: Int = 1,
        indoor: Bool? = nil,
        edible: Bool? = nil,
        cycle: String? = nil,
        watering: String? = nil,
        sunlight: String? = nil,
        hardiness: String? = nil
    ) async throws -> PerenualListResponse {
        let cacheKey = "\(query ?? "")_\(page)_\(indoor ?? false)_\(edible ?? false)_\(cycle ?? "")_\(watering ?? "")_\(sunlight ?? "")_\(hardiness ?? "")"
        if let cached = listCache[cacheKey] { return cached }

        var components = URLComponents(string: "\(Self.baseURL)/species-list")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
        ]

        if let q = query, !q.isEmpty { queryItems.append(URLQueryItem(name: "q", value: q)) }
        if let indoor { queryItems.append(URLQueryItem(name: "indoor", value: indoor ? "1" : "0")) }
        if let edible { queryItems.append(URLQueryItem(name: "edible", value: edible ? "1" : "0")) }
        if let cycle { queryItems.append(URLQueryItem(name: "cycle", value: cycle)) }
        if let watering { queryItems.append(URLQueryItem(name: "watering", value: watering)) }
        if let sunlight { queryItems.append(URLQueryItem(name: "sunlight", value: sunlight)) }
        if let hardiness { queryItems.append(URLQueryItem(name: "hardiness", value: hardiness)) }

        components.queryItems = queryItems

        let response: PerenualListResponse = try await performRequest(url: components.url!)
        listCache[cacheKey] = response
        return response
    }

    // MARK: - Species Detail

    /// Fetch full details for a specific species
    public func fetchSpeciesDetail(id: Int) async throws -> PerenualSpeciesDetail {
        if let cached = detailCache[id] { return cached }

        let url = URL(string: "\(Self.baseURL)/species/details/\(id)")!
        let detail: PerenualSpeciesDetail = try await performRequest(url: url)
        detailCache[id] = detail
        return detail
    }

    // MARK: - Networking

    private func performRequest<T: Decodable>(url: URL) async throws -> T {
        guard let apiKey = Self.getAPIKey() else {
            throw PerenualError.noAPIKey
        }

        // Append API key
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "key", value: apiKey))
        components.queryItems = items

        guard let finalURL = components.url else {
            throw PerenualError.invalidURL
        }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        var request = URLRequest(url: finalURL)
        request.injectTraceHeaders()

        let trace = TraceContext.current
        if trace.isActive {
            logger.traced(level: .debug, "Perenual request: \(finalURL.path)")
        } else {
            logger.debug("Perenual request: \(finalURL.path, privacy: .public)")
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PerenualError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                break
            case 401:
                throw PerenualError.unauthorized
            case 429:
                throw PerenualError.rateLimited
            default:
                throw PerenualError.httpError(httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch let error as PerenualError {
            lastError = error.localizedDescription
            throw error
        } catch let error as DecodingError {
            logger.error("Perenual decode error: \(error.localizedDescription, privacy: .public)")
            lastError = "Failed to parse plant data"
            throw PerenualError.decodingFailed(error)
        } catch {
            lastError = error.localizedDescription
            throw PerenualError.networkError(error)
        }
    }

    // MARK: - Cache Management

    public func clearCache() {
        detailCache.removeAll()
        listCache.removeAll()
    }
}

// MARK: - Errors

public enum PerenualError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimited
    case httpError(Int)
    case decodingFailed(Error)
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .noAPIKey: "No Perenual API key configured"
        case .invalidURL: "Invalid request URL"
        case .invalidResponse: "Invalid server response"
        case .unauthorized: "Invalid API key — check your Perenual subscription"
        case .rateLimited: "API rate limit reached — try again later"
        case .httpError(let code): "Server error (\(code))"
        case .decodingFailed: "Failed to parse plant data"
        case .networkError(let error): "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Mapping to GrowWise Models

public extension PerenualSpeciesDetail {
    /// Maps Perenual watering string to GrowWise WateringFrequency
    var mappedWateringFrequency: WateringFrequency {
        switch watering?.lowercased() {
        case "frequent": .daily
        case "average": .weekly
        case "minimum", "none": .biweekly
        default: .weekly
        }
    }

    /// Maps Perenual sunlight array to GrowWise SunlightLevel
    var mappedSunlightLevel: SunlightLevel {
        let primary = sunlight?.first?.lowercased() ?? ""
        if primary.contains("full sun") { return .fullSun }
        if primary.contains("part shade") || primary.contains("part sun") { return .partialShade }
        if primary.contains("full shade") { return .fullShade }
        if primary.contains("shade") { return .fullShade }
        return .partialShade
    }

    /// Maps Perenual care_level to GrowWise DifficultyLevel
    var mappedDifficultyLevel: DifficultyLevel {
        switch careLevel?.lowercased() {
        case "low": .beginner
        case "medium", "moderate": .intermediate
        case "high": .advanced
        default: .intermediate
        }
    }

    /// Maps Perenual type string to GrowWise PlantType
    var mappedPlantType: PlantType {
        let t = type?.lowercased() ?? ""
        if t.contains("herb") { return .herb }
        if t.contains("flower") || t.contains("bulb") { return .flower }
        if t.contains("succulent") || t.contains("cactus") { return .succulent }
        if t.contains("fruit") { return .fruit }
        if t.contains("vegetable") { return .vegetable }
        if t.contains("tree") { return .tree }
        if t.contains("shrub") || t.contains("bush") { return .shrub }
        if indoor == true { return .houseplant }
        if t.contains("fern") || t.contains("palm") || t.contains("houseplant") { return .houseplant }
        return .flower
    }

    /// Maps Perenual type to GrowWise SpaceRequirement
    var mappedSpaceRequirement: SpaceRequirement {
        let t = type?.lowercased() ?? ""
        if t.contains("tree") { return .large }
        if t.contains("shrub") || t.contains("bush") { return .medium }
        if indoor == true { return .small }
        return .medium
    }

    /// Builds care instructions from available data
    var mappedCareInstructions: [String] {
        var instructions: [String] = []

        if let watering, !watering.isEmpty {
            let benchmark = wateringGeneralBenchmark?.value ?? ""
            let unit = wateringGeneralBenchmark?.unit ?? "days"
            if !benchmark.isEmpty {
                instructions.append("Water every \(benchmark) \(unit) (\(watering.lowercased()) watering)")
            } else {
                instructions.append("Watering: \(watering)")
            }
        }

        if let sunlight, !sunlight.isEmpty {
            instructions.append("Sunlight: \(sunlight.joined(separator: ", "))")
        }

        if let pruning = pruningMonth, !pruning.isEmpty {
            instructions.append("Prune in: \(pruning.joined(separator: ", "))")
        }

        if let soil, !soil.isEmpty {
            instructions.append("Soil: \(soil.joined(separator: ", "))")
        }

        if let hardiness {
            if let min = hardiness.min, let max = hardiness.max, min == max {
                instructions.append("USDA Hardiness Zone: \(min)")
            } else if let min = hardiness.min, let max = hardiness.max {
                instructions.append("USDA Hardiness Zones: \(min)–\(max)")
            }
        }

        if droughtTolerant == true { instructions.append("Drought tolerant") }
        if poisonousToPets == true { instructions.append("⚠️ Toxic to pets") }
        if poisonousToHumans == true { instructions.append("⚠️ Toxic to humans") }
        if medicinal == true { instructions.append("Has medicinal properties") }
        if edibleFruit == true { instructions.append("Produces edible fruit") }
        if edibleLeaf == true { instructions.append("Edible leaves") }

        return instructions
    }
}
