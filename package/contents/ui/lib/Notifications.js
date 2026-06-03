// Notification helpers (no i18n, pure logic)

.pragma library

// Build a notify-send command array for events with a Meet link (uses --wait for action handling)
function buildMeetNotifyCommand(title, body, icon, timeout, meetUrl, joinLabel) {
    return [
        "sh", "-c",
        "A=$(notify-send --wait -t " + timeout + " -i '" + icon + "' -a 'Event Bar'"
        + " --action='default=" + joinLabel + "'"
        + " --action='meet=" + joinLabel + "'"
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
