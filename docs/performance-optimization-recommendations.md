# GrowWise Performance Optimization Recommendations

## Overview

This document provides comprehensive performance optimization strategies for the GrowWise iOS gardening app, focusing on image handling, list performance, memory management, and user experience optimization based on iOS 17+ best practices.

## 1. Image Handling Optimization

### AsyncImage Implementation with Caching

```swift
// Custom AsyncImage with comprehensive caching
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let scale: CGFloat
    private let transaction: Transaction
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    
    @State private var phase: AsyncImagePhase = .empty
    
    init(
        url: URL?,
        scale: CGFloat = 1.0,
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.scale = scale
        self.transaction = transaction
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            switch phase {
            case .empty:
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            case .success(let image):
                content(image)
            case .failure(_):
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
            @unknown default:
                placeholder()
            }
        }
        .onChange(of: url) { _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else {
            phase = .empty
            return
        }
        
        // Check memory cache first
        if let cachedImage = ImageCache.shared.image(for: url) {
            phase = .success(cachedImage)
            return
        }
        
        // Load asynchronously with caching
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                guard let uiImage = UIImage(data: data, scale: scale) else {
                    await MainActor.run {
                        phase = .failure(URLError(.badServerResponse))
                    }
                    return
                }
                
                let image = Image(uiImage: uiImage)
                
                // Cache the image
                ImageCache.shared.setImage(image, for: url)
                
                await MainActor.run {
                    withTransaction(transaction) {
                        phase = .success(image)
                    }
                }
            } catch {
                await MainActor.run {
                    phase = .failure(error)
                }
            }
        }
    }
}

// Singleton image cache with memory management
class ImageCache: ObservableObject {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSURL, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // Configure memory cache
        cache.countLimit = 100 // Maximum 100 images in memory
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB memory limit
        
        // Setup disk cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("ImageCache")
        
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearMemoryCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    func image(for url: URL) -> Image? {
        // Check memory cache first
        if let uiImage = cache.object(forKey: url as NSURL) {
            return Image(uiImage: uiImage)
        }
        
        // Check disk cache
        let cacheKey = url.absoluteString.hash
        let cacheURL = cacheDirectory.appendingPathComponent("\(cacheKey).jpg")
        
        if let data = try? Data(contentsOf: cacheURL),
           let uiImage = UIImage(data: data) {
            // Load back into memory cache
            cache.setObject(uiImage, forKey: url as NSURL, cost: data.count)
            return Image(uiImage: uiImage)
        }
        
        return nil
    }
    
    func setImage(_ image: Image, for url: URL) {
        guard let uiImage = image.asUIImage() else { return }
        
        // Store in memory cache
        cache.setObject(uiImage, forKey: url as NSURL)
        
        // Store in disk cache asynchronously
        Task.detached(priority: .utility) {
            let cacheKey = url.absoluteString.hash
            let cacheURL = self.cacheDirectory.appendingPathComponent("\(cacheKey).jpg")
            
            if let data = uiImage.jpegData(compressionQuality: 0.8) {
                try? data.write(to: cacheURL)
            }
        }
    }
    
    @objc private func clearMemoryCache() {
        cache.removeAllObjects()
    }
    
    func clearAllCache() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

extension Image {
    func asUIImage() -> UIImage? {
        let controller = UIHostingController(rootView: self)
        let view = controller.view
        
        let targetSize = controller.view.intrinsicContentSize
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}
```

### Progressive Image Loading

```swift
struct ProgressiveImageView: View {
    let url: URL?
    let targetSize: CGSize
    
    @State private var lowResImage: Image?
    @State private var highResImage: Image?
    @State private var isLoading = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background placeholder
                Rectangle()
                    .fill(.quaternary.opacity(0.3))
                
                // Low resolution image (loads first)
                if let lowResImage = lowResImage {
                    lowResImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: highResImage == nil ? 2 : 0)
                        .animation(.easeInOut(duration: 0.3), value: highResImage)
                }
                
                // High resolution image (loads second)
                if let highResImage = highResImage {
                    highResImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                }
                
                // Loading indicator
                if isLoading && lowResImage == nil {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .clipped()
        .onAppear {
            loadProgressiveImages()
        }
        .onChange(of: url) { _ in
            loadProgressiveImages()
        }
    }
    
    private func loadProgressiveImages() {
        guard let url = url else { return }
        
        isLoading = true
        lowResImage = nil
        highResImage = nil
        
        // Load low-res thumbnail first
        loadThumbnail(from: url)
        
        // Then load high-res image
        loadHighResolution(from: url)
    }
    
    private func loadThumbnail(from url: URL) {
        // Generate thumbnail URL (adjust based on your image service)
        let thumbnailURL = url.appendingPathComponent("?w=100&h=100&q=50")
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: thumbnailURL)
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        lowResImage = Image(uiImage: uiImage)
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func loadHighResolution(from url: URL) {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        highResImage = Image(uiImage: uiImage)
                    }
                }
            } catch {
                // High-res failed, keep low-res
            }
        }
    }
}
```

### Image Compression and Optimization

```swift
struct ImageProcessor {
    static func processPlantImage(_ image: UIImage, for purpose: ImagePurpose) -> UIImage? {
        switch purpose {
        case .thumbnail:
            return resizeAndCompress(image, to: CGSize(width: 150, height: 150), quality: 0.7)
        case .gallery:
            return resizeAndCompress(image, to: CGSize(width: 800, height: 600), quality: 0.8)
        case .fullSize:
            return compressImage(image, quality: 0.9)
        }
    }
    
    private static func resizeAndCompress(_ image: UIImage, to size: CGSize, quality: CGFloat) -> UIImage? {
        // Calculate optimal size maintaining aspect ratio
        let aspectRatio = image.size.width / image.size.height
        let targetRatio = size.width / size.height
        
        let finalSize: CGSize
        if aspectRatio > targetRatio {
            finalSize = CGSize(width: size.width, height: size.width / aspectRatio)
        } else {
            finalSize = CGSize(width: size.height * aspectRatio, height: size.height)
        }
        
        // Resize image
        let renderer = UIGraphicsImageRenderer(size: finalSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: finalSize))
        }
        
        // Compress
        return compressImage(resizedImage, quality: quality)
    }
    
    private static func compressImage(_ image: UIImage, quality: CGFloat) -> UIImage? {
        guard let data = image.jpegData(compressionQuality: quality),
              let compressedImage = UIImage(data: data) else {
            return nil
        }
        return compressedImage
    }
}

enum ImagePurpose {
    case thumbnail
    case gallery
    case fullSize
}
```

## 2. List Performance Optimization

### Lazy Loading Implementation

```swift
struct OptimizedPlantList: View {
    @StateObject private var plantLoader = PlantLoader()
    @State private var visibleRange: Range<Int> = 0..<20
    
    private let itemsPerPage = 20
    private let prefetchThreshold = 5
    
    var body: some View {
        ScrollViewReader { proxy in
            LazyVStack(spacing: 12) {
                ForEach(Array(plantLoader.plants.enumerated()), id: \.element.id) { index, plant in
                    PlantRowView(plant: plant)
                        .onAppear {
                            handleItemAppear(index: index)
                        }
                        .onDisappear {
                            handleItemDisappear(index: index)
                        }
                }
                
                if plantLoader.isLoading {
                    LoadingRowView()
                }
                
                if plantLoader.hasMoreData {
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            plantLoader.loadNextPage()
                        }
                }
            }
            .padding(.horizontal)
        }
        .onAppear {
            if plantLoader.plants.isEmpty {
                plantLoader.loadInitialData()
            }
        }
    }
    
    private func handleItemAppear(index: Int) {
        // Update visible range
        let newStart = max(0, min(visibleRange.lowerBound, index))
        let newEnd = max(visibleRange.upperBound, index + 1)
        visibleRange = newStart..<newEnd
        
        // Prefetch upcoming images
        if index >= plantLoader.plants.count - prefetchThreshold {
            plantLoader.loadNextPage()
        }
        
        // Preload images for visible items
        let plant = plantLoader.plants[index]
        ImagePreloader.shared.preloadImage(url: plant.thumbnailURL)
    }
    
    private func handleItemDisappear(index: Int) {
        // Clean up images that are far from visible area
        if index < visibleRange.lowerBound - 10 || index > visibleRange.upperBound + 10 {
            let plant = plantLoader.plants[index]
            ImageCache.shared.removeImage(for: plant.thumbnailURL)
        }
    }
}

@MainActor
class PlantLoader: ObservableObject {
    @Published var plants: [Plant] = []
    @Published var isLoading = false
    @Published var hasMoreData = true
    
    private var currentPage = 0
    private let pageSize = 20
    
    func loadInitialData() {
        guard !isLoading else { return }
        
        isLoading = true
        currentPage = 0
        
        Task {
            do {
                let newPlants = try await PlantService.shared.fetchPlants(page: currentPage, pageSize: pageSize)
                plants = newPlants
                hasMoreData = newPlants.count == pageSize
                currentPage += 1
            } catch {
                // Handle error
            }
            isLoading = false
        }
    }
    
    func loadNextPage() {
        guard !isLoading && hasMoreData else { return }
        
        isLoading = true
        
        Task {
            do {
                let newPlants = try await PlantService.shared.fetchPlants(page: currentPage, pageSize: pageSize)
                plants.append(contentsOf: newPlants)
                hasMoreData = newPlants.count == pageSize
                currentPage += 1
            } catch {
                // Handle error
            }
            isLoading = false
        }
    }
}
```

### Efficient List Rendering

```swift
struct HighPerformancePlantGrid: View {
    let plants: [Plant]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private var gridColumns: [GridItem] {
        let columnCount = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount)
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(plants.indices, id: \.self) { index in
                    OptimizedPlantCard(plant: plants[index])
                        .id(plants[index].id) // Stable identity for efficient updates
                }
            }
            .padding()
        }
        .scrollIndicators(.hidden)
        .clipped() // Prevents overdraw
    }
}

struct OptimizedPlantCard: View {
    let plant: Plant
    
    // Minimize state changes
    private let cardHeight: CGFloat = 200
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image with fixed aspect ratio for consistent layout
            CachedAsyncImage(url: plant.thumbnailURL) { image in
                image
                    .resizable()
                    .aspectRatio(4/3, contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary.opacity(0.3))
                    .aspectRatio(4/3, contentMode: .fit)
                    .overlay {
                        Image(systemName: "leaf")
                            .font(.title)
                            .foregroundStyle(.tertiary)
                    }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Text content with fixed layout
            VStack(alignment: .leading, spacing: 4) {
                Text(plant.name)
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    DifficultyBadge(level: plant.difficultyLevel)
                    Spacer()
                    if plant.isUserPlant {
                        HealthStatusIndicator(status: plant.healthStatus)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(height: cardHeight) // Fixed height for consistent scrolling
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12)) // Optimize hit testing
    }
}
```

## 3. Memory Management

### SwiftData Optimization

```swift
// Efficient SwiftData queries with pagination
extension PlantService {
    func fetchPlantsEfficiently(
        limit: Int = 20,
        offset: Int = 0,
        includeUserPlants: Bool = true
    ) throws -> [Plant] {
        let descriptor = FetchDescriptor<Plant>(
            predicate: includeUserPlants ? nil : #Predicate { !$0.isUserPlant },
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        
        // Only load essential properties for list view
        descriptor.propertiesToFetch = [
            \.id, \.name, \.plantType, \.difficultyLevel,
            \.healthStatus, \.thumbnailURL, \.isUserPlant
        ]
        
        return try modelContext.fetch(descriptor)
    }
    
    func fetchPlantDetails(id: UUID) throws -> Plant? {
        let descriptor = FetchDescriptor<Plant>(
            predicate: #Predicate { $0.id == id }
        )
        
        return try modelContext.fetch(descriptor).first
    }
}

// Efficient relationship loading
extension Plant {
    var journalEntriesPublisher: some Publisher<[JournalEntry], Never> {
        $journalEntries
            .map { entries in
                entries.sorted { $0.date > $1.date }
            }
            .eraseToAnyPublisher()
    }
    
    func loadRecentJournalEntries(limit: Int = 5) -> [JournalEntry] {
        return journalEntries
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { $0 }
    }
}
```

### Memory Pressure Handling

```swift
class MemoryManager: ObservableObject {
    static let shared = MemoryManager()
    
    @Published var memoryPressureLevel: MemoryPressureLevel = .normal
    
    private init() {
        setupMemoryPressureSource()
    }
    
    private func setupMemoryPressureSource() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: .main)
        
        source.setEventHandler { [weak self] in
            let event = source.mask
            
            switch event {
            case .normal:
                self?.memoryPressureLevel = .normal
            case .warning:
                self?.memoryPressureLevel = .warning
                self?.handleMemoryWarning()
            case .critical:
                self?.memoryPressureLevel = .critical
                self?.handleMemoryCritical()
            default:
                break
            }
        }
        
        source.resume()
    }
    
    private func handleMemoryWarning() {
        // Clear image caches
        ImageCache.shared.clearMemoryCache()
        
        // Reduce quality of cached images
        ImageProcessor.reduceQuality()
        
        // Notify views to reduce memory usage
        NotificationCenter.default.post(name: .memoryWarning, object: nil)
    }
    
    private func handleMemoryCritical() {
        handleMemoryWarning()
        
        // More aggressive cleanup
        ImageCache.shared.clearAllCache()
        
        // Clear non-essential data
        PlantDataCache.shared.clearCache()
    }
}

enum MemoryPressureLevel {
    case normal, warning, critical
}

extension Notification.Name {
    static let memoryWarning = Notification.Name("memoryWarning")
}
```

### Efficient Data Structures

```swift
// Optimized plant data structure for lists
struct PlantListItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let plantType: PlantType
    let difficultyLevel: DifficultyLevel
    let healthStatus: HealthStatus
    let thumbnailURL: URL?
    let isUserPlant: Bool
    
    // Computed properties for display
    var displayName: String { name }
    var statusColor: Color { healthStatus.color }
    var difficultyIcon: String { difficultyLevel.iconName }
    
    // Efficient initialization from full Plant model
    init(from plant: Plant) {
        self.id = plant.id
        self.name = plant.name
        self.plantType = plant.plantType
        self.difficultyLevel = plant.difficultyLevel
        self.healthStatus = plant.healthStatus
        self.thumbnailURL = plant.thumbnailURL
        self.isUserPlant = plant.isUserPlant
    }
}

// Efficient search implementation
class PlantSearchManager: ObservableObject {
    @Published var searchResults: [PlantListItem] = []
    @Published var isSearching = false
    
    private var searchTask: Task<Void, Never>?
    private let searchDebounceTime: TimeInterval = 0.3
    
    func search(query: String) {
        // Cancel previous search
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        searchTask = Task {
            // Debounce search
            try? await Task.sleep(nanoseconds: UInt64(searchDebounceTime * 1_000_000_000))
            
            guard !Task.isCancelled else { return }
            
            let results = await performSearch(query: query)
            
            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.searchResults = results
                self.isSearching = false
            }
        }
    }
    
    private func performSearch(query: String) async -> [PlantListItem] {
        // Perform search on background queue
        return await Task.detached(priority: .userInitiated) {
            // Implement efficient search algorithm
            // Consider using FTS (Full Text Search) for large datasets
            return PlantDatabase.shared.search(query: query, limit: 50)
        }.value
    }
}
```

## 4. Network Performance

### Efficient API Requests

```swift
class PlantAPIService {
    static let shared = PlantAPIService()
    
    private let session: URLSession
    private let decoder: JSONDecoder
    
    private init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024, // 20 MB
            diskCapacity: 100 * 1024 * 1024,  // 100 MB
            diskPath: "plant_api_cache"
        )
        
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    func fetchPlants(
        page: Int = 0,
        pageSize: Int = 20,
        filters: PlantFilters? = nil
    ) async throws -> [Plant] {
        var components = URLComponents(string: "https://api.growwise.com/plants")!
        
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "pageSize", value: String(pageSize))
        ]
        
        // Add filters to query
        if let filters = filters {
            queryItems.append(contentsOf: filters.queryItems)
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw APIError.serverError
        }
        
        let plantResponse = try decoder.decode(PlantResponse.self, from: data)
        return plantResponse.plants
    }
}

struct PlantFilters {
    let plantTypes: [PlantType]?
    let difficultyLevels: [DifficultyLevel]?
    let sunlightRequirements: [SunlightLevel]?
    
    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        
        if let types = plantTypes {
            items.append(URLQueryItem(name: "types", value: types.map(\.rawValue).joined(separator: ",")))
        }
        
        if let difficulties = difficultyLevels {
            items.append(URLQueryItem(name: "difficulties", value: difficulties.map(\.rawValue).joined(separator: ",")))
        }
        
        if let sunlight = sunlightRequirements {
            items.append(URLQueryItem(name: "sunlight", value: sunlight.map(\.rawValue).joined(separator: ",")))
        }
        
        return items
    }
}
```

### Request Batching and Caching

```swift
class RequestBatcher {
    static let shared = RequestBatcher()
    
    private var pendingRequests: [String: [CheckedContinuation<Data, Error>]] = [:]
    private let batchQueue = DispatchQueue(label: "request.batch", qos: .utility)
    
    func batchedRequest(for url: URL) async throws -> Data {
        let key = url.absoluteString
        
        return try await withCheckedThrowingContinuation { continuation in
            batchQueue.async {
                if self.pendingRequests[key] == nil {
                    self.pendingRequests[key] = []
                    
                    // Start the actual request
                    Task {
                        do {
                            let (data, _) = try await URLSession.shared.data(from: url)
                            
                            await MainActor.run {
                                self.batchQueue.async {
                                    let continuations = self.pendingRequests.removeValue(forKey: key) ?? []
                                    for continuation in continuations {
                                        continuation.resume(returning: data)
                                    }
                                }
                            }
                        } catch {
                            await MainActor.run {
                                self.batchQueue.async {
                                    let continuations = self.pendingRequests.removeValue(forKey: key) ?? []
                                    for continuation in continuations {
                                        continuation.resume(throwing: error)
                                    }
                                }
                            }
                        }
                    }
                }
                
                self.pendingRequests[key]?.append(continuation)
            }
        }
    }
}
```

## 5. User Interface Performance

### Smooth Scrolling Optimization

```swift
struct SmoothScrollingList: View {
    let items: [PlantListItem]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { index in
                    PlantRowView(plant: items[index])
                        .frame(height: 80) // Fixed height for smooth scrolling
                        .id(items[index].id)
                }
            }
        }
        .scrollIndicators(.hidden)
        .simultaneousGesture(
            // Disable bounce for smoother scrolling on older devices
            DragGesture()
                .onChanged { _ in }
        )
    }
}

struct PlantRowView: View {
    let plant: PlantListItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Fixed size thumbnail
            CachedAsyncImage(url: plant.thumbnailURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary.opacity(0.3))
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(plant.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(plant.plantType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    DifficultyBadge(level: plant.difficultyLevel)
                    Spacer()
                    HealthStatusDot(status: plant.healthStatus)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle()) // Optimize hit testing
    }
}
```

### Animation Performance

```swift
struct PerformantAnimations: View {
    @State private var isExpanded = false
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        VStack {
            // Efficient scale animation using scaleEffect
            PlantCard(plant: plant)
                .scaleEffect(scale)
                .onTapGesture {
                    // Use withAnimation for smooth performance
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        scale = scale == 1.0 ? 1.05 : 1.0
                    }
                }
            
            // Efficient expansion animation
            DisclosureGroup("Plant Details", isExpanded: $isExpanded) {
                PlantDetailsView(plant: plant)
                    .frame(maxHeight: isExpanded ? .infinity : 0)
                    .clipped()
            }
            .animation(.easeInOut(duration: 0.25), value: isExpanded)
        }
    }
}

// Optimize complex animations with preference keys
struct AnimationPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct MatchedGeometryTransition: View {
    @Namespace private var animationNamespace
    @State private var showDetail = false
    
    var body: some View {
        if showDetail {
            PlantDetailView(plant: plant)
                .matchedGeometryEffect(id: "plant", in: animationNamespace)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale),
                    removal: .opacity
                ))
        } else {
            PlantCard(plant: plant)
                .matchedGeometryEffect(id: "plant", in: animationNamespace)
                .onTapGesture {
                    withAnimation(.spring()) {
                        showDetail = true
                    }
                }
        }
    }
}
```

## 6. Background Processing

### Efficient Background Sync

```swift
class BackgroundSyncManager: NSObject, ObservableObject {
    static let shared = BackgroundSyncManager()
    
    @Published var syncStatus: SyncStatus = .idle
    
    private override init() {
        super.init()
        setupBackgroundTasks()
    }
    
    private func setupBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.growwise.sync",
            using: nil
        ) { task in
            self.handleBackgroundSync(task: task as! BGAppRefreshTask)
        }
    }
    
    func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: "com.growwise.sync")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        try? BGTaskScheduler.shared.submit(request)
    }
    
    private func handleBackgroundSync(task: BGAppRefreshTask) {
        scheduleBackgroundSync() // Schedule next sync
        
        let syncTask = Task {
            await performSync()
        }
        
        task.expirationHandler = {
            syncTask.cancel()
        }
        
        Task {
            await syncTask.value
            task.setTaskCompleted(success: true)
        }
    }
    
    private func performSync() async {
        // Sync plant care reminders
        await syncReminders()
        
        // Sync journal entries
        await syncJournalEntries()
        
        // Sync plant health data
        await syncPlantHealth()
    }
}

enum SyncStatus {
    case idle
    case syncing
    case completed
    case failed(Error)
}
```

## 7. Performance Monitoring

### Performance Metrics Collection

```swift
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    @Published var metrics: PerformanceMetrics = PerformanceMetrics()
    
    private let displayLink = CADisplayLink()
    private var frameCount = 0
    private var lastTimestamp: CFTimeInterval = 0
    
    private init() {
        setupDisplayLink()
    }
    
    private func setupDisplayLink() {
        displayLink.add(to: .main, forMode: .common)
        displayLink.addTarget(self, selector: #selector(displayLinkCallback))
    }
    
    @objc private func displayLinkCallback() {
        frameCount += 1
        
        if lastTimestamp == 0 {
            lastTimestamp = displayLink.timestamp
            return
        }
        
        let elapsed = displayLink.timestamp - lastTimestamp
        
        if elapsed >= 1.0 {
            let fps = Double(frameCount) / elapsed
            
            DispatchQueue.main.async {
                self.metrics.currentFPS = fps
                self.metrics.updateAverageFPS(fps)
            }
            
            frameCount = 0
            lastTimestamp = displayLink.timestamp
        }
    }
    
    func measureImageLoadTime<T>(operation: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        await MainActor.run {
            metrics.averageImageLoadTime = (metrics.averageImageLoadTime + elapsed) / 2
        }
        
        return result
    }
    
    func measureMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsage = Double(info.resident_size) / (1024 * 1024) // Convert to MB
            
            DispatchQueue.main.async {
                self.metrics.currentMemoryUsage = memoryUsage
                self.metrics.updatePeakMemoryUsage(memoryUsage)
            }
        }
    }
}

struct PerformanceMetrics {
    var currentFPS: Double = 60.0
    var averageFPS: Double = 60.0
    var currentMemoryUsage: Double = 0.0
    var peakMemoryUsage: Double = 0.0
    var averageImageLoadTime: Double = 0.0
    
    mutating func updateAverageFPS(_ newFPS: Double) {
        averageFPS = (averageFPS * 0.9) + (newFPS * 0.1)
    }
    
    mutating func updatePeakMemoryUsage(_ usage: Double) {
        peakMemoryUsage = max(peakMemoryUsage, usage)
    }
}
```

## 8. Implementation Timeline

### Phase 1: Core Optimizations (Weeks 1-2)
- Implement AsyncImage with caching
- Optimize list rendering with LazyVStack/LazyVGrid
- Set up basic memory management
- Implement progressive image loading

### Phase 2: Advanced Features (Weeks 3-4)
- Background sync implementation
- Request batching and network optimization
- Advanced image processing and compression
- Memory pressure handling

### Phase 3: Monitoring and Refinement (Weeks 5-6)
- Performance monitoring implementation
- Animation optimization
- Background processing optimization
- Comprehensive testing and profiling

### Phase 4: Final Optimization (Weeks 7-8)
- Advanced caching strategies
- Network layer optimization
- Memory optimization refinement
- Performance analytics integration

These performance optimization recommendations will ensure GrowWise delivers a smooth, responsive user experience while efficiently managing device resources.