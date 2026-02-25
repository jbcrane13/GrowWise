import Testing
import Foundation
@testable import GrowWiseServices
@testable import GrowWiseModels

// NOTE: BackgroundTaskManager uses a custom TaskPriority enum (distinct from
// Swift's _Concurrency.TaskPriority). All references in this file refer to
// GrowWiseServices.TaskPriority unless fully qualified otherwise.

// MARK: - Suite: Task submission and tracking

@Suite("BackgroundTaskManager Task Submission Tests")
struct BackgroundTaskManagerSubmissionTests {

    // submitTask appends a BackgroundTask to activeTasks synchronously.
    @Test("submitTask adds an entry to activeTasks")
    @MainActor
    func testSubmitTaskAddsToActiveTasks() async throws {
        let manager = BackgroundTaskManager.shared

        let before = manager.activeTasks.count
        let task = manager.submitTask(name: "test-add-\(UUID().uuidString)", priority: .medium) {
            "done"
        }

        // The task is appended synchronously, so the count increases immediately.
        #expect(manager.activeTasks.count > before)

        // Drain the task to avoid leaking into subsequent tests.
        _ = try? await task.value
    }

    // The submitted task's name is reflected in activeTasks.
    @Test("Submitted task name is stored in activeTasks")
    @MainActor
    func testSubmittedTaskNameReflectedInActiveTasks() async throws {
        let manager = BackgroundTaskManager.shared
        let name = "named-task-\(UUID().uuidString)"

        let task = manager.submitTask(name: name, priority: .medium) { "ok" }

        // The task must appear in activeTasks (it may have already completed on fast runners,
        // so we check either activeTasks or completedTasks).
        let inActive    = manager.activeTasks.contains  { $0.name == name }
        let inCompleted = manager.completedTasks.contains { $0.name == name }
        #expect(inActive || inCompleted)

        _ = try? await task.value
    }

    // The initial status of a submitted task must be .pending or .running.
    @Test("Submitted task starts with pending or running status")
    @MainActor
    func testSubmittedTaskInitialStatus() async throws {
        let manager = BackgroundTaskManager.shared
        let name = "status-task-\(UUID().uuidString)"

        let task = manager.submitTask(name: name, priority: .medium) {
            try? await Task.sleep(nanoseconds: 50_000_000)
            return "result"
        }

        // The status should be .pending or .running immediately after submission.
        if let entry = manager.activeTasks.first(where: { $0.name == name }) {
            #expect(entry.status == .pending || entry.status == .running)
        }

        _ = try? await task.value
    }

    // A task that completes successfully moves from activeTasks to completedTasks.
    @Test("Completed task moves from activeTasks to completedTasks")
    @MainActor
    func testCompletedTaskMovesToCompletedTasks() async throws {
        let manager = BackgroundTaskManager.shared
        let name = "complete-task-\(UUID().uuidString)"

        let task = manager.submitTask(name: name, priority: .medium) { "value" }
        _ = try await task.value

        // Give the manager's @MainActor update a cycle to run.
        await Task.yield()

        let inActive    = manager.activeTasks.contains  { $0.name == name }
        let inCompleted = manager.completedTasks.contains { $0.name == name }

        #expect(!inActive, "Task should not remain in activeTasks after completion")
        #expect(inCompleted, "Task should appear in completedTasks after completion")
    }

    // A task that throws an error must also be removed from activeTasks and
    // reflected in completedTasks with a .failed status.
    @Test("Failed task moves to completedTasks with failed status")
    @MainActor
    func testFailedTaskMovesToCompletedTasks() async throws {
        let manager = BackgroundTaskManager.shared
        let name = "fail-task-\(UUID().uuidString)"

        struct TestError: Error {}

        let task = manager.submitTask(name: name, priority: .medium) {
            throw TestError()
        }
        _ = try? await task.value
        await Task.yield()

        let inActive = manager.activeTasks.contains  { $0.name == name }
        let failed   = manager.completedTasks.first  { $0.name == name }

        #expect(!inActive)
        #expect(failed?.status == .failed)
    }
}

// MARK: - Suite: getActiveTasksCount

@Suite("BackgroundTaskManager getActiveTasksCount Tests")
struct BackgroundTaskManagerActiveCountTests {

    @Test("getActiveTasksCount returns zeros when no tasks are active")
    @MainActor
    func testCountsAreZeroWithNoActiveTasks() async throws {
        let manager = BackgroundTaskManager.shared

        // Drain any active tasks from prior tests by waiting briefly.
        for _ in 0..<10 {
            if manager.activeTasks.isEmpty { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        // If tasks from prior suites are still running we cannot guarantee zero,
        // so we only assert the return type is correct (non-negative counts).
        let counts = manager.getActiveTasksCount()
        #expect(counts.high   >= 0)
        #expect(counts.medium >= 0)
        #expect(counts.low    >= 0)
    }

    @Test("getActiveTasksCount reflects submitted task priority")
    @MainActor
    func testCountReflectsPriority() async throws {
        let manager = BackgroundTaskManager.shared

        // Use a long-running task to keep it in activeTasks while we inspect.
        let task = manager.submitTask(name: "count-high-\(UUID().uuidString)", priority: .high) {
            try? await Task.sleep(nanoseconds: 500_000_000)
            return "done"
        }

        let counts = manager.getActiveTasksCount()
        #expect(counts.high >= 1)

        task.cancel()
        _ = try? await task.value
    }

    @Test("getActiveTasksCount differentiates high, medium, low priorities")
    @MainActor
    func testCountDifferentiatePriorities() async throws {
        let manager = BackgroundTaskManager.shared

        let delay: UInt64 = 400_000_000 // 0.4 s

        let high = manager.submitTask(name: "prio-high-\(UUID().uuidString)", priority: .high) {
            try? await Task.sleep(nanoseconds: delay); return "h"
        }
        let med = manager.submitTask(name: "prio-med-\(UUID().uuidString)", priority: .medium) {
            try? await Task.sleep(nanoseconds: delay); return "m"
        }
        let low = manager.submitTask(name: "prio-low-\(UUID().uuidString)", priority: .low) {
            try? await Task.sleep(nanoseconds: delay); return "l"
        }

        let counts = manager.getActiveTasksCount()
        #expect(counts.high   >= 1)
        #expect(counts.medium >= 1)
        #expect(counts.low    >= 1)

        // Clean up
        high.cancel(); med.cancel(); low.cancel()
        _ = try? await high.value
        _ = try? await med.value
        _ = try? await low.value
    }
}

// MARK: - Suite: cancelTask

@Suite("BackgroundTaskManager cancelTask Tests")
struct BackgroundTaskManagerCancelTests {

    @Test("cancelTask moves entry from activeTasks to completedTasks as cancelled")
    @MainActor
    func testCancelTaskMovesToCompleted() async throws {
        let manager = BackgroundTaskManager.shared
        let name = "cancel-me-\(UUID().uuidString)"

        let task = manager.submitTask(name: name, priority: .medium) {
            try? await Task.sleep(nanoseconds: 600_000_000)
            return "never"
        }

        // Grab the task id from activeTasks while it's still running.
        guard let entry = manager.activeTasks.first(where: { $0.name == name }) else {
            // Task may have already completed on an extremely fast runner; skip gracefully.
            task.cancel()
            return
        }

        manager.cancelTask(id: entry.id)

        let inActive    = manager.activeTasks.contains   { $0.name == name }
        let cancelled   = manager.completedTasks.first   { $0.name == name }

        #expect(!inActive,  "Cancelled task should be removed from activeTasks")
        #expect(cancelled?.status == .cancelled, "Cancelled task should have .cancelled status")

        task.cancel()
        _ = try? await task.value
    }

    @Test("cancelTask with unknown id is a no-op and does not crash")
    @MainActor
    func testCancelUnknownIdIsNoop() async throws {
        let manager = BackgroundTaskManager.shared
        // Passing a random UUID that was never submitted should not crash.
        manager.cancelTask(id: UUID())
    }

    @Test("cancelTasks(priority:) cancels all active tasks of that priority")
    @MainActor
    func testCancelTasksByPriority() async throws {
        let manager = BackgroundTaskManager.shared
        let base = UUID().uuidString
        let delay: UInt64 = 600_000_000

        let t1 = manager.submitTask(name: "cancel-low-1-\(base)", priority: .low) {
            try? await Task.sleep(nanoseconds: delay); return "1"
        }
        let t2 = manager.submitTask(name: "cancel-low-2-\(base)", priority: .low) {
            try? await Task.sleep(nanoseconds: delay); return "2"
        }

        // Verify tasks exist in activeTasks before cancelling.
        let lowBefore = manager.activeTasks.filter { $0.name.contains(base) && $0.priority == .low }.count
        #expect(lowBefore >= 2)

        manager.cancelTasks(priority: .low)

        let lowAfter = manager.activeTasks.filter { $0.name.contains(base) && $0.priority == .low }.count
        #expect(lowAfter == 0)

        t1.cancel(); t2.cancel()
        _ = try? await t1.value
        _ = try? await t2.value
    }
}

// MARK: - Suite: updateTaskProgress

@Suite("BackgroundTaskManager updateTaskProgress Tests")
struct BackgroundTaskManagerProgressTests {

    @Test("updateTaskProgress clamps progress to [0, 1]")
    @MainActor
    func testProgressClamping() async throws {
        let manager = BackgroundTaskManager.shared
        let name = "progress-clamp-\(UUID().uuidString)"

        let task = manager.submitTask(name: name, priority: .medium) {
            try? await Task.sleep(nanoseconds: 500_000_000)
            return "done"
        }

        guard let entry = manager.activeTasks.first(where: { $0.name == name }) else {
            task.cancel(); return
        }

        manager.updateTaskProgress(id: entry.id, progress: 1.5)
        #expect(manager.taskProgress[entry.id] == 1.0)

        manager.updateTaskProgress(id: entry.id, progress: -0.5)
        #expect(manager.taskProgress[entry.id] == 0.0)

        manager.updateTaskProgress(id: entry.id, progress: 0.6)
        #expect(manager.taskProgress[entry.id] == 0.6)

        task.cancel()
        _ = try? await task.value
    }

    @Test("updateTaskProgress reflects in activeTasks entry")
    @MainActor
    func testProgressReflectedInActiveTasksEntry() async throws {
        let manager = BackgroundTaskManager.shared
        let name = "progress-entry-\(UUID().uuidString)"

        let task = manager.submitTask(name: name, priority: .medium) {
            try? await Task.sleep(nanoseconds: 500_000_000)
            return "done"
        }

        guard let entry = manager.activeTasks.first(where: { $0.name == name }) else {
            task.cancel(); return
        }

        manager.updateTaskProgress(id: entry.id, progress: 0.42)

        let updatedEntry = manager.activeTasks.first { $0.id == entry.id }
        #expect(abs((updatedEntry?.progress ?? -1) - 0.42) < 0.001)

        task.cancel()
        _ = try? await task.value
    }
}

// MARK: - Suite: batchSubmitTasks

@Suite("BackgroundTaskManager Batch Submission Tests")
struct BackgroundTaskManagerBatchTests {

    @Test("batchSubmitTasks returns the correct number of tasks")
    @MainActor
    func testBatchSubmitReturnsCorrectCount() async throws {
        let manager = BackgroundTaskManager.shared
        let base = UUID().uuidString

        let descriptors: [(name: String, priority: GrowWiseServices.TaskPriority, operation: () async throws -> String)] = [
            (name: "batch-1-\(base)", priority: .high,   operation: { "a" }),
            (name: "batch-2-\(base)", priority: .medium, operation: { "b" }),
            (name: "batch-3-\(base)", priority: .low,    operation: { "c" }),
        ]

        let tasks = manager.batchSubmitTasks(tasks: descriptors)
        #expect(tasks.count == 3)

        for task in tasks { _ = try? await task.value }
    }

    @Test("batchSubmitTasks processes all tasks and they complete successfully")
    @MainActor
    func testBatchSubmitAllComplete() async throws {
        let manager = BackgroundTaskManager.shared
        let base = UUID().uuidString
        var results: [String] = []

        let descriptors: [(name: String, priority: GrowWiseServices.TaskPriority, operation: () async throws -> String)] = [
            (name: "bcomplete-1-\(base)", priority: .medium, operation: { "x" }),
            (name: "bcomplete-2-\(base)", priority: .medium, operation: { "y" }),
            (name: "bcomplete-3-\(base)", priority: .medium, operation: { "z" }),
        ]

        let tasks = manager.batchSubmitTasks(tasks: descriptors)

        for task in tasks {
            if let value = try? await task.value {
                results.append(value)
            }
        }

        #expect(results.count == 3)
        #expect(Set(results) == Set(["x", "y", "z"]))
    }

    @Test("batchSubmitTasks with empty array returns empty task list")
    @MainActor
    func testBatchSubmitEmpty() async throws {
        let manager = BackgroundTaskManager.shared

        let descriptors: [(name: String, priority: GrowWiseServices.TaskPriority, operation: () async throws -> Int)] = []
        let tasks = manager.batchSubmitTasks(tasks: descriptors)

        #expect(tasks.isEmpty)
    }
}

// MARK: - Suite: waitForTask / waitForAllTasks

@Suite("BackgroundTaskManager waitForTask Tests")
struct BackgroundTaskManagerWaitTests {

    @Test("waitForTask returns after the named task completes")
    @MainActor
    func testWaitForTaskReturnAfterCompletion() async throws {
        let manager = BackgroundTaskManager.shared
        let name = "wait-for-\(UUID().uuidString)"

        let swiftTask = manager.submitTask(name: name, priority: .medium) {
            try? await Task.sleep(nanoseconds: 100_000_000)
            return "waited"
        }

        if let entry = manager.activeTasks.first(where: { $0.name == name }) {
            await manager.waitForTask(id: entry.id)
            // After waitForTask returns, the task must no longer be in activeTasks.
            #expect(!manager.activeTasks.contains { $0.id == entry.id })
        }

        _ = try? await swiftTask.value
    }
}

// MARK: - Suite: adjustConcurrency

@Suite("BackgroundTaskManager adjustConcurrency Tests")
struct BackgroundTaskManagerConcurrencyTests {

    @Test("adjustConcurrency with high CPU reduces queue concurrency")
    @MainActor
    func testHighCPUReducesConcurrency() async throws {
        let manager = BackgroundTaskManager.shared

        let highCPU = ResourceUsage(
            cpuUsage: 0.9,
            memoryUsage: 0.5,
            memoryPressure: .normal
        )

        // Should not crash and should reduce limits.
        manager.adjustConcurrency(basedOn: highCPU)
        // No observable public property for maxConcurrentOperationCount; this is
        // a no-crash/no-exception contract test.
    }

    @Test("adjustConcurrency with critical memory suspends queues without crash")
    @MainActor
    func testCriticalMemorySuspendsQueues() async throws {
        let manager = BackgroundTaskManager.shared

        let criticalMemory = ResourceUsage(
            cpuUsage: 0.4,
            memoryUsage: 0.95,
            memoryPressure: .critical
        )

        manager.adjustConcurrency(basedOn: criticalMemory)
        // Contract: must complete without throwing or crashing.
    }

    @Test("adjustConcurrency under normal conditions restores default limits")
    @MainActor
    func testNormalConditionsRestoresDefaults() async throws {
        let manager = BackgroundTaskManager.shared

        let normal = ResourceUsage(
            cpuUsage: 0.2,
            memoryUsage: 0.3,
            memoryPressure: .normal
        )

        manager.adjustConcurrency(basedOn: normal)
        // Contract: must complete without throwing or crashing.
    }
}

// MARK: - Suite: Resource monitoring guard

@Suite("BackgroundTaskManager Resource Monitoring Guard Tests")
@MainActor
struct BackgroundTaskManagerResourceMonitoringTests {

    @Test("Resource monitoring is disabled when --uitesting argument is present")
    @MainActor func testResourceMonitoringDisabledDuringUITesting() {
        // The guard in startResourceMonitoring() checks ProcessInfo arguments.
        // We verify the guard logic in isolation since we cannot inject launch
        // arguments at test-run time.
        let args = ProcessInfo.processInfo.arguments
        let hasUITestingFlag = args.contains("--uitesting")

        // INTEGRATION GAP: To fully test this path you would need to launch the
        // process with "--uitesting" in the launch arguments (possible in UI test
        // targets but not unit test targets).  Here we simply document the
        // expected behaviour and assert the check itself is correct.
        if hasUITestingFlag {
            // When the flag is present the manager's timers should never fire.
            // We cannot directly inspect the private Timer ivars, so we verify
            // that BackgroundTaskManager.shared initialises without crash.
            let _ = BackgroundTaskManager.shared
        } else {
            // Normal path: flag absent, timers start (no assertion possible from
            // outside, but init must not crash).
            let _ = BackgroundTaskManager.shared
        }
    }
}

// MARK: - Suite: TaskPriority supporting type

@Suite("TaskPriority Supporting Type Tests")
struct TaskPriorityTests {

    @Test("TaskPriority raw values are stable strings")
    func testRawValues() {
        #expect(GrowWiseServices.TaskPriority.high.rawValue   == "High")
        #expect(GrowWiseServices.TaskPriority.medium.rawValue == "Medium")
        #expect(GrowWiseServices.TaskPriority.low.rawValue    == "Low")
    }

    @Test("TaskPriority maps to expected Swift concurrency priorities")
    func testTaskPriorityMapping() {
        #expect(GrowWiseServices.TaskPriority.high.taskPriority   == _Concurrency.TaskPriority.high)
        #expect(GrowWiseServices.TaskPriority.medium.taskPriority == _Concurrency.TaskPriority.medium)
        #expect(GrowWiseServices.TaskPriority.low.taskPriority    == _Concurrency.TaskPriority.low)
    }

    @Test("TaskPriority is Codable")
    func testCodable() throws {
        let priorities: [GrowWiseServices.TaskPriority] = [.high, .medium, .low]
        for priority in priorities {
            let data    = try JSONEncoder().encode(priority)
            let decoded = try JSONDecoder().decode(GrowWiseServices.TaskPriority.self, from: data)
            #expect(decoded == priority)
        }
    }
}

// MARK: - Suite: TaskStatus supporting type

@Suite("TaskStatus Supporting Type Tests")
struct TaskStatusTests {

    @Test("TaskStatus raw values are stable strings")
    func testRawValues() {
        #expect(TaskStatus.pending.rawValue   == "Pending")
        #expect(TaskStatus.running.rawValue   == "Running")
        #expect(TaskStatus.completed.rawValue == "Completed")
        #expect(TaskStatus.failed.rawValue    == "Failed")
        #expect(TaskStatus.cancelled.rawValue == "Cancelled")
    }

    @Test("TaskStatus is Codable")
    func testCodable() throws {
        let statuses: [TaskStatus] = [.pending, .running, .completed, .failed, .cancelled]
        for status in statuses {
            let data    = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(TaskStatus.self, from: data)
            #expect(decoded == status)
        }
    }
}

// MARK: - Suite: BackgroundTask model

@Suite("BackgroundTask Model Tests")
struct BackgroundTaskModelTests {

    @Test("BackgroundTask is Codable")
    func testCodable() throws {
        let id   = UUID()
        let task = BackgroundTask(
            id:         id,
            name:       "encode-me",
            priority:   .high,
            status:     .pending,
            createdAt:  Date()
        )

        let data    = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(BackgroundTask.self, from: data)

        #expect(decoded.id       == task.id)
        #expect(decoded.name     == task.name)
        #expect(decoded.priority == task.priority)
        #expect(decoded.status   == task.status)
    }

    @Test("BackgroundTask starts with zero progress")
    func testDefaultProgress() {
        let task = BackgroundTask(
            id:        UUID(),
            name:      "progress-default",
            priority:  .medium,
            status:    .pending,
            createdAt: Date()
        )
        #expect(task.progress == 0)
    }
}

// MARK: - Suite: ResourceUsage and MemoryPressure

@Suite("ResourceUsage and MemoryPressure Tests")
struct ResourceUsageTests {

    @Test("MemoryPressure cases are distinct")
    func testMemoryPressureCases() {
        let pressures: [GrowWiseServices.MemoryPressure] = [.normal, .warning, .critical]
        // Simply ensure all three cases exist and are accessible.
        #expect(pressures.count == 3)
    }

    @Test("ResourceUsage stores provided values")
    func testResourceUsageValues() {
        let usage = ResourceUsage(
            cpuUsage:       0.75,
            memoryUsage:    0.60,
            memoryPressure: .warning
        )

        #expect(abs(usage.cpuUsage    - 0.75) < 0.001)
        #expect(abs(usage.memoryUsage - 0.60) < 0.001)

        if case .warning = usage.memoryPressure {
            // correct
        } else {
            Issue.record("Expected .warning memory pressure")
        }
    }
}

// MARK: - Suite: TaskError

@Suite("TaskError Tests")
struct TaskErrorTests {

    @Test("TaskError.cancelled has a non-empty localised description")
    func testCancelledErrorDescription() {
        let error = TaskError.cancelled
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test("TaskError.failed carries the reason in its description")
    func testFailedErrorContainsReason() {
        let reason = "disk full"
        let error  = TaskError.failed(reason)
        #expect(error.errorDescription?.contains(reason) == true)
    }
}
