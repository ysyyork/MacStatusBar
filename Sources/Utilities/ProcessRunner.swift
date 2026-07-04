import Foundation
import os.log

// MARK: - Process Error Types

enum ProcessError: Error, LocalizedError {
    case timeout
    case executionFailed(String)
    case invalidOutput
    case processNotFound(String)

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Process execution timed out"
        case .executionFailed(let message):
            return "Process execution failed: \(message)"
        case .invalidOutput:
            return "Invalid output from process"
        case .processNotFound(let path):
            return "Process not found at path: \(path)"
        }
    }
}

// MARK: - Process Runner

/// Utility for running external processes with timeout and proper cleanup
struct ProcessRunner {
    /// Run an external process with configurable timeout
    /// - Parameters:
    ///   - executable: Path to the executable
    ///   - arguments: Arguments to pass to the executable
    ///   - timeout: Timeout in seconds (default 5 seconds)
    /// - Returns: Result with output string on success, ProcessError on failure
    static func run(
        executable: String,
        arguments: [String],
        timeout: TimeInterval = 5.0
    ) -> Result<String, ProcessError> {
        // Verify executable exists
        guard FileManager.default.fileExists(atPath: executable) else {
            AppLogger.process.error("Executable not found: \(executable)")
            return .failure(.processNotFound(executable))
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments

        let pipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = pipe
        task.standardError = errorPipe

        // Semaphore for timeout handling
        let semaphore = DispatchSemaphore(value: 0)
        var didTimeout = false
        var processOutput: String?
        var errorOutput: String?

        // Background queue for process execution
        let queue = DispatchQueue(label: "com.macstatusbar.processrunner", qos: .utility)

        queue.async {
            // Drain both pipes concurrently while the process runs. Reading only
            // after waitUntilExit() deadlocks once output exceeds the ~64KB pipe
            // buffer: the child blocks on write() while we block waiting for it
            // to exit (e.g. `ioreg -r -c IOAccelerator` emits ~68KB and hangs
            // until this class's own timeout force-kills it, every single call).
            let readGroup = DispatchGroup()
            var outputData = Data()
            var errorData = Data()

            readGroup.enter()
            DispatchQueue.global(qos: .utility).async {
                outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                readGroup.leave()
            }
            readGroup.enter()
            DispatchQueue.global(qos: .utility).async {
                errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                readGroup.leave()
            }

            do {
                try task.run()
                readGroup.wait()
                task.waitUntilExit()

                processOutput = String(data: outputData, encoding: .utf8)
                errorOutput = String(data: errorData, encoding: .utf8)

            } catch {
                AppLogger.process.error("Failed to run process \(executable): \(error.localizedDescription)")
                errorOutput = error.localizedDescription
                // Task never launched, so nothing will close the pipes' write
                // ends for us — close them so the readers above don't hang.
                pipe.fileHandleForWriting.closeFile()
                errorPipe.fileHandleForWriting.closeFile()
                readGroup.wait()
            }
            semaphore.signal()
        }

        // Wait with timeout
        let result = semaphore.wait(timeout: .now() + timeout)

        if result == .timedOut {
            didTimeout = true
            // Terminate the process if it's still running
            if task.isRunning {
                AppLogger.process.warning("Process timed out, terminating: \(executable)")
                task.terminate()

                // Give it a moment to terminate gracefully
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                    if task.isRunning {
                        // Force kill if still running (SIGKILL)
                        kill(task.processIdentifier, SIGKILL)
                    }
                }
            }
            return .failure(.timeout)
        }

        // Check exit status
        if task.terminationStatus != 0 {
            let errorMessage = errorOutput ?? "Unknown error (exit code: \(task.terminationStatus))"
            AppLogger.process.error("Process failed with exit code \(task.terminationStatus): \(executable)")
            return .failure(.executionFailed(errorMessage))
        }

        // Validate output
        guard let output = processOutput else {
            AppLogger.process.error("No output from process: \(executable)")
            return .failure(.invalidOutput)
        }

        return .success(output)
    }

    /// Run a process and return the output, logging any errors
    /// Returns nil on failure instead of throwing
    static func runOrNil(
        executable: String,
        arguments: [String],
        timeout: TimeInterval = 5.0
    ) -> String? {
        switch run(executable: executable, arguments: arguments, timeout: timeout) {
        case .success(let output):
            return output
        case .failure(let error):
            AppLogger.process.debug("Process returned nil: \(error.localizedDescription)")
            return nil
        }
    }
}
