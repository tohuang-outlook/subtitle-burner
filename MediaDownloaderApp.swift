import AppKit
import Foundation

final class MediaDownloaderDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let urlField = NSTextField()
    let outputField = NSTextField()
    let ytdlpField = NSTextField()
    let ffmpegField = NSTextField()
    let formatPopup = NSPopUpButton()
    let downloadSizePopup = NSPopUpButton()
    let convertSizePopup = NSPopUpButton()
    let customWidthField = NSTextField()
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
        ffmpegField.stringValue = findTool("ffmpeg")
        customWidthField.placeholderString = "e.g. 1280"
        customWidthField.stringValue = ""

        formatPopup.addItems(withTitles: ["MP4 video", "MP3 audio"])
        downloadSizePopup.addItems(withTitles: ["Best", "1080p", "720p", "480p", "360p"])
        convertSizePopup.addItems(withTitles: ["No conversion", "1080p", "720p", "480p", "360p", "Custom width"])
        cookiesPopup.addItems(withTitles: ["No browser cookies", "Safari cookies", "Chrome cookies", "Firefox cookies"])

        root.addArrangedSubview(row("URL", urlField, "Paste", #selector(pasteURL)))
        root.addArrangedSubview(row("Output folder", outputField, "Choose", #selector(chooseOutput)))
        root.addArrangedSubview(popupRow("Download as", formatPopup))
        root.addArrangedSubview(popupRow("Download size", downloadSizePopup))
        root.addArrangedSubview(popupRow("Convert MP4 to", convertSizePopup))
        root.addArrangedSubview(row("Custom width", customWidthField, "Clear", #selector(clearCustomWidth)))
        root.addArrangedSubview(popupRow("Cookies", cookiesPopup))
        root.addArrangedSubview(separator())
        root.addArrangedSubview(row("yt-dlp", ytdlpField, "Find", #selector(chooseYTDLP)))
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

    @objc func chooseOutput() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            outputField.stringValue = url.path
        }
    }

    @objc func chooseYTDLP() { chooseFile(into: ytdlpField) }
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
                ("ffmpeg", self.text(self.ffmpegField))
            ] {
                self.log("\(name): \(FileManager.default.isExecutableFile(atPath: path) ? "OK" : "Missing") \(path)")
            }
            let ytdlp = try self.requireTool(self.text(self.ytdlpField), "yt-dlp")
            let ffmpeg = try self.requireTool(self.text(self.ffmpegField), "ffmpeg")
            self.log("yt-dlp version: \(try self.capture([ytdlp, "--version"]).trimmingCharacters(in: .whitespacesAndNewlines))")
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
        var args = [
            ytdlp,
            "--newline",
            "--no-mtime",
            "-P", outputDir.path,
            "-o", "%(title).200B.%(ext)s",
            "--print", "after_move:filepath"
        ]
        args.append(contentsOf: cookieArgs())

        if mode == "MP3 audio" {
            args.append(contentsOf: ["-x", "--audio-format", "mp3", "--audio-quality", "0"])
        } else {
            args.append(contentsOf: ["--merge-output-format", "mp4", "-f", videoFormat()])
        }
        args.append(sourceURL)

        let result = try runCollecting(args)
        let finalFile = findDownloadedFile(in: result.lines)
        guard let finalFile else {
            throw message("Download finished, but I could not identify the output file. Check the log and output folder.")
        }
        log("Downloaded file: \(finalFile.path)")

        if mode == "MP4 video", selected(convertSizePopup) != "No conversion" {
            let converted = try convertMP4(finalFile)
            log("Converted file: \(converted.path)")
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

    func videoFormat() -> String {
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

    func findDownloadedFile(in lines: [String]) -> URL? {
        for line in lines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("/"), FileManager.default.fileExists(atPath: trimmed) {
                return URL(fileURLWithPath: trimmed)
            }
        }
        return nil
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

    func runCollecting(_ args: [String]) throws -> (status: Int32, lines: [String]) {
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
        if process.terminationStatus != 0 {
            throw message("Command failed with exit code \(process.terminationStatus): \(args[0])")
        }
        return (process.terminationStatus, collected)
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
