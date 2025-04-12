import SwiftUI

struct ContentView: View {
    @ObservedObject var monitor = WindowMonitor()

    var body: some View {
        VStack(alignment: .leading) {
            Text("Window Event Monitor").font(.title).padding()
            List {
                Section("App Events") {
                    ForEach(monitor.appEvents) { event in
                        VStack(alignment: .leading) {
                            Text("\(event.appName) - \(event.event)").bold()
                            Text("\(event.timestamp.description)").font(.caption)
                        }
                        .padding(4)
                    }
                }
                
                Section("Window Events") {
                    ForEach(monitor.windowEvents) { event in
                        VStack(alignment: .leading) {
                            Text("\(event.appName) - \(event.event)").bold()
                            Text("Window: \(event.windowTitle)").font(.caption)
                            Text("\(event.timestamp.description)").font(.caption)
                        }
                        .padding(4)
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}
