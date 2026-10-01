import SwiftUI

@main
struct WeaveApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            TermView()
                .tabItem {
                    Label("Terminal", systemImage: "terminal")
                }

            // Web 表面：先占位，M2 再填
            VStack {
                Text("Web Surface (Coming soon)")
                    .foregroundStyle(.secondary)
            }
            .tabItem {
                Label("Browser", systemImage: "globe")
            }
        }
    }
}