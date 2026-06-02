import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import "lib/Requests.js" as Requests
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

    // --- Formatting helpers ---

    // Relative time shown in the panel (e.g. "in 5min", "Now", "3min ago")
    function formatRelativeTime() {
        if (nextEventIsAllDay) return i18n("Today")
        if (nextEventStartMs <= 0) return i18n("upcoming")
        var diffMin = Math.round((nextEventStartMs - Date.now()) / 60000)
        if (diffMin > 60) {
            var h = Math.floor(diffMin / 60)
            var m = diffMin % 60
            if (m === 0) return i18nc("relative time in hours", "in %1h", h)
            return i18nc("relative time hours and minutes", "in %1h %2min", h, m)
        }
        if (diffMin > 0) return i18nc("relative time in minutes", "in %1min", diffMin)
        if (diffMin >= -1) return i18n("Now")
        var ago = -diffMin
        if (ago < 60) return i18nc("time since event started, in minutes", "%1min ago", ago)
        var hAgo = Math.floor(ago / 60)
        var mAgo = ago % 60
        if (mAgo === 0) return i18nc("time since event started, in hours", "%1h ago", hAgo)
        return i18nc("time since event started, hours and minutes", "%1h %2min ago", hAgo, mAgo)
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
                colorsLoaded = false
                calendarDefaultColor = ""
            }
        }
    }

    Component.onCompleted: {
        if (isLoggedIn) {
            fetchEvents()
        }
    }

    function formatEventTime(startStr, isAllDay) {
        if (isAllDay) return ""
        var eventDate = new Date(startStr)
        return eventDate.toLocaleTimeString(Qt.locale(), "HH:mm")
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

    // --- OAuth ---

    // Refreshes the access token if expired, then calls callback with a valid token
    function ensureAccessToken(callback) {
        var expiresAt = plasmoid.configuration.accessTokenExpiresAt || 0
        if (plasmoid.configuration.accessToken && Date.now() < expiresAt - 5000) {
            callback(plasmoid.configuration.accessToken)
            return
        }

        Requests.postJSON({
            url: "https://oauth2.googleapis.com/token",
            data: {
                client_id: plasmoid.configuration.clientId,
                client_secret: plasmoid.configuration.clientSecret,
                refresh_token: plasmoid.configuration.refreshToken,
                grant_type: "refresh_token"
            }
        }, function(err, data) {
            if (err || !data || !data.access_token) {
                isLoading = false
                return
            }
            plasmoid.configuration.accessToken = data.access_token
            plasmoid.configuration.accessTokenExpiresAt = Date.now() + data.expires_in * 1000
            callback(data.access_token)
        })
    }

    // --- Google Calendar API ---

    // Fetches event color palette and primary calendar color (cached after first call)
    function loadColors(token, callback) {
        if (colorsLoaded) {
            callback()
            return
        }
        Requests.getJSON({
            url: "https://www.googleapis.com/calendar/v3/colors",
            headers: { "Authorization": "Bearer " + token }
        }, function(err, data) {
            if (!err && data && data.event) {
                var colors = {}
                for (var id in data.event) {
                    colors[id] = data.event[id].background
                }
                eventColorMap = colors
            }
            Requests.getJSON({
                url: "https://www.googleapis.com/calendar/v3/users/me/calendarList/primary",
                headers: { "Authorization": "Bearer " + token }
            }, function(err2, calData) {
                if (!err2 && calData && calData.backgroundColor) {
                    calendarDefaultColor = calData.backgroundColor
                }
                colorsLoaded = true
                callback()
            })
        })
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
            var meetUrl = event.meetUrl
            var joinLabel = i18n("Join")
            var cmd = [
                "sh", "-c",
                "A=$(notify-send --wait -t 10000 -i '" + icon + "' -a 'Event Bar'"
                + " --action='default=" + joinLabel + "'"
                + " --action='meet=" + joinLabel + "'"
                + " '" + title.replace(/'/g, "'\"'\"'") + "'"
                + " '" + body.replace(/'/g, "'\"'\"'") + "'"
                + "); [ \"$A\" = default ] || [ \"$A\" = meet ] && xdg-open '"
                + meetUrl.replace(/'/g, "'\"'\"'") + "'"
            ]
            notifier.exec(cmd)
        } else {
            notifier.exec(["notify-send", "-t", "10000", "-i", icon, "-a", "Event Bar", title, body])
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
            var meetUrl = event.meetUrl
            var joinLabel = i18n("Join")
            var cmd = [
                "sh", "-c",
                "A=$(notify-send --wait -t 0 -i '" + icon + "' -a 'Event Bar'"
                + " --action='default=" + joinLabel + "'"
                + " --action='meet=" + joinLabel + "'"
                + " '" + title.replace(/'/g, "'\"'\"'") + "'"
                + (body !== "" ? " '" + body.replace(/'/g, "'\"'\"'") + "'" : "")
                + "); [ \"$A\" = default ] || [ \"$A\" = meet ] && xdg-open '"
                + meetUrl.replace(/'/g, "'\"'\"'") + "'"
            ]
            notifier.exec(cmd)
        } else {
            var cmd2 = ["notify-send", "-t", "0", "-i", icon, "-a", "Event Bar", title]
            if (body !== "") cmd2.push(body)
            notifier.exec(cmd2)
        }
    }

    // Fetches upcoming events from Google Calendar (next 7 days, max 20)
    function fetchEvents() {
        if (!isLoggedIn) return
        isLoading = true

        ensureAccessToken(function(token) {
            loadColors(token, function() {
            var now = new Date()
            var end = new Date(now)
            end.setDate(end.getDate() + 7)

            var url = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
                + "?timeMin=" + encodeURIComponent(now.toISOString())
                + "&timeMax=" + encodeURIComponent(end.toISOString())
                + "&singleEvents=true"
                + "&orderBy=startTime"
                + "&maxResults=20"

            Requests.getJSON({
                url: url,
                headers: { "Authorization": "Bearer " + token }
            }, function(err, data) {
                isLoading = false
                if (err || !data || !data.items) return

                eventsModel.clear()
                for (var i = 0; i < data.items.length; i++) {
                    var event = data.items[i]
                    var isAllDay = !event.start.dateTime
                    var start = event.start.dateTime || event.start.date
                    var end = event.end.dateTime || event.end.date
                    var hasMeet = !!(event.hangoutLink || event.conferenceData)

                    var responseStatus = "accepted"
                    if (event.attendees) {
                        for (var j = 0; j < event.attendees.length; j++) {
                            if (event.attendees[j].self) {
                                responseStatus = event.attendees[j].responseStatus || "needsAction"
                                break
                            }
                        }
                    }

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

                // Prefer the first accepted event for the panel display
                if (eventsModel.count > 0) {
                    var bestIdx = 0
                    for (var k = 0; k < eventsModel.count; k++) {
                        if (eventsModel.get(k).responseStatus === "accepted") {
                            bestIdx = k
                            break
                        }
                    }
                    var best = eventsModel.get(bestIdx)
                    nextEventTitle = best.title
                    nextEventDuration = best.duration
                    nextEventIsAllDay = best.time === ""
                    nextEventStartMs = best.startMs
                } else {
                    nextEventTitle = ""
                    nextEventDuration = ""
                    nextEventStartMs = 0
                    nextEventIsAllDay = false
                }
                checkEventNotifications()
            })
            })
        })
    }

    // --- Compact representation (panel) ---

    compactRepresentation: MouseArea {
        Layout.preferredWidth: labels.implicitWidth
        Layout.fillHeight: true
        onClicked: root.expanded = !root.expanded

        ColumnLayout {
            id: labels
            anchors.centerIn: parent
            spacing: 0

            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 12
                text: root.isLoggedIn && root.nextEventTitle !== ""
                    ? root.nextEventTitle
                    : i18n("Events")
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            // Re-evaluated on each minute tick via timerTick dependency
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: {
                    root.timerTick
                    if (!root.isLoggedIn || (root.nextEventStartMs <= 0 && !root.nextEventIsAllDay)) return i18n("upcoming")
                    var parts = [root.formatRelativeTime()]
                    if (root.nextEventDuration !== "") parts.push(root.nextEventDuration)
                    return parts.join("  ·  ")
                }
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.7
            }
        }
    }

    // --- Full representation (popup) ---

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        Layout.minimumHeight: Kirigami.Units.gridUnit * 14
        Layout.preferredWidth: Layout.minimumWidth
        Layout.preferredHeight: Layout.minimumHeight
        spacing: 0

        PlasmaExtras.PlasmoidHeading {
            Layout.fillWidth: true

            RowLayout {
                anchors.fill: parent

                Kirigami.Heading {
                    Layout.fillWidth: true
                    text: i18n("Upcoming meetings")
                    level: 3
                }

                PlasmaComponents.ToolButton {
                    icon.name: "view-refresh"
                    onClicked: root.fetchEvents()
                    enabled: root.isLoggedIn && !root.isLoading
                }

                PlasmaComponents.ToolButton {
                    icon.name: "window-pin"
                    checkable: true
                    checked: !root.hideOnWindowDeactivate
                    onToggled: root.hideOnWindowDeactivate = !checked
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.isLoggedIn
            text: i18n("Configure your Google account\nin the widget settings.")
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            opacity: 0.7
        }

        PlasmaComponents.BusyIndicator {
            Layout.alignment: Qt.AlignCenter
            Layout.fillHeight: true
            visible: root.isLoggedIn && root.isLoading && eventsModel.count === 0
            running: visible
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.isLoggedIn && !root.isLoading && eventsModel.count === 0
            text: i18n("No upcoming events")
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: 0.7
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: eventsModel.count > 0
            model: eventsModel

            section.property: "sectionDate"
            section.delegate: PlasmaComponents.ItemDelegate {
                width: ListView.view.width
                enabled: false
                contentItem: PlasmaComponents.Label {
                    text: section
                    font.bold: true
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    opacity: 0.6
                }
            }

            delegate: PlasmaComponents.ItemDelegate {
                width: ListView.view.width
                onClicked: Qt.openUrlExternally(model.meetUrl || model.eventUrl)
                opacity: model.responseStatus === "accepted" ? 1.0 : 0.6

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Rectangle {
                        Layout.preferredWidth: 3
                        Layout.fillHeight: true
                        color: model.eventColor !== "" ? model.eventColor : Kirigami.Theme.highlightColor
                        radius: 1
                    }

                    ColumnLayout {
                        Layout.minimumWidth: Kirigami.Units.gridUnit * 5
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 5
                        Layout.alignment: Qt.AlignTop
                        spacing: 0

                        PlasmaComponents.Label {
                            text: model.time !== "" ? model.time : i18n("All day")
                            font.bold: model.time !== ""
                            font.pixelSize: model.time !== "" ? Kirigami.Theme.defaultFont.pixelSize : Kirigami.Theme.smallFont.pixelSize
                            opacity: model.time === "" ? 0.7 : 1.0
                        }
                        PlasmaComponents.Label {
                            text: model.duration
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                            visible: model.duration !== ""
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label {
                                text: model.title
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Kirigami.Icon {
                                source: "camera-video"
                                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                                implicitHeight: Kirigami.Units.iconSizes.smallMedium
                                visible: model.hasMeet
                            }
                        }
                        PlasmaComponents.Label {
                            text: model.location
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            opacity: 0.7
                            visible: model.location !== ""
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
