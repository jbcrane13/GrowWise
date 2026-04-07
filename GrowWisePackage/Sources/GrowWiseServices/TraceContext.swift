import Foundation
import os

// MARK: - TraceContext

/// Propagates a trace ID through async/await call chains using Swift's TaskLocal.
///
/// Usage:
/// ```swift
/// try await TraceContext.withTrace(operation: "sync_garden") { trace in
///     logger.info("[\(trace.traceID)] Starting garden sync")
///     let result = try await cloudSyncService.syncGarden(garden)
/// }
/// ```
///
/// Inside any async function called within that block, read the current trace:
/// ```swift
/// let trace = TraceContext.current
/// logger.info("[\(trace.traceID)] Fetching plants")
/// ```
public struct TraceContext: Sendable {
    /// Unique identifier for the end-to-end operation (propagated across service calls).
    public let traceID: String

    /// Short identifier for this specific span within the trace.
    public let spanID: String

    /// The parent span that initiated this span (nil for root spans).
    public let parentSpanID: String?

    /// Human-readable label for the operation (e.g., "sync_garden", "fetch_species").
    public let operation: String

    /// Timestamp when the trace was created.
    public let startedAt: Date

    @TaskLocal public static var current: TraceContext = .none

    /// Sentinel value when no trace is active.
    public static let none = TraceContext(
        traceID: "no-trace",
        spanID: "no-span",
        parentSpanID: nil,
        operation: "none",
        startedAt: .distantPast
    )

    public init(
        traceID: String = UUID().uuidString,
        spanID: String = Self.generateSpanID(),
        parentSpanID: String? = nil,
        operation: String,
        startedAt: Date = Date()
    ) {
        self.traceID = traceID
        self.spanID = spanID
        self.parentSpanID = parentSpanID
        self.operation = operation
        self.startedAt = startedAt
    }

    /// Whether a real trace is active (not the sentinel value).
    public var isActive: Bool {
        traceID != "no-trace"
    }

    /// Elapsed time since the trace started.
    public var elapsed: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }

    /// Create a child span inheriting this trace's ID.
    public func childSpan(operation: String) -> TraceContext {
        TraceContext(
            traceID: traceID,
            spanID: Self.generateSpanID(),
            parentSpanID: spanID,
            operation: operation
        )
    }

    /// Execute an async block with a new root trace propagated via TaskLocal.
    @discardableResult
    public static func withTrace<T: Sendable>(
        operation: String,
        body: @Sendable (TraceContext) async throws -> T
    ) async rethrows -> T {
        let trace = TraceContext(operation: operation)
        return try await $current.withValue(trace) {
            try await body(trace)
        }
    }

    /// Execute an async block with a child span of the current trace.
    @discardableResult
    public static func withChildSpan<T: Sendable>(
        operation: String,
        body: @Sendable (TraceContext) async throws -> T
    ) async rethrows -> T {
        let parent = current
        let child = parent.isActive
            ? parent.childSpan(operation: operation)
            : TraceContext(operation: operation)
        return try await $current.withValue(child) {
            try await body(child)
        }
    }

    /// 8-character hex span ID (W3C Trace Context style, shortened for logs).
    public static func generateSpanID() -> String {
        let bytes = (0 ..< 4).map { _ in UInt8.random(in: 0 ... 255) }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - URLRequest + Trace Propagation

public extension URLRequest {
    /// Injects the current TraceContext trace ID as `X-Request-ID` and
    /// span/parent as `X-Span-ID` / `X-Parent-Span-ID` headers.
    mutating func injectTraceHeaders(from trace: TraceContext? = nil) {
        let ctx = trace ?? TraceContext.current
        guard ctx.isActive else { return }
        setValue(ctx.traceID, forHTTPHeaderField: "X-Request-ID")
        setValue(ctx.spanID, forHTTPHeaderField: "X-Span-ID")
        if let parent = ctx.parentSpanID {
            setValue(parent, forHTTPHeaderField: "X-Parent-Span-ID")
        }
    }
}

// MARK: - Logger + Trace Convenience

public extension Logger {
    /// Log a message with the current trace context automatically included.
    /// Format: `[traceID:spanID] message`
    func traced(level: OSLogType = .info, _ message: String) {
        let ctx = TraceContext.current
        if ctx.isActive {
            let msg = "[\(ctx.traceID):\(ctx.spanID)] \(message)"
            log(level: level, "\(msg, privacy: .public)")
        } else {
            log(level: level, "\(message, privacy: .public)")
        }
    }
}
