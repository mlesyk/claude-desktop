***THIS IS AN UNOFFICIAL BUILD SCRIPT!***

If you run into an issue with this build script, make an issue here. Don't bug Anthropic about it - they already have enough on their plates.

*This repo is the fork of https://github.com/emsi/claude-desktop
which is fork of https://github.com/aaddrick/claude-desktop-debian*

## What was done in This Fork

This fork fixes **Ubuntu 24.04+ compatibility issues** and adds **flexible launch options** missing from the original implementation.

### Key Improvements

- **Ubuntu 24.04+ Launch Fixes**: Resolves AppArmor restrictions and Electron sandbox configuration issues that prevent Claude Desktop from starting on modern Ubuntu systems
- **Sandbox Launch Options**: Interactive dialog to choose between sandboxed (secure isolation) or direct (system access) execution modes
- **Multi-Sandbox Support**: Create and manage multiple isolated sandbox environments for different projects or security contexts

### What's Fixed

The original implementation failed to launch on Ubuntu 24.04+ due to:
- AppArmor blocking user namespace creation for bubblewrap
- Misconfigured Electron chrome-sandbox SUID permissions
- X11 authentication failures in sandboxed environments

This fork automatically detects and applies the necessary fixes during installation, while adding a user-friendly launcher for choosing between secure sandboxed or direct system execution.

# TLDR
To just build and install Claude Desktop on a Debian-based system, run the following command in your terminal:

```bash
wget -O- https://raw.githubusercontent.com/mlesyk/claude-desktop/refs/heads/main/install-claude-desktop.sh | bash
```

# Supports MCP
This app supports running MCP servers on Linux with some caveats. See the [MCP_LINUX.md](MCP_LINUX.md) file for more information.

# Check [MyManus](https://github.com/emsi/MyManus)
[MyManus](https://github.com/emsi/MyManus) is built around this project and offers incredible AI agent capabilities. Check it out!

# Claude Desktop for Linux

This project was inspired by [k3d3's claude-desktop-linux-flake](https://github.com/k3d3/claude-desktop-linux-flake) and their [Reddit post](https://www.reddit.com/r/ClaudeAI/comments/1hgsmpq/i_successfully_ran_claude_desktop_natively_on/) about running Claude Desktop natively on Linux. Their work provided valuable insights into the application's structure and the native bindings implementation.

![image](https://github.com/user-attachments/assets/93080028-6f71-48bd-8e59-5149d148cd45)

Supports the Ctrl+Alt+Space popup!
![image](https://github.com/user-attachments/assets/1deb4604-4c06-4e4b-b63f-7f6ef9ef28c1)

Supports the Tray menu! (Screenshot of running on KDE)
![image](https://github.com/user-attachments/assets/ba209824-8afb-437c-a944-b53fd9ecd559)

# Installation Options

## 1. Debian Package (New!)

For Debian-based distributions (Debian, Ubuntu, Linux Mint, MX Linux, etc.), you can build and install Claude Desktop using the provided build script:

```bash
# Clone this repository
git clone https://github.com/mlesyk/claude-desktop
cd claude-desktop

# Build and install the package
./install-claude-desktop.sh

# The script will automatically:
# - Check for and install required dependencies
# - Download and extract resources from the Windows version
# - Create a proper Debian package
# - Guide you through installation
```

Requirements:
- Any Debian-based Linux distribution
- Node.js >= 12.0.0 and npm
- Root/sudo access for dependency installation

# How it works

Claude Desktop is an Electron application packaged as a Windows executable. Our build script performs several key operations to make it work on Linux:

1. Downloads and extracts the Windows installer
2. Unpacks the app.asar archive containing the application code
3. Replaces the Windows-specific native module with a Linux-compatible implementation
4. Repackages everything into a proper Debian package

The process works because Claude Desktop is largely cross-platform, with only one platform-specific component that needs replacement.

## The Native Module Challenge

The only platform-specific component is a native Node.js module called `claude-native-bindings`. This module provides system-level functionality like:

- Keyboard input handling
- Window management
- System tray integration
- Monitor information

Our build script replaces this Windows-specific module with a Linux-compatible implementation that:

1. Provides the same API surface to maintain compatibility
2. Implements keyboard handling using the correct key codes from the reference implementation
3. Stubs out unnecessary Windows-specific functionality
4. Maintains critical features like the Ctrl+Alt+Space popup and system tray

The replacement module is carefully designed to match the original API while providing Linux-native functionality where needed. This approach allows the rest of the application to run unmodified, believing it's still running on Windows.

## Build Process Details

> Note: The build script was generated by Claude (Anthropic) to help create a Linux-compatible version of Claude Desktop.

The build script (`install-claude-desktop.sh`) handles the entire process:

1. Checks for a Debian-based system and required dependencies
2. Downloads the official Windows installer
3. Extracts the application resources
4. Processes icons for Linux desktop integration
5. Unpacks and modifies the app.asar:
   - Replaces the native module with our Linux version
   - Updates keyboard key mappings
   - Preserves all other functionality
6. Creates a proper Debian package with:
   - Desktop entry for application menus
   - System-wide icon integration
   - Proper dependency management
   - Post-install configuration

## Updating the Build Script

When a new version of Claude Desktop is released, simply update the `CLAUDE_DOWNLOAD_URL` constant at the top of `install-claude-desktop.sh` to point to the new installer. The script will handle everything else automatically.

# License

The build scripts in this repository, are dual-licensed under the terms of the MIT license and the Apache License (Version 2.0).

See [LICENSE-MIT](LICENSE-MIT) and [LICENSE-APACHE](LICENSE-APACHE) for details.

The Claude Desktop application, not included in this repository, is likely covered by [Anthropic's Consumer Terms](https://www.anthropic.com/legal/consumer-terms).

## Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any
additional terms or conditions.
