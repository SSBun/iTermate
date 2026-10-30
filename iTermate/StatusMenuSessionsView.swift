import SwiftUI

/// Filters live Agent panes rather than accumulating a history of completed turns.
private enum StatusMenuFilter: String, CaseIterable, Identifiable {
    /// Every confirmed non-running Agent, including read completions and idle panes.
    case all = "All"
    /// Agents explicitly waiting for a response.
    case waiting = "Waiting"
    /// Finished results that have not been viewed, excluding failures.
    case unread = "Unread"
    /// Failed or interrupted work, independent of whether it has been viewed.
    case failed = "Failed"

    var id: String { rawValue }

    func includes(_ entry: ItermStore.MenuSession) -> Bool {
        switch self {
        case .all:
            true
        case .waiting:
            entry.status == .awaitingInput
        case .unread:
            entry.isUnread
        case .failed:
            entry.isFailure
        }
    }

    var explanation: String {
        switch self {
        case .all:
            "Non-running Agents · includes read results and idle sessions"
        case .waiting:
            "Viewing a session does not dismiss its request."
        case .unread:
            "One result per session, not a history of completed turns."
        case .failed:
            "Viewing a failure does not resolve it."
        }
    }
}

/// The menu's selection is local; observed states and read acknowledgements belong to the Store.
struct StatusMenuSessionsView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var store: ItermStore

    @ObservedObject var archives: PiSessionArchives

    @State private var filter: StatusMenuFilter = .waiting

    @State private var hasSelectedFilter = false

    @State private var pendingSessionID: String?

    @State private var actionError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AGENT SESSIONS")
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                ForEach(StatusMenuFilter.allCases) { candidate in
                    Button {
                        filter = candidate
                        hasSelectedFilter = true
                        actionError = nil
                    } label: {
                        HStack(spacing: 5) {
                            Text(candidate.rawValue)
                            Text(count(for: candidate).formatted())
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                        .background {
                            if filter == candidate {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.primary.opacity(0.09))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(candidate.rawValue), \(count(for: candidate)) sessions")
                    .accessibilityAddTraits(filter == candidate ? .isSelected : [])
                }
            }
            .padding(3)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 9))

            HStack {
                Text("\(visibleSessions.count) sessions")
                    .foregroundStyle(.secondary)
                Spacer()
                if filter == .unread {
                    Button("Mark All Read") {
                        store.markMenuCompletionsRead()
                    }
                    .buttonStyle(.borderless)
                    .disabled(visibleSessions.isEmpty || pendingSessionID != nil)
                }
            }
            .font(.caption2)
            .frame(height: 20)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if visibleSessions.isEmpty {
                        emptyState
                    } else {
                        ForEach(visibleSessions) { entry in
                            Button {
                                activate(entry)
                            } label: {
                                StatusMenuSessionRow(
                                    entry: entry,
                                    title: archives.sessionTitle(for: entry.session, terminal: .iTerm2)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(pendingSessionID != nil)
                        }
                    }
                }
                .padding(.horizontal, 3)
            }
            .frame(height: 248)
            .id(filter)

            Text(actionError ?? filter.explanation)
                .font(.caption2)
                .foregroundStyle(actionError == nil ? Color.secondary : .red)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .topLeading)
                .help(actionError ?? "Unknown states and ordinary Shell commands are not included.")
        }
        .onAppear {
            hasSelectedFilter = false
            selectInitialFilter()
        }
        .onChange(of: store.statusMenuSessions) { _ in
            selectInitialFilter()
        }
    }

    /// Sorts the current snapshot, preserving terminal order for equal or missing timestamps.
    private var visibleSessions: [ItermStore.MenuSession] {
        store.statusMenuSessions.enumerated().filter { filter.includes($0.element) }.sorted { first, second in
            let firstTime = first.element.changedAt
            let secondTime = second.element.changedAt
            if firstTime != secondTime {
                guard let firstTime else { return false }
                guard let secondTime else { return true }
                return filter == .waiting ? firstTime < secondTime : firstTime > secondTime
            }
            return first.offset < second.offset
        }.map(\.element)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(store.statusMenuConnectionState == .connected ? "No matching Agent sessions" : "Session status unavailable")
                .font(.callout)
            Text(store.statusMenuConnectionState == .connected
                 ? "Running, unobserved and ordinary Shell sessions are not shown."
                 : "Waiting for a fresh iTerm2 snapshot.")
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 65)
    }

    private func count(for filter: StatusMenuFilter) -> Int {
        store.statusMenuSessions.filter(filter.includes).count
    }

    private func selectInitialFilter() {
        guard !hasSelectedFilter, !store.statusMenuSessions.isEmpty else {
            return
        }
        filter = [.waiting, .failed, .unread, .all].first { count(for: $0) > 0 } ?? .all
        hasSelectedFilter = true
    }

    private func activate(_ entry: ItermStore.MenuSession) {
        actionError = nil
        pendingSessionID = entry.id
        store.activateMenuSession(entry) { error in
            pendingSessionID = nil
            if let error {
                actionError = error
            } else {
                dismiss()
            }
        }
    }
}

private struct StatusMenuSessionRow: View {
    let entry: ItermStore.MenuSession

    let title: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            StatusMenuPixelIcon(kind: icon, color: iconColor)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .layoutPriority(1)
                    Spacer(minLength: 4)
                    if let time = entry.changedAt, time.isFinite, time > 0 {
                        Text(Date(timeIntervalSince1970: time), style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Text(statusTitle)
                    .font(.caption)
                    .foregroundStyle(entry.isFailure ? Color.red : .secondary)
                Text("\(entry.session.environmentAgentKind?.displayName ?? "Agent") · \(entry.session.workingDirectoryName ?? "Unknown project")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .help("\(title)\n\(entry.session.path ?? "Unknown project")\n\(statusTitle)")
        .accessibilityElement(children: .combine)
    }

    private var statusTitle: String {
        switch entry.status {
        case .awaitingInput:
            "Waiting for your reply"
        case .interrupted:
            "Interrupted"
        case .finished:
            if entry.isFailure {
                "Failed · exit \(entry.exitStatus.map(String.init) ?? "unknown")"
            } else {
                entry.isUnread ? "Finished · unread" : "Finished · read"
            }
        case .idle:
            "Idle"
        case .running:
            "Running"
        }
    }

    private var icon: StatusMenuPixelIcon.Kind {
        if entry.isFailure {
            return .failed
        }
        switch entry.status {
        case .awaitingInput:
            return .waiting
        case .finished:
            return .finished
        default:
            return .idle
        }
    }

    private var iconColor: Color {
        switch icon {
        case .waiting:
            .orange
        case .failed:
            .red
        case .finished:
            .green
        default:
            .secondary
        }
    }
}

/// Small animated pixel glyphs for the menu, with system Reduce Motion support.
struct StatusMenuPixelIcon: View {
    enum Kind {
        case waiting, finished, failed, idle, running, connected

        var rows: [UInt8] {
            switch self {
            case .waiting:
                [14, 17, 1, 2, 4, 0, 4]
            case .finished:
                [0, 1, 2, 20, 8, 0, 0]
            case .failed:
                [17, 10, 4, 10, 17, 0, 0]
            case .idle:
                [0, 14, 17, 17, 17, 14, 0]
            case .running:
                [4, 12, 31, 6, 12, 8, 0]
            case .connected:
                [0, 4, 14, 31, 14, 4, 0]
            }
        }
    }

    let kind: Kind

    let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.15, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let phase = reduceMotion ? 0 : sin(timeline.date.timeIntervalSinceReferenceDate * 3)
                let pitch = min(size.width / 7, size.height / 9)
                let offsetX = (size.width - pitch * 5) / 2
                let offsetY = (size.height - pitch * 7) / 2
                let opacity = reduceMotion ? 1 : 0.8 + 0.2 * phase
                for (row, bits) in kind.rows.enumerated() {
                    for column in 0..<5 where bits & (1 << (4 - column)) != 0 {
                        let rect = CGRect(
                            x: offsetX + CGFloat(column) * pitch,
                            y: offsetY + CGFloat(row) * pitch,
                            width: pitch * 0.85,
                            height: pitch * 0.85
                        )
                        context.fill(Path(rect), with: .color(color.opacity(opacity)))
                    }
                }
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
