import SwiftUI

/// Computes p50/p95 latency summaries from Phase 0 `ux.perf` event-log entries.
struct PerformanceBaselineSheet: View {
    @Environment(CMSStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var summaries: [MetricSummary] {
        MetricSummary.build(from: store.eventLog.entries)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 700, height: 500)
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Performance baseline")
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    private var subtitle: String {
        if summaries.isEmpty {
            return "No ux.perf samples yet. Trigger a few core flows first."
        }
        let totalSamples = summaries.reduce(0) { $0 + $1.sampleCount }
        return "\(summaries.count) metric\(summaries.count == 1 ? "" : "s"), \(totalSamples) sample\(totalSamples == 1 ? "" : "s")."
    }

    @ViewBuilder
    private var content: some View {
        if summaries.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.subtextAccent)
                Text("No baseline data yet.")
                    .font(.callout)
                Text("Run key flows (open project, save, palette navigation), then reopen this sheet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section {
                    ForEach(summaries) { summary in
                        metricRow(summary)
                    }
                } footer: {
                    Text("p50 and p95 are computed from in-session `ux.perf` events.")
                        .font(.caption)
                }
            }
            .listStyle(.inset)
        }
    }

    @ViewBuilder
    private func metricRow(_ summary: MetricSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(summary.name)
                    .font(.callout.weight(.semibold))
                Spacer()
                Text("\(summary.sampleCount) sample\(summary.sampleCount == 1 ? "" : "s")")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                statPill(label: "p50", valueMs: summary.p50Ms)
                statPill(label: "p95", valueMs: summary.p95Ms)
                statPill(label: "min", valueMs: summary.minMs)
                statPill(label: "max", valueMs: summary.maxMs)
            }

            if let latest = summary.latestMetadata, !latest.isEmpty {
                Text(latest)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func statPill(label: String, valueMs: Int) -> some View {
        HStack(spacing: 5) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(valueMs)ms")
                .font(.caption.monospacedDigit().weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.5), in: Capsule())
    }
}

private struct MetricSummary: Identifiable {
    let id: String
    let name: String
    let sampleCount: Int
    let p50Ms: Int
    let p95Ms: Int
    let minMs: Int
    let maxMs: Int
    let latestMetadata: String?

    static func build(from entries: [EventLog.Entry]) -> [MetricSummary] {
        var buckets: [String: [PerfSample]] = [:]
        for entry in entries where entry.category == "ux.perf" {
            guard let sample = PerfSample.parse(entry.message) else { continue }
            buckets[sample.name, default: []].append(sample)
        }

        return buckets.keys.sorted().compactMap { key in
            guard let samples = buckets[key], !samples.isEmpty else { return nil }
            let latencies = samples.map(\.latencyMs).sorted()
            let p50 = percentile(50, in: latencies)
            let p95 = percentile(95, in: latencies)
            let minValue = latencies.first ?? 0
            let maxValue = latencies.last ?? 0
            let latestMeta = samples.reversed().compactMap(\.metadata).first
            return MetricSummary(
                id: key,
                name: key,
                sampleCount: latencies.count,
                p50Ms: p50,
                p95Ms: p95,
                minMs: minValue,
                maxMs: maxValue,
                latestMetadata: latestMeta
            )
        }
    }

    private static func percentile(_ p: Int, in values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        let bounded = min(max(p, 0), 100)
        if values.count == 1 { return values[0] }
        let rank = Double(bounded) / 100.0 * Double(values.count - 1)
        let index = Int(rank.rounded(.toNearestOrAwayFromZero))
        return values[min(max(index, 0), values.count - 1)]
    }
}

private struct PerfSample {
    let name: String
    let latencyMs: Int
    let metadata: String?

    static func parse(_ message: String) -> PerfSample? {
        guard let colon = message.firstIndex(of: ":") else { return nil }
        let name = String(message[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
        let remainder = String(message[message.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let msRange = remainder.range(of: "ms") else { return nil }
        let valueToken = remainder[..<msRange.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let latency = Int(valueToken) else { return nil }

        let metadata: String? = {
            guard let open = remainder.firstIndex(of: "("),
                  let close = remainder.lastIndex(of: ")"),
                  open < close else {
                return nil
            }
            return String(remainder[remainder.index(after: open)..<close])
        }()

        return PerfSample(name: name, latencyMs: latency, metadata: metadata)
    }
}
