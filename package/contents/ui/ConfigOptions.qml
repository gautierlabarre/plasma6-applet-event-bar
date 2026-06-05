import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: configOptions

    property int cfg_preferTimedHours: plasmoid.configuration.preferTimedHours
    property bool cfg_alignLeft: plasmoid.configuration.alignLeft
    property bool cfg_showIcon: plasmoid.configuration.showIcon
    property bool cfg_hideEventTitle: plasmoid.configuration.hideEventTitle
    property int cfg_maxTitleLength: plasmoid.configuration.maxTitleLength

    // Plasma injects all cfg_* properties into every config page
    property var cfg_clientId
    property var cfg_clientIdDefault
    property var cfg_clientSecret
    property var cfg_clientSecretDefault
    property var cfg_accessToken
    property var cfg_accessTokenDefault
    property var cfg_refreshToken
    property var cfg_refreshTokenDefault
    property var cfg_accessTokenExpiresAt
    property var cfg_accessTokenExpiresAtDefault
    property var cfg_enableNotifications
    property var cfg_enableNotificationsDefault
    property var cfg_enableReminder
    property var cfg_enableReminderDefault
    property var cfg_reminderMinutes
    property var cfg_reminderMinutesDefault
    property var cfg_preferTimedHoursDefault
    property var cfg_alignLeftDefault
    property var cfg_showIconDefault
    property var cfg_hideEventTitleDefault
    property var cfg_maxTitleLengthDefault

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            level: 4
            text: i18n("All-day event")
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true
            wideMode: true

            QQC2.SpinBox {
                Kirigami.FormData.label: i18n("Show if nothing within (hours)")
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

        Kirigami.Heading {
            level: 4
            text: i18n("Personalisation")
            Layout.topMargin: Kirigami.Units.largeSpacing
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true
            wideMode: true

            QQC2.Switch {
                Kirigami.FormData.label: i18n("Align panel text to the left")
                checked: cfg_alignLeft
                onToggled: cfg_alignLeft = checked
            }

            QQC2.Switch {
                Kirigami.FormData.label: i18n("Show calendar icon")
                checked: cfg_showIcon
                onToggled: cfg_showIcon = checked
            }

            QQC2.Switch {
                Kirigami.FormData.label: i18n("Show generic title instead of event name")
                checked: cfg_hideEventTitle
                onToggled: cfg_hideEventTitle = checked
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
