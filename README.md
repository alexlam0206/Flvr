# Flvr 🔥

Flvr is a native macOS menu bar application designed for the Hack Club community to stay updated with Flavortown (flavortown.hackclub.com). It provides a real-time view of projects, store items, and user rankings directly from your menu bar.

## Features

- **Menu Bar Only**: Lives in your system tray, keeping your Dock clean.
- **Real-time Updates**: Automatically fetches fresh data every 60 seconds.
- **Projects Feed**: Browse the latest projects, view demo links, and check out source code repositories.
- **Devlog Integration**: Toggle detailed devlog information to see total time logged and the latest updates for each project.
- **Flavortown Store**: View available items in the store and their current ticket costs.
- **User Rankings**: See top contributors, their Slack IDs, and cookie counts.
- **Custom Header**: Automatically includes the required `X-Flavortown-Ext-2532` header for all API requests.

## How to Use

1. **Launch the app**: The "Flvr" icon (🔥) will appear in your menu bar.
2. **Click the icon**: View the main dashboard with three tabs:
   - 🔨 **Projects**: See what others are building.
   - 🛒 **Store**: Browse Flavortown rewards.
   - 👥 **Users**: See the community leaderboard.
3. **Refresh**: Use the refresh button (↻) in the top right for an immediate update.
4. **Devlog Toggle**: Switch on "Show devlog info" in the Projects tab to see time tracking details.

## Technical Details

- **Built with**: SwiftUI & Swift 6.
- **OS Support**: macOS 14.0+ (Sonoma and later).
- **Architecture**: Modern `@Observable` state management.
- **Persistence**: Integration-ready for future local data caching.

## Contributing

This project was built as a menu bar utility for the Hack Club community. Contributions and feedback are welcome!

---
*Built with love for Hack Club.*
