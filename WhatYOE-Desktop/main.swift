import Cocoa

print("🚀 WhatYOE Desktop App starting...")

let app = NSApplication.shared
let delegate = DesktopAppDelegate()

app.delegate = delegate
app.run()

print("🔚 WhatYOE Desktop App finished")
