//
//  UsageViewController.swift
//  ScoutHawk
//
//  Created by apple on 3/31/25.
//

import Cocoa
import EventKit

class UsageViewController: NSViewController {
    @IBOutlet weak var cpuLabel: NSTextField!
    @IBOutlet weak var ramLabel: NSTextField!
    
    @IBOutlet weak var AcessStatus: NSTextField!
    @IBOutlet weak var ScrRecStatus: NSTextField!
    @IBOutlet weak var InputStatus: NSTextField!
    @IBOutlet weak var FDAStatus: NSTextField!
    
    @IBOutlet var logTextView: NSTextView!
    @IBOutlet var eventsTextView: NSTextView!
    
    @IBOutlet weak var pathFileTextField: NSTextField!
    {
        didSet {
            if pathFileTextField != nil {
                pathFileTextField.isEditable = true
                pathFileTextField.isSelectable = true
                pathFileTextField.allowsEditingTextAttributes = true
            } else {
                        print("⚠️ Warning: pathTextField is nil")
            }
        }
    }
    
    @IBOutlet weak var pathTextField: NSTextField!
    {
        didSet {
            if pathTextField != nil {
                pathTextField.isEditable = true
                pathTextField.isSelectable = true
                pathTextField.allowsEditingTextAttributes = true
            } else {
                        print("⚠️ Warning: pathTextField is nil")
            }
        }
    }
    
    var monitor: SystemMonitor?
    var updateTimer: Timer?
    
    static func freshController() -> UsageViewController {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let viewController = storyboard.instantiateController(withIdentifier: "UsageViewController") as? UsageViewController else {
            fatalError("Could not load UsageViewController from Main.storyboard")
        }
        return viewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        startUpdatingUsage()
    }

    func startUpdatingUsage() {
        updateTimer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(updateUsagePeriodically), userInfo: nil, repeats: true)
    }

    func display(events: [EKEvent]) {
            DispatchQueue.main.async {
                if events.isEmpty {
                    self.eventsTextView.string = "There are no events today."
                    return
                }
                
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .short
                
                let lines = events.map { event -> String in
                    let start = formatter.string(from: event.startDate)
                    let end   = formatter.string(from: event.endDate)
                    let location = event.location ?? ""
                    
                    if location.isEmpty {
                        return "\(start)–\(end): \(event.title ?? "(No title)")"
                    } else {
                        return "\(start)–\(end): \(event.title ?? "(No title)") @ \(location)"
                    }
                }
                
                self.eventsTextView.string = lines.joined(separator: "\n")
            }
        }
        
        func updateEventInfo() {
            let store = EKEventStore()
            store.requestAccess(to: .event) { granted, error in
                if granted {
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: Date())
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

                    let predicate = store.predicateForEvents(withStart: startOfDay,
                                                             end: endOfDay,
                                                             calendars: nil)
                    let events = store.events(matching: predicate)
                    self.display(events: events)
                }
            }
        }
    
    @objc func updateUsagePeriodically() {
        let cpuUsage = SystemMonitor.getCPUUsage()
        let ramUsage = SystemMonitor.getMemoryUsage()
        updateUsage(cpu: cpuUsage, ram: ramUsage)
        
        let hasAccessPermission = SystemMonitor.hasAccessibilityPermission()
        let hasScreenPermission = SystemMonitor.hasScreenRecordingPermission()
        let hasInputPermission = SystemMonitor.checkInputMonitoringPermission()
        let hasFDAPermission = SystemMonitor.CheckFDAPermission()
        updatePrivacy(hasAccessPermission: hasAccessPermission, hasScreenPermission: hasScreenPermission, hasInputPermission: hasInputPermission, hasFDAPermission: hasFDAPermission)
        
        updateEventInfo()
    }
    
    @IBAction func browseFolder(_ sender: Any) {
        let dialog = NSOpenPanel()
            dialog.title = "Select Folder"
            dialog.canChooseDirectories = true
            dialog.canChooseFiles = false
            dialog.allowsMultipleSelection = false
            dialog.showsHiddenFiles = true

            if dialog.runModal() == .OK, let url = dialog.url {
                pathTextField.stringValue = url.path
                logMessage("📂 Selected folder: \(url.path)")
            }
    }
    
    @IBAction func browseFile(_ sender: Any) {
        let dialog = NSOpenPanel()
            dialog.title = "Select File"
            dialog.canChooseDirectories = true
            dialog.canChooseFiles = true
            dialog.allowsMultipleSelection = false
            dialog.showsHiddenFiles = true

            if dialog.runModal() == .OK, let url = dialog.url {
                pathFileTextField.stringValue = url.path
                logMessage("📂 Selected file: \(url.path)")
            }
    }
    
    @IBAction func btnQuit(_ sender: Any) {
        NSApp.terminate(nil)
    }
    
    @IBAction func stopMonitoring(_ sender: Any) {
        monitor?.stopAllMonitoring()
        logMessage("🛑 All monitoring stopped by user.")
    }
    
    @IBAction func startMonitoring(_ sender: Any) {
        let folderPath = pathTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !folderPath.isEmpty else {
                    logMessage("⚠️ Invalid folder path entered.")
                    return
                }
        
        let filePath = pathFileTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !filePath.isEmpty else {
                    logMessage("⚠️ Invalid file path entered.")
                    return
                }
                monitor = SystemMonitor()
                monitor?.setLogHandler { [weak self] message in
                    self?.logMessage(message)
                }
        
                monitor?.startMonitoring(folderPath: folderPath)
                monitor?.monitorPermissions(folderPath: folderPath)
                monitor?.monitorFileAccess(filePath: filePath)
    }
    
    func updateUsage(cpu: Double, ram: Double) {
        cpuLabel.stringValue = String(format: "CPU: %.1f%%", cpu)
        ramLabel.stringValue = String(format: "RAM: %.1f%%", ram)
    }
    
    func updatePrivacy(hasAccessPermission: Bool, hasScreenPermission: Bool, hasInputPermission: Bool, hasFDAPermission: Bool) {
        
        if hasAccessPermission == true
        {
            AcessStatus.stringValue = String("Enabled")
        }
        else
        {
            AcessStatus.stringValue = String("Disabled")
        }

        if hasScreenPermission == true
        {
            ScrRecStatus.stringValue = String("Enabled")
        }
        else
        {
            ScrRecStatus.stringValue = String("Disabled")
        }

        if hasInputPermission == true
        {
            InputStatus.stringValue = String("Enabled")
        }
        else
        {
            InputStatus.stringValue = String("Disabled")
        }

        if hasFDAPermission == true
        {
            FDAStatus.stringValue = String("Enabled")
        }
        else
        {
            FDAStatus.stringValue = String("Disabled")
        }
    }
    
    func logMessage(_ message: String) {
        DispatchQueue.main.async {
            let logText = "\(self.logTextView.string)\n\(message)"
            self.logTextView.string = logText
            self.logTextView.scrollToEndOfDocument(nil)
        }
    }
}

