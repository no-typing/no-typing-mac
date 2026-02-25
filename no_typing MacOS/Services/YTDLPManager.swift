import Foundation

struct YTDLPMetadata: Codable {
    let id: String?
    let title: String?
    let thumbnail: String?
    let uploader: String?
    let webpage_url: String?
}

class YTDLPManager: ObservableObject {
    static let shared = YTDLPManager()

    @Published var isDownloadingBinary = false
    @Published var binaryDownloadProgress: Double = 0.0

    private let session: URLSession

    private var executableURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directoryURL = appSupport.appendingPathComponent("No-Typing/bin", isDirectory: true)

        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        return directoryURL.appendingPathComponent("yt-dlp_macos")
    }

    private var isBinaryAvailable: Bool {
        return FileManager.default.fileExists(atPath: executableURL.path)
    }

    // MARK: - Cached JS Runtime Path
    // Computed once lazily — avoids repeated filesystem enumeration on every fetch call.
    private lazy var jsRuntimePath: String? = {
        var searchPaths: [String] = [
            "/opt/homebrew/bin/node", // Apple Silicon Homebrew
            "/usr/local/bin/node",    // Intel Homebrew or Node installer
            "/usr/bin/node"
        ]

        // Probe NVM installations
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let nvmDir = homeDir + "/.nvm/versions/node"

        if let enumerator = FileManager.default.enumerator(atPath: nvmDir) {
            for case let path as String in enumerator {
                if path.hasSuffix("/bin/node") {
                    searchPaths.append(nvmDir + "/" + path)
                    break
                }
            }
        }

        return searchPaths.first(where: { FileManager.default.fileExists(atPath: $0) })
    }()

    private init() {
        self.session = URLSession(configuration: .default)
    }

    // MARK: - Binary Management

    func ensureBinaryExists(completion: @escaping (Result<Void, Error>) -> Void) {
        if isBinaryAvailable {
            completion(.success(()))
            return
        }

        let downloadURL = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!

        DispatchQueue.main.async {
            self.isDownloadingBinary = true
            self.binaryDownloadProgress = 0.0
        }

        let task = session.downloadTask(with: downloadURL) { [weak self] tempURL, _, error in
            defer {
                DispatchQueue.main.async { self?.isDownloadingBinary = false }
            }

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let tempURL = tempURL, let self = self else {
                completion(.failure(NSError(domain: "YTDLPManager", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Download failed"])))
                return
            }

            do {
                if FileManager.default.fileExists(atPath: self.executableURL.path) {
                    try FileManager.default.removeItem(at: self.executableURL)
                }

                try FileManager.default.moveItem(at: tempURL, to: self.executableURL)

                let chmodProcess = Process()
                chmodProcess.executableURL = URL(fileURLWithPath: "/bin/chmod")
                chmodProcess.arguments = ["+x", self.executableURL.path]
                try chmodProcess.run()
                chmodProcess.waitUntilExit()

                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                completion(.failure(error))
            }
        }

        task.resume()
    }

    // MARK: - Metadata Fetching

    // MARK: - Fast Path OEmbed Resolution
    private struct OEmbedResponse: Codable {
        let title: String?
        let author_name: String?
        let thumbnail_url: String?
    }

    private struct CustomPreviewResponse: Codable {
        struct Metadata: Codable {
            let title: String?
            let description: String?
            let image: String?
            let url: String?
            let logo: String?
        }
        let success: Bool
        let metadata: Metadata?
        let cached: Bool?
    }

    private func tryFastOEmbed(urlString: String, completion: @escaping (YTDLPMetadata?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        let host = url.host?.lowercased() ?? ""
        
        // Handle custom FB/IG Preview API
        if host.contains("facebook.com") || host.contains("fb.watch") || host.contains("instagram.com") {
            guard let apiUrl = URL(string: "https://socialpreviewapi.vercel.app/preview") else {
                completion(nil)
                return
            }
            var request = URLRequest(url: apiUrl)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["url": urlString])
            
            let task = session.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    completion(nil)
                    return
                }
                
                if let preview = try? JSONDecoder().decode(CustomPreviewResponse.self, from: data),
                   preview.success,
                   let meta = preview.metadata {
                    
                    let ytdlpMetadata = YTDLPMetadata(
                        id: nil,
                        title: meta.title ?? "Media Post",
                        thumbnail: meta.image,
                        uploader: host.contains("instagram") ? "Instagram" : "Facebook",
                        webpage_url: urlString
                    )
                    completion(ytdlpMetadata)
                } else {
                    completion(nil)
                }
            }
            task.resume()
            return
        }

        // Standard OEmbed
        var oEmbedUrlString: String? = nil
        let encodedUrl = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString

        if host.contains("youtube.com") || host.contains("youtu.be") {
            oEmbedUrlString = "https://www.youtube.com/oembed?url=\(encodedUrl)&format=json"
        } else if host.contains("tiktok.com") {
            oEmbedUrlString = "https://www.tiktok.com/oembed?url=\(encodedUrl)"
        } else if host.contains("vimeo.com") {
            oEmbedUrlString = "https://vimeo.com/api/oembed.json?url=\(encodedUrl)"
        }

        guard let targetString = oEmbedUrlString, let targetUrl = URL(string: targetString) else {
            completion(nil)
            return
        }

        let task = session.dataTask(with: targetUrl) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            if let oembed = try? JSONDecoder().decode(OEmbedResponse.self, from: data) {
                let metadata = YTDLPMetadata(
                    id: nil,
                    title: oembed.title,
                    thumbnail: oembed.thumbnail_url,
                    uploader: oembed.author_name,
                    webpage_url: urlString
                )
                completion(metadata)
            } else {
                completion(nil)
            }
        }
        task.resume()
    }

    func fetchMetadata(for urlString: String, completion: @escaping (Result<YTDLPMetadata, Error>) -> Void) {
        // Fast Path: Instantly fetch title and thumbnail from lightweight APIs
        tryFastOEmbed(urlString: urlString) { [weak self] fastMetadata in
            if let metadata = fastMetadata {
                DispatchQueue.main.async {
                    completion(.success(metadata))
                }
            } else {
                // Fallback: Heavy yt-dlp execution
                self?.ensureBinaryExists { result in
                    switch result {
                    case .success:
                        self?.executeMetadataFetch(urlString: urlString, completion: completion)
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    private func executeMetadataFetch(urlString: String, completion: @escaping (Result<YTDLPMetadata, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let process = Process()
            let pipe = Pipe()

            process.executableURL = self.executableURL

            // Optimised flag set:
            //  • Single player client ("web") — trying multiple clients was the main
            //    source of latency; add "android" back only if "web" proves unreliable.
            //  • --no-cache-dir  — skip reading/writing the yt-dlp cache on disk.
            //  • --socket-timeout 10 — fail fast instead of hanging on a bad network.
            //  • Removed --match-filter "!is_live" — adds an extra network round-trip;
            //    handle live streams in the caller if needed.
            var args: [String] = [
                "--dump-json",
                "--no-playlist",
                "--flat-playlist",
                "--no-warnings",
                "--no-check-certificate",
                "--no-cache-dir",
                "--socket-timeout", "10",
                "--extractor-args", "youtube:player_client=web"
            ]

            if let jsPath = self.jsRuntimePath {
                args.append(contentsOf: ["--js-runtime", "node:\(jsPath)"])
            }

            args.append(urlString)

            process.arguments = args
            process.standardOutput = pipe
            // Suppress stderr so it doesn't mix with the JSON on stdout
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                guard process.terminationStatus == 0 else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(
                            domain: "YTDLPManager",
                            code: Int(process.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: "Failed to extract metadata from link."]
                        )))
                    }
                    return
                }

                let decoder = JSONDecoder()

                // Fast path: the output is clean JSON
                if let metadata = try? decoder.decode(YTDLPMetadata.self, from: data) {
                    DispatchQueue.main.async { completion(.success(metadata)) }
                    return
                }

                // Slow path: strip leading warnings and find the JSON object
                if let outputString = String(data: data, encoding: .utf8) {
                    for line in outputString.components(separatedBy: .newlines) {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        guard trimmed.hasPrefix("{"), trimmed.hasSuffix("}"),
                              let lineData = trimmed.data(using: .utf8),
                              let metadata = try? decoder.decode(YTDLPMetadata.self, from: lineData)
                        else { continue }

                        DispatchQueue.main.async { completion(.success(metadata)) }
                        return
                    }
                }

                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "YTDLPManager",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Could not parse metadata JSON from yt-dlp output."]
                    )))
                }

            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    // MARK: - Audio Downloading

    func downloadAudio(from urlString: String, onProgress: @escaping (Double) -> Void, completion: @escaping (Result<URL, Error>) -> Void) {
        ensureBinaryExists { [weak self] result in
            switch result {
            case .success:
                self?.executeAudioDownload(urlString: urlString, onProgress: onProgress, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func executeAudioDownload(urlString: String, onProgress: @escaping (Double) -> Void, completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let process = Process()
            let tempDir = FileManager.default.temporaryDirectory
            let outputFileUUID = UUID().uuidString
            let outputTemplate = tempDir.appendingPathComponent("\(outputFileUUID).%(ext)s").path

            process.executableURL = self.executableURL
            process.arguments = [
                "-f", "bestaudio[ext=m4a]/bestaudio[ext=mp3]/bestaudio",
                "-o", outputTemplate,
                "--no-playlist",
                "--no-warnings",
                "--no-cache-dir",
                "--socket-timeout", "15",
                urlString
            ]

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe
            
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let string = String(data: data, encoding: .utf8) else { return }
                
                // Parse lines like: [download]  49.2% of ~10.00MiB at  2.00MiB/s ETA 00:05
                if string.contains("[download]"), let range = string.range(of: #"(\d+\.\d+)%"#, options: .regularExpression) {
                    let percentStr = String(string[range].dropLast())
                    if let progress = Double(percentStr) {
                        DispatchQueue.main.async { onProgress(progress / 100.0) }
                    }
                }
            }

            do {
                try process.run()
                process.waitUntilExit()
                
                outPipe.fileHandleForReading.readabilityHandler = nil

                if process.terminationStatus == 0 {
                    let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
                    if let downloadedFile = files.first(where: { $0.lastPathComponent.hasPrefix(outputFileUUID) }) {
                        DispatchQueue.main.async { completion(.success(downloadedFile)) }
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure(NSError(
                                domain: "YTDLPManager",
                                code: 2,
                                userInfo: [NSLocalizedDescriptionKey: "Download completed but file not found."]
                            )))
                        }
                    }
                } else {
                    let errorData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown yt-dlp error"
                    DispatchQueue.main.async {
                        completion(.failure(NSError(
                            domain: "YTDLPManager",
                            code: Int(process.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: errorString]
                        )))
                    }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
}