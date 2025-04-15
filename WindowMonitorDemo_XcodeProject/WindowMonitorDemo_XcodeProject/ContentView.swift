import SwiftUI

struct ContentView: View {
    @StateObject private var windowMonitor = WindowMonitor()
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            if let bootTime = windowMonitor.bootTime {
                HStack {
                    Text("系统启动时间:")
                        .font(.headline)
                    Text(bootTime.formatted(date: .long, time: .standard))
                        .font(.subheadline)
                    Spacer()
                }
                .padding()
                .background(Color(.windowBackgroundColor))
                Divider()
            }
            
            Picker("视图", selection: $selectedTab) {
                Text("活动记录").tag(0)
                Text("应用时长").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            if selectedTab == 0 {
                List(windowMonitor.activities) { activity in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            if activity.data.app == "System" {
                                Image(systemName: activity.data.title == "屏幕锁定" ? "lock.fill" : "lock.open.fill")
                                    .foregroundColor(activity.data.title == "屏幕锁定" ? .red : .green)
                            }
                            Text(activity.data.app)
                                .font(.headline)
                            Spacer()
                            Text(activity.formattedTimestamp)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(activity.data.title)
                            .font(.subheadline)
                        
                        if activity.duration > 0 {
                            Text("持续时间: \(activity.formattedDuration)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                List(windowMonitor.appDurations) { appDuration in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(appDuration.appName)
                                    .font(.headline)
                                if appDuration.isRunning {
                                    Image(systemName: "circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 8))
                                }
                            }
                            if let launchTime = appDuration.launchTime {
                                Text("启动时间: \(launchTime.formatted(date: .omitted, time: .shortened))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if appDuration.isRunning, let launchTime = appDuration.launchTime {
                            Text(formatDuration(Date().timeIntervalSince(launchTime)))
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
