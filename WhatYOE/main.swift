import Cocoa

print("🚀 main.swift starting - PRINT STATEMENT")

let app = NSApplication.shared
print("✅ NSApplication.shared created - PRINT STATEMENT")

let delegate = AppDelegate()
print("✅ AppDelegate created - PRINT STATEMENT")

app.delegate = delegate
print("✅ AppDelegate set as delegate - PRINT STATEMENT")

print("🔧 Starting app.run() - PRINT STATEMENT")
app.run()

print("🔚 App finished - PRINT STATEMENT")
