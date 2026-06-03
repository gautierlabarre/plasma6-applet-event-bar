import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

MouseArea {
    id: compactView

    required property bool isLoggedIn
    required property string nextEventTitle
    required property string nextEventDuration
    required property bool nextEventIsAllDay
    required property double nextEventStartMs
    required property int timerTick

    Layout.preferredWidth: labels.implicitWidth
    Layout.fillHeight: true

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

    ColumnLayout {
        id: labels
        anchors.centerIn: parent
        spacing: 0

        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 12
            text: compactView.isLoggedIn && compactView.nextEventTitle !== ""
                ? compactView.nextEventTitle
                : i18n("Events")
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        // Re-evaluated on each minute tick via timerTick dependency
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: {
                compactView.timerTick
                if (!compactView.isLoggedIn || (compactView.nextEventStartMs <= 0 && !compactView.nextEventIsAllDay)) return i18n("upcoming")
                var parts = [compactView.formatRelativeTime()]
                if (compactView.nextEventDuration !== "") parts.push(compactView.nextEventDuration)
                return parts.join("  ·  ")
            }
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.7
        }
    }
}
