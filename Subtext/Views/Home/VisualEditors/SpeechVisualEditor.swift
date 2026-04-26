import SwiftUI

struct SpeechVisualEditor: View {
    @Binding var visual: VisualContent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(messages.indices, id: \.self) { idx in
                row(for: idx)
            }
            Button {
                var msgs = messages
                msgs.append(SpeechMessage(side: .left, text: ""))
                write(msgs)
            } label: {
                Label("Add message", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.subtextAccent)
        }
    }

    private var messages: [SpeechMessage] {
        if case .speech(let s) = visual { return s.messages }
        return []
    }

    private func write(_ messages: [SpeechMessage]) {
        visual = .speech(SpeechVisual(messages: messages))
    }

    @ViewBuilder
    private func row(for idx: Int) -> some View {
        HStack(spacing: 8) {
            Picker("", selection: sideBinding(idx: idx)) {
                ForEach(SpeechMessage.Side.allCases) { side in
                    Text(side.rawValue.capitalized).tag(side)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 100)

            TextField("Message", text: textBinding(idx: idx))
                .textFieldStyle(.roundedBorder)

            Button(role: .destructive) {
                var m = messages
                if idx < m.count {
                    m.remove(at: idx)
                    write(m)
                }
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private func sideBinding(idx: Int) -> Binding<SpeechMessage.Side> {
        Binding(
            get: { idx < messages.count ? messages[idx].side : .left },
            set: { newValue in
                var m = messages
                guard idx < m.count else { return }
                m[idx].side = newValue
                write(m)
            }
        )
    }

    private func textBinding(idx: Int) -> Binding<String> {
        Binding(
            get: { idx < messages.count ? messages[idx].text : "" },
            set: { newValue in
                var m = messages
                guard idx < m.count else { return }
                m[idx].text = newValue
                write(m)
            }
        )
    }
}
