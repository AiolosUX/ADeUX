<!--
  This is the RELEASE TEMPLATE — do not fill this one in by hand.
  It's read by .github/workflows/build-release.yml, which substitutes the
  {{PLACEHOLDER}} tokens below with content generated at build time
  (device table) and with the sections you wrote in .github/whats-new.md
  (New Features / Improvements / Bug Fixes / Known Issues / Full Changelog).

  Edit this file only if you want to change the overall LAYOUT of the
  release notes (add/remove sections, change wording, add links).
  To change the CONTENT of a specific release, edit whats-new.md instead.
-->

# ADeUX

### ArkOS Debian User eXperience

ADeUX is an independent, community-driven Linux distribution based on **dArkOS**, focused on supporting and improving the **Game Console** line of retro gaming handhelds.

ADeUX is the successor to the former **ArkOS-R3XS** project, carrying forward its device-specific development, configurations, fixes, and community work.

Images and releases for ADeUX are published through this repository's [Releases](https://github.com/AeolusUX/ADeUX/releases).

---

## Installation

1. Download the appropriate ADeUX package for your device below.
2. Download **all** listed archive parts (`.7z.001`, `.7z.002`, ...) and place them in the same directory.
3. Extract the `.7z.001` file using [7-Zip](https://www.7-zip.org/). The resulting file will be an `.img` image.
4. Write the `.img` image to your microSD card using an imaging tool such as [Raspberry Pi Imager](https://www.raspberrypi.com/software/), [balenaEtcher](https://etcher.balena.io/), or [Win32 Disk Imager](https://sourceforge.net/projects/win32diskimager/).
5. Insert the microSD card into your device and power it on.

> **WARNING:** Writing an image to an SD card will erase all existing data on the card. Make sure you select the correct device.

---

## Supported Devices & Installation Packages

| **Device** | **Date** | **Download** |
|---|---|---|
{{DEVICE_TABLE}}

> **Note:** All split archive parts listed for a device are required. Keep them together before extracting.

---

## What's New

### New Features

{{NEW_FEATURES}}

### Improvements

{{IMPROVEMENTS}}

### Bug Fixes

{{BUG_FIXES}}

{{CHANGELOG_LINE}}

---

## Known Issues

{{KNOWN_ISSUES}}

---

## Support

If you want to support the project and help us continue purchasing devices for development and testing, you can support ADeUX through Ko-fi:

[![Support ADeUX on Ko-fi](https://camo.githubusercontent.com/201ef269611db7eb6b5d08e9f756ab8980df3014b64492770bdf13a6ed924641/68747470733a2f2f6b6f2d66692e636f6d2f696d672f676974687562627574746f6e5f736d2e737667)](https://ko-fi.com/A0A1J951S)
</content>