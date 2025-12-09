//
//  SystemMonitor.swift
//  ScoutHawk
//
//  Created by apple on 3/31/25.
//

import Foundation
import MachO
import Cocoa

class SystemMonitor {
    private var eventStream: FSEventStreamRef?
    private var watchedFolder: String?
    private var lastPermissions: [String: Int] = [:]
    private var logHandler: ((String) -> Void)?
    private var fileMonitors: [String: DispatchSourceFileSystemObject] = [:]
    private var folderEventStreams: [String: FSEventStreamRef] = [:]
    private var isMonitoring: Bool = false
    
    // CPU usage
    static func getCPUUsage() -> Double {
        var load = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: load) / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return -1 }
        let totalTicks = Double(load.cpu_ticks.0 + load.cpu_ticks.1 + load.cpu_ticks.2 + load.cpu_ticks.3)
        let idleTicks = Double(load.cpu_ticks.0)
        return 100.0 * (1.0 - (idleTicks / totalTicks))
    }

    // RAM usage
    static func getMemoryUsage() -> Double {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return -1 }
        let usedMemory = Double(info.active_count + info.inactive_count + info.wire_count) * Double(vm_page_size)
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        return 100.0 * (usedMemory / totalMemory)
    }
    
    static func hasAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    static func hasScreenRecordingPermission() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        }
        
        return CGDisplayStream(
            dispatchQueueDisplay: CGMainDisplayID(),
            outputWidth: 1,
            outputHeight: 1,
            pixelFormat: Int32(kCVPixelFormatType_32BGRA),
            properties: nil,
            queue: DispatchQueue.global(),
            handler: { _, _, _, _ in }
        ) != nil
    }

    static func checkInputMonitoringPermission() -> Bool {
        
        if #available(macOS 10.15, *) {
            let accessType = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
            if accessType == kIOHIDAccessTypeGranted
            {
                return true
            }
            else
            {
                return false
            }
        }
    }

    static func CheckFDAPermission() -> Bool{
        
        var p1 : Int = 0
        let queryString = "kMDItemDisplayName = *TCC.db"
        let username = NSUserName()
        if let query = MDQueryCreate(kCFAllocatorDefault, queryString as CFString, nil, nil) {
            MDQueryExecute(query, CFOptionFlags(kMDQuerySynchronous.rawValue))

            for i in 0..<MDQueryGetResultCount(query) {
                if let rawPtr = MDQueryGetResultAtIndex(query, i) {
                    let item = Unmanaged<MDItem>.fromOpaque(rawPtr).takeUnretainedValue()
                    if let path = MDItemCopyAttribute(item, kMDItemPath) as? String {
                       
                        if path.hasSuffix("/Users/\(username)/Library/Application Support/com.apple.TCC/TCC.db") || path.hasSuffix("/Library/Application Support/com.apple.TCC/TCC.db") {
                            p1 = p1 + 1
                            
                        }
                    }
                }
            }
            
            if p1 > 0 {
                return true
            }
            else {
                return false
            }

        }
        
        return false
    }

    func setLogHandler(_ handler: @escaping (String) -> Void) {
        logHandler = handler
    }

    func log(_ message: String) {
        logHandler?(message)
    }
    
    // start realtime monitoring about sepecific folder
    // Start monitoring a folder
        func startMonitoring(folderPath: String) {
            let callback: FSEventStreamCallback = { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
                let paths = unsafeBitCast(eventPaths, to: UnsafeMutablePointer<UnsafePointer<CChar>?>.self)
                for i in 0..<Int(numEvents) {
                    if let pathPtr = paths[i] {
                        let path = String(cString: pathPtr)
                        if let info = clientCallBackInfo {
                            let monitor = Unmanaged<SystemMonitor>.fromOpaque(info).takeUnretainedValue()
                            let flag = eventFlags[i]
                            if (flag & UInt32(kFSEventStreamEventFlagItemRemoved)) != 0 {
                                monitor.log("🗑️ Folder deleted: \(path)")
                                monitor.stopMonitoringFolder(path)
                            } else if (flag & UInt32(kFSEventStreamEventFlagItemRenamed)) != 0 {
                                monitor.log("🔄 Folder renamed: \(path)")
                                monitor.stopMonitoringFolder(path)
                            } else {
                                monitor.log("🔍 Detected change in: \(path)")
                            }
                        } else {
                            print("⚠️ Client callback info is nil")
                        }
                    }
                }
            }

            let pathsToWatch = [folderPath] as CFArray
            let context = UnsafeMutablePointer<FSEventStreamContext>.allocate(capacity: 1)
            context.pointee = FSEventStreamContext(
                version: 0,
                info: Unmanaged.passUnretained(self).toOpaque(),
                retain: nil,
                release: nil,
                copyDescription: nil
            )

            let stream = FSEventStreamCreate(
                nil,
                callback,
                context,
                pathsToWatch,
                FSEventsGetCurrentEventId(),
                0,
                FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
            )

            if let stream = stream {
                FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
                FSEventStreamStart(stream)
                folderEventStreams[folderPath] = stream
                log("🚀 Monitoring started on folder: \(folderPath)")
            }
        }

        // Stop monitoring the folder
        func stopMonitoringFolder(_ folderPath: String) {
            if let stream = folderEventStreams[folderPath] {
                FSEventStreamStop(stream)
                FSEventStreamInvalidate(stream)
                FSEventStreamRelease(stream)
                folderEventStreams.removeValue(forKey: folderPath)
                log("🛑 Stopped monitoring folder: \(folderPath)")
            } else {
                log("⚠️ No active monitoring for folder: \(folderPath)")
            }
        }


    

    // monitoring changes about filePermission
    func checkFilePermissions(filePath: String) {
        var fileStat = stat()
        if stat(filePath, &fileStat) == 0 {
            let permissions = Int(fileStat.st_mode & 0o777)
            if let lastPerm = lastPermissions[filePath], lastPerm != permissions {
                log("🔄 Permissions changed for \(filePath): \(String(format: "%o", permissions))")
                //print("🔄 Permissions changed for \(filePath): \(String(format: "%o", permissions))")
            }
            lastPermissions[filePath] = permissions
        }
    }

    func monitorPermissions(folderPath: String) {
        isMonitoring = true
        
        DispatchQueue.global(qos: .background).async {
            while true {
                if self.isMonitoring == false {
                    break
                }
                
                if let files = try? FileManager.default.contentsOfDirectory(atPath: folderPath) {
                    for file in files {
                        let filePath = "\(folderPath)/\(file)"
                        self.checkFilePermissions(filePath: filePath)
                    }
                }
                else
                {
                    break
                }
                    
                
                sleep(2)
            }
        }
    }
    
    // Monitor specific file access with robust handling
    func monitorFileAccess(filePath: String) {
        let fileDescriptor = open(filePath, O_EVTONLY)
        if fileDescriptor == -1 {
            log("❌ Unable to open file for monitoring: \(filePath)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: [.attrib, .write, .delete, .rename], queue: DispatchQueue.global())

        source.setEventHandler { [weak self] in
            let flags = source.data
            if flags.contains(.attrib) {
                self?.log("🔍 File attribute changed: \(filePath)")
            }
            if flags.contains(.write) {
                self?.log("✏️ File written: \(filePath)")
            }
            if flags.contains(.delete) {
                self?.log("🗑️ File deleted: \(filePath)")
                self?.stopMonitoringFile(filePath)
            }
            if flags.contains(.rename) {
                self?.log("🔄 File renamed or moved: \(filePath)")
                self?.stopMonitoringFile(filePath)
            }
        }

        source.setCancelHandler {
            close(fileDescriptor)
        }

        source.resume()
        fileMonitors[filePath] = source
        log("🚀 File access monitoring started: \(filePath)")
    }

    // Stop monitoring the file when deleted or renamed
    func stopMonitoringFile(_ filePath: String) {
        if let source = fileMonitors[filePath] {
            source.cancel()
            fileMonitors.removeValue(forKey: filePath)
            log("🛑 Stopped monitoring file: \(filePath)")
        }
    }
    
    // Stop all monitoring activities (folders and files)
    func stopAllMonitoring() {
        // Stop folder monitoring
        isMonitoring = false
        
        for (folderPath, stream) in folderEventStreams {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            log("🛑 Stopped monitoring folder: \(folderPath)")
        }
        folderEventStreams.removeAll()

        // Stop file monitoring
        for (filePath, source) in fileMonitors {
            source.cancel()
            log("🛑 Stopped monitoring file: \(filePath)")
        }
        fileMonitors.removeAll()

        log("🛑 All monitoring activities stopped.")
    }
}
