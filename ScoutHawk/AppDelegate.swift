//
//  AppDelegate.swift
//  ScoutHawk
//
//  Created by apple on 3/31/25.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!
    var popover: NSPopover!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusItem()
        setupPopover()
    }

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "speedometer", accessibilityDescription: nil)
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    func setupPopover() {
        popover = NSPopover()
        popover.contentViewController = UsageViewController.freshController()
        popover.behavior = .semitransient
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
                //updateUsage()
            }
        }
    }

    /*
    func updateUsage() {
        let cpuUsage = SystemMonitor.getCPUUsage()
        let ramUsage = SystemMonitor.getMemoryUsage()
        if let controller = popover.contentViewController as? UsageViewController {
            controller.updateUsage(cpu: cpuUsage, ram: ramUsage)
        }
    }
*/

}

