import SwiftUI

struct ContentView: View {
    @StateObject private var windowMonitor = WindowMonitor()
    
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
            
            List(windowMonitor.activities) { activity in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(activity.data.app)
                            .font(.headline)
                        Spacer()
                        Text(activity.formattedTimestamp)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(activity.data.title)
                        .font(.subheadline)
                    
                    if activity.duration >= 0 {
                        Text("持续时间: \(activity.formattedDuration)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}
