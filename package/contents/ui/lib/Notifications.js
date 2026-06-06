// Notification helpers (no i18n, pure logic)

.pragma library
.import "Log.js" as Log

function sanitizeTimeout(timeout) {
    return parseInt(timeout, 10) || 0
}

function buildMeetNotifyCommand(title, body, icon, timeout, meetUrl, joinLabel) {
    const safeTimeout = sanitizeTimeout(timeout)
    Log.log("notif", "Building Meet notification: \"" + title + "\" timeout=" + safeTimeout + "ms")
    return [
        "sh", "-c",
        "A=$(notify-send --wait -t " + safeTimeout + " -i '" + shellEscape(icon) + "' -a 'Event Bar'"
        + " --action='default=" + shellEscape(joinLabel) + "'"
        + " --action='meet=" + shellEscape(joinLabel) + "'"
        + " '" + shellEscape(title) + "'"
        + (body !== "" ? " '" + shellEscape(body) + "'" : "")
        + "); [ \"$A\" = default ] || [ \"$A\" = meet ] && xdg-open '"
        + shellEscape(meetUrl) + "'"
    ]
}

function buildSimpleNotifyCommand(title, body, icon, timeout) {
    const safeTimeout = sanitizeTimeout(timeout)
    Log.log("notif", "Building notification: \"" + title + "\" timeout=" + safeTimeout + "ms")
    const cmd = ["notify-send", "-t", String(safeTimeout), "-i", icon, "-a", "Event Bar", title]
    if (body !== "") cmd.push(body)
    return cmd
}

function shellEscape(str) {
    return str.replace(/'/g, "'\"'\"'")
}
