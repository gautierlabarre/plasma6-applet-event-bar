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
    required property string nextEventSectionDate
    required property int timerTick
    required property bool alignLeft
    required property bool showIcon
    required property bool hideEventTitle
    required property int maxTitleLength

    Layout.preferredWidth: content.implicitWidth
    Layout.fillHeight: true

    function formatRelativeTime() {
        if (nextEventIsAllDay) return nextEventSectionDate
        if (nextEventStartMs <= 0) return i18n("upcoming")
        const diffMin = Math.round((nextEventStartMs - Date.now()) / 60000)
        if (diffMin > 60) {
            const h = Math.floor(diffMin / 60)
            const m = diffMin % 60
            if (m === 0) return i18nc("relative time in hours", "in %1h", h)
            return i18nc("relative time hours and minutes", "in %1h %2min", h, m)
        }
        if (diffMin > 0) return i18nc("relative time in minutes", "in %1min", diffMin)
        if (diffMin >= -1) return i18n("Now")
        const ago = -diffMin
        if (ago < 60) return i18nc("time since event started, in minutes", "%1min ago", ago)
        const hAgo = Math.floor(ago / 60)
        const mAgo = ago % 60
        if (mAgo === 0) return i18nc("time since event started, in hours", "%1h ago", hAgo)
        return i18nc("time since event started, hours and minutes", "%1h %2min ago", hAgo, mAgo)
    }

    RowLayout {
        id: content
        anchors.centerIn: compactView.alignLeft ? undefined : parent
        anchors.left: compactView.alignLeft ? parent.left : undefined
        anchors.verticalCenter: parent.verticalCenter
        spacing: Kirigami.Units.mediumSpacing

        Kirigami.Icon {
            visible: compactView.showIcon
            source: "office-calendar"
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: Kirigami.Units.iconSizes.smallMedium
        }

        ColumnLayout {
            id: labels
            spacing: 0

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: {
                    if (!compactView.isLoggedIn) return i18n("Events")
                    if (compactView.nextEventTitle === "") return i18n("No events today")
                    const raw = compactView.hideEventTitle ? i18n("Next event") : compactView.nextEventTitle
                    if (raw.length > compactView.maxTitleLength) return raw.substring(0, compactView.maxTitleLength) + "…"
                    return raw
                }
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                horizontalAlignment: compactView.alignLeft ? Text.AlignLeft : Text.AlignHCenter
                elide: Text.ElideRight
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: compactView.isLoggedIn && compactView.nextEventTitle !== ""
                text: {
                    compactView.timerTick
                    if (!compactView.isLoggedIn || (compactView.nextEventStartMs <= 0 && !compactView.nextEventIsAllDay)) return i18n("upcoming")
                    const parts = [compactView.formatRelativeTime()]
                    if (compactView.nextEventDuration !== "") parts.push(compactView.nextEventDuration)
                    return parts.join("  ·  ")
                }
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                horizontalAlignment: compactView.alignLeft ? Text.AlignLeft : Text.AlignHCenter
                opacity: 0.7
            }
        }
    }
}
