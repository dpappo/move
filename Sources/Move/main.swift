import AppKit

MainActor.assumeIsolated {
    if let i = CommandLine.arguments.firstIndex(of: "--screenshots") {
        let dir = CommandLine.arguments.dropFirst(i + 1).first ?? "docs/screenshots"
        Screenshots.render(to: URL(fileURLWithPath: dir))
        exit(0)
    }
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
