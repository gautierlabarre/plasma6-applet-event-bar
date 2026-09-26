import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmaComponents.ItemDelegate {
    id: eventItem

    required property int index
    required property string eventId
    required property string selfEmail
    required property string time
    required property string duration
    required property string title
    required property string location
    required property bool hasMeet
    required property string meetUrl
    required property string eventUrl
    required property string responseStatus
    required property string eventColor
    // "accepted" / "declined" while that response is being sent, "" otherwise
    required property string respondingStatus

    readonly property int colorBarWidth: 3
    readonly property int timeColumnWidth: Kirigami.Units.gridUnit * 5
    // Pending invitation (needsAction or tentative) that the user can answer
    readonly property bool canRespond: responseStatus !== "accepted" && selfEmail !== "" && eventId !== ""
    readonly property bool isResponding: respondingStatus !== ""

    signal respondClicked(string responseStatus)

    width: ListView.view.width
    onClicked: Qt.openUrlExternally(meetUrl || eventUrl)

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            // Only the event content is dimmed, the invitation buttons stay readable
            opacity: eventItem.responseStatus === "accepted" ? 1.0 : 0.6

            Rectangle {
                Layout.preferredWidth: eventItem.colorBarWidth
                Layout.fillHeight: true
                color: eventItem.eventColor !== "" ? eventItem.eventColor : Kirigami.Theme.highlightColor
                radius: 1
            }

            ColumnLayout {
                Layout.minimumWidth: eventItem.timeColumnWidth
                Layout.maximumWidth: eventItem.timeColumnWidth
                Layout.alignment: Qt.AlignTop
                spacing: 0

                PlasmaComponents.Label {
                    text: eventItem.time !== "" ? eventItem.time : i18n("All day")
                    font.bold: eventItem.time !== ""
                    font.pixelSize: eventItem.time !== "" ? Kirigami.Theme.defaultFont.pixelSize : Kirigami.Theme.smallFont.pixelSize
                    opacity: eventItem.time === "" ? 0.7 : 1.0
                }
                PlasmaComponents.Label {
                    text: eventItem.duration
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                    visible: eventItem.duration !== ""
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        text: eventItem.title
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Kirigami.Icon {
                        source: "camera-video"
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: Kirigami.Units.iconSizes.smallMedium
                        visible: eventItem.hasMeet
                    }
                }
                PlasmaComponents.Label {
                    text: eventItem.location
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    opacity: 0.7
                    visible: eventItem.location !== ""
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
        }

        // Invitation actions, aligned with the title column
        RowLayout {
            Layout.leftMargin: eventItem.colorBarWidth + eventItem.timeColumnWidth + Kirigami.Units.smallSpacing * 2
            visible: eventItem.canRespond
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.ToolButton {
                enabled: !eventItem.isResponding
                text: eventItem.respondingStatus === "accepted" ? i18n("Accepting...") : i18n("Accept")
                icon.name: "dialog-ok-apply"
                onClicked: eventItem.respondClicked("accepted")
            }

            PlasmaComponents.ToolButton {
                enabled: !eventItem.isResponding
                text: eventItem.respondingStatus === "declined" ? i18n("Declining...") : i18n("Decline")
                icon.name: "dialog-cancel"
                onClicked: eventItem.respondClicked("declined")
            }
        }
    }
}
