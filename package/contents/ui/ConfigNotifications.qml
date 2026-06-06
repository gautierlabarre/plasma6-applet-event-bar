import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: configNotifications

    property bool cfg_enableNotifications: plasmoid.configuration.enableNotifications
    property bool cfg_enableReminder: plasmoid.configuration.enableReminder
    property int cfg_reminderMinutes: plasmoid.configuration.reminderMinutes

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
    property var cfg_enableNotificationsDefault
    property var cfg_enableReminderDefault
    property var cfg_reminderMinutesDefault
    property var cfg_preferTimedHours
    property var cfg_preferTimedHoursDefault
    property var cfg_alignLeft
    property var cfg_alignLeftDefault
    property var cfg_showIcon
    property var cfg_showIconDefault
    property var cfg_hideEventTitle
    property var cfg_hideEventTitleDefault
    property var cfg_maxTitleLength
    property var cfg_maxTitleLengthDefault

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.Switch {
            Kirigami.FormData.label: i18n("Notify when an event starts")
            checked: cfg_enableNotifications
            onToggled: cfg_enableNotifications = checked
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
