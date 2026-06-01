# uprakigo

**Project name:** The Ultimate PDF Reader for ADHD Kindergartners with Goldfish Memory

`uprakigo` is a native macOS PDF reader for academic papers that assumes three things are true:

1. The paper is important.
2. The margin is too small.
3. Future you will absolutely forget why that one equation looked suspicious at 2:17 AM.

So it gives you a serious paper-reading workflow wrapped in a deeply unserious name: PDF annotation, margin comments, OCR search, AI explanations, figure/table selection, equation-aware context, hidden PDF metadata, and local or hosted AI agents. It is built for the moment when Preview is too quiet, Zotero is too polite, and your paper has decided to communicate exclusively through dense notation and figure captions.

## What It Does

- Opens academic PDFs in a native SwiftUI/PDFKit macOS reader.
- Adds highlights, notes, ink, signatures, text boxes, region selections, and margin comments.
- Connects comments to selected text, figures, tables, or manually chosen anchors with lightweight curved links.
- Stores app metadata inside the PDF so normal PDF readers can still open the file without showing the AIReader state.
- Exports three flavors: plain PDF without metadata, PDF with hidden metadata, and visible annotated PDF.
- Runs OCR and local search so scanned papers stop pretending to be pictures.
- Builds an outline from sections, appendices, figures, and tables.
- Uses AI for selected text, equations, plots, tables, and whole-paper questions.
- Supports hosted DeepSeek and Gemini models, plus local `codex` and `claude` CLI agents when available.

## Project Structure

- `PaperReaderCore`: platform-agnostic models, hidden PDF metadata, normalized geometry, OCR/search abstractions, AI context assembly, hosted API providers, and local agent discovery.
- `uprakigo`: SwiftUI/PDFKit/Vision macOS shell for reading, annotating, OCR, AI sidebar chat, inline suggestions, region selection, margin comments, and PDF export.

The core target intentionally avoids `SwiftUI`, `AppKit`, `PDFKit`, and `Vision` so future shells can reuse the document and AI logic.

## AI Providers

`uprakigo` can use:

- DeepSeek through `DEEPSEEK_API_KEY`.
- Gemini through `GEMINI_API_KEY`, `GEMINI_MODEL`, and `GEMINI_MODEL_FAST`.
- Local Codex CLI, discovered on startup with `which codex`.
- Local Claude CLI, discovered on startup with `which claude`.

The sidebar chat is meant for full paper Q&A. Inline suggestions are meant to be fast, concise explanations of the selected text, equation, figure, or table.

## Install

An install-ready macOS disk image is tracked at:

```text
release/uprakigo-0.1.dmg
```

Open the DMG and drag `uprakigo.app` into Applications. The bundled app is ad-hoc signed for local installation.

## Build And Test

```bash
swift test
swift build
```

To build a local `.app` and `.dmg`:

```bash
scripts/package_dmg.sh
```

Full GUI build/run expects a complete Xcode installation. A Command Line Tools-only setup may fail before compilation if `xcrun` cannot resolve the macOS platform path.

## Status

This is a macOS MVP, but it is already opinionated: keep the PDF readable, keep comments close to the thing they explain, keep AI context paper-specific by default, and keep the original document usable outside the app.
