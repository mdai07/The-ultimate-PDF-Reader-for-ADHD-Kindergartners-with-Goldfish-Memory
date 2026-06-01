import Foundation

public enum MarginAttachmentVisibility: String, Equatable {
    case expanded
    case reduced
    case minimized
    case hidden
}

public struct MarginAttachmentPlacement: Equatable {
    public var yFraction: Double
    public var sourceYFraction: Double?
    public var sourceXFraction: Double?
    public var scale: Double
    public var opacity: Double
    public var lineLimit: Int?
    public var visibility: MarginAttachmentVisibility

    public init(
        yFraction: Double,
        sourceYFraction: Double?,
        sourceXFraction: Double? = nil,
        scale: Double,
        opacity: Double,
        lineLimit: Int?,
        visibility: MarginAttachmentVisibility
    ) {
        self.yFraction = yFraction
        self.sourceYFraction = sourceYFraction
        self.sourceXFraction = sourceXFraction
        self.scale = scale
        self.opacity = opacity
        self.lineLimit = lineLimit
        self.visibility = visibility
    }
}

public struct MarginAttachmentInput<ID: Hashable>: Equatable {
    public var id: ID
    public var sourceYFraction: Double?
    public var sourceXFraction: Double?
    public var displayYOffset: Double?

    public init(id: ID, sourceYFraction: Double?, sourceXFraction: Double? = nil, displayYOffset: Double? = nil) {
        self.id = id
        self.sourceYFraction = sourceYFraction
        self.sourceXFraction = sourceXFraction
        self.displayYOffset = displayYOffset
    }
}

public struct MarginAttachmentLayout: Equatable {
    public var edgePadding: Double
    public var minimumScale: Double
    public var hiddenDistance: Double

    public init(edgePadding: Double = 0.04, minimumScale: Double = 0.58, hiddenDistance: Double = 1.25) {
        self.edgePadding = edgePadding
        self.minimumScale = minimumScale
        self.hiddenDistance = hiddenDistance
    }

    public func placement(sourceYFraction: Double?) -> MarginAttachmentPlacement {
        guard let sourceYFraction else {
            return MarginAttachmentPlacement(
                yFraction: 0.5,
                sourceYFraction: nil,
                scale: 1,
                opacity: 1,
                lineLimit: nil,
                visibility: .expanded
            )
        }

        if sourceYFraction < 0 {
            return offscreenPlacement(sourceYFraction: sourceYFraction, pinnedY: edgePadding, pinnedSourceY: 0)
        }

        if sourceYFraction > 1 {
            return offscreenPlacement(sourceYFraction: sourceYFraction, pinnedY: 1 - edgePadding, pinnedSourceY: 1)
        }

        return MarginAttachmentPlacement(
            yFraction: max(edgePadding, min(1 - edgePadding, sourceYFraction)),
            sourceYFraction: sourceYFraction,
            scale: 1,
            opacity: 1,
            lineLimit: nil,
            visibility: .expanded
        )
    }

    public func placements<ID: Hashable>(for inputs: [MarginAttachmentInput<ID>]) -> [ID: MarginAttachmentPlacement] {
        var result: [ID: MarginAttachmentPlacement] = [:]
        let aboveIDs = inputs
            .filter { ($0.sourceYFraction ?? 0.5) < 0 }
            .sorted { abs($0.sourceYFraction ?? 0) < abs($1.sourceYFraction ?? 0) }
            .map(\.id)
        let belowIDs = inputs
            .filter { ($0.sourceYFraction ?? 0.5) > 1 }
            .sorted { abs(($0.sourceYFraction ?? 1) - 1) < abs(($1.sourceYFraction ?? 1) - 1) }
            .map(\.id)

        let allowedAbove = Set(aboveIDs.prefix(2))
        let allowedBelow = Set(belowIDs.prefix(2))

        for input in inputs {
            var placement = placement(sourceYFraction: input.sourceYFraction)
            placement.sourceXFraction = input.sourceXFraction
            if placement.visibility == .minimized {
                if input.sourceYFraction ?? 0 < 0 {
                    if !allowedAbove.contains(input.id) {
                        placement.visibility = .hidden
                    } else if let index = aboveIDs.firstIndex(of: input.id) {
                        placement.yFraction = edgePadding + Double(index) * 0.08
                    }
                } else if input.sourceYFraction ?? 0 > 1 {
                    if !allowedBelow.contains(input.id) {
                        placement.visibility = .hidden
                    } else if let index = belowIDs.firstIndex(of: input.id) {
                        placement.yFraction = 1 - edgePadding - Double(index) * 0.08
                    }
                }
            }
            result[input.id] = placement
        }

        separateExpandedPlacements(&result, using: inputs)
        applyDisplayYOffsets(&result, using: inputs)
        return result
    }

    private func separateExpandedPlacements<ID: Hashable>(
        _ placements: inout [ID: MarginAttachmentPlacement],
        using inputs: [MarginAttachmentInput<ID>]
    ) {
        let inputOrder = Dictionary(uniqueKeysWithValues: inputs.enumerated().map { ($0.element.id, $0.offset) })
        let ids = placements.keys
            .filter { id in
                guard let placement = placements[id] else {
                    return false
                }
                return placement.visibility == .expanded && placement.sourceYFraction != nil
            }
            .sorted {
                let lhsY = placements[$0]?.yFraction ?? 0
                let rhsY = placements[$1]?.yFraction ?? 0
                if abs(lhsY - rhsY) > 0.0001 {
                    return lhsY < rhsY
                }

                let lhsX = placements[$0]?.sourceXFraction ?? 0.5
                let rhsX = placements[$1]?.sourceXFraction ?? 0.5
                if abs(lhsX - rhsX) > 0.0001 {
                    return lhsX < rhsX
                }

                return (inputOrder[$0] ?? 0) < (inputOrder[$1] ?? 0)
            }

        guard ids.count > 1 else {
            return
        }

        let available = max(0.01, (1 - edgePadding) - edgePadding)
        let gap = min(0.10, available / Double(ids.count - 1))
        var yValues = ids.map { placements[$0]?.yFraction ?? 0.5 }

        yValues[0] = max(edgePadding, yValues[0])
        for index in 1..<yValues.count {
            yValues[index] = max(yValues[index], yValues[index - 1] + gap)
        }

        if let last = yValues.last, last > 1 - edgePadding {
            let overflow = last - (1 - edgePadding)
            for index in yValues.indices {
                yValues[index] -= overflow
            }
        }

        yValues[yValues.count - 1] = min(1 - edgePadding, yValues[yValues.count - 1])
        for index in stride(from: yValues.count - 2, through: 0, by: -1) {
            yValues[index] = min(yValues[index], yValues[index + 1] - gap)
        }

        for (id, yValue) in zip(ids, yValues) {
            placements[id]?.yFraction = max(edgePadding, min(1 - edgePadding, yValue))
        }
    }

    private func applyDisplayYOffsets<ID: Hashable>(
        _ placements: inout [ID: MarginAttachmentPlacement],
        using inputs: [MarginAttachmentInput<ID>]
    ) {
        for input in inputs {
            guard let offset = input.displayYOffset,
                  abs(offset) > 0.0001,
                  var placement = placements[input.id],
                  placement.visibility == .expanded else {
                continue
            }
            placement.yFraction = max(edgePadding, min(1 - edgePadding, placement.yFraction + offset))
            placements[input.id] = placement
        }
    }

    private func offscreenPlacement(sourceYFraction: Double, pinnedY: Double, pinnedSourceY: Double) -> MarginAttachmentPlacement {
        let distance = sourceYFraction < 0 ? abs(sourceYFraction) : abs(sourceYFraction - 1)
        if distance >= hiddenDistance * 0.45 {
            return MarginAttachmentPlacement(
                yFraction: pinnedY,
                sourceYFraction: pinnedSourceY,
                scale: minimumScale,
                opacity: 0.72,
                lineLimit: 1,
                visibility: .minimized
            )
        }

        let progress = min(1, max(0, distance / hiddenDistance))
        return MarginAttachmentPlacement(
            yFraction: pinnedY,
            sourceYFraction: pinnedSourceY,
            scale: max(minimumScale, 1 - progress * 0.36),
            opacity: max(0.38, 1 - progress * 0.46),
            lineLimit: 3,
            visibility: .reduced
        )
    }
}
