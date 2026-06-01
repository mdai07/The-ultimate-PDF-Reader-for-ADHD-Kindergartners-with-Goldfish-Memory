import Foundation

public struct OCRRequest: Equatable {
    public var pageIndex: Int
    public var imageData: Data
    public var imageUTI: String?

    public init(pageIndex: Int, imageData: Data, imageUTI: String? = nil) {
        self.pageIndex = pageIndex
        self.imageData = imageData
        self.imageUTI = imageUTI
    }
}

public protocol OCRProvider {
    var displayName: String { get }

    func recognizeText(in request: OCRRequest) async throws -> [OCRBlock]
}
