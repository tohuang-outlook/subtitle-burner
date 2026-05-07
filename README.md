# Subtitle Burner

This repo contains two small native macOS tools:

- `SubtitleBurner.app`: generate bilingual subtitles and burn them into video.
- `MediaDownloader.app`: download YouTube/Instagram media with `yt-dlp`, save MP4/MP3, and optionally resize MP4 output.

## Media Downloader

Open:

```bash
open /Users/tonyhuang/Documents/Codex/2026-05-02/video-work/MediaDownloader.app
```

Features:

- Paste a YouTube or Instagram URL
- Download as `Youtube MP4`, `Youtube MP3`, `IG video`, or `IG photo`
- Choose download size: `Best`, `1080p`, `720p`, `480p`, `360p`
- Optionally convert downloaded MP4 to `1080p`, `720p`, `480p`, `360p`, or a custom width
- Optional browser cookies: Safari, Chrome, Firefox

Download modes:

- `Youtube MP4`: downloads YouTube video as MP4 using the selected size.
- `Youtube MP3`: extracts YouTube audio and saves MP3.
- `IG video`: downloads Instagram video/reel media as MP4 when available.
- `IG photo`: skips video download and saves Instagram photo media as JPG when available.

Required tools:

```bash
yt-dlp --version
ffmpeg -version
```

If Instagram or YouTube asks for login, choose the browser cookies option that matches the browser where you are already logged in.

Build:

```bash
./build_media_downloader.sh
```

Use only for media you own, have permission to download, or that the platform allows you to save.

---

本資料夾裡的 `SubtitleBurner.app` 是一個原生 macOS 小工具，會依照你的流程處理影片：

1. `.mov` / `.mp4` 轉成 H.264 + AAC `.mp4`
2. 抽出 `16kHz 16-bit WAV`
3. 用 Whisper 產生英文 `.srt`
4. 用 OpenAI、DeepSeek、Kimi 2.5、或 Google Gemini 把英文 `.srt` 翻成繁體中文 `.srt`
5. 合併中文與英文成 `.ass`
6. 用 ffmpeg + libass + `/System/Library/Fonts/STHeiti Medium.ttc` 燒入字幕

## 使用方式

雙擊：

```bash
/Users/tonyhuang/Documents/Codex/2026-05-02/video-work/SubtitleBurner.app
```

或從 Terminal 執行：

```bash
open /Users/tonyhuang/Documents/Codex/2026-05-02/video-work/SubtitleBurner.app
```

這個版本是 Swift/AppKit 原生 app，不依賴 Python Tkinter。

## 需要安裝的工具

這個 app 會自動搜尋 `/opt/homebrew/bin` 和 `/usr/local/bin`。請先確認這些指令在你自己的 Terminal 可用：

```bash
ffmpeg -version
ffmpeg -filters | grep ass
whisper --help
HandBrakeCLI --version
```

如果 `ffmpeg` 沒有 `ass` filter，請用有 libass 的 Homebrew ffmpeg 版本。

## 新流程

按 `English SRT` 後，app 會在輸出資料夾建立：

```text
原始檔名_subtitle_work/
```

裡面會有：

```text
原始檔名.en.srt
```

如果要自動翻譯，先在 `Translate mode` 選擇翻譯服務，再把對應 API key 貼到 `Translate API key` 欄位，按 `Translate EN to ZH`。它會產生：

```text
原始檔名.zh.srt
```

最後按 `Merge ASS + Burn`，產生：

```text
原始檔名.zh_en.ass
原始檔名_with_subtitles.mp4
```

`Run All` 會自動執行：英文 SRT、翻譯中文 SRT、合併 ASS、燒入影片。

如果沒有 API key，也可以自己準備中文 SRT，放到 `Chinese .srt` 欄位後再按 `Merge ASS + Burn`。

## 翻譯模式

`OpenAI`

- API: Responses API
- Default model: `gpt-4.1-mini`
- Key: OpenAI API key

`DeepSeek`

- API: `https://api.deepseek.com/chat/completions`
- Default model: `deepseek-v4-flash`
- Key: DeepSeek API key

`Kimi 2.5`

- API: `https://api.moonshot.ai/v1/chat/completions`
- Default model: `kimi-k2.5`
- Key: Moonshot / Kimi API key

`Google Gemini`

- API: `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`
- Default model: `gemini-2.5-flash`
- Key: Gemini API key
