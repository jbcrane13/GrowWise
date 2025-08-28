import Foundation
import os.log
import QuartzCore

/// Comprehensive performance monitoring service for the GrowWise app
@MainActor
public final class PerformanceMonitor: ObservableObject {
    public static let shared = PerformanceMonitor()
    
    // Performance logger
    private let logger = Logger(subsystem: "com.growwise", category: "Performance")
    
    // Metrics storage
    @Published public private(set) var appLaunchTime: TimeInterval = 0
    @Published public private(set) var currentMemoryUsage: Double = 0
    @Published public private(set) var peakMemoryUsage: Double = 0
    @Published public private(set) var averageFrameRate: Double = 60
    @Published public private(set) var queryMetrics: [QueryMetric] = []
    @Published public private(set) var photoOperationMetrics: [PhotoOperationMetric] = []
    
    // Performance budgets
    private let performanceBudgets = PerformanceBudgets()
    
    // Monitoring state
    private var isMonitoring = false
    private var appStartTime: CFAbsoluteTime?
    private var frameRateTimer: Timer?
    private var memoryTimer: Timer?
    
    // Metrics aggregation
    private var queryTimes: [String: [TimeInterval]] = [:]
    private var operationTimes: [String: [TimeInterval]] = [:]
    
    private init() {
        startMonitoring()
    }
    
    // MARK: - Public Interface
    
    /// Start monitoring app performance
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        // Start memory monitoring
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryMetrics()
            }
        }
        
        // Start frame rate monitoring
        startFrameRateMonitoring()
        
        logger.info("🎯 Performance monitoring started")
    }
    
    /// Stop monitoring
    public func stopMonitoring() {
        isMonitoring = false
        memoryTimer?.invalidate()
        frameRateTimer?.invalidate()
        logger.info("🛑 Performance monitoring stopped")
    }
    
    /// Track app launch time
    public func recordAppLaunchStart() {
        appStartTime = CFAbsoluteTimeGetCurrent()
    }
    
    /// Complete app launch tracking
    public func recordAppLaunchComplete() {
        guard let startTime = appStartTime else { return }
        appLaunchTime = CFAbsoluteTimeGetCurrent() - startTime
        
        if appLaunchTime > performanceBudgets.appLaunchTimeLimit {
            logger.warning("⚠️ App launch exceeded budget: \(self.appLaunchTime)s > \(self.performanceBudgets.appLaunchTimeLimit)s")
        } else {
            logger.info("✅ App launched in \(self.appLaunchTime)s")
        }
        
        appStartTime = nil
    }
    
    /// Track query performance
    public func startQueryTracking(identifier: String) -> QueryTracker {
        return QueryTracker(identifier: identifier, monitor: self)
    }
    
    /// Track photo operation performance
    public func startPhotoOperation(type: PhotoOperationType) -> PhotoOperationTracker {
        return PhotoOperationTracker(type: type, monitor: self)
    }
    
    /// Track UI operation
    public func trackUIOperation(name: String, duration: TimeInterval) {
        if duration > performanceBudgets.uiResponseTimeLimit {
            logger.warning("⚠️ Slow UI operation '\(name)': \(duration)s")
        }
        
        // Store for aggregation
        if operationTimes[name] == nil {
            operationTimes[name] = []
        }
        operationTimes[name]?.append(duration)
        
        // Keep only recent measurements
        if let count = operationTimes[name]?.count, count > 100 {
            operationTimes[name]?.removeFirst(count - 100)
        }
    }
    
    /// Get performance report
    public func generatePerformanceReport() -> PerformanceReport {
        let avgQueryTime = calculateAverageQueryTime()
        let avgPhotoOpTime = calculateAveragePhotoOperationTime()
        
        return PerformanceReport(
            timestamp: Date(),
            appLaunchTime: appLaunchTime,
            averageMemoryUsage: currentMemoryUsage,
            peakMemoryUsage: peakMemoryUsage,
            averageFrameRate: averageFrameRate,
            averageQueryTime: avgQueryTime,
            averagePhotoOperationTime: avgPhotoOpTime,
            slowQueries: getSlowQueries(),
            memoryWarnings: getMemoryWarnings(),
            performanceScore: calculatePerformanceScore()
        )
    }
    
    /// Clear all metrics
    public func clearMetrics() {
        queryMetrics.removeAll()
        photoOperationMetrics.removeAll()
        queryTimes.removeAll()
        operationTimes.removeAll()
        logger.info("🧹 Performance metrics cleared")
    }
    
    // MARK: - Internal Methods
    
    internal func recordQueryMetric(_ metric: QueryMetric) {
        queryMetrics.append(metric)
        
        // Keep only recent metrics
        if queryMetrics.count > 1000 {
            queryMetrics.removeFirst(queryMetrics.count - 1000)
        }
        
        // Track for aggregation
        if queryTimes[metric.identifier] == nil {
            queryTimes[metric.identifier] = []
        }
        queryTimes[metric.identifier]?.append(metric.duration)
        
        // Check performance budget
        if metric.duration > performanceBudgets.queryTimeLimit {
            logger.warning("⚠️ Slow query '\(metric.identifier)': \(metric.duration)s")
        }
    }
    
    internal func recordPhotoOperationMetric(_ metric: PhotoOperationMetric) {
        photoOperationMetrics.append(metric)
        
        // Keep only recent metrics
        if photoOperationMetrics.count > 500 {
            photoOperationMetrics.removeFirst(photoOperationMetrics.count - 500)
        }
        
        // Check performance budget
        if metric.duration > performanceBudgets.photoOperationTimeLimit {
            logger.warning("⚠️ Slow photo operation '\(metric.type.rawValue)': \(metric.duration)s")
        }
    }
    
    // MARK: - Private Methods
    
    private func updateMemoryMetrics() {
        let info = ProcessInfo.processInfo
        let physicalMemory = Double(info.physicalMemory)
        let memoryUsed = Double(getMemoryUsage())
        
        currentMemoryUsage = memoryUsed / 1024 / 1024 // Convert to MB
        
        if currentMemoryUsage > peakMemoryUsage {
            peakMemoryUsage = currentMemoryUsage
        }
        
        // Check memory budget
        if currentMemoryUsage > performanceBudgets.memoryUsageLimit {
            logger.warning("⚠️ Memory usage exceeded budget: \(self.currentMemoryUsage)MB > \(self.performanceBudgets.memoryUsageLimit)MB")
        }
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
    
    private func startFrameRateMonitoring() {
        // This is a simplified frame rate monitor
        // In production, you'd use CADisplayLink for accurate frame timing
        var lastFrameTime = CACurrentMediaTime()
        var frameCount = 0
        var frameTimes: [Double] = []
        
        frameRateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            let currentTime = CACurrentMediaTime()
            let deltaTime = currentTime - lastFrameTime
            lastFrameTime = currentTime
            
            frameCount += 1
            frameTimes.append(deltaTime)
            
            // Calculate average every second
            if frameCount >= 60 {
                let averageFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
                let fps = 1.0 / averageFrameTime
                
                Task { @MainActor in
                    self?.averageFrameRate = min(fps, 60) // Cap at 60 FPS
                    
                    if fps < self?.performanceBudgets.minimumFrameRate ?? 60 {
                        self?.logger.warning("⚠️ Low frame rate detected: \(fps) FPS")
                    }
                }
                
                frameCount = 0
                frameTimes.removeAll()
            }
        }
    }
    
    private func calculateAverageQueryTime() -> TimeInterval {
        let allTimes = queryTimes.values.flatMap { $0 }
        guard !allTimes.isEmpty else { return 0 }
        return allTimes.reduce(0, +) / Double(allTimes.count)
    }
    
    private func calculateAveragePhotoOperationTime() -> TimeInterval {
        guard !photoOperationMetrics.isEmpty else { return 0 }
        let totalTime = photoOperationMetrics.reduce(0) { $0 + $1.duration }
        return totalTime / Double(photoOperationMetrics.count)
    }
    
    private func getSlowQueries() -> [QueryMetric] {
        queryMetrics.filter { $0.duration > performanceBudgets.queryTimeLimit }
            .sorted { $0.duration > $1.duration }
            .prefix(10)
            .map { $0 }
    }
    
    private func getMemoryWarnings() -> [String] {
        var warnings: [String] = []
        
        if currentMemoryUsage > performanceBudgets.memoryUsageLimit {
            warnings.append("Current memory usage (\(String(format: "%.1f", currentMemoryUsage))MB) exceeds limit")
        }
        
        if peakMemoryUsage > performanceBudgets.memoryUsageLimit * 1.5 {
            warnings.append("Peak memory usage (\(String(format: "%.1f", peakMemoryUsage))MB) is critically high")
        }
        
        return warnings
    }
    
    private func calculatePerformanceScore() -> Double {
        var score = 100.0
        
        // Deduct for slow app launch
        if appLaunchTime > performanceBudgets.appLaunchTimeLimit {
            score -= 10
        }
        
        // Deduct for memory issues
        if currentMemoryUsage > performanceBudgets.memoryUsageLimit {
            score -= 15
        }
        
        // Deduct for frame rate issues
        if averageFrameRate < performanceBudgets.minimumFrameRate {
            score -= 20
        }
        
        // Deduct for slow queries
        let slowQueryRatio = Double(getSlowQueries().count) / Double(max(queryMetrics.count, 1))
        score -= slowQueryRatio * 20
        
        return max(score, 0)
    }
}

// MARK: - Supporting Types

public struct PerformanceBudgets {
    public let appLaunchTimeLimit: TimeInterval = 2.0 // 2 seconds
    public let queryTimeLimit: TimeInterval = 0.5 // 500ms
    public let photoOperationTimeLimit: TimeInterval = 1.0 // 1 second
    public let memoryUsageLimit: Double = 50.0 // 50MB
    public let uiResponseTimeLimit: TimeInterval = 0.1 // 100ms
    public let minimumFrameRate: Double = 50.0 // 50 FPS minimum
}

public struct QueryMetric {
    public let identifier: String
    public let duration: TimeInterval
    public let resultCount: Int
    public let cacheHit: Bool
    public let timestamp: Date
}

public struct PhotoOperationMetric {
    public let type: PhotoOperationType
    public let duration: TimeInterval
    public let fileSize: Int?
    public let success: Bool
    public let timestamp: Date
}

public enum PhotoOperationType: String {
    case save = "Save"
    case load = "Load"
    case process = "Process"
    case thumbnail = "Thumbnail"
    case delete = "Delete"
}

public struct PerformanceReport {
    public let timestamp: Date
    public let appLaunchTime: TimeInterval
    public let averageMemoryUsage: Double
    public let peakMemoryUsage: Double
    public let averageFrameRate: Double
    public let averageQueryTime: TimeInterval
    public let averagePhotoOperationTime: TimeInterval
    public let slowQueries: [QueryMetric]
    public let memoryWarnings: [String]
    public let performanceScore: Double
}

// MARK: - Tracker Classes

public class QueryTracker {
    private let identifier: String
    private let monitor: PerformanceMonitor
    private let startTime: CFAbsoluteTime
    private var resultCount = 0
    private var cacheHit = false
    
    init(identifier: String, monitor: PerformanceMonitor) {
        self.identifier = identifier
        self.monitor = monitor
        self.startTime = CFAbsoluteTimeGetCurrent()
    }
    
    public func setCacheHit(_ hit: Bool) {
        cacheHit = hit
    }
    
    public func setResultCount(_ count: Int) {
        resultCount = count
    }
    
    public func complete() {
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let metric = QueryMetric(
            identifier: identifier,
            duration: duration,
            resultCount: resultCount,
            cacheHit: cacheHit,
            timestamp: Date()
        )
        
        Task { @MainActor in
            monitor.recordQueryMetric(metric)
        }
    }
}

public class PhotoOperationTracker {
    private let type: PhotoOperationType
    private let monitor: PerformanceMonitor
    private let startTime: CFAbsoluteTime
    private var fileSize: Int?
    
    init(type: PhotoOperationType, monitor: PerformanceMonitor) {
        self.type = type
        self.monitor = monitor
        self.startTime = CFAbsoluteTimeGetCurrent()
    }
    
    public func setFileSize(_ size: Int) {
        fileSize = size
    }
    
    public func complete(success: Bool = true) {
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let metric = PhotoOperationMetric(
            type: type,
            duration: duration,
            fileSize: fileSize,
            success: success,
            timestamp: Date()
        )
        
        Task { @MainActor in
            monitor.recordPhotoOperationMetric(metric)
        }
    }
}