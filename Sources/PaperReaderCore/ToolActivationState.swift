import Foundation

public enum ToolActivationGesture: Equatable {
    case singleClick
    case doubleClick
}

public enum ToolActivationMode: Equatable {
    case singleUse
    case locked
}

public struct ToolActivationState<Tool: Hashable>: Equatable {
    public private(set) var activeTool: Tool?
    public private(set) var mode: ToolActivationMode?

    public init(activeTool: Tool? = nil, mode: ToolActivationMode? = nil) {
        self.activeTool = activeTool
        self.mode = activeTool == nil ? nil : mode
    }

    public mutating func activate(_ tool: Tool, gesture: ToolActivationGesture) {
        switch gesture {
        case .singleClick:
            if activeTool == tool, mode == .locked {
                clear()
            } else {
                activeTool = tool
                mode = .singleUse
            }
        case .doubleClick:
            activeTool = tool
            mode = .locked
        }
    }

    @discardableResult
    public mutating func consume(_ tool: Tool) -> Bool {
        guard activeTool == tool else {
            return false
        }
        if mode == .singleUse {
            clear()
        }
        return true
    }

    public mutating func clear() {
        activeTool = nil
        mode = nil
    }
}
