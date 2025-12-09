//
//  UsageViewController.swift
//  ScoutHawk
//
//  Created by apple on 3/31/25.
//

import Cocoa

class UsageViewController: NSViewController {
    @IBOutlet weak var cpuLabel: NSTextField!
    @IBOutlet weak var ramLabel: NSTextField!

    @IBOutlet weak var AccessSwitch: NSSwitch!
    @IBOutlet weak var ScreenSwitch: NSSwitch!
    @IBOutlet weak var InputSwitch: NSSwitch!
    @IBOutlet weak var FDASwitch: NSSwitch!
    
    
    @IBOutlet var logTextView: NSTextView!
    
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

    @objc func updateUsagePeriodically() {
        let cpuUsage = SystemMonitor.getCPUUsage()
        let ramUsage = SystemMonitor.getMemoryUsage()
        updateUsage(cpu: cpuUsage, ram: ramUsage)
        
        let hasAccessPermission = SystemMonitor.hasAccessibilityPermission()
        let hasScreenPermission = SystemMonitor.hasScreenRecordingPermission()
        let hasInputPermission = SystemMonitor.checkInputMonitoringPermission()
        let hasFDAPermission = SystemMonitor.CheckFDAPermission()
        updatePrivacy(hasAccessPermission: hasAccessPermission, hasScreenPermission: hasScreenPermission, hasInputPermission: hasInputPermission, hasFDAPermission: hasFDAPermission)
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
            AccessSwitch.state = .on
        }
        else
        {
            AccessSwitch.state = .off
        }

        if hasScreenPermission == true
        {
            ScreenSwitch.state = .on
        }
        else
        {
            ScreenSwitch.state = .off
        }

        if hasInputPermission == true
        {
            InputSwitch.state = .on
        }
        else
        {
            InputSwitch.state = .off
        }

        if hasFDAPermission == true
        {
            FDASwitch.state = .on
        }
        else
        {
            FDASwitch.state = .off
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

