//
//  WindowAccessor.swift
//  Telescope
//
//  Created by Joaquin Uriarte on 4/29/25.
//

import Foundation
import SwiftUI

/// Gives SwiftUI access to the hosting `NSWindow`.
/// – You may *observe* it through a `@Binding`,
/// – or *configure* it once through a closure,
/// – or do both.
struct WindowAccessor: NSViewRepresentable {

    /// Optional binding for views that need to keep a reference.
    var windowBinding: Binding<NSWindow?>?

    /// Optional one-time configuration block (runs first time the window exists).
    var configure: ((NSWindow) -> Void)?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        // Defer to the next run-loop so `view.window` is non-nil.
        DispatchQueue.main.async {
            if let win = view.window {
                // Update the binding if supplied.
                windowBinding?.wrappedValue = win
                // Run one-time configuration if supplied (only once).
                if context.coordinator.didConfigure == false {
                    configure?(win)
                    context.coordinator.didConfigure = true
                }
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) { }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var didConfigure = false
    }
}
