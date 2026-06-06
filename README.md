# Event Bar — KDE Plasma 6 Applet

A KDE Plasma 6 applet that displays your upcoming Google Calendar events directly in the system panel with desktop notifications.

## Features

- **Panel display**: Shows next event title with relative time ("in 5min", "Now", "3min ago")
- **Popup view**: Lists next 20 events (7 days) grouped by date with color-coded borders
- **Notifications**: Optional alerts when events start (persistent) and X minutes before (configurable)
- **Google Meet integration**: One-click join via notification action button
- **Multi-language**: Supports EN, FR, DE, ES, IT
- **Smart prioritization**: Displays accepted events first in panel

## Installation

### Prerequisites

- KDE Plasma 6
- Python 3 (for OAuth flow)
- `notify-send` (for desktop notifications)
- `xdg-open` (for opening URLs from notifications)
- Google Calendar API credentials (Client ID + Secret)

### Install

```bash
kpackagetool6 -t Plasma/Applet -i package
```

### Update

```bash
kpackagetool6 -t Plasma/Applet -u package
```

## Configuration

1. Right-click the applet → Configure
2. Enter your Google API Client ID and Client Secret
3. Click "Sign in with Google" and authorize
4. Optionally enable notifications in the "Options" tab

### Getting Google Calendar API Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project
3. Enable the Google Calendar API
4. Create OAuth 2.0 credentials (Desktop app type)
5. Copy Client ID and Client Secret

## Development

See [SPECS.md](SPECS.md) for complete functional specifications and [CLAUDE.md](CLAUDE.md) for development guidelines.

```bash
# Deploy changes
kpackagetool6 -t Plasma/Applet -u package

# Restart Plasma
plasmashell --replace

# Check logs
journalctl --user --since "1 min ago" | grep eventbar

# Compile translations
bash package/translate/build
```

## Architecture

- **main.qml** (~305 lines): Orchestrator with state, timers, API calls
- **CompactView.qml**: Panel representation with relative time
- **FullView.qml**: Popup with event list and controls
- **EventItem.qml**: Individual event delegate
- **lib/CalendarApi.js**: Google Calendar API logic
- **lib/Notifications.js**: Desktop notification builders

## License

MIT
