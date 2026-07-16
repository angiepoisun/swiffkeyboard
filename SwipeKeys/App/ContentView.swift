import SwiftUI

struct ContentView: View {
    @State private var enabledLanguages: [SupportedLanguage] = LanguageSettings.enabledLanguages()
    @State private var swipeTypingEnabled: Bool = AppGroup.defaults.object(forKey: AppGroup.Key.swipeTypingEnabled) == nil
        ? true
        : AppGroup.defaults.bool(forKey: AppGroup.Key.swipeTypingEnabled)
    @State private var autoCapitalize: Bool = AppGroup.defaults.object(forKey: AppGroup.Key.autoCapitalize) == nil
        ? true
        : AppGroup.defaults.bool(forKey: AppGroup.Key.autoCapitalize)
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Swipe to type. Swipe the spacebar to switch language.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("1. Enable the keyboard") {
                    setupStep(text: "Settings → General → Keyboard → Keyboards → Add New Keyboard → SwipeKeys")
                    setupStep(text: "Tap SwipeKeys in the keyboard list to switch it on. Full Access is not required.")
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                    }
                }

                Section {
                    ForEach(SupportedLanguage.allCases) { language in
                        Toggle(isOn: bindingFor(language)) {
                            HStack {
                                Text(language.flag)
                                VStack(alignment: .leading) {
                                    Text(language.displayName)
                                    Text(layoutLabel(for: language))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onMove(perform: moveLanguage)
                } header: {
                    Text("2. Languages")
                } footer: {
                    Text("Drag to reorder. This is the order the spacebar cycles through when you swipe it left or right — no globe key needed.")
                }

                Section("3. Typing") {
                    Toggle("Swipe (glide) typing", isOn: $swipeTypingEnabled)
                        .onChange(of: swipeTypingEnabled) { newValue in
                            AppGroup.defaults.set(newValue, forKey: AppGroup.Key.swipeTypingEnabled)
                        }
                    Toggle("Auto-capitalize sentences", isOn: $autoCapitalize)
                        .onChange(of: autoCapitalize) { newValue in
                            AppGroup.defaults.set(newValue, forKey: AppGroup.Key.autoCapitalize)
                        }
                }
            }
            .navigationTitle("SwipeKeys")
            .toolbar {
                EditButton()
            }
        }
    }

    private func layoutLabel(for language: SupportedLanguage) -> String {
        switch language {
        case .englishUS: return "QWERTY"
        case .spanish: return "QWERTY + Ñ"
        case .french: return "AZERTY"
        case .german: return "QWERTZ"
        }
    }

    private func bindingFor(_ language: SupportedLanguage) -> Binding<Bool> {
        Binding(
            get: { enabledLanguages.contains(language) },
            set: { isOn in
                if isOn {
                    if !enabledLanguages.contains(language) {
                        enabledLanguages.append(language)
                    }
                } else if enabledLanguages.count > 1 {
                    enabledLanguages.removeAll { $0 == language }
                }
                LanguageSettings.setEnabledLanguages(enabledLanguages)
            }
        )
    }

    private func moveLanguage(from source: IndexSet, to destination: Int) {
        enabledLanguages.move(fromOffsets: source, toOffset: destination)
        LanguageSettings.setEnabledLanguages(enabledLanguages)
    }

    private func setupStep(text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
