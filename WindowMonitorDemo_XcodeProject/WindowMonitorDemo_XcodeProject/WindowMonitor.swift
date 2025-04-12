import Cocoa
import ApplicationServices

class AppEvent: Identifiable {
    let id = UUID()
    let appName: String
    let bundleIdentifier: String
    let event: String
    let timestamp: Date
    let duration: TimeInterval?  // 如果是退出事件，记录运行时长
    
    // 添加日期格式化器
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter
    }()
    
    var formattedTimestamp: String {
        return AppEvent.dateFormatter.string(from: timestamp)
    }
    
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    init(appName: String, bundleIdentifier: String, event: String, timestamp: Date, duration: TimeInterval? = nil) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.event = event
        self.timestamp = timestamp
        self.duration = duration
    }
}

class WindowEvent: Identifiable {
    let id = UUID()
    let appName: String
    let event: String
    let timestamp: Date
    let windowTitle: String
    let duration: TimeInterval?  // 如果是关闭事件，记录窗口打开时长
    
    // 添加日期格式化器
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter
    }()
    
    var formattedTimestamp: String {
        return WindowEvent.dateFormatter.string(from: timestamp)
    }
    
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    init(appName: String, event: String, timestamp: Date, windowTitle: String, duration: TimeInterval? = nil) {
        self.appName = appName
        self.event = event
        self.timestamp = timestamp
        self.windowTitle = windowTitle
        self.duration = duration
    }
}

class WindowMonitor: ObservableObject {
    @Published var appEvents: [AppEvent] = []
    @Published var windowEvents: [WindowEvent] = []
    var observers: [AXObserver] = []
    private var windowOpenTimes: [String: Date] = [:]  // 记录窗口打开时间
    private var appStartTimes: [String: Date] = [:]   // 记录应用启动时间
    private var appObservers: [pid_t: AXObserver] = [:]  // 记录每个应用的观察者

    init() {
        setupApplicationMonitoring()
        
        // 监控所有已运行的应用程序
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            monitorApplication(app)
        }
    }
    
    private func setupApplicationMonitoring() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        
        // 监控应用启动
        notificationCenter.addObserver(
            self,
            selector: #selector(appLaunched(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        
        // 监控应用退出
        notificationCenter.addObserver(
            self,
            selector: #selector(appTerminated(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        
        // 监控应用激活/失活
        notificationCenter.addObserver(
            self,
            selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(appDeactivated(_:)),
            name: NSWorkspace.didDeactivateApplicationNotification,
            object: nil
        )
    }
    
    @objc func appLaunched(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            monitorApplication(app)
            let timestamp = Date()
            appStartTimes[app.bundleIdentifier ?? ""] = timestamp
            appEvents.insert(AppEvent(appName: app.localizedName ?? "Unknown",
                                    bundleIdentifier: app.bundleIdentifier ?? "",
                                    event: "App Launched",
                                    timestamp: timestamp), at: 0)
        }
    }
    
    @objc func appTerminated(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           let startTime = appStartTimes[app.bundleIdentifier ?? ""] {
            let timestamp = Date()
            let duration = timestamp.timeIntervalSince(startTime)
            appStartTimes.removeValue(forKey: app.bundleIdentifier ?? "")
            
            if let pid = app.processIdentifier as pid_t? {
                appObservers.removeValue(forKey: pid)
            }
            
            appEvents.insert(AppEvent(appName: app.localizedName ?? "Unknown",
                                    bundleIdentifier: app.bundleIdentifier ?? "",
                                    event: "App Terminated",
                                    timestamp: timestamp,
                                    duration: duration), at: 0)
        }
    }
    
    @objc func appActivated(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            appEvents.insert(AppEvent(appName: app.localizedName ?? "Unknown",
                                    bundleIdentifier: app.bundleIdentifier ?? "",
                                    event: "App Activated",
                                    timestamp: Date()), at: 0)
        }
    }
    
    @objc func appDeactivated(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            appEvents.insert(AppEvent(appName: app.localizedName ?? "Unknown",
                                    bundleIdentifier: app.bundleIdentifier ?? "",
                                    event: "App Deactivated",
                                    timestamp: Date()), at: 0)
        }
    }
    
    private func monitorApplication(_ app: NSRunningApplication) {
        guard let pid = app.processIdentifier as pid_t? else { return }
        let axApp = AXUIElementCreateApplication(pid)

        var observer: AXObserver?
        let callback: AXObserverCallback = { observer, element, notification, refcon in
            WindowMonitor.windowCallback(observer, element, notification, refcon)
        }

        let error = AXObserverCreate(pid, callback, &observer)
        if error == .success, let obs = observer {
            let runLoopSource = AXObserverGetRunLoopSource(obs)
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
            observers.append(obs)
            appObservers[pid] = obs

            // 创建一个包含 WindowMonitor 和 NSRunningApplication 的结构体
            let context = UnsafeMutablePointer<WindowContext>.allocate(capacity: 1)
            context.initialize(to: WindowContext(monitor: self, app: app))
            
            AXObserverAddNotification(obs, axApp, kAXWindowCreatedNotification as CFString, context)
            AXObserverAddNotification(obs, axApp, kAXUIElementDestroyedNotification as CFString, context)
        }
    }

    // 用于存储上下文信息的结构体
    private struct WindowContext {
        let monitor: WindowMonitor
        let app: NSRunningApplication
    }

    private static func windowCallback(_ observer: AXObserver,
                                     _ element: AXUIElement,
                                     _ notification: CFString,
                                     _ refcon: UnsafeMutableRawPointer?) {
        if let notification = notification as? String,
           let context = refcon?.assumingMemoryBound(to: WindowContext.self) {
            let mySelf = context.pointee.monitor
            let app = context.pointee.app
            let appName = app.localizedName ?? "Unknown"
            let timestamp = Date()
            
            // 获取窗口标题
            var windowTitle: AnyObject?
            AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &windowTitle)
            let title = (windowTitle as? String) ?? "Untitled Window"
            
            // 创建窗口标识符
            let windowIdentifier = "\(appName)-\(title)"
            
            if notification == kAXWindowCreatedNotification {
                // 记录窗口打开时间
                mySelf.windowOpenTimes[windowIdentifier] = timestamp
                DispatchQueue.main.async {
                    mySelf.windowEvents.insert(WindowEvent(appName: appName, 
                                                         event: "Window Opened", 
                                                         timestamp: timestamp,
                                                         windowTitle: title), at: 0)
                }
            } else if notification == kAXUIElementDestroyedNotification {
                // 计算窗口打开时长
                let duration = mySelf.windowOpenTimes[windowIdentifier].map { timestamp.timeIntervalSince($0) }
                mySelf.windowOpenTimes.removeValue(forKey: windowIdentifier)
                
                DispatchQueue.main.async {
                    mySelf.windowEvents.insert(WindowEvent(appName: appName, 
                                                         event: "Window Closed", 
                                                         timestamp: timestamp,
                                                         windowTitle: title,
                                                         duration: duration), at: 0)
                }
            }
        }
    }
}
