import Foundation
@testable import GrowWiseServices
import Testing

struct TraceContextTests {
    // MARK: - Basic Construction

    @Test("TraceContext generates unique trace and span IDs")
    func uniqueIDs() {
        let first = TraceContext(operation: "op_a")
        let second = TraceContext(operation: "op_b")
        #expect(first.traceID != second.traceID)
        #expect(first.spanID != second.spanID)
    }

    @Test("TraceContext stores operation name and start time")
    func fieldsStored() {
        let before = Date()
        let ctx = TraceContext(operation: "fetch_plants")
        let after = Date()
        #expect(ctx.operation == "fetch_plants")
        #expect(ctx.startedAt >= before)
        #expect(ctx.startedAt <= after)
        #expect(ctx.parentSpanID == nil)
    }

    @Test("isActive returns false for sentinel value")
    func sentinelIsNotActive() {
        #expect(TraceContext.none.isActive == false)
        #expect(TraceContext.none.traceID == "no-trace")
    }

    @Test("isActive returns true for real trace")
    func realTraceIsActive() {
        let ctx = TraceContext(operation: "sync")
        #expect(ctx.isActive == true)
    }

    // MARK: - Child Spans

    @Test("Child span inherits parent trace ID but gets a new span ID")
    func childSpanInheritsTraceID() {
        let parent = TraceContext(operation: "parent_op")
        let child = parent.childSpan(operation: "child_op")
        #expect(child.traceID == parent.traceID)
        #expect(child.spanID != parent.spanID)
        #expect(child.parentSpanID == parent.spanID)
        #expect(child.operation == "child_op")
    }

    // MARK: - TaskLocal Propagation

    @Test("withTrace propagates context to nested async calls")
    func withTracePropagation() async {
        #expect(TraceContext.current.isActive == false)

        await TraceContext.withTrace(operation: "root_op") { trace in
            #expect(TraceContext.current.isActive == true)
            #expect(TraceContext.current.traceID == trace.traceID)
            #expect(TraceContext.current.operation == "root_op")
        }

        #expect(TraceContext.current.isActive == false)
    }

    @Test("withChildSpan creates nested span under active trace")
    func testWithChildSpan() async {
        await TraceContext.withTrace(operation: "root") { root in
            await TraceContext.withChildSpan(operation: "child") { child in
                #expect(child.traceID == root.traceID)
                #expect(child.parentSpanID == root.spanID)
                #expect(child.operation == "child")
                #expect(TraceContext.current.spanID == child.spanID)
            }
            #expect(TraceContext.current.spanID == root.spanID)
        }
    }

    @Test("withChildSpan creates root trace when no parent is active")
    func childSpanWithoutParent() async {
        await TraceContext.withChildSpan(operation: "orphan") { ctx in
            #expect(ctx.isActive == true)
            #expect(ctx.operation == "orphan")
            #expect(ctx.parentSpanID == nil)
        }
    }

    // MARK: - Elapsed Time

    @Test("elapsed returns non-negative duration")
    func testElapsed() async throws {
        let ctx = TraceContext(operation: "timed_op")
        try await Task.sleep(for: .milliseconds(50))
        #expect(ctx.elapsed >= 0.04)
    }

    // MARK: - URLRequest Header Injection

    @Test("injectTraceHeaders adds X-Request-ID from explicit trace")
    func headerInjectionExplicit() throws {
        let trace = TraceContext(
            traceID: "test-trace-123",
            spanID: "ab12cd34",
            parentSpanID: "parent-99",
            operation: "api_call"
        )
        let url = try #require(URL(string: "https://example.com/api"))
        var request = URLRequest(url: url)
        request.injectTraceHeaders(from: trace)

        #expect(request.value(forHTTPHeaderField: "X-Request-ID") == "test-trace-123")
        #expect(request.value(forHTTPHeaderField: "X-Span-ID") == "ab12cd34")
        #expect(request.value(forHTTPHeaderField: "X-Parent-Span-ID") == "parent-99")
    }

    @Test("injectTraceHeaders skips headers when no trace is active")
    func headerInjectionNoTrace() throws {
        let url = try #require(URL(string: "https://example.com/api"))
        var request = URLRequest(url: url)
        request.injectTraceHeaders()
        #expect(request.value(forHTTPHeaderField: "X-Request-ID") == nil)
    }

    @Test("injectTraceHeaders reads from TaskLocal when no explicit trace given")
    func headerInjectionFromTaskLocal() async throws {
        let url = try #require(URL(string: "https://example.com"))
        await TraceContext.withTrace(operation: "http_test") { trace in
            var request = URLRequest(url: url)
            request.injectTraceHeaders()
            #expect(request.value(forHTTPHeaderField: "X-Request-ID") == trace.traceID)
            #expect(request.value(forHTTPHeaderField: "X-Span-ID") == trace.spanID)
        }
    }

    @Test("injectTraceHeaders omits X-Parent-Span-ID when no parent exists")
    func headerInjectionNoParent() throws {
        let trace = TraceContext(operation: "root_call")
        let url = try #require(URL(string: "https://example.com"))
        var request = URLRequest(url: url)
        request.injectTraceHeaders(from: trace)
        #expect(request.value(forHTTPHeaderField: "X-Request-ID") == trace.traceID)
        #expect(request.value(forHTTPHeaderField: "X-Parent-Span-ID") == nil)
    }

    // MARK: - Span ID Format

    @Test("Span ID is 8-character hex string")
    func spanIDFormat() {
        let ctx = TraceContext(operation: "format_test")
        #expect(ctx.spanID.count == 8)
        let hexCharSet = CharacterSet(charactersIn: "0123456789abcdef")
        let allHex = ctx.spanID.unicodeScalars.allSatisfy { hexCharSet.contains($0) }
        #expect(allHex == true)
    }
}
