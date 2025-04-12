import SwiftUI

struct ContentView: View {
    @StateObject private var windowMonitor = WindowMonitor()
    
    var body: some View {
        TabView {
            AppEventsView()
                .tabItem {
                    Label("应用事件", systemImage: "app.badge")
                }
            
            WindowEventsView()
                .tabItem {
                    Label("窗口事件", systemImage: "window.shade.open")
                }
        }
        .environmentObject(windowMonitor)
    }
}

struct AppEventsView: View {
    @EnvironmentObject var windowMonitor: WindowMonitor
    
    var body: some View {
        List(windowMonitor.appEvents) { event in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.appName)
                        .font(.headline)
                    Spacer()
                    Text(event.formattedTimestamp)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(event.event)
                    .font(.subheadline)
                
                if let duration = event.formattedDuration {
                    Text("运行时长: \(duration)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct WindowEventsView: View {
    @EnvironmentObject var windowMonitor: WindowMonitor
    
    var body: some View {
        List(windowMonitor.windowEvents) { event in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.appName)
                        .font(.headline)
                    Spacer()
                    Text(event.formattedTimestamp)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(event.windowTitle)
                    .font(.subheadline)
                
                Text(event.event)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let duration = event.formattedDuration {
                    Text("打开时长: \(duration)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
