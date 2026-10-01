import SwiftUI
import SwiftTerm

struct TermView: UIViewRepresentable {
    func makeUIView(context: Context) -> TerminalView {
        let tv = TerminalView(frame: .zero)
        tv.terminalDelegate = context.coordinator

        // 启动时打印欢迎语
        let banner = """
        Weave Terminal v0.0.1
        Running in iOS sandbox.
        Type something and press Enter (echo mode for now).

        $ 
        """
        tv.feed(text: banner)

        return tv
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, TerminalViewDelegate {
        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            // 目前只做回显，后续替换为 LocalPTY.write
            if let text = String(bytes: data, encoding: .utf8) {
                source.feed(text: text)
            }
        }

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: TerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func scrolled(source: TerminalView, position: Double) {}
    }
}