import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

Plasma5Support.DataSource {
    id: execUtil
    engine: "executable"
    connectedSources: []

    property var callbacks: ({})

    onNewData: function(sourceName, data) {
        var stdout = (data["stdout"] || "").trim()
        var stderr = (data["stderr"] || "").trim()
        var exitCode = data["exit code"] || 0
        var exitStatus = data["exit status"] || 0

        if (callbacks[sourceName]) {
            callbacks[sourceName](sourceName, exitCode, exitStatus, stdout, stderr)
            delete callbacks[sourceName]
        }

        disconnectSource(sourceName)
    }

    function exec(cmd, callback) {
        if (Array.isArray(cmd)) {
            cmd = cmd.map(function(token) {
                if (token.indexOf("'") >= 0 || token.indexOf(" ") >= 0) {
                    return "'" + token.replace(/'/g, "'\"'\"'") + "'"
                }
                return token
            }).join(" ")
        }
        if (typeof callback === "function") {
            callbacks[cmd] = callback
        }
        connectSource(cmd)
    }
}
