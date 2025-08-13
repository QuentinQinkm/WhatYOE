import Cocoa

print("🚀 WhatYOE Background Service starting...")

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate
app.run()

print("🔚 WhatYOE Background Service finished")