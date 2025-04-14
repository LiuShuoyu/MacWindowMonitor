import Cocoa
import ApplicationServices
import IOKit

struct WindowActivity: Identifiable, Codable {
    let id: Int
    let timestamp: String
    let duration: Double
    let data: WindowData
    
    struct WindowData: Codable {
        let app: String
        let title: String
        let url: String?
    }
    
    // 修改为 internal 访问级别
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter
    }()
    
    var formattedTimestamp: String {
        if let date = WindowActivity.dateFormatter.date(from: timestamp) {
            let localFormatter = DateFormatter()
            localFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            localFormatter.timeZone = TimeZone.current
            return localFormatter.string(from: date)
        }
        return timestamp
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        let milliseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
    }
}

class WindowMonitor: ObservableObject {
    @Published var activities: [WindowActivity] = []
    @Published var bootTime: Date?
    private var windowStates: [String: (startTime: Date, appName: String, windowTitle: String)] = [:]
    private var currentId = 0
    private var screenLocked = false
    
    init() {
        setupWindowMonitoring()
        getBootTime()
        setupScreenLockMonitoring()
    }
    
    private func getBootTime() {
        var bootTime = timeval()
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        var size = MemoryLayout<timeval>.stride
        
        if sysctl(&mib, 2, &bootTime, &size, nil, 0) == 0 {
            self.bootTime = Date(timeIntervalSince1970: Double(bootTime.tv_sec) + Double(bootTime.tv_usec) / 1_000_000.0)
        }
    }
    
    private func setupWindowMonitoring() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        
        // 监听窗口创建
        notificationCenter.addObserver(
            self,
            selector: #selector(windowCreated(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        
        // 监听窗口关闭
        notificationCenter.addObserver(
            self,
            selector: #selector(windowTerminated(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        
        // 监听窗口激活/失活
        notificationCenter.addObserver(
            self,
            selector: #selector(windowActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(windowDeactivated(_:)),
            name: NSWorkspace.didDeactivateApplicationNotification,
            object: nil
        )
        
        // 初始检查所有窗口
        checkAllWindows()
    }
    
    private func checkAllWindows() {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return
        }
        
        let now = Date()
        for windowInfo in windows {
            if let windowNumber = windowInfo[kCGWindowNumber as String] as? Int,
               let windowTitle = windowInfo[kCGWindowName as String] as? String,
               let appName = windowInfo[kCGWindowOwnerName as String] as? String {
                let windowKey = "\(appName)-\(windowTitle)"
                if windowStates[windowKey] == nil {
                    windowStates[windowKey] = (startTime: now, appName: appName, windowTitle: windowTitle)
                }
            }
        }
    }
    
    @objc private func windowCreated(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            let now = Date()
            let windowKey = "\(app.localizedName ?? "Unknown")"
            windowStates[windowKey] = (startTime: now, appName: app.localizedName ?? "Unknown", windowTitle: app.localizedName ?? "Unknown")
        }
    }
    
    @objc private func windowTerminated(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            let windowKey = "\(app.localizedName ?? "Unknown")"
            if let windowState = windowStates[windowKey] {
                let duration = Date().timeIntervalSince(windowState.startTime)
                recordActivity(windowState: windowState, duration: duration)
                windowStates.removeValue(forKey: windowKey)
            }
        }
    }
    
    @objc private func windowActivated(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            let now = Date()
            let windowKey = "\(app.localizedName ?? "Unknown")"
            windowStates[windowKey] = (startTime: now, appName: app.localizedName ?? "Unknown", windowTitle: app.localizedName ?? "Unknown")
        }
    }
    
    @objc private func windowDeactivated(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            let windowKey = "\(app.localizedName ?? "Unknown")"
            if let windowState = windowStates[windowKey] {
                let duration = Date().timeIntervalSince(windowState.startTime)
                recordActivity(windowState: windowState, duration: duration)
                windowStates.removeValue(forKey: windowKey)
            }
        }
    }
    
    private func recordActivity(windowState: (startTime: Date, appName: String, windowTitle: String), duration: TimeInterval) {
        let activity = WindowActivity(
            id: currentId,
            timestamp: WindowActivity.dateFormatter.string(from: windowState.startTime),
            duration: duration,
            data: WindowActivity.WindowData(
                app: windowState.appName,
                title: windowState.windowTitle,
                url: nil
            )
        )
        
        DispatchQueue.main.async {
            self.activities.insert(activity, at: 0)
        }
        currentId += 1
    }
    
    private func setupScreenLockMonitoring() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        
        // 监听屏幕锁定
        notificationCenter.addObserver(
            self,
            selector: #selector(screenLocked(_:)),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        
        // 监听屏幕解锁
        notificationCenter.addObserver(
            self,
            selector: #selector(screenUnlocked(_:)),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }
    
    @objc private func screenLocked(_ notification: Notification) {
        screenLocked = true
        let now = Date()
        let activity = WindowActivity(
            id: currentId,
            timestamp: WindowActivity.dateFormatter.string(from: now),
            duration: 0,
            data: WindowActivity.WindowData(
                app: "System",
                title: "屏幕锁定",
                url: nil
            )
        )
        
        DispatchQueue.main.async {
            self.activities.insert(activity, at: 0)
        }
        currentId += 1
    }
    
    @objc private func screenUnlocked(_ notification: Notification) {
        screenLocked = false
        let now = Date()
        let activity = WindowActivity(
            id: currentId,
            timestamp: WindowActivity.dateFormatter.string(from: now),
            duration: 0,
            data: WindowActivity.WindowData(
                app: "System",
                title: "屏幕解锁",
                url: nil
            )
        )
        
        DispatchQueue.main.async {
            self.activities.insert(activity, at: 0)
        }
        currentId += 1
    }
}
