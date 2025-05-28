//
//  ContentView.swift
//  Telescope
//
//  Created by Joaquin Uriarte on 4/29/25.
//

import SwiftUI
import AppKit

// TODO: connect all padding and dimensions and express as variables

struct ContentView: View {
    // Shared object carrying settings info
    @EnvironmentObject var settings: AppSettings
    
    // MARK: – State
    @StateObject private var networkMonitor = NetworkMonitor()
    @State private var searchText = ""
    @State private var files: [FileResult] = []
    @State private var didSearch = false
    @State private var isSearching = false
    
    // MARK: – Derived flags
    private var isOpen: Bool      { !files.isEmpty && !isSearching }
    private var noResults: Bool   { didSearch && files.isEmpty && !isSearching }
    private var viewHeight: CGFloat {
        switch (isOpen, noResults, !networkMonitor.isConnected) {
        case (true, _, _):
            return UI.searchBarHeight + UI.resultsPaneHeight + 2
        case (false, true, _):
            return UI.searchBarHeight * 2
        case (false, false, true):
            return UI.searchBarHeight * 2
        default:
            return UI.searchBarHeight
        }
    }
    
    // MARK: – Body -------------------------------------------------------
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            
            if !networkMonitor.isConnected {
                Divider().frame(height: 1)
                noInternetView
            } else if isOpen {
                Divider().frame(height: 1)
                resultsList
            } else if noResults {
                Divider().frame(height: 1)
                noResultsView
            }
        }
        .frame(width: UI.windowWidth, height: viewHeight)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(settings.backgroundColor.opacity(0.95)) // TODO: More rounded
                //.shadow(radius: 2) TODO: verify
        )
    }
    
    // MARK: – Subviews -------------------------------------------------------
    private var searchBar: some View {
        HStack(spacing: UI.stackSpacing) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 20)) // TODO: Verify

            TextField("Telescope Search", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 20)) // TODO: Verify
                .onSubmit {
                    handleEnter()
                }
                .onExitCommand {
                    handleESC()
                }
                // Used to reduce UI when user deletes input
                .onChange(of: searchText) { newValue in
                    if newValue.isEmpty {
                        files = []
                        didSearch = false
                    }
                }
            Spacer()

            // ⚙️ Settings button
            Button {
                // Open the SwiftUI Settings window
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
                if let prefs = NSApp.keyWindow {
                    // 1) Make this window follow the active Space
                    prefs.collectionBehavior.insert(.moveToActiveSpace)
                    // (Optional) also allow over fullscreen apps, etc.
                    prefs.collectionBehavior.insert(.fullScreenAuxiliary)

                    // 2) Center and show it
                    prefs.center()
                    prefs.makeKeyAndOrderFront(nil)
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Open Preferences")
        }
        .padding(.horizontal, 12)
        .frame(height: UI.searchBarHeight)
        .background(Color.clear)
    }
    
    struct FileResultRow: View {
        let file: FileResult
        @State private var isHovered = false

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    // File icon
//                    Image(nsImage: NSWorkspace.shared.icon(forFile: file.path))
//                        .resizable()
//                        .frame(width: 16, height: 16)
                    Text(emojiForFile(atType: file.type))
                                        .font(.system(size: 16))

                    // File name
                    Text(file.name)
                        .font(.headline)

                    // Separator
                    Text("–")

                    // File type
                    Text(file.type)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Middle dot separator
                    Text("·")

                    // Modification date
                    Text("Modified \(file.modificationDate)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // File path
                Text(file.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, UI.paddingBetweenResults)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.defaultMinListRowHeight, UI.resultsListHeight)
            .frame(height: UI.resultsListHeight)
            .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            .onTapGesture {
                Task {
                    do {
                        _ = try await BookmarkService.shared.resolveOrRequestBookmarks()
                        NSWorkspace.shared.open(URL(fileURLWithPath: file.path))
                        BookmarkService.shared.stopAllAccess()
                    } catch {
                        print("Error handling tap gesture: \(error)")
                    }
                }
            }
        }
    }

    private var resultsList: some View { //  TODO: Deal with contents of each list and its spacing to make sure they fit (cummulative padding with spacing and padding)
        List(files.prefix(UI.maxRows)) { file in
                FileResultRow(file: file)
            }
        .listStyle(PlainListStyle())
        // Hides the default background and sets it to clear
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        // Constraints the List with correct dimensions
        .frame(height: UI.resultsPaneHeight)
    }
    
    private var noResultsView: some View {
        Text("No results found")
            .textFieldStyle(PlainTextFieldStyle())
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
    }
    private var noInternetView: some View {
        Text("No internet connection")
            .textFieldStyle(PlainTextFieldStyle())
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
    }
    
    
    // MARK: – Actions --------------------------------------------------------
    
    private func handleEnter() {
        isSearching = true
        files.removeAll()
        Task {
            defer { isSearching = false }
            do {
                // Use APIService to construct mdfindCommand
                
                let response = try await sendQuery(query: searchText)
                if let mdfindCommand = response["mdfind_command"] {
                    let result = try await MdfindService().fetchFiles(using: response)
                    files = result.files
                    didSearch = true
                } else {
                    print("Error: Server response did not include necessary key mdfind_command")
                }
            } catch let error as APIServiceError {
                switch error {
                case .noInternetConnection:
                    // Update UI to indicate no internet connection
                    print("No internet connection.")
                case .timeout:
                    // Update UI to indicate request timed out
                    print("Request timed out.")
                case .serverError(let statusCode):
                    // Update UI to indicate server error with status code
                    print("Server error with status code: \(statusCode)")
                case .decodingError:
                    // Update UI to indicate decoding error
                    print("Failed to decode the response.")
                case .invalidURL:
                    // Update UI to indicate invalid URL
                    print("Invalid URL.")
                case .unknown(let err):
                    // Update UI to indicate an unknown error occurred
                    print("An unknown error occurred: \(err.localizedDescription)")
                }
            } catch {
                // Handle any other unexpected errors
                print("Unexpected error: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleESC() {
        searchText = ""
        files = []
        didSearch = false
    }
}

func emojiForFile(atType type: String) -> String {
    return fileExtensionEmojis[type] ?? "📁" // Default to folder emoji if unknown
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
