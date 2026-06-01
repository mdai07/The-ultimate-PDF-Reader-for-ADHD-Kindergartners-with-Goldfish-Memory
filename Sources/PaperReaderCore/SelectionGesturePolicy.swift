import Foundation

public enum SelectionGesturePolicy {
    public static let magicWandToolID = "magicWand"

    public static func shouldBeginRectangleSelection(activeToolID: String?, startsOnText: Bool) -> Bool {
        guard startsOnText == false else {
            return false
        }
        guard let activeToolID else {
            return true
        }
        return activeToolID == magicWandToolID
    }
}
