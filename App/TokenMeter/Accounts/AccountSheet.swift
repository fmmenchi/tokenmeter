import AppKit
import SwiftUI
import TokenMeterCore

/// The sheet of Add an account… and Edit… (ADR 0014): the tool, the folder with Choose…, a line that says what was
/// found there, and the title, filled in with the email as soon as the folder is one of the tool's. Add and Save write
/// the entry; Edit keeps the tool and the id.
struct AccountSheet: View {
    /// Add an account… opens it on a new entry; Edit… on an existing one.
    enum Target: Identifiable {
        case new
        case existing(AccountSummary)

        var id: String {
            switch self {
            case .new: "new"
            case .existing(let account): account.id
            }
        }
    }

    let meter: Meter
    let target: Target
    @Environment(\.dismiss) private var dismiss
    @State private var tool: AccountTool = .claudeCode
    @State private var folder = ""
    @State private var title = ""
    /// True once the person typed a title: it is theirs then, and the email no longer replaces it.
    @State private var titleIsTheirs = false
    @State private var check: Meter.FolderCheck?
    @State private var error: String?
    @State private var saving = false

    private var existing: AccountSummary? {
        if case .existing(let account) = target { return account } else { return nil }
    }

    /// An entry whose integration is not a tool's has no folder here: only its title can change.
    private var hasFolder: Bool { existing.map { $0.tool != nil } ?? true }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(existing.map { "Edit \($0.title)" } ?? "Add an account").font(.headline)
            Text(explanation).font(.caption).foregroundStyle(.secondary)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
                if hasFolder {
                    GridRow {
                        Text("Tool").gridColumnAlignment(.trailing)
                        Picker("Tool", selection: $tool) {
                            ForEach(AccountTool.allCases, id: \.self) { Text($0.name).tag($0) }
                        }
                        .pickerStyle(.segmented).labelsHidden().fixedSize().disabled(existing != nil)
                    }
                    GridRow {
                        Text("Folder")
                        HStack(spacing: 8) {
                            TextField("~/.claude-work", text: $folder).textFieldStyle(.roundedBorder).font(.body.monospaced())
                            Button("Choose…", action: choose)
                        }
                    }
                    GridRow {
                        Text("")
                        Text(checkText).font(.caption).foregroundStyle(.secondary)
                    }
                }
                GridRow {
                    Text("Title")
                    TextField("Claude · work", text: $title).textFieldStyle(.roundedBorder)
                        .onChange(of: title) { _, _ in if !saving { titleIsTheirs = true } }
                }
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(existing == nil ? "Add" : "Save", action: save)
                    .keyboardShortcut(.defaultAction).disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 500)
        .onAppear(perform: start)
        .task(id: folder) { await lookAtFolder() }
    }

    private var explanation: String {
        existing == nil
            ? "An account is a folder the tool reads: the one in CLAUDE_CONFIG_DIR for Claude Code, in CODEX_HOME for the Codex CLI. The entry goes into providers.json, with an id made from the title; the folder's login, settings and logs stay where they are."
            : "The title is the name on the card and in the notices; the folder is the one the tool reads. The id of the entry does not change, so its history, its order and its notices stay. The tool cannot change: remove the account and add it again."
    }

    private var checkText: String {
        let what = tool == .claudeCode ? ".claude.json and projects/" : "auth.json and config.toml"
        switch check {
        case nil: return folder.isEmpty ? "The folder \(tool.name) reads; Choose… opens it." : "Looking…"
        case .missing: return "No folder there yet. It is created the first time \(tool.name) runs with it."
        case .notTheTools: return "A folder, but \(tool.name) has not used it: no \(what) in it."
        case .found(let email): return "Found: it has \(what)" + (email.map { ", signed in as \($0)." } ?? "; not signed in.")
        }
    }

    private var canSave: Bool {
        !saving && !title.trimmingCharacters(in: .whitespaces).isEmpty && (!hasFolder || !folder.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private func start() {
        guard let existing else { return }
        tool = existing.tool ?? .claudeCode
        folder = existing.home
        title = existing.title
        titleIsTheirs = true
    }

    private func lookAtFolder() async {
        guard hasFolder, !folder.trimmingCharacters(in: .whitespaces).isEmpty else { check = nil; return }
        let result = await meter.checkFolder(folder, tool: tool)
        check = result
        if case .found(let email?) = result, !titleIsTheirs {
            saving = true
            title = email
            saving = false
        }
    }

    /// The system's Open panel, on folders, hidden ones shown: an account's folder is one.
    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.showsHiddenFiles = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        panel.prompt = "Choose"
        panel.message = "The folder \(tool.name) reads for this account"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        folder = Meter.tilde(url.path)
    }

    private func save() {
        saving = true
        error = nil
        let title = title.trimmingCharacters(in: .whitespaces)
        Task {
            let failure: String?
            if let existing {
                failure = await meter.editAccount(existing.id, title: title, folder: hasFolder ? folder : nil)
            } else {
                failure = await meter.addAccount(tool: tool, folder: folder, title: title)
            }
            saving = false
            if let failure { error = failure } else { dismiss() }
        }
    }
}
