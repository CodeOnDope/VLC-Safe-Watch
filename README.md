# 🛡️ VLC Safe Watch

> **Family movie nights, worry-free**

A powerful VLC media player extension that creates customized, family-friendly viewing experiences by skipping unwanted content or playing only specific segments.

[![VLC Version](https://img.shields.io/badge/VLC-3.0%2B-orange)](https://www.videolan.org/vlc/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)](https://github.com/your-username/vlc-safe-watch)

## ✨ Features

- 🎬 **Two Viewing Modes**: Skip unwanted segments or play only marked content
- 📍 **Easy Time Marking**: Capture timestamps with "Now" buttons or manual entry
- 💾 **Smart File Management**: Playlists saved automatically in the same folder as your video
- 🔄 **Non-Destructive**: Original videos remain completely untouched
- ⚡ **Real-Time Detection**: Automatically detects and monitors playing videos
- 🎯 **Frame-Accurate**: Precise timing control for seamless viewing
- 📝 **Visual Interface**: User-friendly step-by-step workflow
- 🔁 **Reusable Playlists**: Create once, enjoy repeatedly

## 🚀 Quick Start

### Installation

1. **Download** the `vlc_safe_watch.lua` file from this repository
2. **Copy** to your VLC extensions folder:
   - **Windows**: `%APPDATA%\vlc\lua\extensions\`
   - **macOS**: `~/Library/Application Support/VLC/lua/extensions/`
   - **Linux**: `~/.local/share/vlc/lua/extensions/`
3. **Restart** VLC Media Player
4. **Access** via `View > VLC Safe Watch` in VLC menu

### Usage

1. **🔍 Play Video**: Open any video in VLC
2. **🎯 Choose Mode**: Select SKIP (remove content) or PLAY (keep only marked content)
3. **📝 Mark Segments**: Use timestamp buttons to mark start/end times
4. **🎬 Create Playlist**: Generate M3U playlist for safe viewing

## 📖 How It Works

### SKIP Mode
Perfect for removing inappropriate content while keeping the story intact

### PLAY Mode  
Great for highlights, educational content, or favorite scenes


## 🎯 Use Cases

- **👨‍👩‍👧‍👦 Families**: Watch movies with children safely
- **🎓 Educators**: Create focused video lessons
- **📺 Content Creators**: Extract specific segments
- **🏠 Home Theater**: Customize viewing experiences
- **📚 Researchers**: Analyze specific video portions

## 📁 File Organization

VLC Safe Watch intelligently saves playlists in the **same folder as your video files**:

```
📁 Movies/
├── 📄 movie.mp4
└── 📄 safe_watch_movie_20241207_143022.m3u  ← Generated playlist
```

Benefits:
- ✅ Easy to find and organize
- ✅ Perfect for family sharing
- ✅ Backup-friendly (files stay together)
- ✅ No hunting through folders

## 🖥️ Screenshots

### Main Interface
![VLC Safe Watch Interface](screenshots/interface.png)
*Clean, step-by-step interface guides you through the process*

### Video Detection
![Video Detection](screenshots/detection.png)
*Automatic video detection with real-time position tracking*

### Segment Management
![Segment Management](screenshots/segments.png)
*Easy segment marking and management*

## ⚙️ Technical Details

### Requirements
- VLC Media Player 3.0 or higher
- Lua extension support (enabled by default)

### Supported Formats
- All video formats supported by VLC
- Generates standard M3U playlist files
- Works with local files and network streams

### File Output
```m3u
#EXTM3U
# VLC Safe Watch Export
# Video: Movie Title
# Mode: SKIP
# Created: 2024-12-07 14:30:22

#EXTVLCOPT:start-time=0
#EXTVLCOPT:stop-time=300
#EXTINF:300,Movie Title - Part 1 (00:00:00-00:05:00)
file:///path/to/video.mp4
```

## 🛠️ Development

### Building from Source
```bash
git clone https://github.com/your-username/vlc-safe-watch.git
cd vlc-safe-watch
# Copy vlc_safe_watch.lua to VLC extensions folder
```

### Contributing
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

📋 Changelog
v2.5.11 (Latest)

✅ Fixed extension reopening issues
✅ Improved dialog management
✅ Enhanced cleanup processes
✅ Better error handling

v2.5.10

✅ Added HTML font colors for step indicators
✅ Improved UI visual feedback
✅ Enhanced status updates
## 🤝 Support

### Getting Help
- 📚 Check the [Wiki](../../wiki) for detailed guides
- 🐛 Report bugs via [Issues](../../issues)
- 💬 Join discussions in [Discussions](../../discussions)
- 📧 Contact: [dina.multi@gmail.com](mailto:dina.multi@gmail.com)

### Known Issues
- Some network streams may not be detected immediately
- Very short segments (< 0.5s) may be filtered out
- Folder write permissions may affect save location

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- VLC Media Player team for the excellent Lua extension API
- Community contributors and testers
- Families worldwide who deserve worry-free movie nights


<div align="center">

**Made with ❤️ for families everywhere**

[🌟 Star this repo](../../stargazers) • [🍴 Fork](../../fork) • [📥 Download](../../releases/latest)

</div>
