# Telescope macOS App

This document provides an overview of the Telescope macOS application, its structure, services, and how it works.

## Project Structure

The project is organized as a standard Xcode project with the following key components:

- **TelescopeApp.swift**: The main entry point of the application.
- **ContentView.swift**: Defines the main user interface of the application.
- **SettingsView.swift**: Defines the user interface for application settings.
- **Assets.xcassets**: Contains application assets like icons and images.
- **Info.plist**: Configuration file for the application. It's important to configure the `API_ENDPOINT` key in this file before running the app (see "Building and Running" section).
- **Telescope.entitlements**: Defines the application's entitlements and capabilities.

### Services

The application utilizes several services to provide its functionality:

- **APIService.swift**: Handles communication with external APIs. It's used to send a user's natural language query to a remote LLM server, which then converts the query into a structured `mdfind` command and filter flags.
- **MdfindService.swift**: Interacts with macOS's `mdfind` (Spotlight search) utility to search for files based on the command received from the `APIService`.
- **BookmarkService.swift**: Manages bookmarks, allowing the app to request persistent read access to user-specified folders outside its sandbox, enhancing search capabilities.
- **InternetMonitor.swift**: Monitors internet connectivity, which is crucial for the `APIService`.
- **WindowAccessor.swift**: Provides access to and management of the application's `NSPopover` (a panel-like interface), which is how the app's UI is presented.
- **ShortcutNames.swift**: Manages the names for user-configurable keyboard shortcuts.

### Helper Files

- **DataStructures.swift**: Contains custom data structures used throughout the application, including the expected structure for the LLM server's response.

### Dependencies

The application relies on the following external Swift Package Manager dependencies:

- **SwiftShell**: A library to run shell commands from Swift. This is used to execute the `mdfind` command generated from the user's query. (https://github.com/kareman/SwiftShell)
- **KeyboardShortcuts**: A library for adding user-customizable global keyboard shortcuts, allowing the app to be invoked quickly, similar to Spotlight. (https://github.com/sindresorhus/KeyboardShortcuts)
- **Sparkle**: A software update framework for macOS, enabling automatic updates. (https://github.com/sparkle-project/Sparkle)

## How the App Works

Telescope is a macOS menu bar utility designed for quick, natural language file searching. Its workflow is as follows:

1.  **Interface and Configuration**: The app provides a user interface through an `NSPopover` (managed by `WindowAccessor.swift` and defined in `ContentView.swift` and `SettingsView.swift`). Users can:
    *   Define file access permissions for the app (via `BookmarkService.swift` in the "Access" tab of Settings).
    *   Set a global keyboard shortcut for invoking the app (via `KeyboardShortcuts`).
    *   Access the main search input.
2.  **Natural Language Query**: The user types a natural language query into the search box.
3.  **Query Processing**: The app sends this query via `APIService.swift` to a configured LLM endpoint (specified in `Info.plist`). The server processes the query and returns a corresponding `mdfind` command and any necessary filter flags.
4.  **File Search**: `MdfindService.swift` receives the `mdfind` command and, using `SwiftShell`, executes it to search for local file metadata.
5.  **Filtering and Display**: The app applies any returned filter flags to the search results and displays the relevant files to the user.
6.  **Interaction**: The user can scroll through the list of returned files and click on any file to open it.
7.  **Background Utility Behavior**:
    *   Telescope is designed as a background utility (`INFOPLIST_KEY_LSUIElement = YES` in `Info.plist`), meaning it doesn't have a Dock icon.
    *   It's intended to be invoked via its global keyboard shortcut.
    *   The app's popover automatically hides when it loses focus, allowing for a seamless workflow.
8.  **Updates**: The app supports automatic updates through the Sparkle framework.

## Building and Running

To build and run the Telescope application:

1.  **Clone the Repository**: If you haven't already, clone the project to your local machine.
2.  **Open in Xcode**: Open the `Telescope.xcodeproj` file in Xcode.
3.  **Configure API Endpoint (Crucial Prerequisite)**:
    *   Before running the app, you **must** configure the API endpoint.
    *   Open the `Info.plist` file located in the `Telescope` group in the Project Navigator.
    *   Locate the key named `API_ENDPOINT`.
    *   Set its string value to an appropriate URL for an LLM server capable of processing the user's natural language query and returning a JSON response. The expected JSON structure from the server is defined in `DataStructures.swift`:
        ```swift
        // LLM Server Return Structure
        struct LLMResponse: Decodable {
            let data: [String: String?]
        
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                self.data = try container.decode([String: String?].self)
            }
        }
        ```
4.  **Select Scheme**: Ensure the "Telescope" scheme is selected.
5.  **Build and Run**: Build and run the application on a macOS device or simulator.

## Contributing and Future Enhancements

We welcome contributions to Telescope! If you have improvements or new features, please feel free to submit a pull request.

### Potential Next Steps

Here are some ideas for future development:

- **File Name Content Search**: Enhance the search to look for context matches within file names.
- **File Content Search**: Implement the ability to search *within* the content of files, not just their metadata or names. This would likely require additional services and indexing strategies.
- **Advanced Filtering Options**: Provide users with more granular control over search results through advanced filter UI (e.g., by date, kind, specific metadata attributes).
- **Integration with Cloud Services**: Allow searching files stored in popular cloud storage services.