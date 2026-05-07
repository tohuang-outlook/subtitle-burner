import AppKit
import Foundation

final class MediaDownloaderDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let urlField = NSTextField()
    let outputField = NSTextField()
    let ytdlpField = NSTextField()
    let galleryDLField = NSTextField()
    let ffmpegField = NSTextField()
    let formatPopup = NSPopUpButton()
    let downloadSizePopup = NSPopUpButton()
    let convertSizePopup = NSPopUpButton()
    let customWidthField = NSTextField()
    let igIndexesField = NSTextField()
    let cookiesPopup = NSPopUpButton()
    let logView = NSTextView()
    var running = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildUI()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func buildUI() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Media Downloader"
        window.center()

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 10
        root.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        root.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            root.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            root.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor)
        ])

        urlField.placeholderString = "Paste YouTube or Instagram URL"
        outputField.stringValue = "\(NSHomeDirectory())/Downloads"
        ytdlpField.stringValue = findTool("yt-dlp")
        galleryDLField.stringValue = findTool("gallery-dl")
        ffmpegField.stringValue = findTool("ffmpeg")
        customWidthField.placeholderString = "e.g. 1280"
        customWidthField.stringValue = ""
        igIndexesField.placeholderString = "all, 1, 1,3,5, or 2-8"
        igIndexesField.stringValue = "all"

        formatPopup.addItems(withTitles: ["Youtube MP4", "Youtube MP3", "IG video", "IG photo"])
        downloadSizePopup.addItems(withTitles: ["Best", "1080p", "720p", "480p", "360p"])
        convertSizePopup.addItems(withTitles: ["No conversion", "1080p", "720p", "480p", "360p", "Custom width"])
        cookiesPopup.addItems(withTitles: ["No browser cookies", "Safari cookies", "Chrome cookies", "Firefox cookies"])

        root.addArrangedSubview(row("URL", urlField, "Paste", #selector(pasteURL)))
        root.addArrangedSubview(row("Output folder", outputField, "Choose", #selector(chooseOutput)))
        root.addArrangedSubview(popupRow("Download as", formatPopup))
        root.addArrangedSubview(popupRow("Download size", downloadSizePopup))
        root.addArrangedSubview(popupRow("Convert MP4 to", convertSizePopup))
        root.addArrangedSubview(row("Custom width", customWidthField, "Clear", #selector(clearCustomWidth)))
        root.addArrangedSubview(row("IG indexes", igIndexesField, "List", #selector(listIGIndexes)))
        root.addArrangedSubview(popupRow("Cookies", cookiesPopup))
        root.addArrangedSubview(separator())
        root.addArrangedSubview(row("yt-dlp", ytdlpField, "Find", #selector(chooseYTDLP)))
        root.addArrangedSubview(row("gallery-dl", galleryDLField, "Find", #selector(chooseGalleryDL)))
        root.addArrangedSubview(row("ffmpeg", ffmpegField, "Find", #selector(chooseFFmpeg)))

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 10
        buttons.addArrangedSubview(button("Check Tools", #selector(checkTools)))
        buttons.addArrangedSubview(button("Download", #selector(download)))
        buttons.addArrangedSubview(NSView())
        root.addArrangedSubview(buttons)

        let note = NSTextField(labelWithString: "Use only for media you own, have permission to download, or that the platform allows you to save.")
        note.font = .systemFont(ofSize: 12)
        root.addArrangedSubview(note)

        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.documentView = logView
        root.addArrangedSubview(scroll)
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func row(_ title: String, _ field: NSTextField, _ buttonTitle: String, _ action: Selector) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8
        let titleLabel = label(title)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(field)
        stack.addArrangedSubview(button(buttonTitle, action))
        titleLabel.widthAnchor.constraint(equalToConstant: 130).isActive = true
        field.heightAnchor.constraint(equalToConstant: 26).isActive = true
        return stack
    }

    func popupRow(_ title: String, _ popup: NSPopUpButton) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8
        let titleLabel = label(title)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(popup)
        stack.addArrangedSubview(NSView())
        titleLabel.widthAnchor.constraint(equalToConstant: 130).isActive = true
        return stack
    }

    func label(_ value: String) -> NSTextField {
        let field = NSTextField(labelWithString: value)
        field.alignment = .right
        return field
    }

    func button(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    @objc func pasteURL() {
        urlField.stringValue = NSPasteboard.general.string(forType: .string) ?? urlField.stringValue
    }

    @objc func clearCustomWidth() {
        customWidthField.stringValue = ""
    }

    @objc func listIGIndexes() {
        start {
            try self.performListIGIndexes()
        }
    }

    @objc func chooseOutput() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            outputField.stringValue = url.path
        }
    }

    @objc func chooseYTDLP() { chooseFile(into: ytdlpField) }
    @objc func chooseGalleryDL() { chooseFile(into: galleryDLField) }
    @objc func chooseFFmpeg() { chooseFile(into: ffmpegField) }

    func chooseFile(into field: NSTextField) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            field.stringValue = url.path
        }
    }

    @objc func checkTools() {
        start {
            for (name, path) in [
                ("yt-dlp", self.text(self.ytdlpField)),
                ("gallery-dl", self.text(self.galleryDLField)),
                ("ffmpeg", self.text(self.ffmpegField))
            ] {
                self.log("\(name): \(FileManager.default.isExecutableFile(atPath: path) ? "OK" : "Missing") \(path)")
            }
            let ytdlp = try self.requireTool(self.text(self.ytdlpField), "yt-dlp")
            let galleryDL = try self.requireTool(self.text(self.galleryDLField), "gallery-dl")
            let ffmpeg = try self.requireTool(self.text(self.ffmpegField), "ffmpeg")
            self.log("yt-dlp version: \(try self.capture([ytdlp, "--version"]).trimmingCharacters(in: .whitespacesAndNewlines))")
            self.log("gallery-dl version: \(try self.capture([galleryDL, "--version"]).trimmingCharacters(in: .whitespacesAndNewlines))")
            let ffmpegVersion = try self.capture([ffmpeg, "-hide_banner", "-version"])
            self.log(ffmpegVersion.split(whereSeparator: \.isNewline).first.map(String.init) ?? "ffmpeg OK")
        }
    }

    @objc func download() {
        start {
            try self.performDownload()
        }
    }

    func performDownload() throws {
        let ytdlp = try requireTool(text(ytdlpField), "yt-dlp")
        let outputDir = URL(fileURLWithPath: text(outputField).isEmpty ? "\(NSHomeDirectory())/Downloads" : text(outputField))
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let sourceURL = text(urlField).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceURL.isEmpty else { throw message("Paste a YouTube or Instagram URL first.") }

        let mode = selected(formatPopup)
        if mode == "IG photo" {
            try performIGPhotoDownload(sourceURL: sourceURL, outputDir: outputDir)
            return
        }

        var args = [
            ytdlp,
            "--newline",
            "--no-mtime",
            "-P", outputDir.path,
            "-o", "%(title).180B [%(id)s].%(ext)s",
            "--print", "after_move:filepath"
        ]
        args.append(contentsOf: cookieArgs())
        args.append(contentsOf: igPlaylistArgs(for: mode))

        switch mode {
        case "Youtube MP3":
            args.append(contentsOf: ["-x", "--audio-format", "mp3", "--audio-quality", "0"])
            log("Youtube MP3 mode selected. yt-dlp will extract audio and save MP3.")
        case "Youtube MP4":
            args.append(contentsOf: ["--merge-output-format", "mp4", "-f", youtubeVideoFormat()])
            log("Youtube MP4 mode selected. yt-dlp will download video using the selected size.")
        case "IG video":
            args.append(contentsOf: ["--ignore-errors", "--merge-output-format", "mp4", "-f", instagramVideoFormat()])
            log("IG video mode selected. yt-dlp will download Instagram video/reel media as MP4 when available.")
        default:
            throw message("Choose a download mode first.")
        }
        args.append(sourceURL)

        let startedAt = Date()
        let result = try runCollecting(args)
        var downloadedFiles = findDownloadedFiles(in: result.lines)
        if downloadedFiles.isEmpty {
            downloadedFiles = recentFiles(in: outputDir, since: startedAt, mode: mode)
        }
        guard let finalFile = downloadedFiles.last else {
            throw message("Download finished, but I could not identify the output file. Check the log and output folder.")
        }
        for file in downloadedFiles {
            log("Downloaded file: \(file.path)")
        }

        if ["Youtube MP4", "IG video"].contains(mode), selected(convertSizePopup) != "No conversion" {
            let converted = try convertMP4(finalFile)
            log("Converted file: \(converted.path)")
        }
    }

    func performIGPhotoDownload(sourceURL: String, outputDir: URL) throws {
        let galleryDL = try requireTool(text(galleryDLField), "gallery-dl")
        if cookieArgs().isEmpty {
            log("IG photo mode selected without browser cookies. If IG says login required, choose cookies from a browser where you are logged in.")
        }
        let ranges = igGalleryRanges()
        let rangeText = ranges.compactMap { $0 }.joined(separator: ",")
        log("IG photo mode selected. gallery-dl will download Instagram photo media\(rangeText.isEmpty ? "" : " for index range \(rangeText)").")

        var downloadedFiles: [URL] = []
        var seen = Set<String>()
        for range in ranges {
            var args = [
                galleryDL,
                "--no-mtime",
                "-D", outputDir.path,
                "--Print", "after:{_path}"
            ]
            args.append(contentsOf: cookieArgs())
            if let range {
                args.append(contentsOf: ["--range", range])
            } else {
                args.append(contentsOf: ["--filter", "video_url is None"])
            }
            args.append(sourceURL)

            let startedAt = Date()
            let result = try runCollecting(args)
            var files = findDownloadedFiles(in: result.lines)
            if files.isEmpty {
                files = recentFiles(in: outputDir, since: startedAt, mode: "IG photo")
            }
            for file in files where !seen.contains(file.path) {
                seen.insert(file.path)
                downloadedFiles.append(file)
            }
        }

        guard !downloadedFiles.isEmpty else {
            throw message("IG photo download finished, but I could not identify a JPG/PNG output file. Check the log and output folder.")
        }
        for file in downloadedFiles {
            log("Downloaded file: \(file.path)")
        }
    }

    func performListIGIndexes() throws {
        let ytdlp = try requireTool(text(ytdlpField), "yt-dlp")
        let sourceURL = text(urlField).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceURL.isEmpty else { throw message("Paste an Instagram URL first.") }
        if !sourceURL.contains("instagram.com") {
            log("This looks like a non-Instagram URL; index listing is meant for IG carousel posts.")
        }
        if cookieArgs().isEmpty {
            log("Instagram often requires login. If this fails, choose Chrome/Safari/Firefox cookies where you are logged into IG.")
        }
        let args = [
            ytdlp,
            "--ignore-errors",
            "--flat-playlist",
            "--print",
            "%(playlist_index)s/%(playlist_count)s  %(id)s  %(title)s"
        ] + cookieArgs() + [sourceURL]
        let result = try runCollecting(args, allowFailure: true)
        let indexLines = result.lines.filter { line in
            line.range(of: #"^\d+/\d+"#, options: .regularExpression) != nil
        }
        let parsed = indexLines.compactMap(parseIndexLine)
        if let total = parsed.map(\.total).max() {
            let videoIndexes = parsed.map(\.index).sorted()
            let photoCandidates = Array(Set(1...total).subtracting(videoIndexes)).sorted()
            log("IG carousel indexes detected: \(total)")
            if !videoIndexes.isEmpty {
                log("Likely video indexes: \(joinIndexes(videoIndexes))")
            }
            if !photoCandidates.isEmpty {
                log("Likely photo indexes: \(joinIndexes(photoCandidates))")
            }
            log("Use IG indexes to download only what you want, for example: \(videoIndexes.first.map(String.init) ?? "1") or \(joinIndexes(Array(photoCandidates.prefix(3))))")
        } else {
            log("Could not detect index count from yt-dlp output. Check the log above.")
        }
    }

    func convertMP4(_ input: URL) throws -> URL {
        let ffmpeg = try requireTool(text(ffmpegField), "ffmpeg")
        let conversion = selected(convertSizePopup)
        let scale: String
        let suffix: String
        switch conversion {
        case "1080p":
            scale = "scale=-2:1080"
            suffix = "1080p"
        case "720p":
            scale = "scale=-2:720"
            suffix = "720p"
        case "480p":
            scale = "scale=-2:480"
            suffix = "480p"
        case "360p":
            scale = "scale=-2:360"
            suffix = "360p"
        case "Custom width":
            let widthText = text(customWidthField).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let width = Int(widthText), width > 0 else {
                throw message("Enter a positive custom width, for example 1280.")
            }
            scale = "scale=\(width):-2"
            suffix = "w\(width)"
        default:
            return input
        }
        let output = input.deletingPathExtension()
            .appendingPathComponentSibling("\(input.deletingPathExtension().lastPathComponent)_\(suffix).mp4")
        try run([
            ffmpeg,
            "-y",
            "-i", input.path,
            "-vf", scale,
            "-c:v", "libx264",
            "-preset", "fast",
            "-crf", "22",
            "-c:a", "aac",
            "-b:a", "160k",
            output.path
        ])
        return output
    }

    func youtubeVideoFormat() -> String {
        switch selected(downloadSizePopup) {
        case "1080p":
            return "bv*[height<=1080][ext=mp4]+ba[ext=m4a]/b[height<=1080][ext=mp4]/best[height<=1080]/best"
        case "720p":
            return "bv*[height<=720][ext=mp4]+ba[ext=m4a]/b[height<=720][ext=mp4]/best[height<=720]/best"
        case "480p":
            return "bv*[height<=480][ext=mp4]+ba[ext=m4a]/b[height<=480][ext=mp4]/best[height<=480]/best"
        case "360p":
            return "bv*[height<=360][ext=mp4]+ba[ext=m4a]/b[height<=360][ext=mp4]/best[height<=360]/best"
        default:
            return "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/best"
        }
    }

    func instagramVideoFormat() -> String {
        switch selected(downloadSizePopup) {
        case "1080p":
            return "best[height<=1080][ext=mp4]/best[height<=1080]/best[ext=mp4]/best"
        case "720p":
            return "best[height<=720][ext=mp4]/best[height<=720]/best[ext=mp4]/best"
        case "480p":
            return "best[height<=480][ext=mp4]/best[height<=480]/best[ext=mp4]/best"
        case "360p":
            return "best[height<=360][ext=mp4]/best[height<=360]/best[ext=mp4]/best"
        default:
            return "best[ext=mp4]/best"
        }
    }

    func cookieArgs() -> [String] {
        switch selected(cookiesPopup) {
        case "Safari cookies":
            return ["--cookies-from-browser", "safari"]
        case "Chrome cookies":
            return ["--cookies-from-browser", "chrome"]
        case "Firefox cookies":
            return ["--cookies-from-browser", "firefox"]
        default:
            return []
        }
    }

    func igPlaylistArgs(for mode: String) -> [String] {
        guard mode == "IG video" else {
            return []
        }
        if cookieArgs().isEmpty {
            log("Instagram mode selected without browser cookies. If IG says login required, choose cookies from a browser where you are logged in.")
        }
        let raw = text(igIndexesField).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, raw.lowercased() != "all" else {
            return []
        }
        return ["--playlist-items", raw]
    }

    func igGalleryRanges() -> [String?] {
        let raw = text(igIndexesField).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, raw.lowercased() != "all" else {
            return [nil]
        }
        return raw.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { Optional($0) }
    }

    func findDownloadedFiles(in lines: [String]) -> [URL] {
        var files: [URL] = []
        var seen = Set<String>()
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let candidates = pathCandidates(from: trimmed)
            for candidate in candidates where FileManager.default.fileExists(atPath: candidate) && !seen.contains(candidate) {
                seen.insert(candidate)
                files.append(URL(fileURLWithPath: candidate))
            }
        }
        return files
    }

    func pathCandidates(from line: String) -> [String] {
        var candidates: [String] = []
        if line.hasPrefix("/") {
            candidates.append(line)
        }
        for marker in [" to: ", " Destination: ", " Merging formats into "] {
            if let range = line.range(of: marker) {
                var path = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                path = path.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if path.hasPrefix("/") {
                    candidates.append(path)
                }
            }
        }
        return candidates
    }

    func recentFiles(in directory: URL, since date: Date, mode: String) -> [URL] {
        let allowedExtensions: Set<String>
        switch mode {
        case "IG photo":
            allowedExtensions = ["jpg", "jpeg", "png", "webp", "heic", "avif"]
        case "Youtube MP3":
            allowedExtensions = ["mp3", "m4a", "opus", "wav"]
        default:
            allowedExtensions = ["mp4", "m4v", "mov", "webm", "mkv"]
        }
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        let threshold = date.addingTimeInterval(-5)
        return urls.compactMap { url -> (URL, Date)? in
            guard allowedExtensions.contains(url.pathExtension.lowercased()),
                  let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = values.contentModificationDate,
                  modified >= threshold else {
                return nil
            }
            return (url, modified)
        }
        .sorted { $0.1 < $1.1 }
        .map { $0.0 }
    }

    func start(_ work: @escaping () throws -> Void) {
        if running {
            alert("A job is already running.")
            return
        }
        running = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try work()
                self.log("Done.")
            } catch {
                self.log("Error: \(error.localizedDescription)")
                self.alert(error.localizedDescription)
            }
            self.running = false
        }
    }

    func run(_ args: [String]) throws {
        let result = try runCollecting(args)
        if result.status != 0 {
            throw message("Command failed with exit code \(result.status): \(args[0])")
        }
    }

    func runCollecting(_ args: [String], allowFailure: Bool = false) throws -> (status: Int32, lines: [String]) {
        log("$ \(args.joined(separator: " "))")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: args[0])
        process.arguments = Array(args.dropFirst())
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + (env["PATH"] ?? "")
        process.environment = env
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        var lines: [String] = []
        let lock = NSLock()
        try process.run()
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { h in
            let data = h.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            let split = text.split(whereSeparator: \.isNewline).map(String.init)
            lock.lock()
            lines.append(contentsOf: split)
            lock.unlock()
            split.forEach { self.log($0) }
        }
        process.waitUntilExit()
        handle.readabilityHandler = nil
        lock.lock()
        let collected = lines
        lock.unlock()
        if process.terminationStatus != 0 && !allowFailure {
            throw message("Command failed with exit code \(process.terminationStatus): \(args[0])")
        }
        return (process.terminationStatus, collected)
    }

    func parseIndexLine(_ line: String) -> (index: Int, total: Int)? {
        let parts = line.split(separator: " ", maxSplits: 1)
        guard let first = parts.first else { return nil }
        let indexParts = first.split(separator: "/")
        guard indexParts.count == 2,
              let index = Int(indexParts[0]),
              let total = Int(indexParts[1]) else {
            return nil
        }
        return (index, total)
    }

    func joinIndexes(_ indexes: [Int]) -> String {
        indexes.map(String.init).joined(separator: ",")
    }

    func capture(_ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: args[0])
        process.arguments = Array(args.dropFirst())
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + (env["PATH"] ?? "")
        process.environment = env
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    func requireTool(_ path: String, _ name: String) throws -> String {
        guard !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) else {
            throw message("\(name) was not found. Install it, then set its path.")
        }
        return path
    }

    func findTool(_ name: String) -> String {
        for dir in ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"] {
            let path = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return ""
    }

    func selected(_ popup: NSPopUpButton) -> String {
        if Thread.isMainThread {
            return popup.titleOfSelectedItem ?? ""
        }
        return DispatchQueue.main.sync {
            popup.titleOfSelectedItem ?? ""
        }
    }

    func text(_ field: NSTextField) -> String {
        if Thread.isMainThread {
            return field.stringValue
        }
        return DispatchQueue.main.sync {
            field.stringValue
        }
    }

    func log(_ value: String) {
        DispatchQueue.main.async {
            self.logView.textStorage?.append(NSAttributedString(string: value + "\n"))
            self.logView.scrollToEndOfDocument(nil)
        }
    }

    func alert(_ value: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Media Downloader"
            alert.informativeText = value
            alert.runModal()
        }
    }

    func message(_ value: String) -> NSError {
        NSError(domain: "MediaDownloader", code: 1, userInfo: [NSLocalizedDescriptionKey: value])
    }
}

extension URL {
    func appendingPathComponentSibling(_ name: String) -> URL {
        deletingLastPathComponent().appendingPathComponent(name)
    }
}

let app = NSApplication.shared
let delegate = MediaDownloaderDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
