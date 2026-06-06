import QtQuick
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import "lib/Requests.js" as Requests
import "lib/CalendarApi.js" as CalendarApi
import "lib/EventLogic.js" as EventLogic
import "lib/Notifications.js" as Notifications
import "lib/Log.js" as Log
import "lib"

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation

    readonly property int msPerMinute: 60000
    readonly property int msPerHour: 3600000
    readonly property int reminderNotifTimeoutMs: 10000
    readonly property int refreshIntervalMs: 5 * msPerMinute

    property bool isLoggedIn: plasmoid.configuration.refreshToken !== ""
    property bool isLoading: false
    property string errorMessage: ""

    // Displayed in the panel's compact representation
    property string nextEventTitle: ""
    property string nextEventDuration: ""
    property double nextEventStartMs: 0
    property bool nextEventIsAllDay: false
    property string nextEventSectionDate: ""

    // Google Calendar color palette, fetched once then cached
    property var eventColorMap: ({})
    property string calendarDefaultColor: ""
    property bool colorsLoaded: false

    // Tracks startMs of events already notified to avoid duplicates
    property var notifiedEvents: ({})

    // Used to run notify-send commands
    ExecUtil {
        id: notifier
    }

    // --- Timers ---

    property int timerTick: 0

    function msUntilNextMinute() {
        const ms = msPerMinute - (Date.now() % msPerMinute)
        return ms < 100 ? msPerMinute : ms
    }

    Timer {
        id: minuteTimer
        interval: root.msUntilNextMinute()
        running: root.isLoggedIn
        onTriggered: {
            root.timerTick++
            Log.log("timer", "Minute tick #" + root.timerTick)
            checkEventNotifications()
            interval = root.msUntilNextMinute()
            restart()
        }
    }

    ListModel {
        id: eventsModel
    }

    Timer {
        id: refreshTimer
        interval: root.refreshIntervalMs
        repeat: true
        running: isLoggedIn
        onTriggered: {
            Log.log("timer", "Refresh timer fired, fetching events")
            fetchEvents()
        }
    }

    Timer {
        id: fetchTimeout
        interval: Requests.DEFAULT_TIMEOUT_MS
        onTriggered: {
            if (isLoading) {
                Log.log("api", "Fetch timeout (15s), forcing error state")
                isLoading = false
                errorMessage = i18n("Could not load events (timeout)")
            }
        }
    }

    Connections {
        target: plasmoid.configuration
        function onRefreshTokenChanged() {
            if (plasmoid.configuration.refreshToken !== "") {
                Log.log("auth", "Refresh token set, fetching events")
                fetchEvents()
            } else {
                Log.log("auth", "Signed out, clearing state")
                eventsModel.clear()
                clearPanelEvent()
                colorsLoaded = false
                calendarDefaultColor = ""
                errorMessage = ""
            }
        }
        function onPreferTimedHoursChanged() {
            updatePanelEvent()
        }
        function onEnableDebugLogsChanged() {
            Log.enabled = plasmoid.configuration.enableDebugLogs
            Log.log("config", "Debug logs " + (Log.enabled ? "enabled" : "disabled"))
        }
    }

    Component.onCompleted: {
        Log.enabled = plasmoid.configuration.enableDebugLogs
        Log.log("init", "Applet loaded, isLoggedIn=" + isLoggedIn)
        if (isLoggedIn) fetchEvents()
    }

    // --- Panel event selection ---

    function clearPanelEvent() {
        nextEventTitle = ""
        nextEventDuration = ""
        nextEventStartMs = 0
        nextEventIsAllDay = false
        nextEventSectionDate = ""
    }

    function updatePanelEvent() {
        if (eventsModel.count === 0) {
            clearPanelEvent()
            return
        }
        const bestIdx = EventLogic.findBestEventIndex(
            eventsModel, i18n("Today"),
            plasmoid.configuration.preferTimedHours, msPerHour)
        if (bestIdx >= 0) {
            const best = eventsModel.get(bestIdx)
            nextEventTitle = best.title
            nextEventDuration = best.duration
            nextEventIsAllDay = best.time === ""
            nextEventStartMs = best.startMs
            nextEventSectionDate = best.sectionDate
            Log.log("events", "Panel event: \"" + best.title + "\" startMs=" + best.startMs + " allDay=" + nextEventIsAllDay)
        } else {
            clearPanelEvent()
            Log.log("events", "No event to show in panel today")
        }
    }

    // --- Formatting helpers (need i18n, must stay in QML) ---

    function formatEventTime(startStr, isAllDay) {
        if (isAllDay) return ""
        return new Date(startStr).toLocaleTimeString(Qt.locale(), "HH:mm")
    }

    function formatDuration(startStr, endStr, isAllDay) {
        if (isAllDay) return ""
        const startMs = new Date(startStr).getTime()
        const endMs = new Date(endStr).getTime()
        const minutes = Math.round((endMs - startMs) / msPerMinute)
        if (minutes < 60) return i18nc("short duration in minutes", "%1min", minutes)
        const hours = Math.floor(minutes / 60)
        if (hours >= 24) {
            const days = Math.floor(hours / 24)
            const remH = hours % 24
            if (remH === 0) return i18nc("short duration in days", "%1d", days)
            return i18nc("short duration days and hours", "%1d %2h", days, remH)
        }
        const rem = minutes % 60
        if (rem === 0) return i18nc("short duration in hours", "%1h", hours)
        return i18nc("short duration hours and minutes", "%1h%2", hours, rem)
    }

    function formatSectionDate(startStr, isAllDay) {
        const eventDate = new Date(startStr)
        const now = new Date()
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        const eventDay = new Date(eventDate.getFullYear(), eventDate.getMonth(), eventDate.getDate())
        const diffDays = Math.round((eventDay - today) / (24 * msPerHour))
        if (diffDays === 0) return i18n("Today")
        if (diffDays === 1) return i18n("Tomorrow")
        return Qt.locale().dayName(eventDate.getDay(), Locale.LongFormat) + " " + eventDate.getDate()
    }

    // --- Notifications ---

    function markNotified(notifKey) {
        const updated = notifiedEvents
        updated[notifKey] = true
        notifiedEvents = updated
    }

    function checkEventNotifications() {
        const now = Date.now()
        for (let i = 0; i < eventsModel.count; i++) {
            const event = eventsModel.get(i)
            if (event.startMs <= 0) continue
            const key = String(event.startMs)
            const timeUntil = event.startMs - now

            if (plasmoid.configuration.enableReminder) {
                const reminderMs = plasmoid.configuration.reminderMinutes * msPerMinute
                const reminderKey = "reminder_" + key
                if (timeUntil > 0 && timeUntil <= reminderMs && !notifiedEvents[reminderKey]) {
                    markNotified(reminderKey)
                    Log.log("notif", "Sending reminder for \"" + event.title + "\" in " + Math.round(timeUntil / msPerMinute) + "min")
                    sendReminderNotification(event)
                }
            }

            if (plasmoid.configuration.enableNotifications) {
                const elapsed = now - event.startMs
                if (elapsed >= 0 && elapsed < msPerMinute && !notifiedEvents[key]) {
                    markNotified(key)
                    Log.log("notif", "Sending start notification for \"" + event.title + "\"")
                    sendEventNotification(event)
                }
            }
        }
    }

    function sendReminderNotification(event) {
        const title = i18n("Reminder: %1", event.title)
        const minutes = plasmoid.configuration.reminderMinutes
        const bodyParts = [i18n("In %1 minutes", minutes)]
        if (event.location) bodyParts.push(event.location)
        const body = bodyParts.join("\n")
        const icon = event.hasMeet ? "camera-video" : "appointment-soon"

        if (event.hasMeet && event.meetUrl) {
            notifier.exec(Notifications.buildMeetNotifyCommand(
                title, body, icon, reminderNotifTimeoutMs, event.meetUrl, i18n("Join")))
        } else {
            notifier.exec(Notifications.buildSimpleNotifyCommand(title, body, icon, reminderNotifTimeoutMs))
        }
    }

    function sendEventNotification(event) {
        const title = i18n("%1 is starting", event.title)
        const bodyParts = []
        if (event.time !== "") {
            let timeLine = event.time
            if (event.duration !== "") timeLine += " · " + event.duration
            bodyParts.push(timeLine)
        }
        if (event.location) bodyParts.push(event.location)
        const body = bodyParts.join("\n")
        const icon = event.hasMeet ? "camera-video" : "appointment-soon"

        if (event.hasMeet && event.meetUrl) {
            notifier.exec(Notifications.buildMeetNotifyCommand(
                title, body, icon, 0, event.meetUrl, i18n("Join")))
        } else {
            notifier.exec(Notifications.buildSimpleNotifyCommand(title, body, icon, 0))
        }
    }

    // --- Google Calendar API ---

    function fetchEvents() {
        if (!isLoggedIn) return
        isLoading = true
        errorMessage = ""
        fetchTimeout.restart()
        Log.log("api", "Fetching events...")
        CalendarApi.ensureAccessToken(plasmoid.configuration, Requests, onTokenReady)
    }

    function onTokenReady(token) {
        if (!token) {
            Log.log("auth", "Failed to obtain access token")
            fetchTimeout.stop()
            isLoading = false
            errorMessage = i18n("Authentication failed. Try signing in again.")
            return
        }
        Log.log("auth", "Access token ready")
        if (!colorsLoaded) {
            CalendarApi.loadColors(token, Requests, function(colors, calColor) {
                onColorsReady(colors, calColor, token)
            })
        } else {
            loadEvents(token)
        }
    }

    function onColorsReady(colors, calColor, token) {
        Log.log("api", "Colors loaded: " + Object.keys(colors).length + " event colors, calendar=" + (calColor || "none"))
        eventColorMap = colors
        if (calColor) calendarDefaultColor = calColor
        colorsLoaded = true
        loadEvents(token)
    }

    function loadEvents(token) {
        CalendarApi.fetchEvents(token, Requests, function(items) {
            fetchTimeout.stop()
            isLoading = false
            if (!items) {
                Log.log("api", "fetchEvents returned null (error or empty response)")
                errorMessage = i18n("Could not load events. Check your connection.")
                return
            }
            errorMessage = ""
            Log.log("events", "Processing " + items.length + " events from API")
            populateModel(items)
            updatePanelEvent()
            checkEventNotifications()
            Log.log("events", "Model updated: " + eventsModel.count + " events loaded")
        })
    }

    function populateModel(items) {
        eventsModel.clear()
        for (let i = 0; i < items.length; i++) {
            const event = items[i]
            const responseStatus = CalendarApi.getResponseStatus(event)
            if (responseStatus === "declined") {
                Log.log("events", "Skipping declined event: \"" + (event.summary || "(no title)") + "\"")
                continue
            }
            const isAllDay = !event.start.dateTime
            const start = event.start.dateTime || event.start.date
            const end = event.end.dateTime || event.end.date
            eventsModel.append({
                time: formatEventTime(start, isAllDay),
                duration: formatDuration(start, end, isAllDay),
                title: event.summary || i18n("(no title)"),
                location: event.location || "",
                hasMeet: !!(event.hangoutLink || event.conferenceData),
                meetUrl: event.hangoutLink || "",
                eventUrl: event.htmlLink || "",
                startMs: isAllDay ? 0 : new Date(start).getTime(),
                sectionDate: formatSectionDate(start, isAllDay),
                responseStatus: responseStatus,
                eventColor: EventLogic.resolveEventColor(event, eventColorMap, calendarDefaultColor)
            })
        }
    }

    // --- Views ---

    compactRepresentation: CompactView {
        isLoggedIn: root.isLoggedIn
        nextEventTitle: root.nextEventTitle
        nextEventDuration: root.nextEventDuration
        nextEventIsAllDay: root.nextEventIsAllDay
        nextEventStartMs: root.nextEventStartMs
        nextEventSectionDate: root.nextEventSectionDate
        timerTick: root.timerTick
        alignLeft: plasmoid.configuration.alignLeft
        showIcon: plasmoid.configuration.showIcon
        hideEventTitle: plasmoid.configuration.hideEventTitle
        maxTitleLength: plasmoid.configuration.maxTitleLength
        onClicked: root.expanded = !root.expanded
    }

    fullRepresentation: FullView {
        isLoggedIn: root.isLoggedIn
        isLoading: root.isLoading
        errorMessage: root.errorMessage
        events: eventsModel
        hideOnWindowDeactivate: root.hideOnWindowDeactivate
        onRefreshClicked: root.fetchEvents()
        onTogglePin: root.hideOnWindowDeactivate = !root.hideOnWindowDeactivate
    }
}
