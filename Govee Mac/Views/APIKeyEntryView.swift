import SwiftUI

/// A polished SwiftUI view for entering and saving the Govee API key securely to Keychain.
/// Integrates with `SettingsStore` and uses `APIKeyKeychain` for persistence.
struct APIKeyEntryView: View {
    @EnvironmentObject var settings: SettingsStore

    @State private var apiKey: String = ""
    @State private var showKey: Bool = false
    @State private var isSaving: Bool = false
    @State private var saveSucceeded: Bool = false
    @State private var errorMessage: String?
    @State private var copied: Bool = false

    @Namespace private var animation

    private var isDirty: Bool { apiKey != (settings.goveeApiKey) }
    private var isValid: Bool { !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && apiKey.count >= 10 }

    var body: some View {
        VStack(spacing: 28) {
            header
            keyEntryCard
            actionBar
            if saveSucceeded { successBanner }
            if let error = errorMessage { errorBanner(error) }
            Spacer(minLength: 0)
        }
        .padding(40)
        .background(backgroundGradient.ignoresSafeArea())
        .onAppear { loadExisting() }
        .animation(.spring(duration: 0.55), value: saveSucceeded)
        .animation(.easeInOut, value: errorMessage)
        .frame(minWidth: 560, minHeight: 420)
    }

    // MARK: Sections
    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.linearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Govee API Key")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("Speichere deinen Schlüssel sicher im Schlüsselbund. Er wird für Cloud-Funktionen benötigt.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var keyEntryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Schlüssel eingeben")
                .font(.headline)
                .foregroundStyle(.primary)
            ZStack(alignment: .trailing) {
                Group {
                    if showKey {
                        TextField("API Key", text: $apiKey, prompt: Text("API Key"))
                            .textFieldStyle(.plain)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("API Key", text: $apiKey)
                            .textFieldStyle(.plain)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.regularMaterial))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(borderGradient, lineWidth: 1)
                )

                HStack(spacing: 12) {
                    Button { showKey.toggle() } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help(showKey ? "Schlüssel verbergen" : "Schlüssel anzeigen")

                    if !apiKey.isEmpty {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(apiKey, forType: .string)
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(copied ? .green : .secondary)
                                .padding(6)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("In Zwischenablage kopieren")
                    }
                }
                .padding(.trailing, 10)
            }
            validationHints
        }
        .padding(20)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var validationHints: some View {
        VStack(alignment: .leading, spacing: 6) {
            if apiKey.isEmpty {
                Label("Schlüssel darf nicht leer sein", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else if apiKey.count < 10 {
                Label("Sehr kurz – bitte prüfen", systemImage: "questionmark.circle")
                    .foregroundStyle(.orange)
                    .font(.caption)
            } else if !isDirty {
                Label("Unverändert", systemImage: "circle")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else if isValid {
                Label("Bereit zum Speichern", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
        .animation(.easeInOut, value: apiKey)
    }

    private var actionBar: some View {
        HStack(spacing: 16) {
            Button(role: .destructive) { clearKey() } label: {
                Label("Löschen", systemImage: "trash")
            }
            .disabled(settings.goveeApiKey.isEmpty && apiKey.isEmpty)

            Spacer()

            Button { Task { await save() } } label: {
                if isSaving {
                    ProgressView().progressViewStyle(.circular)
                } else {
                    Label("Speichern", systemImage: "checkmark.seal")
                        .labelStyle(.titleAndIcon)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .controlSize(.large)
            .disabled(!isValid || !isDirty || isSaving)
        }
        .padding(.top, 4)
    }

    private var successBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
            Text("Schlüssel erfolgreich im Schlüsselbund gespeichert")
                .font(.subheadline)
            Spacer()
            Button("Fertig") { saveSucceeded = false }
                .buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.thinMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.green.opacity(0.35), lineWidth: 1)
        )
        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "xmark.octagon.fill")
                .font(.title2)
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
            Spacer()
            Button("Schließen") { errorMessage = nil }
                .buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.thinMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.red.opacity(0.35), lineWidth: 1)
        )
        .transition(.opacity)
    }

    // MARK: Actions
    private func loadExisting() {
        if let existing = try? APIKeyKeychain.load(), !existing.isEmpty {
            apiKey = existing
            settings.goveeApiKey = existing // keep settings in sync for other views
        }
    }
    private func clearKey() {
        apiKey = ""
        do {
            try APIKeyKeychain.delete()
            settings.goveeApiKey = ""
            saveSucceeded = false
        } catch { errorMessage = "Fehler beim Löschen: \(error)" }
    }
    private func save() async {
        guard isValid else { return }
        isSaving = true
        errorMessage = nil
        do {
            try APIKeyKeychain.save(key: apiKey)
            settings.goveeApiKey = apiKey
            withAnimation { saveSucceeded = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { saveSucceeded = false } }
        } catch {
            errorMessage = "Speichern fehlgeschlagen: \(error)"
        }
        isSaving = false
    }

    // MARK: Styling Helpers
    private var backgroundGradient: some View {
        LinearGradient(colors: [Color(NSColor.windowBackgroundColor).opacity(0.95), Color.blue.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    private var cardBackground: some View { RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial) }
    private var cardBorder: some View { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(borderGradient, lineWidth: 1) }
    private var borderGradient: LinearGradient { LinearGradient(colors: [.blue.opacity(0.45), .purple.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing) }
}

#Preview {
    APIKeyEntryView()
        .environmentObject(SettingsStore())
        .frame(width: 600, height: 480)
}
