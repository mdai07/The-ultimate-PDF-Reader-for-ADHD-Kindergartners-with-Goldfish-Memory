import Foundation

public struct CommentSelectionState: Equatable {
    public private(set) var selectedCommentID: UUID?

    public init(selectedCommentID: UUID? = nil) {
        self.selectedCommentID = selectedCommentID
    }

    public mutating func select(_ id: UUID) {
        selectedCommentID = id
    }

    public mutating func clear() {
        selectedCommentID = nil
    }

    public mutating func clearIfSelected(_ id: UUID) {
        if selectedCommentID == id {
            selectedCommentID = nil
        }
    }

    public mutating func commentIDForDeletion(existingCommentIDs: Set<UUID>) -> UUID? {
        guard let selectedCommentID else {
            return nil
        }
        guard existingCommentIDs.contains(selectedCommentID) else {
            self.selectedCommentID = nil
            return nil
        }
        return selectedCommentID
    }
}
