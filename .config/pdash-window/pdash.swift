import AppKit
import WebKit

let dashboard = URL(string: "http://localhost:3030/")!

final class TitlebarDragArea: NSView {
    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let start = event.locationInWindow
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if next.type == .leftMouseUp {
                nextResponder?.mouseDown(with: event)
                nextResponder?.mouseUp(with: next)
                return
            }
            if hypot(next.locationInWindow.x - start.x, next.locationInWindow.y - start.y) > 3 {
                window.performDrag(with: event)
                return
            }
        }
    }
}

@MainActor
final class Dashboard: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 1000, height: 640),
        styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
        backing: .buffered,
        defer: false
    )
    let webView = WKWebView()
    private var retry: Task<Void, Error>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        window.title = "pdash"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        if !window.setFrameUsingName("pdash") {
            window.center()
        }
        window.setFrameAutosaveName("pdash")

        let content = window.contentView!
        webView.frame = content.bounds
        webView.autoresizingMask = [.width, .height]
        content.addSubview(webView)

        let titlebarHeight = window.frame.height - window.contentLayoutRect.height
        let dragArea = TitlebarDragArea(
            frame: NSRect(x: 0, y: content.bounds.height - titlebarHeight, width: content.bounds.width, height: titlebarHeight)
        )
        dragArea.autoresizingMask = [.width, .minYMargin]
        content.addSubview(dragArea)
        dragArea.nextResponder = webView

        webView.navigationDelegate = self
        load()
        window.initialFirstResponder = webView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc func load() {
        retry?.cancel()
        webView.load(URLRequest(url: dashboard))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadAgain(after: error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadAgain(after: error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        load()
    }

    private func loadAgain(after error: Error) {
        let failure = error as NSError
        guard !(failure.domain == NSURLErrorDomain && failure.code == NSURLErrorCancelled) else { return }
        retry?.cancel()
        retry = Task {
            try await Task.sleep(for: .seconds(2))
            load()
        }
    }
}

func menu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
    let submenu = NSMenu(title: title)
    submenu.items = items
    let item = NSMenuItem()
    item.submenu = submenu
    return item
}

@main
@MainActor
enum Pdash {
    static func main() {
        let app = NSApplication.shared
        let delegate = Dashboard()
        let reload = NSMenuItem(title: "Reload", action: #selector(Dashboard.load), keyEquivalent: "r")
        reload.target = delegate
        let mainMenu = NSMenu()
        mainMenu.items = [
            menu("pdash", [NSMenuItem(title: "Quit pdash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")]),
            menu("File", [reload, NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")]),
            menu("Edit", [
                NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"),
                NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"),
            ]),
            menu("Window", [NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")]),
        ]
        app.mainMenu = mainMenu
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
