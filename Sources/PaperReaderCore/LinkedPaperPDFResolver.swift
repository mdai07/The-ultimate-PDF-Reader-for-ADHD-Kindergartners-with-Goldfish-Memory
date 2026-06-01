import Foundation

public enum LinkedPaperPDFResolver {
    public static func directPDFURL(for url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return nil
        }

        if isArxivURL(url),
           let arxivPDFURL = arxivPDFURL(for: url) {
            return arxivPDFURL
        }

        if url.pathExtension.lowercased() == "pdf" {
            return url
        }

        return nil
    }

    public static func pdfURL(inHTML html: String, pageURL: URL) -> URL? {
        for attributeName in ["citation_pdf_url", "eprints.document_url", "dc.identifier", "og:pdf"] {
            if let value = metaContent(named: attributeName, in: html),
               let url = resolvedPDFURL(from: value, relativeTo: pageURL) {
                return url
            }
        }

        if let value = linkHref(matchingRel: "alternate", type: "application/pdf", in: html),
           let url = resolvedPDFURL(from: value, relativeTo: pageURL) {
            return url
        }

        if let value = firstPDFHref(in: html),
           let url = resolvedPDFURL(from: value, relativeTo: pageURL) {
            return url
        }

        return nil
    }

    public static func destinationURL(forPDFURL pdfURL: URL, sourcePaperURL: URL) -> URL {
        let directory = sourcePaperURL.deletingLastPathComponent()
        let filename = sanitizedPDFBaseName(from: pdfURL)
        return directory.appendingPathComponent(filename).appendingPathExtension("pdf")
    }

    private static func isArxivURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else {
            return false
        }
        return host == "arxiv.org" || host.hasSuffix(".arxiv.org")
    }

    private static func arxivPDFURL(for url: URL) -> URL? {
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let components = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard let first = components.first?.lowercased(),
              ["abs", "html", "pdf"].contains(first),
              components.count >= 2 else {
            return nil
        }

        let identifier = components.dropFirst().joined(separator: "/")
        guard !identifier.isEmpty else {
            return nil
        }

        let pdfIdentifier = identifier.lowercased().hasSuffix(".pdf")
            ? identifier
            : "\(identifier).pdf"
        return URL(string: "https://arxiv.org/pdf/\(pdfIdentifier)")
    }

    private static func resolvedPDFURL(from rawValue: String, relativeTo pageURL: URL) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        let resolved = URL(string: trimmed, relativeTo: pageURL)?.absoluteURL
        guard let resolved else {
            return nil
        }
        if let direct = directPDFURL(for: resolved) {
            return direct
        }
        guard resolved.pathExtension.lowercased() == "pdf" else {
            return nil
        }
        return resolved
    }

    private static func sanitizedPDFBaseName(from url: URL) -> String {
        let lastComponent = url.deletingPathExtension().lastPathComponent
        let fallback = UUID().uuidString
        let raw = lastComponent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : lastComponent
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        let scalars = raw.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(scalars)
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".-"))
        return collapsed.isEmpty ? fallback : collapsed
    }

    private static func metaContent(named name: String, in html: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        let patterns = [
            #"<meta\b(?=[^>]*(?:name|property)\s*=\s*["']\#(escaped)["'])(?=[^>]*content\s*=\s*["']([^"']+)["'])[^>]*>"#,
            #"<meta\b(?=[^>]*content\s*=\s*["']([^"']+)["'])(?=[^>]*(?:name|property)\s*=\s*["']\#(escaped)["'])[^>]*>"#
        ]
        return firstCapture(matchingAny: patterns, in: html)
    }

    private static func linkHref(matchingRel rel: String, type: String, in html: String) -> String? {
        let escapedRel = NSRegularExpression.escapedPattern(for: rel)
        let escapedType = NSRegularExpression.escapedPattern(for: type)
        let patterns = [
            #"<link\b(?=[^>]*rel\s*=\s*["'][^"']*\#(escapedRel)[^"']*["'])(?=[^>]*type\s*=\s*["']\#(escapedType)["'])(?=[^>]*href\s*=\s*["']([^"']+)["'])[^>]*>"#,
            #"<link\b(?=[^>]*href\s*=\s*["']([^"']+)["'])(?=[^>]*rel\s*=\s*["'][^"']*\#(escapedRel)[^"']*["'])(?=[^>]*type\s*=\s*["']\#(escapedType)["'])[^>]*>"#
        ]
        return firstCapture(matchingAny: patterns, in: html)
    }

    private static func firstPDFHref(in html: String) -> String? {
        let patterns = [
            #"<a\b(?=[^>]*href\s*=\s*["']([^"']+\.pdf(?:\?[^"']*)?)["'])[^>]*>"#,
            #"<link\b(?=[^>]*href\s*=\s*["']([^"']+\.pdf(?:\?[^"']*)?)["'])[^>]*>"#
        ]
        return firstCapture(matchingAny: patterns, in: html)
    }

    private static func firstCapture(matchingAny patterns: [String], in text: String) -> String? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
                  let match = expression.firstMatch(in: text, range: range),
                  match.numberOfRanges > 1,
                  let captureRange = Range(match.range(at: 1), in: text) else {
                continue
            }
            return htmlDecoded(String(text[captureRange]))
        }
        return nil
    }

    private static func htmlDecoded(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
