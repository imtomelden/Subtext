import SwiftUI

/// Single source for dev-server phase visuals, tooltips, and accessibility hints.
enum DevServerPhaseVisuals {
    struct Treatment {
        var shortLabel: String
        var verboseLabel: String
        var pillHelp: String
        var primaryTitle: String
        var primarySystemImage: String
        var primaryHelp: String
        var primaryHint: String
        var showsProgressDot: Bool
        var showsPrimarySpinner: Bool
    }

    static func treatment(phase: DevServerPhase, defaultPort: Int) -> Treatment {
        switch phase {
        case .stopped:
            return Treatment(
                shortLabel: "Stopped",
                verboseLabel: "Dev server is stopped.",
                pillHelp: "Dev server: stopped. Click for full controls and log.",
                primaryTitle: "Start",
                primarySystemImage: "play.fill",
                primaryHelp: "Start the local Astro dev server (npm run dev)",
                primaryHint: "Runs preflight, then npm run dev in your website repo.",
                showsProgressDot: false,
                showsPrimarySpinner: false
            )
        case .preflighting:
            return Treatment(
                shortLabel: "Preflight…",
                verboseLabel: "Running preflight checks before launch.",
                pillHelp: "Dev server: running preflight. Click for details.",
                primaryTitle: "Cancel",
                primarySystemImage: "xmark",
                primaryHelp: "Cancel — running preflight checks…",
                primaryHint: "Stops the launch before the dev server comes online.",
                showsProgressDot: true,
                showsPrimarySpinner: true
            )
        case .starting:
            return Treatment(
                shortLabel: "Starting…",
                verboseLabel: "Waiting for dev server to come online.",
                pillHelp: "Dev server: starting. Click for details.",
                primaryTitle: "Cancel",
                primarySystemImage: "xmark",
                primaryHelp: "Cancel — waiting for dev server to come online…",
                primaryHint: "Stops the launch if the process has not finished starting.",
                showsProgressDot: true,
                showsPrimarySpinner: true
            )
        case .running(_, let p):
            return Treatment(
                shortLabel: "Running · :\(p)",
                verboseLabel: "Dev server is running on port \(p).",
                pillHelp: "Dev server: running on port \(p). Click for log and controls.",
                primaryTitle: "Stop",
                primarySystemImage: "stop.fill",
                primaryHelp: "Stop the dev server running on port \(p)",
                primaryHint: "Sends SIGTERM and waits for the process to exit.",
                showsProgressDot: false,
                showsPrimarySpinner: false
            )
        case .stopping:
            return Treatment(
                shortLabel: "Stopping…",
                verboseLabel: "Stopping the dev server process.",
                pillHelp: "Dev server: stopping. Click for details.",
                primaryTitle: "Stop",
                primarySystemImage: "stop.fill",
                primaryHelp: "Stopping… waiting for the server process to exit",
                primaryHint: "Please wait until the process has fully stopped.",
                showsProgressDot: true,
                showsPrimarySpinner: true
            )
        case .restarting:
            return Treatment(
                shortLabel: "Restarting…",
                verboseLabel: "Restarting the dev server.",
                pillHelp: "Dev server: restarting. Click for details.",
                primaryTitle: "Restart",
                primarySystemImage: "arrow.clockwise",
                primaryHelp: "Restarting… reaping then relaunching the dev server",
                primaryHint: "Stop then start in one sequence.",
                showsProgressDot: true,
                showsPrimarySpinner: true
            )
        case .failed(let failure):
            let msg = failure.message
            return Treatment(
                shortLabel: "Failed",
                verboseLabel: "\(failure.kind.label): \(msg)",
                pillHelp: "Dev server: failed — \(failure.kind.label). Click for details and log.",
                primaryTitle: "Retry",
                primarySystemImage: "arrow.clockwise",
                primaryHelp: "Retry — last failure: \(msg)",
                primaryHint: "Runs preflight and starts npm run dev again.",
                showsProgressDot: false,
                showsPrimarySpinner: false
            )
        }
    }

    static func openDevServerWindowHelp() -> String {
        "Open the Dev Server window for full controls and log"
    }

    static func openInBrowserHelp(port: Int) -> String {
        "Open http://localhost:\(port)/ in your default browser"
    }

    static func restartHelp() -> String {
        "Restart the dev server (Stop, then Start)"
    }

    static func runPreflightHelp() -> String {
        "Validate the website repo before launching the dev server"
    }

    static func repairContentHelp(repairableCount: Int) -> String {
        "Auto-fix \(repairableCount) repairable issue\(repairableCount == 1 ? "" : "s")"
    }

    static func livePreviewHelp() -> String {
        "Open live preview (⌘⌥P)"
    }
}

struct DevServerStatusPill: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var phase: DevServerPhase
    var compact: Bool
    var defaultPort: Int
    var onTap: (() -> Void)?

    private var treatment: DevServerPhaseVisuals.Treatment {
        DevServerPhaseVisuals.treatment(phase: phase, defaultPort: defaultPort)
    }

    var body: some View {
        let t = treatment
        HStack(spacing: compact ? 6 : 8) {
            statusDot
            if !compact {
                Text(t.shortLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 5 : 7)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(pillFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(pillBorder, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture {
            onTap?()
        }
        .help(t.pillHelp)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(t.verboseLabel)
        .accessibilityHint(onTap != nil ? "Opens the Dev Server window." : "")
    }

    @ViewBuilder
    private var statusDot: some View {
        let (fill, pulse) = dotStyle
        Group {
            if pulse, !reduceMotion {
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let opacity = 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 4))
                    Circle()
                        .fill(fill)
                        .frame(width: compact ? 8 : 10, height: compact ? 8 : 10)
                        .opacity(opacity)
                }
            } else {
                Circle()
                    .fill(fill)
                    .frame(width: compact ? 8 : 10, height: compact ? 8 : 10)
            }
        }
        .overlay {
            if case .running = phase {
                let fill = Color.subtextAccent
                Circle()
                    .stroke(fill.opacity(0.35), lineWidth: 3)
                    .frame(width: compact ? 14 : 16, height: compact ? 14 : 16)
            }
        }
    }

    private var dotStyle: (Color, Bool) {
        switch phase {
        case .stopped:
            return (.secondary, false)
        case .preflighting, .starting, .stopping, .restarting:
            return (Color.subtextWarning, true)
        case .running:
            return (Color.subtextAccent, false)
        case .failed:
            return (.red, false)
        }
    }

    private var pillFill: Color {
        switch phase {
        case .stopped:
            return Color.primary.opacity(0.04)
        case .preflighting, .starting, .stopping, .restarting:
            return Color.subtextWarning.opacity(0.10)
        case .running:
            return Color.subtextAccent.opacity(0.10)
        case .failed:
            return Color.red.opacity(0.10)
        }
    }

    private var pillBorder: Color {
        switch phase {
        case .stopped:
            return Color.primary.opacity(0.08)
        case .preflighting, .starting, .stopping, .restarting:
            return Color.subtextWarning.opacity(0.45)
        case .running:
            return Color.subtextAccent.opacity(0.45)
        case .failed:
            return Color.red.opacity(0.45)
        }
    }
}
