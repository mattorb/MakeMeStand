[![tests](https://github.com/mattorb/MakeMeStand/actions/workflows/unittest.yml/badge.svg?q=1)](https://github.com/mattorb/MakeMeStand/actions/workflows/unittest.yml)

# Make Me Stand!
A macOS status menu app that automatically triggers the IDÅSEN powered standing desk periodically throughout the day.

![makemestand_statusmenu_app](https://github.com/user-attachments/assets/a20b4249-316a-4b4c-9b70-576b3d34a020)

**Pre-requisite:** Requires you to own the compatible powered desk with matching Linak [DPG] BLE controller.

## Usage
### End User Installation
Not available yet.

### Developer Installation
Build and run in Xcode.

### Automatic Stand & Sit Configuration
1. Configure an interval to match your preferences -- for example, 5 minutes of standing each hour near the end of the hour.
2. Configure the Inactivity timer so automatic stand/sit will disable automatically if you are away from the computer (based on no mouse/keyboard activity) for more than x minutes.  Ghost buster 😀
3. Launch on demand, or set it to launch on login.
4. Connect&Pair to your preferred desk and enable autoconnect for the next time it is launched.

## Project Status
I cobbled this together as a side project just for fun.

I wanted to explore writing tests for code that interacts with a BLE device, using the Blueconnect library.

## Acknowledgements
Inspiration and many learnings from these projects:
- [idasen-controller-mac](https://github.com/DWilliames/idasen-controller-mac)
- [Blueconnect](https://github.com/danielepantaleone/BlueConnect)
