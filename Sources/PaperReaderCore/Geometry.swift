import Foundation

public struct PageSize: Codable, Equatable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct PageRect: Codable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct NormalizedPoint: Codable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct NormalizedRect: Codable, Equatable, Hashable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public init(pageRect: PageRect, pageSize: PageSize) {
        self.init(
            x: pageSize.width == 0 ? 0 : pageRect.x / pageSize.width,
            y: pageSize.height == 0 ? 0 : pageRect.y / pageSize.height,
            width: pageSize.width == 0 ? 0 : pageRect.width / pageSize.width,
            height: pageSize.height == 0 ? 0 : pageRect.height / pageSize.height
        )
    }

    public func pageRect(in pageSize: PageSize) -> PageRect {
        PageRect(
            x: x * pageSize.width,
            y: y * pageSize.height,
            width: width * pageSize.width,
            height: height * pageSize.height
        )
    }
}
