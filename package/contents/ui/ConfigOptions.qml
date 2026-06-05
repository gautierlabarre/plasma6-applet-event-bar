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
    property int cfg_preferTimedHours: plasmoid.configuration.preferTimedHours
    property bool cfg_alignLeft: plasmoid.configuration.alignLeft
    property bool cfg_showIcon: plasmoid.configuration.showIcon
    property bool cfg_hideEventTitle: plasmoid.configuration.hideEventTitle
    property int cfg_maxTitleLength: plasmoid.configuration.maxTitleLength

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

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
            }

            QQC2.SpinBox {
                Kirigami.FormData.label: i18n("Show all-day event if nothing within (hours)")
                value: cfg_preferTimedHours
                from: 0
                to: 12
                onValueModified: cfg_preferTimedHours = value
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            text: cfg_preferTimedHours > 0
                ? i18n("If a timed event starts within %1h, it will be shown instead.", cfg_preferTimedHours)
                : i18n("The all-day event is always shown first.")
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            wrapMode: Text.WordWrap
            opacity: 0.7
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.Switch {
                Kirigami.FormData.label: i18n("Align panel text to the left")
                checked: cfg_alignLeft
                onToggled: cfg_alignLeft = checked
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
            }

            QQC2.Switch {
                Kirigami.FormData.label: i18n("Show calendar icon")
                checked: cfg_showIcon
                onToggled: cfg_showIcon = checked
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
            }

            QQC2.Switch {
                Kirigami.FormData.label: i18n("Show generic title instead of event name")
                checked: cfg_hideEventTitle
                onToggled: cfg_hideEventTitle = checked
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
            }

            QQC2.SpinBox {
                Kirigami.FormData.label: i18n("Maximum title width (characters)")
                value: cfg_maxTitleLength
                from: 10
                to: 40
                onValueModified: cfg_maxTitleLength = value
            }
        }
    }
}
