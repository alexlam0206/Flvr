//
//  FlvrApp.swift
//  Flvr
//

import SwiftUI
import SwiftData

@main
struct FlvrApp: App {
    @State private var manager = FlavortownManager()
    
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        #if os(macOS)
        MenuBarExtra {
            ContentView(manager: manager)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                if let time = manager.totalLoggedTimeText {
                    Text(time)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                }
            }
        }
        .menuBarExtraStyle(.window)
        #else
        WindowGroup {
            ContentView(manager: manager)
        }
        #endif
    }
}

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app is treated as an accessory (menu bar app) on macOS
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        
        NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { event in
            if self.isEventInStatusBarItem(event) {
                self.showContextMenu()
                return nil
            }
            return event
        }
    }
    
    private func isEventInStatusBarItem(_ event: NSEvent) -> Bool {
        guard let window = event.window, window.className == "NSStatusBarWindow" else { return false }
        return true
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Flvr 🔥", action: nil, keyEquivalent: ""))
        menu.item(at: 0)?.isEnabled = false
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About Flvr", action: #selector(about), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Refresh Data", action: #selector(refresh), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Flvr", action: #selector(quit), keyEquivalent: "q"))
        
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    
    @objc func about() { NSApp.orderFrontStandardAboutPanel(nil) }
    @objc func refresh() {
        NotificationCenter.default.post(name: NSNotification.Name("RefreshData"), object: nil)
    }
    @objc func quit() { NSApplication.shared.terminate(nil) }
}
#endif
