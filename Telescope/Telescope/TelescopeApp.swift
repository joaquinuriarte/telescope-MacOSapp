//
//  TelescopeApp.swift
//  Telescope
//
//  Created by Joaquin Uriarte on 4/29/25.
//
//
import SwiftUI
import AppKit
import KeyboardShortcuts
import Sparkle

let appSettings = AppSettings()

@main
struct TelescopeApp: App {
    private let updaterController: SPUStandardUpdaterController
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Initialize the updater controller
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        appDelegate.settings = appSettings
    }
    
    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appSettings)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updaterController.checkForUpdates(nil)
                }
            }
        }
    }
}


final class AppDelegate: NSObject, NSApplicationDelegate {

    private var panel: NSPanel?
    var settings: AppSettings!
    
    
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Open Preferences at launch
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)

        // 2. Bring your app (and its windows) to the front
        NSApp.activate(ignoringOtherApps: true)
        
        // 3. Modify Preferences window
        if let prefs = NSApp.keyWindow {
            // 1) Make this window follow the active Space
            prefs.collectionBehavior.insert(.moveToActiveSpace)
            // (Optional) also allow over fullscreen apps, etc.
            prefs.collectionBehavior.insert(.fullScreenAuxiliary)

            // 2) Center and show it
            prefs.center()
            prefs.makeKeyAndOrderFront(nil)
        }
        
        // Register the global shortcut with default: (⌃⌘T).
        KeyboardShortcuts.onKeyDown(for: .summon) { [weak self] in
            self?.togglePanel()
        }
        KeyboardShortcuts.setShortcut(.init(.l, modifiers: [.command]), for: .summon)
        
        // Hide panel when ESC is pressed inside it
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // 53 = Escape
            if event.keyCode == 53 {
                // Hide panel and release it
                self?.panel?.orderOut(nil)
                self?.panel = nil
            }
            // Do nothing
            return event
        }
        
        // Release panel when it's deactivated through user clicking out of it
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: NSApplication.willResignActiveNotification,
            object: nil
        )
        
        // Listen whenever any NSWindow becomes key
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }
    
    // MARK: – Helpers
    
    @objc private func windowDidBecomeKey(_ note: Notification) {
        guard let window = note.object as? NSWindow else { return }
        switch window.title {
        case "Telescope Settings":
            // Settings just opened → hide Telescope panel
            if let p = panel {
                p.orderOut(nil)
                panel = nil
            }
        case "Telescope":
            // Spotlight panel just opened → close Settings window
            NSApp.closeWindow(titled: "Telescope Settings")
        default:
            break
        }
    }
    
    // Releases Panel when app is deactivated
    @objc func applicationWillResignActive(_ notification: Notification) {
        panel?.orderOut(nil)
        panel = nil
    }
    
    // Hide and show NSPanel
    private func togglePanel() {
        if let panel = panel {
            // Hide panel and release it
            panel.orderOut(nil)
            self.panel = nil
        } else {
            buildAndShowPanel()
        }
    }
    
    // Build NSPanel
    private func buildAndShowPanel() {
        // Make panel activate
        NSApp.activate(ignoringOtherApps: true)

        // Make a subclass of NSPanel to override "canBecomeKey" so users can type
        final class SpotlightPanel: NSPanel {
            override var canBecomeKey: Bool { true }
            override var canBecomeMain: Bool { true }
        }
        
        // Create NSPanel using our custom NSPanel subclass
        let p = SpotlightPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: UI.windowWidth, height: UI.searchBarHeight)) ,
            styleMask: [.fullSizeContentView, .borderless], // TODO: Add explanation for each of these //.nonactivatingPanel,
            backing: .buffered,
            defer: false
        )
        // TODO: Is transient and LSUIElement = YES redundant? Is fullScreenAuxiliary and orderFrontRegardless redundant?
        // Keeps window above all other ones
        p.isFloatingPanel = true
        // .transient: Removes the window from Mission Control and App Exposé snapshots, and macOS automatically closes it if the user explicitly hides the application
        // .moveToActiveSpace: When the panel becomes active (or is ordered front), macOS moves it to the user’s current Space instead of switching Spaces
        // .fullScreenAuxiliary: Allows the window to float over apps that are in their own full-screen Space
        p.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
        // Make panel transparent so that inside view can be seen
        p.isOpaque = false
        // Make panel clear. View living inside will carry visible components
        p.backgroundColor = .clear
        //Enable dragging of UI
        p.isMovableByWindowBackground = true
        //Auto-closes panel when user switches apps
        p.hidesOnDeactivate = true //TODO: Should not happen when users swipes up
        // Center app on middle of screen
        p.center()
        // Name panel
        p.title = "Telescope"
        // Provide our View to be shown inside the NSPanel
        p.contentView = NSHostingView(rootView: ContentView().environmentObject(settings))
        // visible even over fullscreen apps
        p.makeKeyAndOrderFront(nil)
        // Make textField the first response after SwiftUI/AppKit finished instaling it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.00) { [weak self, weak p] in
            guard
                let panel = p,
                let content = panel.contentView,
                let textField = self?.findTextField(in: content)
            else { return }
            panel.makeFirstResponder(textField)
        }
        
        self.panel = p
    }
    
    private func findTextField(in view: NSView) -> NSTextField? {
        if let tf = view as? NSTextField, tf.isEditable {
            return tf
        }
        for subview in view.subviews {
            if let found = findTextField(in: subview) {
                return found
            }
        }
        return nil
    }

    // TODO: To be implemented
    func applicationWillTerminate(_ notification: Notification) {
        
    }
}

// Extension to close windows
extension NSApplication {
    func closeWindow(titled title: String) {
        for win in windows where win.title == title {
            win.close()
        }
    }
}

// MARK: - Observable Settings Object to manage your app's settings
class AppSettings: ObservableObject {
    @Published var backgroundColor: Color = Color(NSColor.windowBackgroundColor)
}

