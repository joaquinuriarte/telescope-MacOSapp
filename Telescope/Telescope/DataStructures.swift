//
//  DataStructures.swift
//  Telescope
//
//  Created by Joaquin Uriarte on 4/29/25.
//

import Foundation
import SwiftUI

// ---- UI Components
enum UI {
    static let windowWidth: CGFloat             = 675
    static let searchBarHeight: CGFloat         = 60
    static let resultsListHeight: CGFloat       = 50
    static let resultsPaneHeight: CGFloat       = searchBarHeight * 6
    static let rowHeight: CGFloat               = 40
    static let stackSpacing: CGFloat            = 4
    static let paddingBetweenResults: CGFloat   = 4
    static let maxRows                          = 1000 // TODO: Do we need this?
}

// LLM Server Return Structure
struct LLMResponse: Decodable {
    let data: [String: String?]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.data = try container.decode([String: String?].self)
    }
}

// Custom API Error Types
enum APIServiceError: Error {
    case invalidURL
    case serverError(statusCode: Int)
    case decodingError
    case noInternetConnection
    case timeout
    case unknown(Error)
}

// ---- Mdfind SERVICE, ContentView
struct FileResult: Identifiable {
    let id: Int
    let name: String
    let path: String
    let type: String
    let creationDate: String
    let modificationDate: String
}

// ---- API SERVICE
// API payload structure
struct ModelConfig: Codable {
    let model: String
}
// API payload structure
struct Payload: Codable {
    let query: String
    let modelType: String
    let modelConfig: ModelConfig
}
// Define the response structure
struct ResponseData: Codable {
    let mdfind_command: String?
}

// File extension emojis
let fileExtensionEmojis: [String: String] = [ //TODO: Some items here will never show up. See determineFileType func on MdfindService
    "pdf": "📄",
    // Will never show up
    "doc": "📝", "docx": "📝",
    // Will never show up
    "xls": "📊", "xlsx": "📊",
    // Will never show up
    "ppt": "📈", "pptx": "📈",
    "txt": "📄",
    // Will never show up
    "jpg": "🖼️", "jpeg": "🖼️", "png": "🖼️", "gif": "🖼️",
    "image": "🖼️",
    // Will never show up
    "mp3": "🎵", "wav": "🎵",
    "audio": "🎵",
    // Will never show up
    "mp4": "🎞️", "mov": "🎞️",
    "video": "🎞️",
    "zip": "🗜️",
    // Will never show up
    "rar": "🗜️",
    "html": "🌐", "css": "🎨", "js": "📜",
    "swift": "🦅", "py": "🐍", "java": "☕️", "c": "🔧", "cpp": "🔧",
    "json": "🔣", "xml": "🗂️",
    "key": "📊", "pages": "📄", "numbers": "📈"
]
