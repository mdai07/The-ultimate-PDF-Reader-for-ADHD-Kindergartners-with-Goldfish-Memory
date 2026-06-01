import AppKit
import PaperReaderCore
import Vision

final class VisionOCRProvider: OCRProvider {
    enum VisionOCRError: Error {
        case invalidImageData
    }

    let displayName = "Apple Vision"

    func recognizeText(in request: OCRRequest) async throws -> [OCRBlock] {
        guard let image = NSImage(data: request.imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw VisionOCRError.invalidImageData
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        return try await withCheckedThrowingContinuation { continuation in
            let recognitionRequest = VNRecognizeTextRequest { vnRequest, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = (vnRequest.results as? [VNRecognizedTextObservation]) ?? []
                let blocks = observations.compactMap { observation -> OCRBlock? in
                    guard let candidate = observation.topCandidates(1).first else {
                        return nil
                    }
                    let box = observation.boundingBox
                    return OCRBlock(
                        pageIndex: request.pageIndex,
                        bounds: NormalizedRect(
                            x: box.minX,
                            y: 1 - box.maxY,
                            width: box.width,
                            height: box.height
                        ),
                        text: candidate.string,
                        confidence: Double(candidate.confidence),
                        source: .appleVision
                    )
                }
                continuation.resume(returning: blocks)
            }
            recognitionRequest.recognitionLevel = .accurate
            recognitionRequest.usesLanguageCorrection = true

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([recognitionRequest])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
