import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import "lib/Requests.js" as Requests
import "lib/CalendarApi.js" as CalendarApi
import "lib/Notifications.js" as Notifications
import "lib"

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation

    property bool isLoggedIn: plasmoid.configuration.refreshToken !== ""
    property bool isLoading: false

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

    // Incremented on each minute tick to force re-evaluation of panel text binding
    property int timerTick: 0

    // Milliseconds until the next system clock minute boundary
    function msUntilNextMinute() {
        var ms = 60000 - (Date.now() % 60000)
        return ms < 100 ? 60000 : ms
    }

    // Fires exactly on each minute boundary, synced with the system clock
    Timer {
        id: minuteTimer
        interval: root.msUntilNextMinute()
        running: root.isLoggedIn
        onTriggered: {
            root.timerTick++
            checkEventNotifications()
            interval = root.msUntilNextMinute()
            restart()
        }
    }

    ListModel {
        id: eventsModel
    }

    // Refetch events from Google Calendar every 5 minutes
    Timer {
        id: refreshTimer
        interval: 5 * 60 * 1000
        repeat: true
        running: isLoggedIn
        onTriggered: fetchEvents()
    }

    // Reset state when user signs out
    Connections {
        target: plasmoid.configuration
        function onRefreshTokenChanged() {
            if (plasmoid.configuration.refreshToken !== "") {
                fetchEvents()
            } else {
                eventsModel.clear()
                nextEventTitle = ""
                nextEventDuration = ""
                nextEventStartMs = 0
                nextEventIsAllDay = false
                nextEventSectionDate = ""
                colorsLoaded = false
                calendarDefaultColor = ""
            }
        }
        function onPreferTimedHoursChanged() {
            updatePanelEvent()
        }
    }

    Component.onCompleted: {
        if (isLoggedIn) fetchEvents()
    }

    // --- Formatting helpers (need i18n, must stay in QML) ---

    function updatePanelEvent() {
        var todayLabel = i18n("Today")
        if (eventsModel.count > 0) {
            var bestIdx = -1
            var preferHours = plasmoid.configuration.preferTimedHours
            var now = Date.now()
            for (var k = 0; k < eventsModel.count; k++) {
                var ev = eventsModel.get(k)
                if (ev.sectionDate !== todayLabel) continue
                if (ev.responseStatus !== "accepted") continue
                if (bestIdx < 0) bestIdx = k
                if (preferHours > 0 && ev.startMs > 0 && ev.startMs - now < preferHours * 3600000) {
                    bestIdx = k
                    break
                }
            }
            if (bestIdx >= 0) {
                var best = eventsModel.get(bestIdx)
                nextEventTitle = best.title
                nextEventDuration = best.duration
                nextEventIsAllDay = best.time === ""
                nextEventStartMs = best.startMs
                nextEventSectionDate = best.sectionDate
            } else {
                nextEventTitle = ""
                nextEventDuration = ""
                nextEventStartMs = 0
                nextEventIsAllDay = false
                nextEventSectionDate = ""
            }
        } else {
            nextEventTitle = ""
            nextEventDuration = ""
            nextEventStartMs = 0
            nextEventIsAllDay = false
            nextEventSectionDate = ""
        }
    }

    function formatEventTime(startStr, isAllDay) {
        if (isAllDay) return ""
        return new Date(startStr).toLocaleTimeString(Qt.locale(), "HH:mm")
    }

    function formatDuration(startStr, endStr, isAllDay) {
        if (isAllDay) return ""
        var startMs = new Date(startStr).getTime()
        var endMs = new Date(endStr).getTime()
        var minutes = Math.round((endMs - startMs) / 60000)
        if (minutes < 60) return i18nc("short duration in minutes", "%1min", minutes)
        var hours = Math.floor(minutes / 60)
        if (hours >= 24) {
            var days = Math.floor(hours / 24)
            var remH = hours % 24
            if (remH === 0) return i18nc("short duration in days", "%1d", days)
            return i18nc("short duration days and hours", "%1d %2h", days, remH)
        }
        var rem = minutes % 60
        if (rem === 0) return i18nc("short duration in hours", "%1h", hours)
        return i18nc("short duration hours and minutes", "%1h%2", hours, rem)
    }

    function formatSectionDate(startStr, isAllDay) {
        var eventDate = new Date(startStr)
        var now = new Date()
        var today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        var eventDay = new Date(eventDate.getFullYear(), eventDate.getMonth(), eventDate.getDate())
        var diffDays = Math.round((eventDay - today) / (1000 * 60 * 60 * 24))
        if (diffDays === 0) return i18n("Today")
        if (diffDays === 1) return i18n("Tomorrow")
        return Qt.locale().dayName(eventDate.getDay(), Locale.LongFormat) + " " + eventDate.getDate()
    }

    // --- Notifications ---

    // Checks all events for reminder and start-time notifications
    function checkEventNotifications() {
        var now = Date.now()
        for (var i = 0; i < eventsModel.count; i++) {
            var event = eventsModel.get(i)
            if (event.startMs <= 0) continue
            var key = String(event.startMs)
            var timeUntil = event.startMs - now

            if (plasmoid.configuration.enableReminder) {
                var reminderMs = plasmoid.configuration.reminderMinutes * 60000
                var reminderKey = "reminder_" + key
                if (timeUntil > 0 && timeUntil <= reminderMs && !notifiedEvents[reminderKey]) {
                    var u1 = notifiedEvents
                    u1[reminderKey] = true
                    notifiedEvents = u1
                    sendReminderNotification(event)
                }
            }

            if (plasmoid.configuration.enableNotifications) {
                var elapsed = now - event.startMs
                if (elapsed >= 0 && elapsed < 60000 && !notifiedEvents[key]) {
                    var u2 = notifiedEvents
                    u2[key] = true
                    notifiedEvents = u2
                    sendEventNotification(event)
                }
            }
        }
    }

    // Reminder: fires X minutes before the event (transient, 10s)
    function sendReminderNotification(event) {
        var title = i18n("Reminder: %1", event.title)
        var minutes = plasmoid.configuration.reminderMinutes
        var bodyParts = [i18n("In %1 minutes", minutes)]
        if (event.location) bodyParts.push(event.location)
        var body = bodyParts.join("\n")
        var icon = event.hasMeet ? "camera-video" : "appointment-soon"

        if (event.hasMeet && event.meetUrl) {
            notifier.exec(Notifications.buildMeetNotifyCommand(
                title, body, icon, 10000, event.meetUrl, i18n("Join")))
        } else {
            notifier.exec(Notifications.buildSimpleNotifyCommand(title, body, icon, 10000))
        }
    }

    // Start notification: fires when the event begins (persistent, stays until dismissed)
    function sendEventNotification(event) {
        var title = i18n("%1 is starting", event.title)
        var bodyParts = []
        if (event.time !== "") {
            var timeLine = event.time
            if (event.duration !== "") timeLine += " · " + event.duration
            bodyParts.push(timeLine)
        }
        if (event.location) bodyParts.push(event.location)
        var body = bodyParts.join("\n")
        var icon = event.hasMeet ? "camera-video" : "appointment-soon"

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

        CalendarApi.ensureAccessToken(plasmoid.configuration, Requests, function(token) {
            if (!token) { isLoading = false; return }

            if (!colorsLoaded) {
                CalendarApi.loadColors(token, Requests, function(colors, calColor) {
                    eventColorMap = colors
                    if (calColor) calendarDefaultColor = calColor
                    colorsLoaded = true
                    loadEvents(token)
                })
            } else {
                loadEvents(token)
            }
        })
    }

    function loadEvents(token) {
        CalendarApi.fetchEvents(token, Requests, function(items) {
            isLoading = false
            if (!items) return

            eventsModel.clear()
            for (var i = 0; i < items.length; i++) {
                var event = items[i]
                var isAllDay = !event.start.dateTime
                var start = event.start.dateTime || event.start.date
                var end = event.end.dateTime || event.end.date
                var hasMeet = !!(event.hangoutLink || event.conferenceData)
                var responseStatus = CalendarApi.getResponseStatus(event)

                if (responseStatus === "declined") continue

                var eventColor = calendarDefaultColor
                if (event.colorId && eventColorMap[event.colorId]) {
                    eventColor = eventColorMap[event.colorId]
                }

                eventsModel.append({
                    time: formatEventTime(start, isAllDay),
                    duration: formatDuration(start, end, isAllDay),
                    title: event.summary || i18n("(no title)"),
                    location: event.location || "",
                    hasMeet: hasMeet,
                    meetUrl: event.hangoutLink || "",
                    eventUrl: event.htmlLink || "",
                    startMs: isAllDay ? 0 : new Date(start).getTime(),
                    sectionDate: formatSectionDate(start, isAllDay),
                    responseStatus: responseStatus,
                    eventColor: eventColor
                })
            }

            updatePanelEvent()
            checkEventNotifications()
        })
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
        events: eventsModel
        hideOnWindowDeactivate: root.hideOnWindowDeactivate
        onRefreshClicked: root.fetchEvents()
        onTogglePin: root.hideOnWindowDeactivate = !root.hideOnWindowDeactivate
    }
}
