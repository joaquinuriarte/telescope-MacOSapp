//
//  BookmarkService.swift
//  Telescope
//
//  Created by Joaquin Uriarte on 4/30/25.
//

import Foundation
import AppKit

final class BookmarkService {
    static let shared = BookmarkService()
    private init() {}   // enforce singleton

    private var liveURLs: [URL] = []
    private let bookmarksKey = "homeFolderBookmarks"

    // MARK: – Public APIs

    /// Resolve all stored bookmarks, start security scopes, and return live URLs.
    func resolvedFolderURLs() -> [URL] {
        let blobs = loadBlobs()
        liveURLs = resolveAndStartAccess(from: blobs)
        return liveURLs
    }

    /// Ask user for folders, replace ALL bookmarks with their selection.
    @MainActor
    func requestAndStoreBookmarks() throws -> [URL] {
        let urls = try pickFolders(message: "Pick the folder(s) Telescope is allowed to search.",
                                   prompt: "Grant Access")
        let blobs = try urls.map { try $0.bookmarkData(options: [.withSecurityScope],
                                                        includingResourceValuesForKeys: nil,
                                                        relativeTo: nil) }
        saveBlobs(blobs)
        liveURLs = startAccess(for: blobs)
        return liveURLs
    }

    /// Ask user for folders, append only the new ones to the existing list.
    @MainActor
    func addBookmarks() throws -> [URL] {
        let urls = try pickFolders(message: "Pick additional folder(s) Telescope can search.",
                                   prompt: "Add")
        var blobs = loadBlobs()
        for url in urls {
            let data = try url.bookmarkData(options: [.withSecurityScope],
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil)
            if !blobs.contains(data) {
                blobs.append(data)
            }
        }
        saveBlobs(blobs)
        liveURLs = startAccess(for: blobs)
        return liveURLs
    }

    /// Delete all bookmarks and stop their security scopes.
    func deleteAllBookmarks() {
        liveURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        liveURLs.removeAll()
        UserDefaults.standard.removeObject(forKey: bookmarksKey)
    }

    /// Delete only the bookmark whose lastPathComponent matches `name`.
    func deleteBookmark(named folderName: String) {
        var blobs = loadBlobs()
        blobs.removeAll { data in
            // 1) create a mutable Bool to receive the `isStale` flag
            var isStale: Bool = false

            // 2) pass that Bool’s inout pointer instead of `nil`
            guard let url = try? URL(
                    resolvingBookmarkData: data,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
            ) else { return false }

            return url.lastPathComponent == folderName
        }

        // Persist and restart scopes
        saveBlobs(blobs)
        liveURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        liveURLs = startAccess(for: blobs)
    }

    /// Returns the folder names (last path components) of all current bookmarks.
    func bookmarkFolderNames() -> [String] {
        resolvedFolderURLs().map { $0.lastPathComponent }
    }
    
    /// Stop and clear all active security‐scoped accesses.
    func stopAllAccess() {
        liveURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        liveURLs.removeAll()
    }

    /// Resolve existing bookmarks or, if none exist, ask the user to pick them.
    @MainActor
    func resolveOrRequestBookmarks() async throws -> [URL] {
        var folders = resolvedFolderURLs()
        if folders.isEmpty {
            folders = try requestAndStoreBookmarks()
        }
        return folders
    }


    // MARK: – Private Helpers

    /// Load raw bookmark‐data blobs from UserDefaults.
    private func loadBlobs() -> [Data] {
        UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] ?? []
    }

    /// Persist raw bookmark‐data blobs to UserDefaults.
    private func saveBlobs(_ blobs: [Data]) {
        UserDefaults.standard.set(blobs, forKey: bookmarksKey)
    }

    /// Given raw blobs, resolve each to a URL, refresh stale ones, start access, and return live URLs.
    private func resolveAndStartAccess(from blobs: [Data]) -> [URL] {
        blobs.compactMap { data in
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: data,
                                     options: [.withSecurityScope],
                                     relativeTo: nil,
                                     bookmarkDataIsStale: &isStale)
            else { return nil }

            // Refresh stale bookmark
            if isStale,
               let fresh = try? url.bookmarkData(options: [.withSecurityScope]) {
                saveBlobs(blobs.map { $0 == data ? fresh : $0 })
            }

            return url.startAccessingSecurityScopedResource() ? url : nil
        }
    }

    /// Helper to start access on an array of blobs and return their URLs.
    private func startAccess(for blobs: [Data]) -> [URL] {
        blobs.compactMap { data in
            var isStale: Bool = false
            guard let url = try? URL(
                    resolvingBookmarkData: data,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
            ) else { return nil }

            return url.startAccessingSecurityScopedResource() ? url : nil
        }
    }

    /// Show an NSOpenPanel configured for folder selection.
    @MainActor
    private func pickFolders(message: String, prompt: String) throws -> [URL] {
        let panel = NSOpenPanel()
        panel.message               = message
        panel.prompt                = prompt
        panel.canChooseFiles        = false
        panel.canChooseDirectories  = true
        panel.allowsMultipleSelection = true
        panel.directoryURL          = FileManager.default.homeDirectoryForCurrentUser

        guard panel.runModal() == .OK else {
            throw CocoaError(.userCancelled)
        }
        return panel.urls
    }
}
