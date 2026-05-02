import SwiftUI

struct SpeechVisualEditor: View {
    @Binding var visual: VisualContent
    @State private var previewExpanded = true

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

            DisclosureGroup(isExpanded: $previewExpanded) {
                SpeechBlockPreview(
                    messages: messages,
                    delayMin: speech.randomDelayMinSeconds,
                    delayMax: speech.randomDelayMaxSeconds
                )
                .padding(.top, 6)
            } label: {
                Text("Preview")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.subtextAccent)
            }
            .animation(Motion.snappy, value: previewExpanded)
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

            SubtextTextField("Message", text: textBinding(idx: idx))

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

private struct SpeechBlockPreview: View {
    let messages: [SpeechMessage]
    let delayMin: Int?
    let delayMax: Int?

    var body: some View {
        let minS = delayMin ?? 10
        let maxS = delayMax ?? 20
        VStack(alignment: .leading, spacing: 10) {
            if messages.isEmpty {
                Text("No messages yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(Array(messages.enumerated()), id: \.offset) { index, msg in
                    if index > 0, minS > 0 || maxS > 0 {
                        Text("…")
                            .font(.caption.italic())
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: msg.side == .left ? .leading : .trailing)
                            .accessibilityLabel("Random delay between replies, about \(minS)–\(maxS) seconds")
                    }
                    bubble(msg)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Tokens.Background.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Tokens.Border.default, lineWidth: 0.5)
                )
        )
    }

    @ViewBuilder
    private func bubble(_ msg: SpeechMessage) -> some View {
        let isLeft = msg.side == .left
        HStack {
            if !isLeft { Spacer(minLength: 40) }
            Text(msg.text.isEmpty ? "Message" : msg.text)
                .font(.caption)
                .foregroundStyle(Tokens.Text.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isLeft ? Color.subtextAccent.opacity(0.16) : Tokens.Background.elevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isLeft ? Color.subtextAccent.opacity(0.22) : Tokens.Border.subtle,
                            lineWidth: 0.5
                        )
                )
            if isLeft { Spacer(minLength: 40) }
        }
    }
}
