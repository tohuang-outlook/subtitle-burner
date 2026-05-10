// MediaDownloaderApp.swift
// Redesigned UI: sectioned layout, progress bar, cancel button,
// URL history, UserDefaults persistence, drag-and-drop, dark mode aware.

import AppKit
import Foundation

// MARK: - UserDefaults keys

private enum Prefs {
    static let outputFolder   = "md.outputFolder"
    static let ytdlpPath      = "md.ytdlpPath"
    static let galleryDLPath  = "md.galleryDLPath"
    static let ffmpegPath     = "md.ffmpegPath"
    static let format         = "md.format"
    static let downloadSize   = "md.downloadSize"
    static let convertSize    = "md.convertSize"
    static let cookies        = "md.cookies"
    static let urlHistory     = "md.urlHistory"
}

// MARK: - AppDelegate

final class MediaDownloaderDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!

    // URL bar
    let urlCombo        = NSComboBox()
    let pasteButton     = NSButton()
    let clearButton     = NSButton()

    // Options
    let formatPopup       = NSPopUpButton()
    let downloadSizePopup = NSPopUpButton()
    let convertSizePopup  = NSPopUpButton()
    let customWidthField  = NSTextField()
    let igIndexesField    = NSTextField()
    let listButton        = NSButton()
    let cookiesPopup      = NSPopUpButton()

    // Output
    let outputField     = NSTextField()

    // Tools (collapsible section)
    var toolsDisclosure = NSButton()
    var toolsStack      = NSStackView()
    let ytdlpField      = NSTextField()
    let galleryDLField  = NSTextField()
    let ffmpegField     = NSTextField()

    // Actions
    let downloadButton  = NSButton()
    let cancelButton    = NSButton()
    let checkButton     = NSButton()

    // Progress
    let progressBar     = NSProgressIndicator()
    let statusLabel     = NSTextField(labelWithString: "")

    // Log
    let logView         = NSTextView()

    // State
    var running         = false
    var activeProcess:  Process?
    var urlHistory:     [String] = []

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ n: Notification) {
        buildUI()
        restorePrefs()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }

    // MARK: - Prefs

    func restorePrefs() {
        let d = UserDefaults.standard
        outputField.stringValue    = d.string(forKey: Prefs.outputFolder) ?? "\(NSHomeDirectory())/Downloads"
        ytdlpField.stringValue     = d.string(forKey: Prefs.ytdlpPath)    ?? findTool("yt-dlp")
        galleryDLField.stringValue = d.string(forKey: Prefs.galleryDLPath) ?? findTool("gallery-dl")
        ffmpegField.stringValue    = d.string(forKey: Prefs.ffmpegPath)   ?? findTool("ffmpeg")
        urlHistory = d.stringArray(forKey: Prefs.urlHistory) ?? []
        urlCombo.removeAllItems()
        urlCombo.addItems(withObjectValues: urlHistory)

        if let fmt = d.string(forKey: Prefs.format), formatPopup.item(withTitle: fmt) != nil {
            formatPopup.selectItem(withTitle: fmt)
        }
        if let ds = d.string(forKey: Prefs.downloadSize), downloadSizePopup.item(withTitle: ds) != nil {
            downloadSizePopup.selectItem(withTitle: ds)
        }
        if let cs = d.string(forKey: Prefs.convertSize), convertSizePopup.item(withTitle: cs) != nil {
            convertSizePopup.selectItem(withTitle: cs)
        }
        if let ck = d.string(forKey: Prefs.cookies), cookiesPopup.item(withTitle: ck) != nil {
            cookiesPopup.selectItem(withTitle: ck)
        }
        updateFormatUI()
    }

    func savePrefs() {
        let d = UserDefaults.standard
        d.set(outputField.stringValue,    forKey: Prefs.outputFolder)
        d.set(ytdlpField.stringValue,     forKey: Prefs.ytdlpPath)
        d.set(galleryDLField.stringValue, forKey: Prefs.galleryDLPath)
        d.set(ffmpegField.stringValue,    forKey: Prefs.ffmpegPath)
        d.set(formatPopup.titleOfSelectedItem,       forKey: Prefs.format)
        d.set(downloadSizePopup.titleOfSelectedItem, forKey: Prefs.downloadSize)
        d.set(convertSizePopup.titleOfSelectedItem,  forKey: Prefs.convertSize)
        d.set(cookiesPopup.titleOfSelectedItem,      forKey: Prefs.cookies)
        d.set(urlHistory, forKey: Prefs.urlHistory)
    }

    func addURLToHistory(_ url: String) {
        urlHistory.removeAll { $0 == url }
        urlHistory.insert(url, at: 0)
        if urlHistory.count > 20 { urlHistory = Array(urlHistory.prefix(20)) }
        urlCombo.removeAllItems()
        urlCombo.addItems(withObjectValues: urlHistory)
        savePrefs()
    }

    // MARK: - UI

    func buildUI() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Media Downloader"
        window.center()
        window.minSize = NSSize(width: 680, height: 560)

        let content = window.contentView!

        // Outer scroll so the whole thing is usable at smaller heights
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 0
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            root.topAnchor.constraint(equalTo: content.topAnchor),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])

        // ── Section 1: URL ──────────────────────────────────────────────
        let urlSection = makeSection(title: "URL")
        let urlRow = NSStackView()
        urlRow.orientation = .horizontal
        urlRow.spacing = 6

        urlCombo.placeholderString = "Paste or type a YouTube / Instagram URL"
        urlCombo.isEditable = true
        urlCombo.completes = true
        urlCombo.delegate = self
        urlCombo.hasVerticalScroller = true

        pasteButton.title = "Paste"
        pasteButton.bezelStyle = .rounded
        pasteButton.target = self
        pasteButton.action = #selector(pasteURL)
        pasteButton.widthAnchor.constraint(equalToConstant: 54).isActive = true

        clearButton.title = "✕"
        clearButton.bezelStyle = .rounded
        clearButton.target = self
        clearButton.action = #selector(clearURL)
        clearButton.toolTip = "Clear URL"
        clearButton.widthAnchor.constraint(equalToConstant: 32).isActive = true

        urlRow.addArrangedSubview(urlCombo)
        urlRow.addArrangedSubview(pasteButton)
        urlRow.addArrangedSubview(clearButton)
        urlSection.addArrangedSubview(urlRow)
        root.addArrangedSubview(urlSection)

        // ── Section 2: Download Options ─────────────────────────────────
        let optSection = makeSection(title: "Download Options")

        // Format + Download size on one row
        let row1 = NSStackView()
        row1.orientation = .horizontal
        row1.spacing = 16
        formatPopup.addItems(withTitles: ["YouTube MP4", "YouTube MP3", "IG video", "IG photo"])
        formatPopup.target = self
        formatPopup.action = #selector(formatChanged)
        row1.addArrangedSubview(labeledControl("Format", formatPopup))

        downloadSizePopup.addItems(withTitles: ["Best", "1080p", "720p", "480p", "360p"])
        row1.addArrangedSubview(labeledControl("Download size", downloadSizePopup))
        row1.addArrangedSubview(NSView()) // spacer
        optSection.addArrangedSubview(row1)

        // Convert + Custom width
        let row2 = NSStackView()
        row2.orientation = .horizontal
        row2.spacing = 16
        convertSizePopup.addItems(withTitles: ["No conversion", "1080p", "720p", "480p", "360p", "Custom width"])
        convertSizePopup.target = self
        convertSizePopup.action = #selector(convertChanged)
        row2.addArrangedSubview(labeledControl("Convert MP4 to", convertSizePopup))

        customWidthField.placeholderString = "e.g. 1280"
        customWidthField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        customWidthField.heightAnchor.constraint(equalToConstant: 26).isActive = true
        let customWidthLabeled = labeledControl("Custom width", customWidthField)
        row2.addArrangedSubview(customWidthLabeled)
        row2.addArrangedSubview(NSView())
        optSection.addArrangedSubview(row2)

        // Cookies
        let row3 = NSStackView()
        row3.orientation = .horizontal
        row3.spacing = 16
        cookiesPopup.addItems(withTitles: ["No cookies", "Safari cookies", "Chrome cookies", "Firefox cookies"])
        cookiesPopup.selectItem(withTitle: "Chrome cookies")
        row3.addArrangedSubview(labeledControl("Browser cookies", cookiesPopup))
        row3.addArrangedSubview(NSView())
        optSection.addArrangedSubview(row3)

        // IG indexes (shown only for IG modes)
        let igRow = NSStackView()
        igRow.orientation = .horizontal
        igRow.spacing = 8
        igIndexesField.placeholderString = "all  or  1  or  1,3,5  or  2-8"
        igIndexesField.stringValue = "all"
        igIndexesField.heightAnchor.constraint(equalToConstant: 26).isActive = true

        listButton.title = "List indexes"
        listButton.bezelStyle = .rounded
        listButton.target = self
        listButton.action = #selector(listIGIndexes)

        igRow.addArrangedSubview(labeledControl("IG indexes", igIndexesField))
        igRow.addArrangedSubview(listButton)
        igRow.addArrangedSubview(NSView())
        igRow.identifier = NSUserInterfaceItemIdentifier("igRow")
        optSection.addArrangedSubview(igRow)

        root.addArrangedSubview(optSection)

        // ── Section 3: Output ───────────────────────────────────────────
        let outSection = makeSection(title: "Output Folder")
        let outRow = NSStackView()
        outRow.orientation = .horizontal
        outRow.spacing = 8
        outputField.heightAnchor.constraint(equalToConstant: 26).isActive = true
        let chooseOutBtn = NSButton(title: "Choose…", target: self, action: #selector(chooseOutput))
        chooseOutBtn.bezelStyle = .rounded
        outRow.addArrangedSubview(outputField)
        outRow.addArrangedSubview(chooseOutBtn)
        outSection.addArrangedSubview(outRow)
        root.addArrangedSubview(outSection)

        // ── Section 4: Tools (collapsible) ──────────────────────────────
        let toolsSection = makeSection(title: "")

        toolsDisclosure.setButtonType(.onOff)
        toolsDisclosure.bezelStyle = .disclosure
        toolsDisclosure.title = "Tools"
        toolsDisclosure.font = .boldSystemFont(ofSize: 12)
        toolsDisclosure.target = self
        toolsDisclosure.action = #selector(toggleTools)
        toolsDisclosure.state = .off
        toolsSection.addArrangedSubview(toolsDisclosure)

        toolsStack.orientation = .vertical
        toolsStack.spacing = 6
        toolsStack.isHidden = true

        for (label, field, sel) in [
            ("yt-dlp", ytdlpField, #selector(chooseYTDLP)),
            ("gallery-dl", galleryDLField, #selector(chooseGalleryDL)),
            ("ffmpeg", ffmpegField, #selector(chooseFFmpeg))
        ] as [(String, NSTextField, Selector)] {
            field.heightAnchor.constraint(equalToConstant: 26).isActive = true
            let findBtn = NSButton(title: "Find…", target: self, action: sel)
            findBtn.bezelStyle = .rounded
            let r = NSStackView()
            r.orientation = .horizontal
            r.spacing = 8
            let lbl = NSTextField(labelWithString: label)
            lbl.alignment = .right
            lbl.widthAnchor.constraint(equalToConstant: 80).isActive = true
            r.addArrangedSubview(lbl)
            r.addArrangedSubview(field)
            r.addArrangedSubview(findBtn)
            toolsStack.addArrangedSubview(r)
        }

        let checkRow = NSStackView()
        checkRow.orientation = .horizontal
        checkRow.spacing = 8
        checkButton.title = "Check Tools"
        checkButton.bezelStyle = .rounded
        checkButton.target = self
        checkButton.action = #selector(checkTools)
        checkRow.addArrangedSubview(checkButton)
        checkRow.addArrangedSubview(NSView())
        toolsStack.addArrangedSubview(checkRow)

        toolsSection.addArrangedSubview(toolsStack)
        root.addArrangedSubview(toolsSection)

        // ── Action bar ──────────────────────────────────────────────────
        let actionBar = NSStackView()
        actionBar.orientation = .horizontal
        actionBar.spacing = 10
        actionBar.edgeInsets = NSEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)

        downloadButton.title = "⬇  Download"
        downloadButton.bezelStyle = .rounded
        downloadButton.keyEquivalent = "\r"
        downloadButton.target = self
        downloadButton.action = #selector(download)
        if let cell = downloadButton.cell as? NSButtonCell {
            cell.backgroundColor = .controlAccentColor
        }
        downloadButton.widthAnchor.constraint(equalToConstant: 120).isActive = true

        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelDownload)
        cancelButton.isEnabled = false

        // Progress
        progressBar.style = .bar
        progressBar.isIndeterminate = true
        progressBar.isHidden = true

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail

        actionBar.addArrangedSubview(downloadButton)
        actionBar.addArrangedSubview(cancelButton)
        actionBar.addArrangedSubview(progressBar)
        actionBar.addArrangedSubview(statusLabel)
        actionBar.addArrangedSubview(NSView())
        progressBar.widthAnchor.constraint(equalToConstant: 120).isActive = true

        root.addArrangedSubview(hDivider())
        root.addArrangedSubview(actionBar)

        // ── Disclaimer ──────────────────────────────────────────────────
        let disclaimer = NSTextField(labelWithString: "⚠️  Use only for media you own, have permission to download, or that the platform allows you to save.")
        disclaimer.font = .systemFont(ofSize: 10)
        disclaimer.textColor = .secondaryLabelColor
        disclaimer.alignment = .center
        disclaimer.cell?.wraps = true
        let disclaimerWrapper = NSStackView()
        disclaimerWrapper.edgeInsets = NSEdgeInsets(top: 0, left: 16, bottom: 4, right: 16)
        disclaimerWrapper.addArrangedSubview(disclaimer)
        root.addArrangedSubview(disclaimerWrapper)

        // ── Log ─────────────────────────────────────────────────────────
        root.addArrangedSubview(hDivider())

        let logHeader = NSStackView()
        logHeader.orientation = .horizontal
        logHeader.edgeInsets = NSEdgeInsets(top: 4, left: 16, bottom: 0, right: 16)
        let logTitle = NSTextField(labelWithString: "Log")
        logTitle.font = .boldSystemFont(ofSize: 11)
        logTitle.textColor = .secondaryLabelColor
        let clearLogBtn = NSButton(title: "Clear", target: self, action: #selector(clearLog))
        clearLogBtn.bezelStyle = .inline
        clearLogBtn.font = .systemFont(ofSize: 11)
        logHeader.addArrangedSubview(logTitle)
        logHeader.addArrangedSubview(NSView())
        logHeader.addArrangedSubview(clearLogBtn)
        root.addArrangedSubview(logHeader)

        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        logView.textColor = .secondaryLabelColor
        logView.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 1)
        logView.textContainerInset = NSSize(width: 8, height: 8)

        let logScroll = NSScrollView()
        logScroll.hasVerticalScroller = true
        logScroll.documentView = logView
        logScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        root.addArrangedSubview(logScroll)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        updateFormatUI()
    }

    // MARK: - Section builder

    func makeSection(title: String) -> NSStackView {
        let section = NSStackView()
        section.orientation = .vertical
        section.spacing = 8
        section.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        section.alignment = .leading

        if !title.isEmpty {
            let header = NSTextField(labelWithString: title.uppercased())
            header.font = .boldSystemFont(ofSize: 10)
            header.textColor = .secondaryLabelColor
            section.addArrangedSubview(header)
            section.addArrangedSubview(hDividerThin())
        }
        return section
    }

    func labeledControl(_ text: String, _ control: NSView) -> NSStackView {
        let s = NSStackView()
        s.orientation = .vertical
        s.spacing = 3
        s.alignment = .leading
        let lbl = NSTextField(labelWithString: text)
        lbl.font = .systemFont(ofSize: 11)
        lbl.textColor = .secondaryLabelColor
        s.addArrangedSubview(lbl)
        s.addArrangedSubview(control)
        return s
    }

    func hDivider() -> NSBox {
        let b = NSBox(); b.boxType = .separator; return b
    }

    func hDividerThin() -> NSBox {
        let b = NSBox()
        b.boxType = .separator
        b.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return b
    }

    // MARK: - Format / convert UI updates

    @objc func formatChanged() {
        updateFormatUI()
        savePrefs()
    }

    @objc func convertChanged() {
        let isCustom = convertSizePopup.titleOfSelectedItem == "Custom width"
        customWidthField.isEnabled = isCustom
        customWidthField.alphaValue = isCustom ? 1 : 0.4
        savePrefs()
    }

    func updateFormatUI() {
        let mode = formatPopup.titleOfSelectedItem ?? ""
        let isIG = mode.hasPrefix("IG")
        let isVideo = mode == "YouTube MP4" || mode == "IG video"

        // Show download size only for video formats
        downloadSizePopup.isEnabled = isVideo
        convertSizePopup.isEnabled = isVideo

        // Show IG indexes row only for IG modes
        for view in igIndexesField.superview?.superview?.subviews ?? [] {
            if (view as? NSStackView)?.identifier?.rawValue == "igRow" {
                view.isHidden = !isIG
            }
        }
        // Find igRow inside toolsStack's parent section
        findIGRow()?.isHidden = !isIG

        convertChanged()
    }

    func findIGRow() -> NSStackView? {
        // Walk view hierarchy to find the igRow stack
        func search(_ view: NSView) -> NSStackView? {
            if let s = view as? NSStackView, s.identifier?.rawValue == "igRow" { return s }
            for sub in view.subviews { if let found = search(sub) { return found } }
            return nil
        }
        return search(window.contentView!)
    }

    // MARK: - Actions

    @objc func pasteURL() {
        let s = NSPasteboard.general.string(forType: .string) ?? ""
        if !s.isEmpty { urlCombo.stringValue = s }
    }

    @objc func clearURL() {
        urlCombo.stringValue = ""
    }

    @objc func clearLog() {
        logView.textStorage?.setAttributedString(NSAttributedString(string: ""))
    }

    @objc func toggleTools() {
        toolsStack.isHidden = toolsDisclosure.state == .off
    }

    @objc func chooseOutput() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            outputField.stringValue = url.path
            savePrefs()
        }
    }

    @objc func chooseYTDLP()     { chooseFile(into: ytdlpField) }
    @objc func chooseGalleryDL() { chooseFile(into: galleryDLField) }
    @objc func chooseFFmpeg()    { chooseFile(into: ffmpegField) }

    func chooseFile(into field: NSTextField) {
        let panel = NSOpenPanel()
        if panel.runModal() == .OK, let url = panel.url {
            field.stringValue = url.path
            savePrefs()
        }
    }

    @objc func cancelDownload() {
        activeProcess?.terminate()
        activeProcess = nil
        running = false
        setRunning(false)
        log("⚠️ Cancelled.")
    }

    @objc func checkTools() {
        start {
            for (name, path) in [
                ("yt-dlp",      self.text(self.ytdlpField)),
                ("gallery-dl",  self.text(self.galleryDLField)),
                ("ffmpeg",      self.text(self.ffmpegField))
            ] {
                let ok = FileManager.default.isExecutableFile(atPath: path)
                self.log("\(ok ? "✅" : "❌") \(name): \(path)")
                if ok {
                    let version = (try? self.capture([path, "--version"]))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !version.isEmpty { self.log("   version: \(version.split(whereSeparator: \.isNewline).first.map(String.init) ?? version)") }
                }
            }
        }
    }

    @objc func listIGIndexes() {
        start { try self.performListIGIndexes() }
    }

    @objc func download() {
        start { try self.performDownload() }
    }

    // MARK: - Running state

    func setRunning(_ on: Bool) {
        DispatchQueue.main.async {
            self.downloadButton.isEnabled = !on
            self.cancelButton.isEnabled = on
            self.progressBar.isHidden = !on
            if on { self.progressBar.startAnimation(nil) }
            else  { self.progressBar.stopAnimation(nil) }
            if !on { self.statusLabel.stringValue = "" }
        }
    }

    func setStatus(_ s: String) {
        DispatchQueue.main.async { self.statusLabel.stringValue = s }
    }

    func start(_ work: @escaping () throws -> Void) {
        guard !running else { alert("A download is already running."); return }
        running = true
        setRunning(true)
        savePrefs()
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try work()
                self.log("✅ Done.")
            } catch let err as NSError where err.domain == "MediaDownloader" {
                self.log("❌ \(err.localizedDescription)")
                self.alert(err.localizedDescription)
            } catch {
                self.log("❌ \(error.localizedDescription)")
            }
            self.running = false
            self.setRunning(false)
        }
    }

    // MARK: - Download logic (unchanged from original, just wired to new UI)

    func performDownload() throws {
        let outputDir = URL(fileURLWithPath: text(outputField).isEmpty
            ? "\(NSHomeDirectory())/Downloads" : text(outputField))
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let sourceURL = text(urlCombo).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceURL.isEmpty else { throw message("Paste a YouTube or Instagram URL first.") }

        addURLToHistory(sourceURL)

        let mode = selected(formatPopup)
        if mode.hasPrefix("IG") { try requireInstagramCookies() }

        setStatus("Downloading…")

        if ["IG video", "IG photo"].contains(mode) {
            let downloadedFiles = try performIGDownload(sourceURL: sourceURL, outputDir: outputDir, mode: mode)
            if mode == "IG video", selected(convertSizePopup) != "No conversion" {
                for file in downloadedFiles {
                    setStatus("Converting \(file.lastPathComponent)…")
                    let converted = try convertMP4(file)
                    log("Converted: \(converted.path)")
                }
            }
            return
        }

        let ytdlp = try requireTool(text(ytdlpField), "yt-dlp")
        var args = [ytdlp, "--newline", "--no-mtime",
                    "-P", outputDir.path,
                    "-o", "%(title).180B [%(id)s].%(ext)s",
                    "--print", "after_move:filepath"]
        args.append(contentsOf: cookieArgs())

        switch mode {
        case "YouTube MP3":
            args.append(contentsOf: ["-x", "--audio-format", "mp3", "--audio-quality", "0"])
            setStatus("Extracting audio…")
        case "YouTube MP4":
            args.append(contentsOf: ["--merge-output-format", "mp4", "-f", youtubeVideoFormat()])
            setStatus("Downloading video…")
        default:
            throw message("Choose a download mode first.")
        }
        args.append(sourceURL)

        let startedAt = Date()
        let result = try runCollecting(args)
        var files = findDownloadedFiles(in: result.lines)
        if files.isEmpty { files = recentFiles(in: outputDir, since: startedAt, mode: mode) }
        guard let final = files.last else {
            throw message("Download finished but I couldn't identify the output file. Check the log.")
        }
        for f in files { log("📁 \(f.path)") }

        if ["YouTube MP4", "IG video"].contains(mode), selected(convertSizePopup) != "No conversion" {
            setStatus("Converting…")
            let converted = try convertMP4(final)
            log("📁 Converted: \(converted.path)")
        }
    }

    func performIGDownload(sourceURL: String, outputDir: URL, mode: String) throws -> [URL] {
        let galleryDL = try requireTool(text(galleryDLField), "gallery-dl")
        let ranges = igGalleryRanges()
        let filter = mode == "IG video" ? "video_url is not None" : "video_url is None"
        var downloadedFiles: [URL] = []
        var seen = Set<String>()
        for range in ranges {
            var args = [galleryDL, "--no-mtime", "-D", outputDir.path, "--Print", "after:{_path}"]
            args.append(contentsOf: cookieArgs())
            args.append(contentsOf: ["--filter", filter])
            if let range { args.append(contentsOf: ["--range", range]) }
            args.append(sourceURL)
            let startedAt = Date()
            let result = try runCollecting(args)
            var files = findDownloadedFiles(in: result.lines)
            if files.isEmpty { files = recentFiles(in: outputDir, since: startedAt, mode: mode) }
            for f in files where !seen.contains(f.path) { seen.insert(f.path); downloadedFiles.append(f) }
        }
        guard !downloadedFiles.isEmpty else {
            throw message("\(mode) download finished but no output file was found. Check IG indexes and log.")
        }
        for f in downloadedFiles { log("📁 \(f.path)") }
        return downloadedFiles
    }

    func performListIGIndexes() throws {
        let ytdlp = try requireTool(text(ytdlpField), "yt-dlp")
        let sourceURL = text(urlCombo).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceURL.isEmpty else { throw message("Paste an Instagram URL first.") }
        setStatus("Listing indexes…")
        let args = [ytdlp, "--ignore-errors", "--flat-playlist",
                    "--print", "%(playlist_index)s/%(playlist_count)s %(id)s %(title)s"]
            + cookieArgs() + [sourceURL]
        let result = try runCollecting(args, allowFailure: true)
        let parsed = result.lines
            .filter { $0.range(of: #"^\d+/\d+"#, options: .regularExpression) != nil }
            .compactMap(parseIndexLine)
        if let total = parsed.map(\.total).max() {
            let videos = parsed.map(\.index).sorted()
            let photos = Array(Set(1...total).subtracting(videos)).sorted()
            log("Carousel has \(total) items")
            if !videos.isEmpty { log("  Video indexes: \(joinIndexes(videos))") }
            if !photos.isEmpty { log("  Photo indexes: \(joinIndexes(photos))") }
        } else {
            log("Could not detect index count. Check the log above.")
        }
    }

    func convertMP4(_ input: URL) throws -> URL {
        let ffmpeg = try requireTool(text(ffmpegField), "ffmpeg")
        let conversion = selected(convertSizePopup)
        let scale: String
        let suffix: String
        switch conversion {
        case "1080p": scale = "scale=-2:1080"; suffix = "1080p"
        case "720p":  scale = "scale=-2:720";  suffix = "720p"
        case "480p":  scale = "scale=-2:480";  suffix = "480p"
        case "360p":  scale = "scale=-2:360";  suffix = "360p"
        case "Custom width":
            let w = text(customWidthField).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let width = Int(w), width > 0 else { throw message("Enter a positive custom width, e.g. 1280.") }
            scale = "scale=\(width):-2"; suffix = "w\(width)"
        default: return input
        }
        let output = input.deletingLastPathComponent()
            .appendingPathComponent("\(input.deletingPathExtension().lastPathComponent)_\(suffix).mp4")
        try run([ffmpeg, "-y", "-i", input.path, "-vf", scale,
                 "-c:v", "libx264", "-preset", "fast", "-crf", "22",
                 "-c:a", "aac", "-b:a", "160k", output.path])
        return output
    }

    func youtubeVideoFormat() -> String {
        switch selected(downloadSizePopup) {
        case "1080p": return "bv*[height<=1080][ext=mp4]+ba[ext=m4a]/b[height<=1080][ext=mp4]/best[height<=1080]/best"
        case "720p":  return "bv*[height<=720][ext=mp4]+ba[ext=m4a]/b[height<=720][ext=mp4]/best[height<=720]/best"
        case "480p":  return "bv*[height<=480][ext=mp4]+ba[ext=m4a]/b[height<=480][ext=mp4]/best[height<=480]/best"
        case "360p":  return "bv*[height<=360][ext=mp4]+ba[ext=m4a]/b[height<=360][ext=mp4]/best[height<=360]/best"
        default:      return "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/best"
        }
    }

    func cookieArgs() -> [String] {
        switch selected(cookiesPopup) {
        case "Safari cookies":  return ["--cookies-from-browser", "safari"]
        case "Chrome cookies":  return ["--cookies-from-browser", "chrome"]
        case "Firefox cookies": return ["--cookies-from-browser", "firefox"]
        default: return []
        }
    }

    func requireInstagramCookies() throws {
        guard !cookieArgs().isEmpty else {
            throw message("Instagram downloads require browser cookies. Choose Chrome/Safari/Firefox from the cookies menu (where you are logged into Instagram).")
        }
    }

    func igGalleryRanges() -> [String?] {
        let raw = text(igIndexesField).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, raw.lowercased() != "all" else { return [nil] }
        return raw.split(separator: ",").map { Optional(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    func findDownloadedFiles(in lines: [String]) -> [URL] {
        var files: [URL] = []
        var seen = Set<String>()
        for line in lines {
            for candidate in pathCandidates(from: line.trimmingCharacters(in: .whitespacesAndNewlines)) {
                if FileManager.default.fileExists(atPath: candidate) && !seen.contains(candidate) {
                    seen.insert(candidate)
                    files.append(URL(fileURLWithPath: candidate))
                }
            }
        }
        return files
    }

    func pathCandidates(from line: String) -> [String] {
        var candidates: [String] = []
        if line.hasPrefix("/") { candidates.append(line) }
        for marker in [" to: ", " Destination: ", " Merging formats into "] {
            if let range = line.range(of: marker) {
                var path = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                path = path.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if path.hasPrefix("/") { candidates.append(path) }
            }
        }
        return candidates
    }

    func recentFiles(in directory: URL, since date: Date, mode: String) -> [URL] {
        let exts: Set<String>
        switch mode {
        case "IG photo":    exts = ["jpg","jpeg","png","webp","heic","avif"]
        case "YouTube MP3": exts = ["mp3","m4a","opus","wav"]
        default:            exts = ["mp4","m4v","mov","webm","mkv"]
        }
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles)
        else { return [] }
        let threshold = date.addingTimeInterval(-5)
        return urls.compactMap { url -> (URL, Date)? in
            guard exts.contains(url.pathExtension.lowercased()),
                  let vals = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let mod = vals.contentModificationDate, mod >= threshold else { return nil }
            return (url, mod)
        }.sorted { $0.1 < $1.1 }.map(\.0)
    }

    // MARK: - Process helpers

    func run(_ args: [String]) throws {
        let r = try runCollecting(args)
        if r.status != 0 { throw message("Command failed (\(r.status)): \(args[0])") }
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
        activeProcess = process
        pipe.fileHandleForReading.readabilityHandler = { h in
            let data = h.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            let split = text.split(whereSeparator: \.isNewline).map(String.init)
            lock.lock(); lines.append(contentsOf: split); lock.unlock()
            split.forEach { self.log($0) }
        }
        process.waitUntilExit()
        pipe.fileHandleForReading.readabilityHandler = nil
        activeProcess = nil
        if process.terminationStatus != 0 && !allowFailure {
            throw message("Command failed (\(process.terminationStatus)): \(args[0])")
        }
        lock.lock(); defer { lock.unlock() }
        return (process.terminationStatus, lines)
    }

    func capture(_ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: args[0])
        p.arguments = Array(args.dropFirst())
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        p.environment = env
        let pipe = Pipe()
        p.standardOutput = pipe; p.standardError = pipe
        try p.run(); p.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    func requireTool(_ path: String, _ name: String) throws -> String {
        guard !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) else {
            throw message("\(name) not found. Open the Tools section and set its path.")
        }
        return path
    }

    func findTool(_ name: String) -> String {
        ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
            .map { "\($0)/\(name)" }
            .first { FileManager.default.isExecutableFile(atPath: $0) } ?? ""
    }

    func parseIndexLine(_ line: String) -> (index: Int, total: Int)? {
        let parts = line.split(separator: " ", maxSplits: 1)
        guard let first = parts.first else { return nil }
        let ip = first.split(separator: "/")
        guard ip.count == 2, let i = Int(ip[0]), let t = Int(ip[1]) else { return nil }
        return (i, t)
    }

    func joinIndexes(_ a: [Int]) -> String { a.map(String.init).joined(separator: ",") }

    func selected(_ popup: NSPopUpButton) -> String {
        Thread.isMainThread ? popup.titleOfSelectedItem ?? "" : DispatchQueue.main.sync { popup.titleOfSelectedItem ?? "" }
    }

    func text(_ field: NSTextField) -> String {
        Thread.isMainThread ? field.stringValue : DispatchQueue.main.sync { field.stringValue }
    }

    func text(_ combo: NSComboBox) -> String {
        Thread.isMainThread ? combo.stringValue : DispatchQueue.main.sync { combo.stringValue }
    }

    func log(_ value: String) {
        DispatchQueue.main.async {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            self.logView.textStorage?.append(NSAttributedString(string: value + "\n", attributes: attrs))
            self.logView.scrollToEndOfDocument(nil)
        }
    }

    func alert(_ value: String) {
        DispatchQueue.main.async {
            let a = NSAlert()
            a.messageText = "Media Downloader"
            a.informativeText = value
            a.runModal()
        }
    }

    func message(_ value: String) -> NSError {
        NSError(domain: "MediaDownloader", code: 1, userInfo: [NSLocalizedDescriptionKey: value])
    }
}

// MARK: - NSComboBoxDelegate (URL field)

extension MediaDownloaderDelegate: NSComboBoxDelegate {
    func comboBoxSelectionDidChange(_ notification: Notification) {
        // selection from dropdown — nothing extra needed
    }
}

// MARK: - URL extension

extension URL {
    func appendingPathComponentSibling(_ name: String) -> URL {
        deletingLastPathComponent().appendingPathComponent(name)
    }
}

// MARK: - Entry point

let app = NSApplication.shared
let delegate = MediaDownloaderDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
