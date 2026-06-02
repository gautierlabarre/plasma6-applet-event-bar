import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: configOptions

    property bool cfg_enableNotifications: plasmoid.configuration.enableNotifications
    property bool cfg_enableReminder: plasmoid.configuration.enableReminder
    property int cfg_reminderMinutes: plasmoid.configuration.reminderMinutes

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.Switch {
                Kirigami.FormData.label: i18n("Notify when an event starts")
                checked: cfg_enableNotifications
                onToggled: cfg_enableNotifications = checked
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
            }

            QQC2.Switch {
                id: reminderSwitch
                Kirigami.FormData.label: i18n("Show a reminder notification")
                checked: cfg_enableReminder
                onToggled: cfg_enableReminder = checked
            }

            QQC2.SpinBox {
                Kirigami.FormData.label: i18n("Minutes before")
                value: cfg_reminderMinutes
                from: 1
                to: 60
                onValueModified: cfg_reminderMinutes = value
                enabled: cfg_enableReminder
            }
        }
    }
}
