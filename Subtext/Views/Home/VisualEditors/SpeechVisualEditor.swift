import SwiftUI

struct SpeechVisualEditor: View {
    @Binding var visual: VisualContent
    private static let secondsFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 1
        formatter.maximum = 600
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox("Random status timing range (seconds)") {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lower")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField(
                            "10",
                            value: lowerRangeBinding,
                            formatter: Self.secondsFormatter
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 88)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Upper")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField(
                            "20",
                            value: upperRangeBinding,
                            formatter: Self.secondsFormatter
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 88)
                    }
                }
                .padding(.top, 2)
            }

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

    private var speech: SpeechVisual {
        if case .speech(let s) = visual { return s }
        return SpeechVisual(messages: [])
    }

    private func write(_ messages: [SpeechMessage]) {
        visual = .speech(SpeechVisual(
            messages: messages,
            randomDelayMinSeconds: speech.randomDelayMinSeconds,
            randomDelayMaxSeconds: speech.randomDelayMaxSeconds
        ))
    }

    private func writeRange(min: Int, max: Int) {
        visual = .speech(SpeechVisual(
            messages: messages,
            randomDelayMinSeconds: min,
            randomDelayMaxSeconds: max
        ))
    }

    private var lowerRangeBinding: Binding<Int> {
        Binding(
            get: { max(1, speech.randomDelayMinSeconds ?? 10) },
            set: { newValue in
                let minValue = max(1, newValue)
                let currentMax = max(1, speech.randomDelayMaxSeconds ?? 20)
                writeRange(min: minValue, max: max(minValue, currentMax))
            }
        )
    }

    private var upperRangeBinding: Binding<Int> {
        Binding(
            get: { max(1, speech.randomDelayMaxSeconds ?? 20) },
            set: { newValue in
                let maxValue = max(1, newValue)
                let currentMin = max(1, speech.randomDelayMinSeconds ?? 10)
                writeRange(min: min(currentMin, maxValue), max: maxValue)
            }
        )
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
