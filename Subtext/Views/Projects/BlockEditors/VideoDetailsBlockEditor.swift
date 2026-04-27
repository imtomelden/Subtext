import SwiftUI

struct VideoDetailsBlockEditor: View {
    @Binding var block: VideoDetailsBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldRow("Runtime") {
                TextField("Optional", text: Binding(
                    get: { block.runtime ?? "" },
                    set: { block.runtime = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            FieldRow("Platform") {
                TextField("Optional", text: Binding(
                    get: { block.platform ?? "" },
                    set: { block.platform = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            FieldRow("Transcript URL") {
                TextField("https://…", text: Binding(
                    get: { block.transcriptUrl ?? "" },
                    set: { block.transcriptUrl = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            FieldRow("Credits") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(block.credits.enumerated()), id: \.offset) { i, _ in
                        HStack {
                            TextField("Name / role", text: Binding(
                                get: { block.credits[i] },
                                set: { block.credits[i] = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            Button(role: .destructive) {
                                block.credits.remove(at: i)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        block.credits.append("")
                    } label: {
                        Label("Add credit", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.subtextAccent)
                }
            }
        }
    }
}
