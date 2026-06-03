# Event Bar — Functional Specifications

> KDE Plasma 6 applet displaying Google Calendar events in the system panel

## Overview

The applet displays the next event in the KDE panel with relative time and duration. A click opens a popup listing the next 20 events (7 days). Optional notifications at event start and X minutes before.

## Features

### 1. Panel Display (Compact Representation)

**Behavior**
- Displays the title of the next accepted event
- Line 1: event title (ellipsed if too long, max 12 grid units)
- Line 2: relative time + duration separated by " · "
- Fallback: displays "Events" / "upcoming" if not logged in or no events

**Relative time** (updated every minute, synced with system clock)
- All-day: "Today"
- Future > 60min: "in Xh Ymin" or "in Xh"
- Future 1-60min: "in Xmin"
- -1 to 0min: "Now"
- Past: "Xmin ago", "Xh Ymin ago"

**Event priority**
- The first accepted event (`responseStatus === "accepted"`) is displayed
- If none accepted: displays the first in the list
- Declined events are excluded

**Synchronized timer**
- Timer triggers exactly at system minute transitions (`:00` seconds)
- Calculation: `60000 - (Date.now() % 60000)` with < 100ms protection
- Forces binding re-evaluation via `timerTick++`

### 2. Popup (Full Representation)

**Display**
- Min size: 18×14 grid units
- Header: "Upcoming meetings" + refresh button + pin button
- List grouped by date section ("Today", "Tomorrow", day+date)
- States: loading (spinner), empty ("No upcoming events"), error (warning icon + message + retry button), not logged in (config message)

**Event item** (delegate)
- Left colored border (3px): Google Calendar event color or default color
- Left column (5 grid units): time HH:mm or "All day" (italic, opacity 0.7) + duration
- Right column: title + camera icon if Meet + location (opacity 0.7)
- Opacity 0.6 if tentative/needsAction event (not accepted)
- Click: opens Meet URL if available, otherwise event URL

**Buttons**
- Refresh: reloads events (disabled if loading)
- Pin: toggles `hideOnWindowDeactivate` (KDE standard style: `window-pin`)

### 3. Notifications

**Start notification** (if enabled in Options)
- Triggers between 0 and 60s after event start
- Title: "%1 is starting"
- Body: time · duration + location (if present)
- Icon: `camera-video` if Meet, otherwise `appointment-soon`
- Duration: persistent (`-t 0`)
- "Join" action if Meet URL available (click or action → `xdg-open`)

**Reminder notification** (if enabled in Options)
- Triggers X minutes before (config 1-60min, default 5min)
- Title: "Reminder: %1"
- Body: "In X minutes" + location (if present)
- Duration: 10 seconds (`-t 10000`)
- "Join" action if Meet URL available

**Deduplication**
- Tracking via `notifiedEvents` object: key `String(startMs)` for start, `"reminder_" + startMs` for reminder
- Full object reassignment to trigger QML reactivity

### 4. Google Calendar Configuration

**"Google Account" page**
- OAuth 2.0 flow: Client ID + Client Secret → Authorization code → Tokens
- External Python script `lib/google-calendar-oauth.py` for local server
- Storage: `refreshToken` persisted, `accessToken` + `accessTokenExpiresAt` cached
- Automatic token refresh if expired (5s margin)

**"Options" page**
- Switch: "Notify when an event starts"
- Switch: "Show a reminder notification" + SpinBox minutes (1-60, default 5)

### 5. Google Calendar API

**Used endpoints**
- `POST /oauth2/token`: refresh access token
- `GET /calendar/v3/colors`: color palette (once, cached)
- `GET /users/me/calendarList/primary`: default calendar color
- `GET /calendars/primary/events`: events (next 7 days, max 20, `singleEvents=true`, `orderBy=startTime`)

**Refresh frequency**
- Auto: every 5 minutes (if logged in)
- Manual: refresh button in popup
- On login: `onRefreshTokenChanged`

**Colors**
- Priority: `event.colorId` → event color palette
- Fallback: `calendarDefaultColor` (primary calendar color)
- Final fallback: `Kirigami.Theme.highlightColor`

**Filters**
- Exclusion: declined events (`responseStatus === "declined"`)
- Response status: detected via `attendees[].self` (default "accepted" if absent)

## Architecture

### File structure

```
package/contents/
├── ui/
│   ├── main.qml                  # ~305 lines - Orchestrator
│   ├── CompactView.qml            # ~60 lines - Panel
│   ├── FullView.qml               # ~105 lines - Popup
│   ├── EventItem.qml              # ~75 lines - List item
│   ├── ConfigGeneral.qml          # Google Account config
│   ├── ConfigOptions.qml          # Notifications config
│   └── lib/
│       ├── CalendarApi.js         # ~90 lines - Google API (.pragma library)
│       ├── Notifications.js       # ~30 lines - notify-send builders (.pragma library)
│       ├── Requests.js            # HTTP helpers
│       ├── ExecUtil.qml           # Plasma5Support.DataSource wrapper
│       └── google-calendar-oauth.py # OAuth flow
├── config/
│   ├── config.qml                 # Config pages
│   └── main.xml                   # KConfig schema
└── scripts/                       # (empty, OAuth script in lib/)
```

### Responsibilities

**main.qml** (PlasmoidItem)
- Global state: `isLoggedIn`, `isLoading`, `errorMessage`, `nextEvent*`, `eventsModel`, `notifiedEvents`
- Timers: `minuteTimer` (clock sync), `refreshTimer` (5min)
- API: calls `CalendarApi.*` and handles callbacks
- Notifications: `checkEventNotifications()`, `sendEventNotification()`, `sendReminderNotification()`
- i18n formatting: `formatEventTime()`, `formatDuration()`, `formatSectionDate()`
- Instantiates `CompactView` and `FullView` with bindings

**CompactView.qml** (MouseArea)
- Required props: `isLoggedIn`, `nextEventTitle`, `nextEventDuration`, `nextEventIsAllDay`, `nextEventStartMs`, `timerTick`
- Internal function: `formatRelativeTime()` (requires i18n)
- Click: emits `clicked` signal → `root.expanded = !root.expanded`

**FullView.qml** (ColumnLayout)
- Required props: `isLoggedIn`, `isLoading`, `errorMessage`, `events` (ListModel), `hideOnWindowDeactivate`
- Signals: `refreshClicked()`, `togglePin()`
- Delegates to `EventItem` for each event

**EventItem.qml** (PlasmaComponents.ItemDelegate)
- Required props: all model props (`time`, `duration`, `title`, `location`, `hasMeet`, `meetUrl`, `eventUrl`, `responseStatus`, `eventColor`)
- Auto-provided by ListView via model roles

**CalendarApi.js** (.pragma library)
- Pure functions: `ensureAccessToken(config, Requests, callback)`, `loadColors()`, `fetchEvents()`, `getResponseStatus()`
- No QML/i18n dependencies
- Callbacks use `(result, error)` convention: second argument is error string on failure, null on success
- Mutates `config.accessToken` and `config.accessTokenExpiresAt` directly

**Notifications.js** (.pragma library)
- Pure functions: `buildMeetNotifyCommand()`, `buildSimpleNotifyCommand()`, `shellEscape()`
- Returns command arrays for `ExecUtil.exec()`

## Technical Constraints

### QML/Qt 6
- PlasmoidItem (Plasma 6, not PlasmaCore.Applet)
- `compactRepresentation` and `fullRepresentation`: auto-wrapped Components
- Required properties: must be bound at instantiation site
- Scoping: avoid name collisions between props and ids (e.g. `events` vs `eventsModel`)

### i18n (Internationalization)
- `i18n()` and `i18nc()` functions only available in QML files
- `.pragma library` JS files: no i18n access → formatting done in QML
- .po/.mo files: compiled via `bash package/translate/build`
- Supported languages: fr, de, es, it

### Timers and Reactivity
- QML property bindings: automatically re-evaluated if dependencies change
- Signal references (`timer.triggered`): do NOT work to force re-evaluation in Qt 6
- Solution: property counter (`timerTick`) incremented on each tick, referenced in binding
- Object mutation: reassign entire object to trigger reactivity (`notifiedEvents = updated`)

### KDE Notifications
- `notify-send` via Plasma5Support.DataSource engine "executable"
- Interactive actions: `--wait --action=id=label` + shell wrapper `sh -c "..."` to handle return
- Timeout: `-t 0` (persistent), `-t 10000` (10s)
- History: notifications appear in KDE notification center

### Error Handling
- API errors (token refresh, event fetch) are displayed in the popup via `errorMessage` property
- Error state: warning icon + translated message + "Retry" button (only when no cached events)
- If cached events exist during an error, they remain visible (error clears on next successful fetch)
- Errors are logged to journal via `console.warn("[EventBar] ...")`
- `errorMessage` is cleared on successful fetch, on new fetch attempt, and on logout

### Google Calendar API
- OAuth 2.0: refresh token stored, access token volatile
- Rate limiting: not handled (low usage: 1 req/5min)
- Scopes: `calendar.readonly`

## Extension Points

### Adding a New Feature

1. **New event data**: add to model in `main.qml:loadEvents()` + required prop in `EventItem.qml`
2. **New notification**: add `send*Notification()` function in `main.qml` + builder in `Notifications.js`
3. **New formatting**: function in `main.qml` if uses i18n, otherwise in CalendarApi.js
4. **New view**: create `XxxView.qml` with required props, instantiate in `main.qml`
5. **New config**: add entry in `config/main.xml` + access via `plasmoid.configuration.xxx`

### Recommended Manual Tests

- Panel: verify display with accepted, tentative, all-day, past, future events
- Popup: verify grouping by date, scroll, colors, Meet click
- Timer: verify clock sync (transition from one minute to next)
- Notifications: test start (persistent + action) and reminder (10s + action)
- Config: sign in/out, change notification options
- Edge cases: 0 events, 2 simultaneous events, event without title, without location

## Known Bugs / Limitations

- KDE notifications: sometimes don't persist in history (inconsistent notify-send behavior)
- All-day events: `startMs = 0` → no notification possible
- Multi-calendar: primary calendar only
- Timezone: uses system local timezone (no conversion)
