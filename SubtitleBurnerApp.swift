import AppKit
import Foundation

struct Paths {
    let root: URL
    let mp4: URL
    let wav: URL
    let zhSRT: URL
    let enSRT: URL
    let ass: URL
    let burned: URL
}

struct Cue {
    let start: String
    let end: String
    let text: String
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let appBinDir: String
    let sourceField = NSTextField()
    let outputField = NSTextField()
    let englishField = NSTextField()
    let chineseField = NSTextField()
    let ffmpegField = NSTextField()
    let ffprobeField = NSTextField()
    let whisperField = NSTextField()
    let apiKeyField = NSSecureTextField()
    let translateModelField = NSTextField()
    let modelPopup = NSPopUpButton()
    let providerPopup = NSPopUpButton()
    let logView = NSTextView()
    var running = false

    override init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        appBinDir = support.appendingPathComponent("SubtitleBurner/bin", isDirectory: true).path
        super.init()
        prepareAppBin()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildUI()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func buildUI() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Subtitle Burner"
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

        sourceField.stringValue = ""
        outputField.stringValue = "\(NSHomeDirectory())/Downloads"
        englishField.stringValue = ""
        chineseField.stringValue = ""
        ffmpegField.stringValue = findTool("ffmpeg")
        ffprobeField.stringValue = findTool("ffprobe")
        whisperField.stringValue = findTool("whisper")
        apiKeyField.stringValue = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        translateModelField.stringValue = "gpt-4.1-mini"

        root.addArrangedSubview(row("Source .mov/.mp4", sourceField, "Choose", #selector(chooseSource)))
        root.addArrangedSubview(row("Output folder", outputField, "Choose", #selector(chooseOutput)))
        root.addArrangedSubview(row("English .srt", englishField, "Choose", #selector(chooseEnglishSRT)))
        root.addArrangedSubview(row("Chinese .srt", chineseField, "Choose", #selector(chooseChineseSRT)))
        root.addArrangedSubview(separator())
        root.addArrangedSubview(row("ffmpeg", ffmpegField, "Find", #selector(chooseFFmpeg)))
        root.addArrangedSubview(row("ffprobe", ffprobeField, "Find", #selector(chooseFFprobe)))
        root.addArrangedSubview(row("whisper", whisperField, "Find", #selector(chooseWhisper)))
        root.addArrangedSubview(providerRow())
        root.addArrangedSubview(row("Translate API key", apiKeyField, "Paste", #selector(pasteAPIKey)))
        root.addArrangedSubview(row("Translate model", translateModelField, "Default", #selector(defaultTranslateModel)))

        let modelRow = NSStackView()
        modelRow.orientation = .horizontal
        modelRow.spacing = 8
        let modelLabel = label("Whisper model")
        modelPopup.addItems(withTitles: ["turbo", "small", "medium", "large-v3"])
        modelRow.addArrangedSubview(modelLabel)
        modelRow.addArrangedSubview(modelPopup)
        modelRow.addArrangedSubview(NSView())
        modelLabel.widthAnchor.constraint(equalToConstant: 130).isActive = true
        root.addArrangedSubview(modelRow)

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 10
        buttons.addArrangedSubview(button("Check Dependencies", #selector(checkDependencies)))
        buttons.addArrangedSubview(button("English SRT", #selector(runEnglishSRT)))
        buttons.addArrangedSubview(button("Translate EN to ZH", #selector(translateENToZH)))
        buttons.addArrangedSubview(button("Merge ASS + Burn", #selector(mergeAndBurn)))
        buttons.addArrangedSubview(button("Run All", #selector(runAll)))
        buttons.addArrangedSubview(NSView())
        root.addArrangedSubview(buttons)

        let note = NSTextField(labelWithString: "Flow: generate English SRT, translate it to Chinese SRT with OpenAI, DeepSeek, or Kimi 2.5, then burn Chinese top + English bottom.")
        note.font = .systemFont(ofSize: 12)
        root.addArrangedSubview(note)

        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.documentView = logView
        root.addArrangedSubview(scroll)
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 320).isActive = true

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

    func providerRow() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8
        let titleLabel = label("Translate mode")
        providerPopup.addItems(withTitles: ["OpenAI", "DeepSeek", "Kimi 2.5", "Google Gemini"])
        providerPopup.target = self
        providerPopup.action = #selector(providerChanged)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(providerPopup)
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

    @objc func chooseSource() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["mov", "mp4", "m4v"]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            sourceField.stringValue = url.path
            if outputField.stringValue.isEmpty {
                outputField.stringValue = url.deletingLastPathComponent().path
            }
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

    @objc func chooseEnglishSRT() { chooseFile(into: englishField, types: ["srt"]) }
    @objc func chooseChineseSRT() { chooseFile(into: chineseField, types: ["srt"]) }
    @objc func chooseFFmpeg() { chooseFile(into: ffmpegField, types: nil) }
    @objc func chooseFFprobe() { chooseFile(into: ffprobeField, types: nil) }
    @objc func chooseWhisper() { chooseFile(into: whisperField, types: nil) }
    @objc func pasteAPIKey() { apiKeyField.stringValue = NSPasteboard.general.string(forType: .string) ?? apiKeyField.stringValue }
    @objc func defaultTranslateModel() { translateModelField.stringValue = defaultModel(for: selectedProvider()) }
    @objc func providerChanged() {
        translateModelField.stringValue = defaultModel(for: selectedProvider())
        switch selectedProvider() {
        case "OpenAI":
            apiKeyField.stringValue = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? apiKeyField.stringValue
        case "DeepSeek":
            apiKeyField.stringValue = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? ""
        case "Kimi 2.5":
            apiKeyField.stringValue = ProcessInfo.processInfo.environment["MOONSHOT_API_KEY"] ?? ""
        case "Google Gemini":
            apiKeyField.stringValue = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
        default:
            break
        }
    }

    func chooseFile(into field: NSTextField, types: [String]?) {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = types
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            field.stringValue = url.path
        }
    }

    @objc func checkDependencies() {
        start {
            self.log("Checking dependencies...")
            for (name, path) in [
                ("ffmpeg", self.text(self.ffmpegField)),
                ("ffprobe", self.text(self.ffprobeField)),
                ("whisper", self.text(self.whisperField)),
                ("STHeiti Medium.ttc", "/System/Library/Fonts/STHeiti Medium.ttc")
            ] {
                self.log("\(name): \(FileManager.default.fileExists(atPath: path) ? "OK" : "Missing") \(path)")
            }
            let ffmpeg = self.text(self.ffmpegField)
            if FileManager.default.fileExists(atPath: ffmpeg) {
                let output = try self.capture([ffmpeg, "-hide_banner", "-filters"])
                self.log("ffmpeg libass filter: \(output.contains(" ass ") ? "OK" : "Missing")")
            }
        }
    }

    @objc func runEnglishSRT() {
        start { try self.generateEnglishSRT() }
    }

    @objc func translateENToZH() {
        start { try self.translateEnglishToChinese() }
    }

    @objc func mergeAndBurn() {
        start { try self.mergeBurn() }
    }

    @objc func runAll() {
        start {
            try self.generateEnglishSRT()
            try self.translateEnglishToChinese()
            try self.mergeBurn()
        }
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

    func generateEnglishSRT() throws {
        let source = try requireSource()
        let ffmpeg = try requireTool(text(ffmpegField), "ffmpeg")
        let whisper = try requireTool(text(whisperField), "whisper")
        let paths = makePaths(source)
        try FileManager.default.createDirectory(at: paths.root, withIntermediateDirectories: true)

        try run([ffmpeg, "-y", "-i", source.path, "-c:v", "libx264", "-preset", "fast", "-crf", "22", "-c:a", "aac", "-b:a", "160k", paths.mp4.path])
        try run([ffmpeg, "-y", "-i", paths.mp4.path, "-vn", "-acodec", "pcm_s16le", "-ar", "16000", paths.wav.path])
        try run([whisper, paths.wav.path, "--model", selectedModel(), "--language", "en", "--task", "transcribe", "--output_format", "srt", "--output_dir", paths.root.path])
        let whisperSRT = paths.root.appendingPathComponent("\(paths.wav.deletingPathExtension().lastPathComponent).srt")
        guard FileManager.default.fileExists(atPath: whisperSRT.path) else {
            throw message("Whisper finished but did not create the expected SRT: \(whisperSRT.path)")
        }
        if whisperSRT.path != paths.enSRT.path {
            if FileManager.default.fileExists(atPath: paths.enSRT.path) {
                try FileManager.default.removeItem(at: paths.enSRT)
            }
            try FileManager.default.moveItem(at: whisperSRT, to: paths.enSRT)
        }
        setText(englishField, paths.enSRT.path)
        log("English SRT: \(paths.enSRT.path)")
        log("Suggested Chinese SRT path: \(paths.zhSRT.path)")
    }

    func translateEnglishToChinese() throws {
        let source = try requireSource()
        let paths = makePaths(source)
        let english = text(englishField)
        let enPath = URL(fileURLWithPath: english.isEmpty ? paths.enSRT.path : english)
        guard FileManager.default.fileExists(atPath: enPath.path) else {
            throw message("English SRT not found. Generate it first or choose one: \(enPath.path)")
        }
        let apiKey = text(apiKeyField).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw message("Enter a \(selectedProvider()) API key to auto-translate, or choose an existing Chinese SRT manually.")
        }
        log("Translating English SRT to Chinese with \(selectedProvider())...")
        let translated = try translateSRT(enPath, apiKey: apiKey, provider: selectedProvider(), model: translateModel())
        try translated.write(to: paths.zhSRT, atomically: true, encoding: .utf8)
        setText(chineseField, paths.zhSRT.path)
        log("Chinese SRT: \(paths.zhSRT.path)")
    }

    func mergeBurn() throws {
        let source = try requireSource()
        let ffmpeg = try requireTool(text(ffmpegField), "ffmpeg")
        let paths = makePaths(source)
        let english = text(englishField)
        let enPath = english.isEmpty ? paths.enSRT.path : english
        let chinese = text(chineseField)
        let zhPath = chinese.isEmpty ? paths.zhSRT.path : chinese
        guard FileManager.default.fileExists(atPath: paths.mp4.path) else { throw message("MP4 not found. Run Steps 1-3 first: \(paths.mp4.path)") }
        guard FileManager.default.fileExists(atPath: zhPath) else { throw message("Chinese SRT not found. Translate first or choose one: \(zhPath)") }
        guard FileManager.default.fileExists(atPath: enPath) else { throw message("English SRT not found. Generate it first or choose one: \(enPath)") }
        guard FileManager.default.fileExists(atPath: "/System/Library/Fonts/STHeiti Medium.ttc") else { throw message("Required font not found: /System/Library/Fonts/STHeiti Medium.ttc") }

        let size = videoSize(paths.mp4)
        log("Video resolution for ASS PlayRes: \(Int(size.width))x\(Int(size.height))")
        try writeASS(zh: URL(fileURLWithPath: zhPath), en: URL(fileURLWithPath: enPath), out: paths.ass, width: Int(size.width), height: Int(size.height))
        log("ASS subtitles: \(paths.ass.path)")
        let filter = "ass='\(filterEscape(paths.ass.path))':fontsdir='/System/Library/Fonts'"
        try run([ffmpeg, "-y", "-i", paths.mp4.path, "-vf", filter, "-c:v", "libx264", "-preset", "fast", "-crf", "22", "-c:a", "aac", "-b:a", "160k", paths.burned.path])
        log("Burned video: \(paths.burned.path)")
    }

    func requireSource() throws -> URL {
        let path = text(sourceField).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { throw message("Choose a source video first.") }
        let outputText = text(outputField)
        let output = outputText.isEmpty ? URL(fileURLWithPath: path).deletingLastPathComponent().path : outputText
        try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
        return URL(fileURLWithPath: path)
    }

    func requireTool(_ path: String, _ name: String) throws -> String {
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { throw message("\(name) was not found. Install it, then set its path.") }
        return path
    }

    func makePaths(_ source: URL) -> Paths {
        let outputText = text(outputField)
        let output = URL(fileURLWithPath: outputText.isEmpty ? source.deletingLastPathComponent().path : outputText)
        let stem = source.deletingPathExtension().lastPathComponent
        let root = output.appendingPathComponent("\(stem)_subtitle_work", isDirectory: true)
        return Paths(
            root: root,
            mp4: root.appendingPathComponent("\(stem).mp4"),
            wav: root.appendingPathComponent("\(stem).wav"),
            zhSRT: root.appendingPathComponent("\(stem).zh.srt"),
            enSRT: root.appendingPathComponent("\(stem).en.srt"),
            ass: root.appendingPathComponent("\(stem).zh_en.ass"),
            burned: root.appendingPathComponent("\(stem)_with_subtitles.mp4")
        )
    }

    func run(_ args: [String]) throws {
        log("$ \(args.joined(separator: " "))")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: args[0])
        process.arguments = Array(args.dropFirst())
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "\(appBinDir):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + (env["PATH"] ?? "")
        process.environment = env
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { h in
            let data = h.availableData
            if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                text.split(whereSeparator: \.isNewline).forEach { self.log(String($0)) }
            }
        }
        process.waitUntilExit()
        handle.readabilityHandler = nil
        if process.terminationStatus != 0 {
            throw message("Command failed with exit code \(process.terminationStatus): \(args[0])")
        }
    }

    func capture(_ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: args[0])
        process.arguments = Array(args.dropFirst())
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    func videoSize(_ url: URL) -> CGSize {
        let ffprobe = text(ffprobeField)
        guard FileManager.default.fileExists(atPath: ffprobe) else { return CGSize(width: 1920, height: 1080) }
        do {
            let json = try capture([ffprobe, "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height", "-of", "json", url.path])
            let data = Data(json.utf8)
            if let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let streams = object["streams"] as? [[String: Any]],
               let first = streams.first,
               let width = first["width"] as? Int,
               let height = first["height"] as? Int {
                return CGSize(width: width, height: height)
            }
        } catch {
            log("Could not read video size with ffprobe; using 1920x1080.")
        }
        return CGSize(width: 1920, height: 1080)
    }

    func translateSRT(_ url: URL, apiKey: String, provider: String, model: String) throws -> String {
        let cues = try parseSRT(url)
        guard !cues.isEmpty else { throw message("English SRT has no cues.") }
        var translated = Array(repeating: "", count: cues.count)
        try translateCueRange(cues, start: 0, end: cues.count, maxChunkSize: 24, translated: &translated, apiKey: apiKey, provider: provider, model: model)

        var lines: [String] = []
        for (index, cue) in cues.enumerated() {
            lines.append("\(index + 1)")
            lines.append("\(cue.start) --> \(cue.end)")
            lines.append(translated[index])
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    func translateCueRange(_ cues: [Cue], start: Int, end: Int, maxChunkSize: Int, translated: inout [String], apiKey: String, provider: String, model: String) throws {
        var cursor = start
        while cursor < end {
            let chunkEnd = min(cursor + maxChunkSize, end)
            do {
                let result = try translateCueChunk(cues, start: cursor, end: chunkEnd, apiKey: apiKey, provider: provider, model: model)
                for index in cursor..<chunkEnd {
                    guard let text = result[index + 1], !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw message("Translation missing cue \(index + 1).")
                    }
                    translated[index] = text
                }
                cursor = chunkEnd
            } catch {
                let count = chunkEnd - cursor
                if count == 1 {
                    throw error
                }
                let smaller = max(1, count / 2)
                log("Retrying cues \(cursor + 1)-\(chunkEnd) in smaller batches because: \(error.localizedDescription)")
                try translateCueRange(cues, start: cursor, end: chunkEnd, maxChunkSize: smaller, translated: &translated, apiKey: apiKey, provider: provider, model: model)
                cursor = chunkEnd
            }
        }
    }

    func translateCueChunk(_ cues: [Cue], start: Int, end: Int, apiKey: String, provider: String, model: String) throws -> [Int: String] {
        let items = cues[start..<end].enumerated().map { offset, cue -> [String: Any] in
            [
                "id": start + offset + 1,
                "text": cue.text
            ]
        }
        let inputData = try JSONSerialization.data(withJSONObject: items)
        let inputJSON = String(data: inputData, encoding: .utf8) ?? "[]"
        let prompt = """
        Translate the `text` field of each object in this JSON array from English into Traditional Chinese.
        Keep subtitles natural and concise for burned-in video.
        Preserve every `id` exactly.
        Do not merge, omit, renumber, reorder, or add items.
        Return only a valid JSON array of objects shaped exactly like:
        [{"id": 1, "text": "翻譯"}]
        No Markdown.

        \(inputJSON)
        """
        log("Translating cues \(start + 1)-\(end) of \(cues.count)...")
        let output: String
        if provider == "OpenAI" {
            output = try callOpenAIResponses(input: prompt, apiKey: apiKey, model: model)
        } else if provider == "Google Gemini" {
            output = try callGemini(input: prompt, apiKey: apiKey, model: model)
        } else {
            output = try callChatCompletions(input: prompt, apiKey: apiKey, provider: provider, model: model)
        }
        let objects = try parseJSONObjects(output)
        var result: [Int: String] = [:]
        for object in objects {
            guard let id = object["id"] as? Int,
                  let text = object["text"] as? String else {
                throw message("Translation item is missing id/text: \(object)")
            }
            result[id] = text
        }
        let expected = Set((start + 1)...end)
        let actual = Set(result.keys)
        guard actual == expected else {
            let missing = expected.subtracting(actual).sorted()
            let extra = actual.subtracting(expected).sorted()
            throw message("Translation id mismatch. Missing: \(missing), extra: \(extra).")
        }
        return result
    }

    func callOpenAIResponses(input: String, apiKey: String, model: String) throws -> String {
        let body: [String: Any] = [
            "model": model,
            "instructions": "You are a professional subtitle translator. Return only the requested machine-readable output.",
            "input": input
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = data

        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var response: URLResponse?
        var responseError: Error?
        URLSession.shared.dataTask(with: request) { data, urlResponse, error in
            responseData = data
            response = urlResponse
            responseError = error
            semaphore.signal()
        }.resume()
        semaphore.wait()

        if let responseError {
            throw responseError
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let detail = responseData.flatMap { String(data: $0, encoding: .utf8) } ?? "No response body."
            throw message("OpenAI API returned HTTP \(http.statusCode): \(detail)")
        }
        guard let responseData else {
            throw message("OpenAI API returned no data.")
        }
        let object = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
        if let outputText = object?["output_text"] as? String {
            return outputText
        }
        if let output = object?["output"] as? [[String: Any]] {
            var parts: [String] = []
            for item in output {
                if let content = item["content"] as? [[String: Any]] {
                    for entry in content {
                        if let text = entry["text"] as? String {
                            parts.append(text)
                        }
                    }
                }
            }
            if !parts.isEmpty {
                return parts.joined(separator: "\n")
            }
        }
        let raw = String(data: responseData, encoding: .utf8) ?? ""
        throw message("Could not read text from OpenAI response: \(raw)")
    }

    func callChatCompletions(input: String, apiKey: String, provider: String, model: String) throws -> String {
        let baseURL: String
        switch provider {
        case "DeepSeek":
            baseURL = "https://api.deepseek.com"
        case "Kimi 2.5":
            baseURL = "https://api.moonshot.ai/v1"
        default:
            throw message("Unsupported translation provider: \(provider)")
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "system",
                    "content": "You are a professional subtitle translator. Return only the requested machine-readable output."
                ],
                [
                    "role": "user",
                    "content": input
                ]
            ],
            "temperature": 0.2
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = data

        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var response: URLResponse?
        var responseError: Error?
        URLSession.shared.dataTask(with: request) { data, urlResponse, error in
            responseData = data
            response = urlResponse
            responseError = error
            semaphore.signal()
        }.resume()
        semaphore.wait()

        if let responseError {
            throw responseError
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let detail = responseData.flatMap { String(data: $0, encoding: .utf8) } ?? "No response body."
            throw message("\(provider) API returned HTTP \(http.statusCode): \(detail)")
        }
        guard let responseData else {
            throw message("\(provider) API returned no data.")
        }
        guard let object = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            let raw = String(data: responseData, encoding: .utf8) ?? ""
            throw message("Could not read text from \(provider) response: \(raw)")
        }
        return content
    }

    func callGemini(input: String, apiKey: String, model: String) throws -> String {
        let escapedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(escapedModel):generateContent")!
        let body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        [
                            "text": """
                            You are a professional subtitle translator. Return only the requested machine-readable output.

                            \(input)
                            """
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2,
                "thinkingConfig": [
                    "thinkingBudget": 0
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = data

        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var response: URLResponse?
        var responseError: Error?
        URLSession.shared.dataTask(with: request) { data, urlResponse, error in
            responseData = data
            response = urlResponse
            responseError = error
            semaphore.signal()
        }.resume()
        semaphore.wait()

        if let responseError {
            throw responseError
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let detail = responseData.flatMap { String(data: $0, encoding: .utf8) } ?? "No response body."
            throw message("Google Gemini API returned HTTP \(http.statusCode): \(detail)")
        }
        guard let responseData else {
            throw message("Google Gemini API returned no data.")
        }
        guard let object = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let candidates = object["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            let raw = String(data: responseData, encoding: .utf8) ?? ""
            throw message("Could not read text from Google Gemini response: \(raw)")
        }
        let text = parts.compactMap { $0["text"] as? String }.joined(separator: "\n")
        guard !text.isEmpty else {
            let raw = String(data: responseData, encoding: .utf8) ?? ""
            throw message("Google Gemini returned an empty text response: \(raw)")
        }
        return text
    }

    func parseJSONStringArray(_ value: String) throws -> [String] {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text.replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = text.data(using: .utf8),
              let array = try JSONSerialization.jsonObject(with: data) as? [String] else {
            throw message("Translation was not a JSON string array: \(value)")
        }
        return array
    }

    func parseJSONObjects(_ value: String) throws -> [[String: Any]] {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text.replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = text.data(using: .utf8),
              let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw message("Translation was not a JSON object array: \(value)")
        }
        return array
    }

    func writeASS(zh: URL, en: URL, out: URL, width: Int, height: Int) throws {
        let zhCues = try parseSRT(zh)
        let enCues = try parseSRT(en)
        guard !zhCues.isEmpty else { throw message("Chinese SRT has no cues.") }
        if zhCues.count != enCues.count {
            log("Warning: Chinese cues=\(zhCues.count), English cues=\(enCues.count). Matching by cue order.")
        }
        let fontSize = max(32, Int(Double(height) * 0.047))
        let marginV = max(55, Int(Double(height) * 0.075))
        let outline = max(2, Int(Double(height) * 0.0025))
        var lines = [
            "[Script Info]",
            "ScriptType: v4.00+",
            "PlayResX: \(width)",
            "PlayResY: \(height)",
            "ScaledBorderAndShadow: yes",
            "",
            "[V4+ Styles]",
            "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding",
            "Style: Default,Heiti SC,\(fontSize),&H00FFFFFF,&H000000FF,&H00000000,&H99000000,0,0,0,0,100,100,0,0,1,\(outline),1,2,80,80,\(marginV),1",
            "",
            "[Events]",
            "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text"
        ]
        for index in zhCues.indices {
            let zhCue = zhCues[index]
            let enText = index < enCues.count ? enCues[index].text : ""
            let body = "\(assEscape(zhCue.text))\\N\\N\(assEscape(enText))"
            lines.append("Dialogue: 0,\(srtTimeToAss(zhCue.start)),\(srtTimeToAss(zhCue.end)),Default,,0,0,0,,\(body)")
        }
        try lines.joined(separator: "\n").appending("\n").write(to: out, atomically: true, encoding: .utf8)
    }

    func parseSRT(_ url: URL) throws -> [Cue] {
        let raw = try String(contentsOf: url, encoding: .utf8)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return [] }
        return raw.components(separatedBy: "\n\n").compactMap { block in
            let lines = block.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            guard lines.count >= 2 else { return nil }
            let timingIndex = lines[0].contains("-->") ? 0 : 1
            guard lines.indices.contains(timingIndex), lines[timingIndex].contains("-->") else { return nil }
            let timing = lines[timingIndex].components(separatedBy: "-->")
            let text = lines.dropFirst(timingIndex + 1).joined(separator: "\n")
            return Cue(start: timing[0].trimmingCharacters(in: .whitespaces).components(separatedBy: " ")[0],
                       end: timing[1].trimmingCharacters(in: .whitespaces).components(separatedBy: " ")[0],
                       text: text)
        }
    }

    func srtTimeToAss(_ value: String) -> String {
        let parts = value.replacingOccurrences(of: ",", with: ".").components(separatedBy: ".")
        let hms = parts[0].split(separator: ":").map(String.init)
        let centis = String((parts.count > 1 ? parts[1] : "00").prefix(2))
        return "\(Int(hms[0]) ?? 0):\(hms[1]):\(hms[2]).\(centis)"
    }

    func assEscape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "{", with: "\\{")
            .replacingOccurrences(of: "}", with: "\\}")
            .replacingOccurrences(of: "\n", with: "\\N")
    }

    func filterEscape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ":", with: "\\:")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: ",", with: "\\,")
    }

    func findTool(_ name: String) -> String {
        for dir in [appBinDir, "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"] {
            let path = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return ""
    }

    func prepareAppBin() {
        do {
            try FileManager.default.createDirectory(atPath: appBinDir, withIntermediateDirectories: true)
            for name in ["ffmpeg", "ffprobe", "whisper"] {
                let link = "\(appBinDir)/\(name)"
                if FileManager.default.fileExists(atPath: link) {
                    continue
                }
                for dir in ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"] {
                    let target = "\(dir)/\(name)"
                    if FileManager.default.isExecutableFile(atPath: target) {
                        try? FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: target)
                        break
                    }
                }
            }
        } catch {
            NSLog("Could not prepare app bin directory: \(error.localizedDescription)")
        }
    }

    func log(_ value: String) {
        DispatchQueue.main.async {
            self.logView.textStorage?.append(NSAttributedString(string: value + "\n"))
            self.logView.scrollToEndOfDocument(nil)
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

    func setText(_ field: NSTextField, _ value: String) {
        if Thread.isMainThread {
            field.stringValue = value
        } else {
            DispatchQueue.main.sync {
                field.stringValue = value
            }
        }
    }

    func selectedModel() -> String {
        if Thread.isMainThread {
            return modelPopup.titleOfSelectedItem ?? "turbo"
        }
        return DispatchQueue.main.sync {
            self.modelPopup.titleOfSelectedItem ?? "turbo"
        }
    }

    func selectedProvider() -> String {
        if Thread.isMainThread {
            return providerPopup.titleOfSelectedItem ?? "OpenAI"
        }
        return DispatchQueue.main.sync {
            self.providerPopup.titleOfSelectedItem ?? "OpenAI"
        }
    }

    func translateModel() -> String {
        let value = text(translateModelField).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? defaultModel(for: selectedProvider()) : value
    }

    func defaultModel(for provider: String) -> String {
        switch provider {
        case "DeepSeek":
            return "deepseek-v4-flash"
        case "Kimi 2.5":
            return "kimi-k2.5"
        case "Google Gemini":
            return "gemini-2.5-flash"
        default:
            return "gpt-4.1-mini"
        }
    }

    func alert(_ value: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Subtitle Burner"
            alert.informativeText = value
            alert.runModal()
        }
    }

    func message(_ value: String) -> NSError {
        NSError(domain: "SubtitleBurner", code: 1, userInfo: [NSLocalizedDescriptionKey: value])
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
