//
//  MdfindService.swift
//  Telescope
//
//  Created by Joaquin Uriarte on 4/29/25.
//

import Foundation
import SwiftShell
import AppKit
import UniformTypeIdentifiers

//TODO: The architecture for this should abstract mac specific mdfind predicate syntax from LLM and have a mapping to resolve LLM response

func determineFileType(for path: String) -> String {
    var fileURL = URL(fileURLWithPath: path)

    // Check and remove the .icloud extension if present
    if fileURL.pathExtension.lowercased() == "icloud" {
        fileURL.deletePathExtension()
    }
    
    let fileExtension = fileURL.pathExtension.lowercased()
    guard let utType = UTType(filenameExtension: fileExtension) else {
        return "unknown"
    }

    if utType.conforms(to: .image) {
        return "image"
    } else if utType.conforms(to: .video) {
        return "video"
    } else if utType.conforms(to: .audio) {
        return "audio"
    } else if utType.conforms(to: .pdf) {
        return "pdf"
    } else if utType.conforms(to: .text) {
        return "text"
    } else if utType.conforms(to: .zip) {
        return "zip"
    } else {
        return utType.identifier // Returns the UTI identifier as a fallback
    }
}

func parseMDFindCommand(_ command: String) -> (searchPath: String?, predicate: String) {
    var components: [String] = []
    var currentComponent = ""
    var insideQuotes = false

    for char in command {
        if char == "\"" {
            insideQuotes.toggle()
        } else if char == " " && !insideQuotes {
            if !currentComponent.isEmpty {
                components.append(currentComponent)
                currentComponent = ""
            }
        } else {
            currentComponent.append(char)
        }
    }

    if !currentComponent.isEmpty {
        components.append(currentComponent)
    }

    var searchPath: String?
    var predicateComponents: [String] = []
    var skipNext = false

    for (index, component) in components.enumerated() {
        if skipNext {
            skipNext = false
            continue
        }

        if component == "-onlyin", index + 1 < components.count {
            searchPath = components[index + 1]
            skipNext = true
        } else {
            predicateComponents.append(component)
        }
    }

    let predicate = predicateComponents.joined(separator: " ")
    return (searchPath, predicate)
}

class MdfindService {
    private let maxResults = 1000 // TODO: Ver si pichar cap and if not move to datastructures + make equal to maxResultsShown en UI?
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path // TODO: Move to datastructures

    // MARK: – 0. Fucntion to extract path from mdfind_command
    func extractOnlyinPath(from command: String) -> String? {
        let pattern = #"-onlyin\s+"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: command, range: NSRange(command.startIndex..., in: command)),
              let range = Range(match.range(at: 1), in: command) else {
            return nil
        }
        return String(command[range])
    }
    
    
    // MARK: – 1. Single‑query helper
    func spotlightSearch(scopes: [URL], predicateString: String) async throws -> [(path: String, created: Date?, modified: Date?)] {
        // Build the query
        let query             = NSMetadataQuery()
        query.predicate       = NSPredicate(fromMetadataQueryString: predicateString)
        query.searchScopes = scopes.map(\.path)
        query.operationQueue  = .main                           // callback on main

        // Run & await the result
        return try await withCheckedThrowingContinuation { cont in
            var finish: NSObjectProtocol?
            
            func cleanUp(_ items: [(String, Date?, Date?)]?, _ error: Error?) {
                if query.isStarted { query.stop() }
                if let f = finish { NotificationCenter.default.removeObserver(f) }
                if let items = items { cont.resume(returning: items) }
                else { cont.resume(throwing: error ?? CocoaError(.fileReadUnknown)) }
            }
            finish = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: query, queue: .main
            ) { _ in
                let tuples: [(String, Date?, Date?)] = query.results.compactMap { result in
                    guard let item = result as? NSMetadataItem,
                          let path = item.value(forAttribute: kMDItemPath as String) as? String
                    else { return nil }

                    let created = item.value(forAttribute: kMDItemFSCreationDate as String) as? Date
                    let modified = item.value(forAttribute: kMDItemFSContentChangeDate as String) as? Date
                    
                    return (path, created, modified)
                }
                cleanUp(tuples, nil)
            }
            guard query.start() else {
                cleanUp(nil, CocoaError(.fileReadUnknown))
                return
            }
        }
    }

    // MARK: – 2. Wrapper that guarantees bookmarks
    func runSpotlight(for parsedCommand: String) async throws -> [(path: String, created: Date?, modified: Date?)]  {
        // 1. Resolve or request bookmarks
        let folders = try await BookmarkService.shared.resolveOrRequestBookmarks()
        
        // 2. Run ONE query across all scopes
        return try await spotlightSearch(scopes: folders, predicateString: parsedCommand)
    }
    
    // MARK: – Path filtering
    /// Returns true when `path` is inside `originalPath` (case‑insensitive).
    func pathMatchesOriginal(_ path: String, originalPath: String?) -> Bool {
        guard let original = originalPath?.lowercased(), !original.isEmpty else { return true }
        let lower = path.lowercased()
        return lower.contains("/\(original)") || lower.contains("/\(original)/")
    }

    /// Returns true when creationDate satisfies the optional "yyyy-MM-dd" filter.
    /// Pass `nil` for `dateFilter` to accept all dates.
    func dateMatchesFilter(_ date: Date?, startDateFilter: String?, endDateFilter: String?) -> Bool {
        // If creation date is nil, return true
        guard let date = date else { return true }
        
        // Convert filter strings to dates if they exist
        let startDate: Date? = startDateFilter.flatMap { filter in
            // For start date, use beginning of day (00:00:00)
            ISO8601DateFormatter().date(from: filter + "T00:00:00Z")
        }
        
        let endDate: Date? = endDateFilter.flatMap { filter in
            // For end date, use end of day (23:59:59)
            ISO8601DateFormatter().date(from: filter + "T23:59:59Z")
        }
        
        // Create calendar for date comparison
        let calendar = Calendar.current
        
        // Strip time components from the date
        let dateOnly = calendar.startOfDay(for: date)
        let startDateOnly = startDate.map { calendar.startOfDay(for: $0) }
        let endDateOnly = endDate.map { calendar.startOfDay(for: $0) }
        
        // Check if date is within range
        let afterStart = startDateOnly.map { dateOnly >= $0 } ?? true
        let beforeEnd = endDateOnly.map { dateOnly <= $0 } ?? true
        
        return afterStart && beforeEnd
    }
    
    // MARK: – 3. Main file fetcher function
    func fetchFiles(using response: [String: String?]) async throws -> (files: [FileResult], totalResults: Int, hasMore: Bool) {
        //UserDefaults.standard.removeObject(forKey: "homeFolderBookmark") //TODO: eliminates bookmark. Erase, using for debug
        guard let mdfindCommand = response["mdfind_command"] ?? nil else {
            throw CocoaError(.fileReadUnknown)
        }
        

        // Parse command
        let parsedCommand = parseMDFindCommand(mdfindCommand)

        // return object
        var files: [FileResult] = []
        // Efficiency gain
        files.reserveCapacity(maxResults)
        
        // Fire mdfind & process returned files
        do {
            let allPaths = try await runSpotlight(for: parsedCommand.predicate)
            for (idx, hit) in allPaths.enumerated() {
                // hit = (path, created?, modified?) from runSpotlight
                guard pathMatchesOriginal(hit.path, originalPath: parsedCommand.searchPath) else { continue }
                
                // Only apply date filtering if at least one filter is present
                let startDateFilter = response["startDate_filter"] ?? nil
                let endDateFilter = response["endDate_filter"] ?? nil
                 
                if startDateFilter != nil || endDateFilter != nil {
                    let useCreationFlag: Bool = {
                        guard let raw = response["useCreation"] ?? nil else { return true }   // default
                        return (raw as NSString).boolValue      // accepts "true"/"false"/"1"/"0"
                    }()
                    let chosenDate = useCreationFlag ? hit.created : hit.modified
                    guard dateMatchesFilter(chosenDate, startDateFilter: startDateFilter, endDateFilter: endDateFilter) else { continue }
                }
                
                if files.count == maxResults { break }        // early‑exit once full
                
                let file = FileResult(
                    id: idx,
                    name: URL(fileURLWithPath: hit.path).lastPathComponent,
                    path: hit.path,
                    type: determineFileType(for: hit.path),
                    creationDate: hit.created.map {
                        DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short)
                    } ?? "Unknown",
                    modificationDate: hit.modified.map {
                        DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short)
                    } ?? "Unknown"
                )
                files.append(file)
            }
                        
            BookmarkService.shared.stopAllAccess()
            return (files: files, totalResults: files.count, hasMore: files.count > maxResults)
        } catch {
            print("mdfind failed:", error)
        }
        BookmarkService.shared.stopAllAccess()
        return (files: files, totalResults: files.count, hasMore: files.count > maxResults)
    }
}

