import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

Plasma5Support.DataSource {
    id: execUtil
    engine: "executable"
    connectedSources: []

    property var callbacks: ({})

    onNewData: function(sourceName, data) {
        const stdout = (data["stdout"] || "").trim()
        const stderr = (data["stderr"] || "").trim()
        const exitCode = data["exit code"] || 0
        const exitStatus = data["exit status"] || 0

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
