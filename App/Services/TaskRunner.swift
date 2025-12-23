import Combine
import Foundation
import Darwin

struct TaskOutput: Identifiable, Hashable {
    let id: UUID
    let line: String
    let isError: Bool
    let timestamp: Date
}

enum TaskEvent: Hashable {
    case output(TaskOutput)
    case finished(Int32)
}

struct TaskHandle {
    let id: String
    let title: String
    let stream: AsyncStream<TaskEvent>
}

@MainActor
final class TaskRunner: ObservableObject {
    private struct RunningTask {
        let process: Process
        let logURL: URL
        let logHandle: FileHandle
    }

    private var running: [String: RunningTask] = [:]

    func run(
        title: String,
        launchPath: String,
        arguments: [String],
        environment: [String: String] = [:],
        currentDirectory: URL? = nil
    ) throws -> TaskHandle {
        let taskID = UUID().uuidString
        let logURL = AppPaths.logsURL(taskID: taskID)
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let logHandle = try FileHandle(forWritingTo: logURL)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        var continuation: AsyncStream<TaskEvent>.Continuation!
        let stream = AsyncStream<TaskEvent> { streamContinuation in
            continuation = streamContinuation
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        if let currentDirectory {
            process.currentDirectoryURL = currentDirectory
        }
        if !environment.isEmpty {
            var env = ProcessInfo.processInfo.environment
            environment.forEach { env[$0.key] = $0.value }
            process.environment = env
        }

        var stdoutBuffer = Data()
        var stderrBuffer = Data()

        func handleLines(_ data: Data, isError: Bool) {
            guard !data.isEmpty else { return }
            logHandle.write(data)
            let output = String(data: data, encoding: .utf8) ?? ""
            let timestamp = Date()
            continuation.yield(.output(TaskOutput(id: UUID(), line: output, isError: isError, timestamp: timestamp)))
        }

        func drainBuffer(_ buffer: inout Data, isError: Bool) {
            let delimiter = Data([0x0A])
            while let range = buffer.range(of: delimiter) {
                let lineData = buffer.subdata(in: 0..<range.lowerBound)
                buffer.removeSubrange(0...range.lowerBound)
                handleLines(lineData, isError: isError)
            }
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            Task { @MainActor in
                stdoutBuffer.append(data)
                drainBuffer(&stdoutBuffer, isError: false)
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            Task { @MainActor in
                stderrBuffer.append(data)
                drainBuffer(&stderrBuffer, isError: true)
            }
        }

        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                if !stdoutBuffer.isEmpty {
                    handleLines(stdoutBuffer, isError: false)
                }
                if !stderrBuffer.isEmpty {
                    handleLines(stderrBuffer, isError: true)
                }
                try? logHandle.close()
                self?.running.removeValue(forKey: taskID)
                continuation.yield(.finished(process.terminationStatus))
                continuation.finish()
            }
        }

        do {
            try process.run()
            let runningTask = RunningTask(process: process, logURL: logURL, logHandle: logHandle)
            running[taskID] = runningTask
        } catch {
            try? logHandle.close()
            continuation.finish()
            throw error
        }

        return TaskHandle(id: taskID, title: title, stream: stream)
    }

    func terminate(taskID: String) async {
        guard let task = running[taskID] else { return }
        task.process.terminate()
        try? await Task.sleep(for: .seconds(2))
        if task.process.isRunning {
            kill(task.process.processIdentifier, SIGKILL)
        }
    }
}
