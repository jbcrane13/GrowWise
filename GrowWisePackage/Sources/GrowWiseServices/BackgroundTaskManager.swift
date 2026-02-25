import Foundation
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import os.log
#if canImport(BackgroundTasks) && (os(iOS) || os(tvOS))
@preconcurrency import BackgroundTasks
#endif

/// Background task management system for heavy operations
@MainActor
@Observable public final class BackgroundTaskManager {
    public static let shared = BackgroundTaskManager()
    
    // Task logger
    private let logger = Logger(subsystem: "com.growwise", category: "BackgroundTasks")
    
    // Task queues
    private let highPriorityQueue = DispatchQueue(label: "com.growwise.tasks.high", qos: .userInitiated)
    private let mediumPriorityQueue = DispatchQueue(label: "com.growwise.tasks.medium", qos: .default)
    private let lowPriorityQueue = DispatchQueue(label: "com.growwise.tasks.low", qos: .background)
    
    // Operation queues for more control
    private let photoOperationQueue = OperationQueue()
    private let dataOperationQueue = OperationQueue()
    
    // Task tracking
    public private(set) var activeTasks: [BackgroundTask] = []
    public private(set) var completedTasks: [BackgroundTask] = []
    public private(set) var taskProgress: [UUID: Double] = [:]
    
    // Task persistence
    private let taskPersistenceKey = "com.growwise.background.tasks"
    
    // Resource monitoring
    private var cpuUsageTimer: Timer?
    private var memoryUsageTimer: Timer?
    private var isLowPriorityQueueSuspended = false
    
    private init() {
        configureOperationQueues()
        restorePersistedTasks()
        startResourceMonitoring()

        // Register for background tasks
        #if canImport(BackgroundTasks) && (os(iOS) || os(tvOS))
        registerBackgroundTasks()
        #endif

        logger.info("📋 Background Task Manager initialized")
    }
    
    // MARK: - Public Interface
    
    /// Submit a task for background execution
    @discardableResult
    public func submitTask<T>(
        name: String,
        priority: TaskPriority = .medium,
        persist: Bool = false,
        operation: @escaping () async throws -> T
    ) -> Task<T, Error> {
        let taskId = UUID()
        let backgroundTask = BackgroundTask(
            id: taskId,
            name: name,
            priority: priority,
            status: .pending,
            createdAt: Date()
        )
        
        // Track the task
        activeTasks.append(backgroundTask)
        
        // Persist if needed
        if persist {
            persistTask(backgroundTask)
        }
        
        // Create and return the task
        let task = Task(priority: priority.taskPriority) {
            self.updateTaskStatus(taskId, status: .running)
            
            do {
                let result = try await operation()
                self.completeTask(taskId, success: true)
                return result
            } catch {
                self.completeTask(taskId, success: false, error: error)
                throw error
            }
        }
        
        logger.info("📥 Submitted task: \(name) with priority: \(priority.rawValue)")
        
        return task
    }
    
    /// Submit an image processing task
    public func submitImageProcessingTask(
        image: PlatformImage,
        operations: [ImageOperation],
        completion: @escaping (Result<PlatformImage, Error>) -> Void
    ) {
        let operation = ImageProcessingOperation(
            image: image,
            operations: operations
        ) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let processedImage):
                    self?.logger.info("✅ Image processing completed successfully")
                    completion(.success(processedImage))
                case .failure(let error):
                    self?.logger.error("❌ Image processing failed: \(error)")
                    completion(.failure(error))
                }
            }
        }
        
        photoOperationQueue.addOperation(operation)
    }
    
    /// Submit a data sync task
    public func submitDataSyncTask(
        syncType: DataSyncType,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let operation = DataSyncOperation(syncType: syncType) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    self?.logger.info("✅ Data sync completed: \(syncType.rawValue)")
                    completion(.success(()))
                case .failure(let error):
                    self?.logger.error("❌ Data sync failed: \(error)")
                    completion(.failure(error))
                }
            }
        }
        
        dataOperationQueue.addOperation(operation)
    }
    
    /// Cancel a specific task
    public func cancelTask(id: UUID) {
        if let index = activeTasks.firstIndex(where: { $0.id == id }) {
            activeTasks[index].status = .cancelled
            logger.info("🚫 Cancelled task: \(self.activeTasks[index].name)")
            
            // Move to completed with cancelled status
            completedTasks.append(activeTasks[index])
            activeTasks.remove(at: index)
        }
    }
    
    /// Cancel all tasks with a specific priority
    public func cancelTasks(priority: TaskPriority) {
        let tasksToCancel = activeTasks.filter { $0.priority == priority }
        
        for task in tasksToCancel {
            cancelTask(id: task.id)
        }
    }
    
    /// Update task progress
    public func updateTaskProgress(id: UUID, progress: Double) {
        taskProgress[id] = min(max(progress, 0), 1.0)
        
        if let index = activeTasks.firstIndex(where: { $0.id == id }) {
            activeTasks[index].progress = progress
        }
    }
    
    /// Get active tasks count by priority
    public func getActiveTasksCount() -> (high: Int, medium: Int, low: Int) {
        let high = activeTasks.filter { $0.priority == .high }.count
        let medium = activeTasks.filter { $0.priority == .medium }.count
        let low = activeTasks.filter { $0.priority == .low }.count
        
        return (high, medium, low)
    }
    
    /// Batch submit tasks
    public func batchSubmitTasks<T>(
        tasks: [(name: String, priority: TaskPriority, operation: () async throws -> T)]
    ) -> [Task<T, Error>] {
        return tasks.map { task in
            submitTask(
                name: task.name,
                priority: task.priority,
                operation: task.operation
            )
        }
    }
    
    /// Wait for all active tasks to complete
    public func waitForAllTasks() async {
        let taskIds = activeTasks.map { $0.id }
        
        for id in taskIds {
            await waitForTask(id: id)
        }
    }
    
    /// Wait for a specific task to complete
    public func waitForTask(id: UUID) async {
        while activeTasks.contains(where: { $0.id == id }) {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }
    
    // MARK: - Resource Management
    
    /// Adjust queue concurrency based on system resources
    public func adjustConcurrency(basedOn resourceUsage: ResourceUsage) {
        if resourceUsage.cpuUsage > 0.8 {
            // High CPU usage - reduce concurrency
            photoOperationQueue.maxConcurrentOperationCount = 1
            dataOperationQueue.maxConcurrentOperationCount = 1
        } else if resourceUsage.memoryPressure == .critical {
            // Critical memory pressure - pause non-essential tasks
            photoOperationQueue.isSuspended = true
            suspendLowPriorityQueueIfNeeded()
        } else {
            // Normal conditions
            photoOperationQueue.maxConcurrentOperationCount = 2
            dataOperationQueue.maxConcurrentOperationCount = 3
            photoOperationQueue.isSuspended = false
            resumeLowPriorityQueueIfNeeded()
        }
    }
    
    // MARK: - Private Methods
    
    private func configureOperationQueues() {
        photoOperationQueue.name = "com.growwise.photo.operations"
        photoOperationQueue.maxConcurrentOperationCount = 2
        photoOperationQueue.qualityOfService = .userInitiated
        
        dataOperationQueue.name = "com.growwise.data.operations"
        dataOperationQueue.maxConcurrentOperationCount = 3
        dataOperationQueue.qualityOfService = .background
    }
    
    @MainActor
    private func updateTaskStatus(_ id: UUID, status: TaskStatus) {
        if let index = activeTasks.firstIndex(where: { $0.id == id }) {
            activeTasks[index].status = status
        }
    }
    
    @MainActor
    private func completeTask(_ id: UUID, success: Bool, error: Error? = nil) {
        if let index = activeTasks.firstIndex(where: { $0.id == id }) {
            var task = activeTasks[index]
            task.status = success ? .completed : .failed
            task.completedAt = Date()
            task.error = error?.localizedDescription
            
            completedTasks.append(task)
            activeTasks.remove(at: index)
            taskProgress.removeValue(forKey: id)
            
            // Keep only recent completed tasks
            if completedTasks.count > 100 {
                completedTasks.removeFirst(completedTasks.count - 100)
            }
        }
    }
    
    private func persistTask(_ task: BackgroundTask) {
        var persistedTasks = getPersistedTasks()
        persistedTasks.append(task)
        
        if let encoded = try? JSONEncoder().encode(persistedTasks) {
            UserDefaults.standard.set(encoded, forKey: taskPersistenceKey)
        }
    }
    
    private func getPersistedTasks() -> [BackgroundTask] {
        guard let data = UserDefaults.standard.data(forKey: taskPersistenceKey),
              let tasks = try? JSONDecoder().decode([BackgroundTask].self, from: data) else {
            return []
        }
        return tasks
    }
    
    private func restorePersistedTasks() {
        let persistedTasks = getPersistedTasks()
        
        for task in persistedTasks where task.status == .pending || task.status == .running {
            // Re-queue persisted tasks
            logger.info("📂 Restoring persisted task: \(task.name)")
            // Implementation would depend on task serialization strategy
        }
        
        // Clear persisted tasks after restoration
        UserDefaults.standard.removeObject(forKey: taskPersistenceKey)
    }
    
    private func startResourceMonitoring() {
        guard !ProcessInfo.processInfo.arguments.contains("--uitesting") else { return }

        cpuUsageTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.monitorCPUUsage()
            }
        }

        memoryUsageTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.monitorMemoryUsage()
            }
        }
    }
    
    private func monitorCPUUsage() {
        let usage = getCurrentCPUUsage()
        
        if usage > 0.9 {
            logger.warning("⚠️ High CPU usage detected: \(String(format: "%.1f%%", usage * 100))")
            
            // Automatically pause low priority tasks
            suspendLowPriorityQueueIfNeeded()
            
            // Resume after a delay
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                self.resumeLowPriorityQueueIfNeeded()
            }
        }
    }
    
    private func monitorMemoryUsage() {
        let memoryInfo = getMemoryInfo()
        
        if memoryInfo.pressure == .critical {
            logger.warning("⚠️ Critical memory pressure detected")
            
            // Cancel low priority tasks
            cancelTasks(priority: .low)
        }
    }
    
    private func getCurrentCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0 }
        
        // Simplified CPU usage calculation
        return Double(info.resident_size) / Double(ProcessInfo.processInfo.physicalMemory)
    }
    
    private func getMemoryInfo() -> (used: Double, pressure: MemoryPressure) {
        let info = ProcessInfo.processInfo
        let physicalMemory = Double(info.physicalMemory)
        let memoryUsed = Double(getMemoryUsage())
        let usageRatio = memoryUsed / physicalMemory
        
        let pressure: MemoryPressure
        if usageRatio > 0.9 {
            pressure = .critical
        } else if usageRatio > 0.75 {
            pressure = .warning
        } else {
            pressure = .normal
        }
        
        return (memoryUsed / 1024 / 1024, pressure) // Convert to MB
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    // MARK: - Background Task Registration

    #if canImport(BackgroundTasks) && (os(iOS) || os(tvOS))
    private func registerBackgroundTasks() {
        // Register background tasks with iOS
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.growwise.refresh",
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleAppRefresh(task: refreshTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.growwise.processing",
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleProcessing(task: processingTask)
        }
    }

    nonisolated private func handleAppRefresh(task: BGAppRefreshTask) {
        // Handle app refresh in background
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task.detached { [weak self] in
            // Perform refresh operations off main thread
            await self?.performBackgroundRefresh()
            task.setTaskCompleted(success: true)
        }
    }

    nonisolated private func handleProcessing(task: BGProcessingTask) {
        // Handle background processing
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task.detached { [weak self] in
            // Perform processing operations off main thread
            await self?.performBackgroundProcessing()
            task.setTaskCompleted(success: true)
        }
    }

    nonisolated private func performBackgroundRefresh() async {
        // Implementation for background refresh
        await MainActor.run {
            logger.info("🔄 Performing background refresh")
        }
    }

    nonisolated private func performBackgroundProcessing() async {
        // Implementation for background processing
        await MainActor.run {
            logger.info("⚙️ Performing background processing")
        }
    }
    #else
    // macOS stub - background tasks not supported
    private func registerBackgroundTasks() {
        logger.info("📋 Background tasks not available on macOS")
    }
    #endif

    private func suspendLowPriorityQueueIfNeeded() {
        guard !isLowPriorityQueueSuspended else { return }
        lowPriorityQueue.suspend()
        isLowPriorityQueueSuspended = true
    }

    private func resumeLowPriorityQueueIfNeeded() {
        guard isLowPriorityQueueSuspended else { return }
        lowPriorityQueue.resume()
        isLowPriorityQueueSuspended = false
    }
}

// MARK: - Supporting Types

public enum TaskPriority: String, Codable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    var taskPriority: _Concurrency.TaskPriority {
        switch self {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }
}

public enum TaskStatus: String, Codable {
    case pending = "Pending"
    case running = "Running"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
}

public struct BackgroundTask: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let priority: TaskPriority
    public var status: TaskStatus
    public let createdAt: Date
    public var completedAt: Date?
    public var progress: Double = 0
    public var error: String?
}

public enum DataSyncType: String {
    case plants = "Plants"
    case journals = "Journals"
    case reminders = "Reminders"
    case photos = "Photos"
    case full = "Full"
}

public enum ImageOperation {
    case resize(CGSize)
    case compress(quality: CGFloat)
    case crop(CGRect)
    case rotate(degrees: CGFloat)
    case filter(name: String)
}

public struct ResourceUsage {
    public let cpuUsage: Double
    public let memoryUsage: Double
    public let memoryPressure: MemoryPressure
}

public enum MemoryPressure {
    case normal
    case warning
    case critical
}

// MARK: - Custom Operations

class ImageProcessingOperation: Operation, @unchecked Sendable {
    private let image: PlatformImage
    private let operations: [ImageOperation]
    private let completion: (Result<PlatformImage, Error>) -> Void
    
    init(image: PlatformImage, operations: [ImageOperation], completion: @escaping (Result<PlatformImage, Error>) -> Void) {
        self.image = image
        self.operations = operations
        self.completion = completion
        super.init()
    }
    
    override func main() {
        guard !isCancelled else {
            completion(.failure(TaskError.cancelled))
            return
        }
        
        var processedImage = image
        
        for operation in operations {
            guard !isCancelled else {
                completion(.failure(TaskError.cancelled))
                return
            }
            
            switch operation {
            case .resize(let size):
                processedImage = resize(image: processedImage, to: size)
            case .compress(let quality):
                processedImage = compress(image: processedImage, quality: quality)
            case .crop(let rect):
                processedImage = crop(image: processedImage, to: rect)
            case .rotate(let degrees):
                processedImage = rotate(image: processedImage, degrees: degrees)
            case .filter(let name):
                processedImage = applyFilter(to: processedImage, name: name)
            }
        }
        
        completion(.success(processedImage))
    }
    
    private func resize(image: PlatformImage, to size: CGSize) -> PlatformImage {
        // Thread-safe implementation using Core Graphics
        #if canImport(UIKit)
        guard let cgImage = image.cgImage else { return image }
        #else
        guard let cgImage = image.cgImage else { return image }
        #endif

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))

        guard let resizedCGImage = context.makeImage() else {
            return image
        }

        #if canImport(UIKit)
        return UIImage(cgImage: resizedCGImage, scale: image.scale, orientation: image.imageOrientation)
        #else
        return NSImage(cgImage: resizedCGImage, size: size)
        #endif
    }
    
    private func compress(image: PlatformImage, quality: CGFloat) -> PlatformImage {
        // Thread-safe compression using Core Graphics
        #if canImport(UIKit)
        guard let cgImage = image.cgImage else { return image }
        #else
        guard let cgImage = image.cgImage else { return image }
        #endif

        // Create mutable data for JPEG output
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return image
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]

        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            return image
        }

        let compressedData = mutableData as Data

        #if canImport(UIKit)
        guard let compressedImage = UIImage(data: compressedData) else {
            return image
        }
        return compressedImage
        #else
        guard let compressedImage = NSImage(data: compressedData) else {
            return image
        }
        return compressedImage
        #endif
    }
    
    private func crop(image: PlatformImage, to rect: CGRect) -> PlatformImage {
        #if canImport(UIKit)
        guard let cgImage = image.cgImage,
              let croppedCGImage = cgImage.cropping(to: rect) else {
            return image
        }
        return UIImage(cgImage: croppedCGImage)
        #else
        // macOS: Safe unwrapping for NSImage cgImage
        guard let cgImage = image.cgImage else {
            // Fallback: Use Core Image if cgImage is unavailable
            guard let ciImage = CIImage(data: image.tiffRepresentation ?? Data()) else {
                return image
            }
            let context = CIContext()
            let croppedCI = ciImage.cropped(to: rect)
            guard let cgImageResult = context.createCGImage(croppedCI, from: croppedCI.extent) else {
                return image
            }
            return NSImage(cgImage: cgImageResult, size: rect.size)
        }

        guard let croppedCGImage = cgImage.cropping(to: rect) else {
            return image
        }
        return NSImage(cgImage: croppedCGImage, size: rect.size)
        #endif
    }
    
    private func rotate(image: PlatformImage, degrees: CGFloat) -> PlatformImage {
        let radians = degrees * .pi / 180
        let rotatedSize = CGRect(origin: .zero, size: image.size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size

        #if canImport(UIKit)
        // Account for image scale on iOS
        let scale = image.scale
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: rotatedSize, format: format)

        return renderer.image { context in
            let origin = CGPoint(
                x: rotatedSize.width / 2,
                y: rotatedSize.height / 2
            )
            context.cgContext.translateBy(x: origin.x, y: origin.y)
            context.cgContext.rotate(by: radians)
            image.draw(in: CGRect(
                x: -image.size.width / 2,
                y: -image.size.height / 2,
                width: image.size.width,
                height: image.size.height
            ))
        }
        #else
        // macOS: Use Core Image for rotation to maintain fidelity
        guard let ciImage = CIImage(data: image.tiffRepresentation ?? Data()) else {
            // Fallback to NSImage drawing if Core Image unavailable
            let newImage = NSImage(size: rotatedSize)
            newImage.lockFocus()
            let transform = NSAffineTransform()
            transform.translateX(by: rotatedSize.width / 2, yBy: rotatedSize.height / 2)
            transform.rotate(byRadians: radians)
            transform.concat()
            image.draw(in: CGRect(
                x: -image.size.width / 2,
                y: -image.size.height / 2,
                width: image.size.width,
                height: image.size.height
            ))
            newImage.unlockFocus()
            return newImage
        }

        let filter = CIFilter(name: "CIAffineTransform")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        let transform = CGAffineTransform(rotationAngle: radians)
        filter?.setValue(transform, forKey: kCIInputTransformKey)

        guard let outputImage = filter?.outputImage else {
            return image
        }

        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return NSImage(cgImage: cgImage, size: rotatedSize)
        #endif
    }
    
    private func applyFilter(to image: PlatformImage, name: String) -> PlatformImage {
        // Simplified filter application
        // In production, you'd use Core Image filters
        return image
    }
}

#if canImport(AppKit)
extension NSImage {
    var cgImage: CGImage? {
        var rect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
#endif

class DataSyncOperation: Operation, @unchecked Sendable {
    private let syncType: DataSyncType
    private let completion: (Result<Void, Error>) -> Void
    
    init(syncType: DataSyncType, completion: @escaping (Result<Void, Error>) -> Void) {
        self.syncType = syncType
        self.completion = completion
        super.init()
    }
    
    override func main() {
        guard !isCancelled else {
            completion(.failure(TaskError.cancelled))
            return
        }
        
        // Simulate data sync
        Thread.sleep(forTimeInterval: 1.0)
        
        guard !isCancelled else {
            completion(.failure(TaskError.cancelled))
            return
        }
        
        completion(.success(()))
    }
}

enum TaskError: LocalizedError {
    case cancelled
    case failed(String)
    
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Task was cancelled"
        case .failed(let reason):
            return "Task failed: \(reason)"
        }
    }
}
