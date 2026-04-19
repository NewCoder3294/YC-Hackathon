import Foundation
import Observation
import ZIPFoundation
import os

private let log = Logger(subsystem: "com.broadcastbrain.mac", category: "model-installer")

/// Downloads a Cactus-ready model bundle (config.json + weights/<model>-<precision>.zip)
/// from `huggingface.co/Cactus-Compute` on first launch, extracts it into a
/// directory, and hands that directory to `RealCactusService`.
///
/// Cactus on Apple expects a *directory* containing `config.json` plus the
/// unzipped weight files — it does not accept a standalone GGUF.
@MainActor
@Observable
final class ModelInstaller: NSObject, URLSessionDownloadDelegate {
    enum State: Equatable {
        case notStarted
        case preparing
        case downloading(received: Int64, total: Int64)
        case extracting
        case installed
        case failed(String)
    }

    var state: State = .notStarted

    let modelName: String
    let precision: String

    /// Directory passed to `cactusInit(...)`. Contains `config.json` and the
    /// unzipped weight files.
    let modelDir: URL

    private var session: URLSession!
    private var task: URLSessionDownloadTask?
    private var downloadContinuation: CheckedContinuation<URL, Error>?

    override init() {
        let env = ProcessInfo.processInfo.environment
        self.modelName = env["BROADCASTBRAIN_MODEL_NAME"] ?? "gemma-3-1b-it"
        self.precision = env["BROADCASTBRAIN_MODEL_PRECISION"] ?? "int4"

        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.modelDir = appSupport
            .appendingPathComponent("BroadcastBrain/models/\(self.modelName)")

        super.init()

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    private var configURL: URL {
        URL(string: "https://huggingface.co/Cactus-Compute/\(modelName)/resolve/main/config.json")!
    }

    private var weightsURL: URL {
        URL(string: "https://huggingface.co/Cactus-Compute/\(modelName)/resolve/main/weights/\(modelName)-\(precision).zip")!
    }

    /// Kick off install. Idempotent — noop if already running or installed.
    func install() {
        switch state {
        case .preparing, .downloading, .extracting, .installed:
            return
        default:
            break
        }

        if isAlreadyInstalled() {
            log.info("model already installed at \(self.modelDir.path, privacy: .public)")
            state = .installed
            return
        }

        state = .preparing
        Task { [weak self] in
            guard let self else { return }
            await self.performInstall()
        }
    }

    func retry() {
        task?.cancel()
        task = nil
        downloadContinuation = nil
        state = .notStarted
        install()
    }

    private func performInstall() async {
        do {
            try FileManager.default.createDirectory(
                at: modelDir,
                withIntermediateDirectories: true
            )

            // 1. config.json (tiny)
            log.info("downloading config.json from \(self.configURL.absoluteString, privacy: .public)")
            let (configData, configResponse) = try await URLSession.shared.data(from: configURL)
            try Self.validateHTTP(configResponse, label: "config.json")
            try configData.write(
                to: modelDir.appendingPathComponent("config.json"),
                options: .atomic
            )

            // 2. weights zip (big, with progress)
            log.info("downloading weights from \(self.weightsURL.absoluteString, privacy: .public)")
            state = .downloading(received: 0, total: 0)
            let zipLocalURL = try await downloadWeightsWithProgress()

            // 3. unzip into modelDir
            log.info("extracting \(zipLocalURL.lastPathComponent, privacy: .public) → \(self.modelDir.path, privacy: .public)")
            state = .extracting
            try FileManager.default.unzipItem(at: zipLocalURL, to: modelDir)
            flattenIfSingleSubdir()

            // 4. clean up the tmp zip
            try? FileManager.default.removeItem(at: zipLocalURL)

            log.info("install complete")
            state = .installed
        } catch {
            log.error("install failed: \(error.localizedDescription, privacy: .public)")
            state = .failed(error.localizedDescription)
        }
    }

    /// If the zip produced a single top-level subdirectory (e.g. `gemma-3-1b-it-int4/…`),
    /// move its contents up into `modelDir` so Cactus can find `config.json`
    /// and the weights side-by-side at the expected path.
    private func flattenIfSingleSubdir() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: modelDir.path) else { return }
        // Ignore the config.json we wrote in step 1.
        let nonConfig = entries.filter { $0 != "config.json" }
        guard nonConfig.count == 1 else { return }
        let child = modelDir.appendingPathComponent(nonConfig[0])
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: child.path, isDirectory: &isDir), isDir.boolValue else { return }

        if let grandchildren = try? fm.contentsOfDirectory(atPath: child.path) {
            for name in grandchildren {
                let src = child.appendingPathComponent(name)
                let dst = modelDir.appendingPathComponent(name)
                try? fm.moveItem(at: src, to: dst)
            }
            try? fm.removeItem(at: child)
        }
    }

    private func downloadWeightsWithProgress() async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            self.downloadContinuation = cont
            self.task = self.session.downloadTask(with: weightsURL)
            self.task?.resume()
        }
    }

    private func isAlreadyInstalled() -> Bool {
        let fm = FileManager.default
        let configPath = modelDir.appendingPathComponent("config.json")
        guard fm.fileExists(atPath: configPath.path) else { return false }
        guard let entries = try? fm.contentsOfDirectory(atPath: modelDir.path) else { return false }
        // Need more than just config.json — weights must be extracted too.
        return entries.count > 1
    }

    private static func validateHTTP(_ response: URLResponse, label: String) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw NSError(
                domain: "ModelInstaller",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode) fetching \(label)"]
            )
        }
    }

    // MARK: - URLSessionDownloadDelegate

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor [weak self] in
            self?.state = .downloading(
                received: totalBytesWritten,
                total: totalBytesExpectedToWrite
            )
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // URLSession deletes the tmp file as soon as we return, so move it
        // somewhere persistent before hopping to the main actor.
        let tmpZip = FileManager.default.temporaryDirectory
            .appendingPathComponent("cactus-weights-\(UUID().uuidString).zip")
        var moveError: Error?
        do {
            if FileManager.default.fileExists(atPath: tmpZip.path) {
                try FileManager.default.removeItem(at: tmpZip)
            }
            try FileManager.default.moveItem(at: location, to: tmpZip)
        } catch {
            moveError = error
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            if let err = moveError {
                self.downloadContinuation?.resume(throwing: err)
            } else {
                self.downloadContinuation?.resume(returning: tmpZip)
            }
            self.downloadContinuation = nil
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.downloadContinuation?.resume(throwing: error)
            self.downloadContinuation = nil
        }
    }
}
