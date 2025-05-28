//
//  SettingsView.swift
//  Telescope
//
//  Created by Joaquin Uriarte on 5/1/25.
//

//  SettingsView.swift
import SwiftUI
import AppKit
import KeyboardShortcuts

struct SettingsView: View {
    // Selected tab
    @State private var selection: Tab = .instructions
    @Environment(\.presentationMode) var presentation
    
    enum Tab: String, CaseIterable, Identifiable {
        case instructions   = "Instructions"
        case bookmarks    = "Access"
        case shortcut     = "Shortcut"
        var id: String { rawValue }
        
        var systemImage: String {
            switch self {
            case .instructions: return "list.bullet"
            case .shortcut:   return "keyboard"
            case .bookmarks:  return "bookmark"
            }
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                
                // ── 1. Header: 15% of height ─────────────────────────
                VStack(spacing: 0) {
                    Label("Welcome to Telescope!", systemImage: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 20))
                        .padding(.bottom, 10)
                    Text("Find your files, just by asking.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(height: geo.size.height * 0.15)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal)
                .padding(.top, 20)
                
                // ── 2. Tab Picker: 10% of height ───────────────────────
                Picker("", selection: $selection) {
                    ForEach(Tab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.systemImage)
                            .tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .frame(height: geo.size.height * 0.10)
                .padding(.bottom, 10)
                
                // ── 3. Content Area: 60% of height ────────────────────
                Group {
                    switch selection {
                    case .instructions: InstructionsTab()
                    case .bookmarks:   BookmarkSettings()
                    case .shortcut:    ShortcutSettings()
                    }
                }
                .frame(height: geo.size.height * 0.50)
                .padding(.horizontal)
                
                // ── 4. Footer / Quit: 15% of height ───────────────────
                VStack(spacing: 0) {
                    Button("Quit Telescope") {
                        NSApplication.shared.terminate(nil)
                    }
                    .padding(.bottom, 10)
                    Text(
                        "Quitting Telescope means you can’t summon it with the shortcut anymore.\n" +
                        "To reopen, launch the Telescope app manually."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                }
                .frame(height: geo.size.height * 0.25)
                .frame(maxWidth: .infinity, alignment: .bottom)
                .padding(.horizontal)
            }
            // ensure the stack fills its container and clips any overflow
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .frame(minWidth: 460, minHeight: 400)
    }
}

// MARK: - Placeholder tab contents
private struct InstructionsTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // 1. Overview
                Text("How Telescope Works")
                    .font(.title3).bold()
                    .foregroundColor(.secondary)
                Text("""
Telescope helps you find files on your computer just by asking—no computer jargon, just plain, everyday language.
""")
                .foregroundColor(.secondary)
                
                // 2. Shortcut
                Text("Opening & Closing the App")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("""
You can summon or hide Telescope with a shortcut. The default is **⌘ + L**, but you can change it in the Shortcut settings.
""")
                .foregroundColor(.secondary)
                // 3. Permissions
                Text("Permissions")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("""
To work, Telescope needs permission to read your files. You can control which folders it can access in the Access settings.
""")
                .foregroundColor(.secondary)
                
                // 4. Supported Search Types & Examples
                Text("Supported Searches & Examples")
                    .font(.headline)
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text("•").bold()
                        Text("**File name** — “Anything named **Budget**”")
                    }
                    .foregroundColor(.secondary)
                    HStack(alignment: .top) {
                        Text("•").bold()
                        Text("**File type** — “**PDFs/Images** from last week”")
                    }
                    .foregroundColor(.secondary)
                    HStack(alignment: .top) {
                        Text("•").bold()
                        Text("**Date** — “Files I edited **yesterday**”")
                    }
                    .foregroundColor(.secondary)
                    HStack(alignment: .top) {
                        Text("•").bold()
                        Text("**Location** — “Photos from my **Downloads** folder”")
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }
}


//private struct AppearanceSettings: View {
//    @State private var selectedColor: Color = Color(NSColor.windowBackgroundColor)
//    @EnvironmentObject var settings: AppSettings
//    private let availableColors: [Color] = [Color(NSColor.windowBackgroundColor), .red, .green, .blue, .orange, .purple, .gray]
//    private let colorNames: [String] = ["Default", "Red", "Green", "Blue", "Orange", "Purple", "Gray"]
//    var body: some View {
//        VStack {
//            Spacer()
//            HStack(spacing: 12) {
//                Text("Change Telescope’s background color:")
//                    .foregroundColor(.secondary)
//
//                Picker("", selection: $selectedColor) {
//                    ForEach(0..<availableColors.count, id: \.self) { index in
//                        Text(colorNames[index])
//                            .tag(availableColors[index])
//                    }
//                }
//                .pickerStyle(MenuPickerStyle())
//                .labelsHidden()
//                .frame(width: 100)
//                .onChange(of: selectedColor) { newColor in
//                    settings.backgroundColor = newColor
//                }
//            }
//            Spacer()
//        }
//        .frame(maxWidth: .infinity)
//        .padding()
//    }
//}
private struct ShortcutSettings: View {
    @State private var showSavedAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // 1. Title band
            Text("Change the global shortcut that summons Telescope.")
                .font(.headline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // 2. Instruction band
            HStack(spacing: 8) {
                Text("Current shortcut:")
                    .foregroundColor(.secondary)
                if let shortcut = KeyboardShortcuts.Name.summon.shortcut {
                    Text(shortcut.description)
                        .foregroundColor(.primary)
                } else {
                    Text("None set")
                        .foregroundColor(.secondary)
                }
            }
            // 3. Instructions
            Text("To customize shortcut click the box, press Command/Control + a key, and click save):")
                .foregroundColor(.secondary)

            // 4. Button band
            HStack(spacing: 75) {
                KeyboardShortcuts.Recorder(for: .summon)
                    .frame(width: 50, height: 30)

                Button("Save Shortcut") {
                    showSavedAlert = true
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .alert(
                    "Shortcut Saved",
                    isPresented: $showSavedAlert
                ) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Your new shortcut is \(KeyboardShortcuts.Name.summon.shortcut?.description ?? "none").")
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        // Fill its container and pin to top
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}


private struct BookmarkSettings: View {
    @State private var folders: [String] = []

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 10) {
                // 1. Header — 10% of height
                Text("These are the folders Telescope has access to:")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(height: geo.size.height * 0.10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                // 2. List — 80% of height
                List {
                    ForEach(folders, id: \.self) { folder in
                        HStack {
                            Text(folder).foregroundColor(.secondary)
                            Spacer()
                            Button {
                                BookmarkService.shared.deleteBookmark(named: folder)
                                reloadFolders()
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        // Give every row the same vertical padding
                        .padding(.vertical, 8)
                    }
                }
                .frame(height: geo.size.height * 0.80)
                .listStyle(PlainListStyle())
                .padding(.horizontal)

                // 3. Footer buttons — 10% of height
                HStack {
                    Spacer()
                    Button("Add Folder") {
                        Task {
                            do {
                                _ = try await BookmarkService.shared.addBookmarks()
                                reloadFolders()
                            } catch { }
                        }
                    }
                    Spacer()
                    Button("Delete All") {
                        BookmarkService.shared.deleteAllBookmarks()
                        reloadFolders()
                    }
                    Spacer()
                }
                .frame(height: geo.size.height * 0.10)
                .padding(.horizontal)
            }
            // Make the VStack fill the entire GeometryReader
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear(perform: reloadFolders)
    }

    private func reloadFolders() {
        folders = BookmarkService.shared.bookmarkFolderNames()
    }
}

//struct SettingsView_Previews: PreviewProvider {
//    static var previews: some View {
//        SettingsView()
//    }
//}
