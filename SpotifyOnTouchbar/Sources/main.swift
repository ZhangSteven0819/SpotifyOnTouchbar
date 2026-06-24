import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// 无 Dock 图标（accessory 模式）
app.setActivationPolicy(.accessory)
app.activate(ignoringOtherApps: true)
app.run()
