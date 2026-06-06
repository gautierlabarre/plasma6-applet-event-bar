import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: fullView

    required property bool isLoggedIn
    required property bool isLoading
    required property string errorMessage
    required property var events
    required property bool hideOnWindowDeactivate

    signal refreshClicked()
    signal togglePin()

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
                onClicked: fullView.refreshClicked()
                enabled: fullView.isLoggedIn && !fullView.isLoading
            }

            PlasmaComponents.ToolButton {
                icon.name: "window-pin"
                checkable: true
                checked: !fullView.hideOnWindowDeactivate
                onToggled: fullView.togglePin()
            }
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !fullView.isLoggedIn
        text: i18n("Configure your Google account\nin the widget settings.")
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        opacity: 0.7
    }

    PlasmaComponents.BusyIndicator {
        Layout.alignment: Qt.AlignCenter
        Layout.fillHeight: true
        visible: fullView.isLoggedIn && fullView.isLoading && fullView.events.count === 0
        running: visible
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: fullView.isLoggedIn && !fullView.isLoading && fullView.errorMessage !== "" && fullView.events.count === 0
        spacing: Kirigami.Units.smallSpacing

        Item { Layout.fillHeight: true }

        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            source: "dialog-warning"
            implicitWidth: Kirigami.Units.iconSizes.large
            implicitHeight: Kirigami.Units.iconSizes.large
            opacity: 0.6
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: fullView.errorMessage
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            opacity: 0.7
        }

        PlasmaComponents.Button {
            Layout.alignment: Qt.AlignHCenter
            text: i18n("Retry")
            icon.name: "view-refresh"
            onClicked: fullView.refreshClicked()
        }

        Item { Layout.fillHeight: true }
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: fullView.isLoggedIn && !fullView.isLoading && fullView.errorMessage === "" && fullView.events.count === 0
        text: i18n("No upcoming events")
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        opacity: 0.7
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing
        Layout.topMargin: Kirigami.Units.smallSpacing
        visible: fullView.errorMessage !== "" && !fullView.isLoading && fullView.events.count > 0
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: "dialog-warning"
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: Kirigami.Units.iconSizes.smallMedium
            opacity: 0.7
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: fullView.errorMessage
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            opacity: 0.7
            elide: Text.ElideRight
        }
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        visible: fullView.events.count > 0
        model: fullView.events

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

        delegate: EventItem {}
    }
}
