# WhatYOE - AI Job Experience Analyzer

A Safari web extension that uses Apple's Foundation Models to analyze job experience requirements on LinkedIn.

## Features

- 🤖 **AI-Powered Analysis**: Uses Apple's Foundation Models to extract years of experience requirements
- 🎯 **Smart Job Card Labels**: Color-coded labels showing "✓ 3 Years", "✗ 5 Years", or "Unspecified"
- 🔄 **Auto-Analysis**: Toggle to automatically analyze jobs when navigating LinkedIn pages
- 📊 **Live Statistics**: Real-time stats showing qualifying jobs, too high requirements, and total analyzed

## System Requirements

- **macOS 26.0 or later**
- **Xcode 26.0 or later**
- **Apple's Foundation Models** availability on your device

## Setup

1. **Enable Developer Extensions**: Open Safari and choose Develop > Allow Unsigned Extensions
2. **Configure App Target**: In Xcode project settings, select the WhatYOE target
3. **Setup Signing**: Click the Signing & Capabilities tab and choose "Sign to Run Locally"
4. **Configure Extension Target**: Repeat step 3 for the WhatYOE Extension target
5. **Build and Run**: Build the project in Xcode and run the WhatYOE app
6. **Enable Extension**: Go to Safari > Settings > Extensions and enable "WhatYOE Extension"

## Usage

1. Navigate to [LinkedIn Jobs](https://www.linkedin.com/jobs/)
2. Click the extension icon in Safari's toolbar
3. Enter your years of experience
4. Click "Analyze Jobs" or toggle "Auto-Analysis"
5. View color-coded labels on job cards:
   - 🟢 **Green "✓ X Years"**: You qualify
   - 🔴 **Red "✗ X Years"**: Requires more experience
   - 🟡 **Yellow "Unspecified"**: Requirements unclear

## License

See the LICENSE.txt file for this sample's licensing information.

