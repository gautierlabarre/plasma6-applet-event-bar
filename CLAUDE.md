# Instructions for Claude Code

## Project

KDE Plasma 6 applet displaying Google Calendar events. See [SPECS.md](SPECS.md) for complete feature and architecture documentation.

## Development Rules

### 1. Maintaining Specifications

**IMPORTANT**: Every functional or architectural change must be reflected in `SPECS.md`:

- **New feature**: document in appropriate section with expected behavior
- **Behavior change**: update relevant section
- **Architecture change**: update file structure and responsibilities
- **Bug fix that changes behavior**: document new correct behavior
- **Added technical constraint**: add to "Technical Constraints"

**When to update**: After each commit that modifies:
- User-visible behavior
- API or Google Calendar endpoints
- File structure or component responsibilities
- Formatting or calculation rules
- Notifications

**How**: Read SPECS.md, identify relevant section, update with changes. If change doesn't fit any section, add a new one.

### 2. Internationalization (i18n)

- **ALWAYS** use `i18n()` or `i18nc()` for user-facing strings
- **NEVER** hardcode text in English or French in code
- Formatting functions using i18n **MUST** stay in QML files
- After adding new strings: update `package/translate/template.pot` and .po files

### 3. Architecture and Separation

- **main.qml**: orchestrator only (state, timers, coordination)
- **Views (CompactView, FullView, EventItem)**: pure presentation with required props
- **lib/*.js (.pragma library)**: pure logic without QML/i18n dependencies
- **Do NOT** mix business logic and presentation in views
- **Do NOT** access `plasmoid.configuration` directly from views

### 4. Notifications

- Use `Notifications.js` builders to construct commands
- Always use `shellEscape()` for arguments containing user text
- Deduplication: tracking via `notifiedEvents` with full object reassignment

### 5. Timers and QML Reactivity

- **Clock synchronization**: timer calculated via `msUntilNextMinute()`
- **Force re-evaluation**: use property counter (`timerTick++`), NOT signal reference
- **Object mutation**: always reassign (`obj = updated`), don't just mutate

### 6. Manual Testing

Before considering a change complete:
1. Deploy with `kpackagetool6 -t Plasma/Applet -u package`
2. Restart with `plasmashell --replace`
3. Check logs: `journalctl --user --since "1 min ago" | grep eventbar`
4. Test nominal case AND edge cases listed in SPECS.md

## Useful Commands

```bash
# Deploy and test
kpackagetool6 -t Plasma/Applet -u package && plasmashell --replace &

# Compile translations
bash package/translate/build

# Check logs
journalctl --user -u plasma-plasmashell.service --since "1 min ago"
```

## References

- [KDE Plasma QML API](https://api.kde.org/frameworks/plasma-framework/html/index.html)
- [Google Calendar API](https://developers.google.com/calendar/api/v3/reference)
- [Qt 6 QML](https://doc.qt.io/qt-6/qmlapplications.html)
