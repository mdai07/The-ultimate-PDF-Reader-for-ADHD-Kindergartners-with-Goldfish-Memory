import Foundation

public struct EquationMarkdownLink: Equatable, Hashable {
    public var text: String
    public var url: String

    public init(text: String, url: String) {
        self.text = text
        self.url = url
    }
}

public enum EquationMarkdownRenderer {
    private enum Segment: Equatable {
        case text(String)
        case inlineMath(String)
        case displayMath(String)
    }

    public static func containsEquationMarkup(_ text: String) -> Bool {
        segments(in: text).contains { segment in
            switch segment {
            case .inlineMath, .displayMath:
                return true
            case .text:
                return false
            }
        }
    }

    public static func htmlDocument(for text: String, equationLinks: [EquationMarkdownLink] = []) -> String {
        let body = bodyHTML(for: text, equationLinks: equationLinks)
        return """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        html, body { margin: 0; padding: 0; background: transparent; }
        body {
            color: #202124;
            font: -apple-system-body;
            font-size: 13px;
            line-height: 1.38;
            overflow-wrap: anywhere;
        }
        strong { font-weight: 650; }
        em { font-style: italic; }
        code {
            font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
            font-size: 0.92em;
            padding: 0.08em 0.28em;
            border-radius: 4px;
            background: rgba(0, 0, 0, 0.07);
        }
        a { color: #0b57d0; text-decoration: none; }
        a.equation-link {
            border-bottom: 1px dotted currentColor;
            font-weight: 560;
        }
        .display-math {
            display: block;
            margin: 0.36em 0;
            overflow-x: auto;
            overflow-y: hidden;
        }
        mjx-container { outline: none; }
        @media (prefers-color-scheme: dark) {
            body { color: #f5f5f7; }
            code { background: rgba(255, 255, 255, 0.13); }
            a { color: #8ab4ff; }
        }
        </style>
        <script>
        function reportHeight() {
            const height = Math.ceil(Math.max(
                document.body.scrollHeight,
                document.documentElement.scrollHeight
            ));
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.height) {
                window.webkit.messageHandlers.height.postMessage(height);
            }
        }
        window.MathJax = {
            tex: {
                inlineMath: [['\\\\(', '\\\\)']],
                displayMath: [['\\\\[', '\\\\]']],
                processEscapes: true
            },
            options: {
                skipHtmlTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code']
            },
            startup: {
                pageReady: () => MathJax.startup.defaultPageReady().then(() => {
                    reportHeight();
                    setTimeout(reportHeight, 120);
                })
            }
        };
        window.addEventListener('load', () => {
            reportHeight();
            setTimeout(reportHeight, 300);
            setTimeout(reportHeight, 900);
        });
        </script>
        <script defer src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
        </head>
        <body>\(body)</body>
        </html>
        """
    }

    private static func bodyHTML(for text: String, equationLinks: [EquationMarkdownLink]) -> String {
        segments(in: text).map { segment in
            switch segment {
            case .text(let text):
                return inlineMarkdownHTML(for: text, equationLinks: equationLinks)
                    .replacingOccurrences(of: "\n", with: "<br>")
            case .inlineMath(let math):
                return "<span class=\"inline-math\">\\(\(escapeHTML(math))\\)</span>"
            case .displayMath(let math):
                return "<span class=\"display-math\">\\[\(escapeHTML(math))\\]</span>"
            }
        }
        .joined()
    }

    private static func segments(in text: String) -> [Segment] {
        var segments: [Segment] = []
        var current = text.startIndex
        var textStart = current

        func appendText(upTo index: String.Index) {
            guard textStart < index else {
                return
            }
            segments.append(.text(String(text[textStart..<index])))
        }

        while current < text.endIndex {
            if starts(with: "\\(", in: text, at: current),
               let closing = text.range(of: "\\)", range: text.index(current, offsetBy: 2)..<text.endIndex) {
                appendText(upTo: current)
                segments.append(.inlineMath(String(text[text.index(current, offsetBy: 2)..<closing.lowerBound])))
                current = closing.upperBound
                textStart = current
                continue
            }

            if starts(with: "\\[", in: text, at: current),
               let closing = text.range(of: "\\]", range: text.index(current, offsetBy: 2)..<text.endIndex) {
                appendText(upTo: current)
                segments.append(.displayMath(String(text[text.index(current, offsetBy: 2)..<closing.lowerBound])))
                current = closing.upperBound
                textStart = current
                continue
            }

            if starts(with: "$$", in: text, at: current),
               let closing = rangeOfUnescaped("$$", in: text, after: text.index(current, offsetBy: 2)) {
                let content = String(text[text.index(current, offsetBy: 2)..<closing.lowerBound])
                if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    appendText(upTo: current)
                    segments.append(.displayMath(content))
                    current = closing.upperBound
                    textStart = current
                    continue
                }
            }

            if text[current] == "$",
               !isEscapedDelimiter(at: current, in: text),
               let closing = rangeOfUnescaped("$", in: text, after: text.index(after: current)) {
                let content = String(text[text.index(after: current)..<closing.lowerBound])
                if looksLikeMath(content) {
                    appendText(upTo: current)
                    segments.append(.inlineMath(content))
                    current = closing.upperBound
                    textStart = current
                    continue
                }
            }

            current = text.index(after: current)
        }

        appendText(upTo: text.endIndex)
        return segments
    }

    private static func inlineMarkdownHTML(for text: String, equationLinks: [EquationMarkdownLink]) -> String {
        var html = escapeHTML(text)
        html = replaceInlineMarkdown(pattern: #"`([^`]+)`"#, in: html, template: "<code>$1</code>")
        html = replaceInlineMarkdown(pattern: #"\*\*([^*]+)\*\*"#, in: html, template: "<strong>$1</strong>")
        html = replaceInlineMarkdown(pattern: #"(?<!\*)\*([^*]+)\*(?!\*)"#, in: html, template: "<em>$1</em>")
        html = replaceInlineMarkdown(
            pattern: #"\[([^\]]+)\]\((https?://[^)]+)\)"#,
            in: html,
            template: #"<a href="$2">$1</a>"#
        )
        html = linkEquationReferences(in: html, links: equationLinks)
        return html
    }

    private static func linkEquationReferences(in html: String, links: [EquationMarkdownLink]) -> String {
        var rendered = html
        var seen = Set<String>()
        let uniqueLinks = links
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.url.isEmpty }
            .filter { seen.insert($0.text).inserted }
            .sorted { $0.text.count > $1.text.count }

        for link in uniqueLinks {
            let escapedText = escapeHTML(link.text)
            guard rendered.contains(escapedText) else {
                continue
            }
            let escapedURL = escapeHTML(link.url)
            rendered = rendered.replacingOccurrences(
                of: escapedText,
                with: #"<a class="equation-link" href="\#(escapedURL)">\#(escapedText)</a>"#
            )
        }

        return rendered
    }

    private static func replaceInlineMarkdown(pattern: String, in text: String, template: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }

    private static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func starts(with prefix: String, in text: String, at index: String.Index) -> Bool {
        text[index...].hasPrefix(prefix)
    }

    private static func rangeOfUnescaped(
        _ delimiter: String,
        in text: String,
        after index: String.Index
    ) -> Range<String.Index>? {
        var searchStart = index
        while searchStart < text.endIndex,
              let range = text.range(of: delimiter, range: searchStart..<text.endIndex) {
            if !isEscapedDelimiter(at: range.lowerBound, in: text) {
                return range
            }
            searchStart = range.upperBound
        }
        return nil
    }

    private static func isEscapedDelimiter(at index: String.Index, in text: String) -> Bool {
        guard index > text.startIndex else {
            return false
        }
        var backslashCount = 0
        var cursor = index
        while cursor > text.startIndex {
            cursor = text.index(before: cursor)
            if text[cursor] == "\\" {
                backslashCount += 1
            } else {
                break
            }
        }
        return backslashCount % 2 == 1
    }

    private static func looksLikeMath(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains("\n\n") else {
            return false
        }
        if trimmed.count == 1,
           trimmed.unicodeScalars.first?.properties.isAlphabetic == true {
            return true
        }
        let mathMarkers = ["\\", "_", "^", "=", "+", "-", "*", "/", "<", ">", "\\frac", "\\sum", "\\int"]
        if mathMarkers.contains(where: { trimmed.contains($0) }) {
            return true
        }
        return trimmed.unicodeScalars.contains { $0.properties.isAlphabetic }
            && trimmed.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) }
    }
}
