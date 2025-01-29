[![tests](https://github.com/mattorb/MakeMeStand/actions/workflows/unittest.yml/badge.svg?q=1)](https://github.com/mattorb/MakeMeStand/actions/workflows/unittest.yml)
![License](https://img.shields.io/github/license/mattorb/MakeMeStand)

# Make Me Stand!
A macOS status menu app that automatically triggers the IDÅSEN powered standing desk periodically throughout the day.

Status Menu

<img src="https://github.com/user-attachments/assets/b0a4a86d-75fc-47f0-bc48-a2fcee20abb3" width="300">

Settings

<img src="https://github.com/user-attachments/assets/a448649c-ea32-46db-921a-168c3473de88" width="300">

## Why?
1. To make repeated and frequent standing throughout the day an easier default than not.
1. I was looking for an excuse to explore writing tests for code that interacts with a BLE device, using the Blueconnect library, and building a status menu app with SwiftUI.

**Pre-requisite:** Requires you to own the compatible powered desk with matching Linak [DPG] BLE controller.

## Features
- Shows connection status and desk height (configurable) in status menu
- Save your preferred stand/sit height
- Configurable automatic stand/sit interval, per hour
- Automatic stand/sit behavior disables temporarily if you haven't touched the mouse or keyboard for a period of time (configurable)
- Double tap the hardware switch to move to stand/sit position

## Usage
### End User Installation
Not available yet.

### Developer Installation
Build and run in Xcode.

### Automatic Stand & Sit Configuration
1. Configure an interval to match your preferences -- for example, 5 minutes of standing each hour near the end of the hour.
1. Configure the Inactivity timer so automatic stand/sit will disable automatically if you are away from the computer (based on no mouse/keyboard activity) for more than x minutes.  Ghost buster 😀
1. Launch on demand, or set it to launch on login.
1. Connect&Pair to your preferred desk and enable autoconnect for the next time it is launched.

## Contributing
Fork the repo and create a new branch (feature-xyz).
Submit a pull request with a clear description.

## License
This project is licensed under the MIT License.

## Acknowledgements
Inspiration and many learnings from these projects:
- [idasen-controller-mac](https://github.com/DWilliames/idasen-controller-mac)
- [Blueconnect](https://github.com/danielepantaleone/BlueConnect)
