import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmaComponents.ItemDelegate {
    id: eventItem

    required property int index
    required property string time
    required property string duration
    required property string title
    required property string location
    required property bool hasMeet
    required property string meetUrl
    required property string eventUrl
    required property string responseStatus
    required property string eventColor

    width: ListView.view.width
    onClicked: Qt.openUrlExternally(meetUrl || eventUrl)
    opacity: responseStatus === "accepted" ? 1.0 : 0.6

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        Rectangle {
            Layout.preferredWidth: 3
            Layout.fillHeight: true
            color: eventItem.eventColor !== "" ? eventItem.eventColor : Kirigami.Theme.highlightColor
            radius: 1
        }

        ColumnLayout {
            Layout.minimumWidth: Kirigami.Units.gridUnit * 5
            Layout.maximumWidth: Kirigami.Units.gridUnit * 5
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
}
