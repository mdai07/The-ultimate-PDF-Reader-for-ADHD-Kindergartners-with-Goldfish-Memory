import Foundation

public struct DocumentEdit: Equatable {
    public var before: DocumentSession
    public var after: DocumentSession

    public init(before: DocumentSession, after: DocumentSession) {
        self.before = before
        self.after = after
    }
}

public struct DocumentEditHistory: Equatable {
    private var undoStack: [DocumentEdit] = []
    private var redoStack: [DocumentEdit] = []

    public init() {}

    public var canUndo: Bool {
        !undoStack.isEmpty
    }

    public var canRedo: Bool {
        !redoStack.isEmpty
    }

    public mutating func record(before: DocumentSession, after: DocumentSession) {
        guard before != after else {
            return
        }
        undoStack.append(DocumentEdit(before: before, after: after))
        redoStack.removeAll()
    }

    public mutating func undo(current: DocumentSession) -> DocumentSession? {
        guard let edit = undoStack.popLast() else {
            return nil
        }
        redoStack.append(edit)
        return edit.before
    }

    public mutating func redo(current: DocumentSession) -> DocumentSession? {
        guard let edit = redoStack.popLast() else {
            return nil
        }
        undoStack.append(edit)
        return edit.after
    }

    public mutating func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
