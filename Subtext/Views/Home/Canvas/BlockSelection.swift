import Foundation

/// Single source of truth for hover and inline-edit state on the home
/// canvas. Owned by `HomeEditorView`; child views observe it directly.
@Observable
final class BlockSelection {
    var editingID: String?
    var hoveredID: String?

    func toggle(_ id: String) {
        editingID = editingID == id ? nil : id
    }

    func select(_ id: String) {
        editingID = id
    }

    func deselect() {
        editingID = nil
    }

    func isEditing(_ id: String) -> Bool {
        editingID == id
    }
}
