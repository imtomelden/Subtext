import AppKit
import SwiftUI

/// Settings-initiated audit surfacing:
///   • Orphan images (on disk, never referenced)
///   • Broken image references (referenced from content, missing on disk)
///   • SEO checklist failures per project
///
/// Intentionally read-only. Clicking a row reveals the asset in Finder or
/// opens the owning project so the user can fix the underlying issue.
struct SiteHealthSheet: View {
    @Environment(CMSStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    enum Tab: String, CaseIterable, Identifiable {
        case orphans, broken, seo
        var id: String { rawValue }

        var title: String {
            switch self {
            case .orphans: "Orphan images"
            case .broken: "Broken references"
            case .seo: "Project SEO"
            }
        }
    }

    @State private var selected: Tab = .orphans
    @State private var report: AssetAudit.AuditReport?
    @State private var loading: Bool = false
    private let audit = AssetAudit()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Picker("", selection: $selected) {
                ForEach(Tab.allCases) { tab in
                    Text("\(tab.title) \(count(for: tab))")
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            content
        }
        .frame(width: 620, height: 480)
        .task { await refresh() }
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Site health").font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(loading)
            .help("Re-run the audit")

            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    private var subtitle: String {
        guard let report else { return "Scanning /public/images and project content…" }
        return "\(report.assets.count) assets • \(ByteFormatter.string(for: report.totalBytes)) on disk"
    }

    private func count(for tab: Tab) -> String {
        guard let report else { return "" }
        let n: Int = switch tab {
        case .orphans: report.orphans.count
        case .broken: report.broken.count
        case .seo: report.seoIssues.values.reduce(0) { $0 + $1.count }
        }
        return n == 0 ? "" : "(\(n))"
    }

    @ViewBuilder
    private var content: some View {
        if loading && report == nil {
            ProgressView("Auditing…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let report {
            switch selected {
            case .orphans: orphansList(report)
            case .broken: brokenList(report)
            case .seo: seoList(report)
            }
        } else {
            Text("Scan failed.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Orphans

    @ViewBuilder
    private func orphansList(_ report: AssetAudit.AuditReport) -> some View {
        if report.orphans.isEmpty {
            emptyState(icon: "checkmark.seal.fill",
                       text: "No orphan images.",
                       detail: "Every image under /public/images is referenced somewhere in your content.")
        } else {
            VStack(spacing: 0) {
                HStack {
                    Text("\(report.orphans.count) orphan image\(report.orphans.count == 1 ? "" : "s"), \(ByteFormatter.string(for: report.orphanBytes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

                List {
                    ForEach(report.orphans) { asset in
                        OrphanRow(asset: asset)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Broken

    @ViewBuilder
    private func brokenList(_ report: AssetAudit.AuditReport) -> some View {
        if report.broken.isEmpty {
            emptyState(icon: "checkmark.seal.fill",
                       text: "No broken references.",
                       detail: "Every image path referenced in content resolves to a file under /public/images.")
        } else {
            List {
                ForEach(report.broken, id: \.self) { path in
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(path)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.inset)
        }
    }

    // MARK: - SEO

    @ViewBuilder
    private func seoList(_ report: AssetAudit.AuditReport) -> some View {
        if report.seoIssues.isEmpty {
            emptyState(icon: "checkmark.seal.fill",
                       text: "All projects pass the SEO checklist.",
                       detail: "Title, description, thumbnail, date, and slug are filled in and consistent across every project.")
        } else {
            List {
                ForEach(report.seoIssues.keys.sorted(), id: \.self) { fileName in
                    Section {
                        ForEach(report.seoIssues[fileName] ?? []) { issue in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: issue.severity == .error ? "exclamationmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundStyle(issue.severity == .error ? .red : Color.subtextWarning)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(issue.message).font(.callout)
                                    Text(issue.code)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Button {
                            store.selectedProjectFileName = fileName
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.forward.app")
                                Text(projectTitle(for: fileName))
                                    .font(.callout.weight(.semibold))
                            }
                            .foregroundStyle(Color.subtextAccent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private func projectTitle(for fileName: String) -> String {
        if let doc = store.projects.first(where: { $0.fileName == fileName }) {
            return doc.frontmatter.title.isEmpty ? fileName : doc.frontmatter.title
        }
        return fileName
    }

    // MARK: - Shared

    @ViewBuilder
    private func emptyState(icon: String, text: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(Color.subtextAccent)
            Text(text).font(.callout.weight(.medium))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func refresh() async {
        loading = true
        defer { loading = false }
        let splash = store.splashContent
        let projects = store.projects
        let result = await audit.audit(splash: splash, projects: projects)
        self.report = result
        let seoCount = result.seoIssues.values.reduce(0) { $0 + $1.count }
        let total = result.orphans.count + result.broken.count + seoCount
        store.recordSiteHealthIssueTotal(total)
    }
}

private struct OrphanRow: View {
    let asset: AssetAudit.AssetEntry

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            AssetThumbnail(src: asset.relativePath, size: 44, cornerRadius: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.relativePath)
                    .font(.callout.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(metadataLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([asset.url])
            } label: {
                Image(systemName: "arrow.up.right.square")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Reveal in Finder")
        }
        .padding(.vertical, 4)
    }

    private var metadataLine: String {
        var parts: [String] = [ByteFormatter.string(for: asset.sizeBytes)]
        if let size = asset.pixelSize {
            parts.append("\(Int(size.width))×\(Int(size.height))")
        }
        return parts.joined(separator: " · ")
    }
}
