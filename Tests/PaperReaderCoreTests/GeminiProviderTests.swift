import XCTest
@testable import PaperReaderCore

final class GeminiProviderTests: XCTestCase {
    func testBuildsGenerateContentRequestWithSystemInstructionAndConversation() throws {
        let request = try GeminiProvider.makeRequest(
            apiKey: "gemini-secret",
            model: "gemini-2.5-pro",
            messages: [
                AIMessage(role: .system, content: "You answer paper questions."),
                AIMessage(role: .user, content: "What is the main result?"),
                AIMessage(role: .assistant, content: "The paper reports a stable diagnostic."),
                AIMessage(role: .user, content: "Where is it defined?")
            ]
        )

        XCTAssertEqual(
            request.url?.absoluteString,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=gemini-secret"
        )
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(request.httpBody)
        let decoded = try JSONDecoder().decode(GeminiProvider.GenerateContentRequestBody.self, from: body)
        XCTAssertEqual(decoded.systemInstruction?.parts.compactMap(\.text), ["You answer paper questions."])
        XCTAssertEqual(decoded.contents.map(\.role), ["user", "model", "user"])
        XCTAssertEqual(decoded.contents.flatMap { $0.parts.compactMap(\.text) }, [
            "What is the main result?",
            "The paper reports a stable diagnostic.",
            "Where is it defined?"
        ])
    }

    func testBuildsGenerateContentRequestWithInlineImageAttachment() throws {
        let request = try GeminiProvider.makeRequest(
            apiKey: "gemini-secret",
            model: "gemini-2.5-pro",
            messages: [
                AIMessage(
                    role: .user,
                    content: "Explain the selected equation.",
                    imageAttachments: [
                        AIImageAttachment(
                            label: "selected equation crop",
                            mimeType: "image/png",
                            base64Data: "abc123"
                        )
                    ]
                )
            ]
        )

        let body = try XCTUnwrap(request.httpBody)
        let decoded = try JSONDecoder().decode(GeminiProvider.GenerateContentRequestBody.self, from: body)
        let parts = try XCTUnwrap(decoded.contents.first?.parts)
        XCTAssertEqual(parts.first?.text, "Explain the selected equation.")
        XCTAssertEqual(parts.last?.inlineData?.mimeType, "image/png")
        XCTAssertEqual(parts.last?.inlineData?.data, "abc123")
    }

    func testParsesGeminiGenerateContentResponseIntoAssistantMessage() throws {
        let data = """
        {
          "candidates": [
            {
              "content": {
                "parts": [
                  { "text": "The diagnostic is defined after Eq. 2." },
                  { "text": " It is then tested in Table 1." }
                ]
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let message = try GeminiProvider.parseGenerateContentResponse(data)

        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content, "The diagnostic is defined after Eq. 2. It is then tested in Table 1.")
    }
}
