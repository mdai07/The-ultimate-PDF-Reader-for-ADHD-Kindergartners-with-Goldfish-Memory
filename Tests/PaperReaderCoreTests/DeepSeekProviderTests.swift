import XCTest
@testable import PaperReaderCore

final class DeepSeekProviderTests: XCTestCase {
    func testBuildsOpenAICompatibleDeepSeekChatRequest() throws {
        let request = try DeepSeekProvider.makeRequest(
            apiKey: "secret",
            model: "deepseek-v4-pro",
            messages: [
                AIMessage(role: .system, content: "You answer paper questions."),
                AIMessage(role: .user, content: "What is the main result?")
            ],
            stream: false
        )

        XCTAssertEqual(request.url?.absoluteString, "https://api.deepseek.com/chat/completions")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(request.httpBody)
        let decoded = try JSONDecoder().decode(DeepSeekProvider.ChatRequestBody.self, from: body)
        XCTAssertEqual(decoded.model, "deepseek-v4-pro")
        XCTAssertEqual(decoded.messages.map(\.role), ["system", "user"])
        XCTAssertEqual(decoded.stream, false)
    }

    func testParsesDeepSeekChatResponseIntoAssistantMessage() throws {
        let data = """
        {
          "choices": [
            {
              "message": {
                "role": "assistant",
                "content": "The paper proves convergence."
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let message = try DeepSeekProvider.parseChatResponse(data)

        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content, "The paper proves convergence.")
    }
}
