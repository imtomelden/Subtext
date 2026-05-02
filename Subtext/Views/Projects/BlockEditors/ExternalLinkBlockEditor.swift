import SwiftUI

struct ExternalLinkBlockEditor: View {
    @Binding var block: ExternalLinkBlock

    private var urlIsValid: Bool {
        guard !block.href.isEmpty else { return true }
        guard let url = URL(string: block.href) else { return false }
        return url.scheme == "https" || url.scheme == "http"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldRow("URL") {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("https://…", text: $block.href)
                        .textFieldStyle(.roundedBorder)
                        .overlay(alignment: .trailing) {
                            if block.href.isEmpty {
                                Text("Required")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                    .padding(.trailing, 8)
                            } else if !urlIsValid {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(.red)
                                    .padding(.trailing, 8)
                            }
                        }
                    if !urlIsValid && !block.href.isEmpty {
                        Text("Enter a valid URL starting with https://")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }
            FieldRow("Button label") {
                TextField("View project →", text: Binding(
                    get: { block.label ?? "" },
                    set: { block.label = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }
}
