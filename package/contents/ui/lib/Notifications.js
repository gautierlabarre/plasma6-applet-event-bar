// Notification helpers (no i18n, pure logic)

.pragma library

// Build a notify-send command array for events with a Meet link (uses --wait for action handling)
function buildMeetNotifyCommand(title, body, icon, timeout, meetUrl, joinLabel) {
    var escapedJoinLabel = shellEscape(joinLabel)
    return [
        "sh", "-c",
        "A=$(notify-send --wait -t " + String(parseInt(timeout) || 0)
        + " -i '" + shellEscape(icon) + "' -a 'Event Bar'"
        + " --action='default=" + escapedJoinLabel + "'"
        + " --action='meet=" + escapedJoinLabel + "'"
        + " '" + shellEscape(title) + "'"
        + (body !== "" ? " '" + shellEscape(body) + "'" : "")
        + "); [ \"$A\" = default ] || [ \"$A\" = meet ] && xdg-open '"
        + shellEscape(meetUrl) + "'"
    ]
}

// Build a simple notify-send command array (no action, fire-and-forget)
function buildSimpleNotifyCommand(title, body, icon, timeout) {
    var cmd = ["notify-send", "-t", String(timeout), "-i", icon, "-a", "Event Bar", title]
    if (body !== "") cmd.push(body)
    return cmd
}

function shellEscape(str) {
    return str.replace(/'/g, "'\"'\"'")
}
