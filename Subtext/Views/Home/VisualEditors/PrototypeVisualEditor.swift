import SwiftUI

/// Legacy no-op editor kept only to avoid build breaks in older
/// Xcode project variants that still include this file.
struct PrototypeVisualEditor: View {
    @Binding var visual: VisualContent

    var body: some View {
        EmptyView()
    }
}
