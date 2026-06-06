import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid
import "lib/Requests.js" as Requests
import "lib/Log.js" as Log
import "lib"

KCM.SimpleKCM {
    id: configPage

    property string cfg_clientId: plasmoid.configuration.clientId
    property string cfg_clientSecret: plasmoid.configuration.clientSecret
    property string cfg_accessToken: plasmoid.configuration.accessToken
    property string cfg_refreshToken: plasmoid.configuration.refreshToken
    property bool isLoggedIn: cfg_refreshToken !== ""
    property bool isLoggingIn: false
    property string statusMessage: ""

    // Plasma injects all cfg_* properties into every config page
    property var cfg_accessTokenExpiresAt
    property var cfg_accessTokenExpiresAtDefault
    property var cfg_accessTokenDefault
    property var cfg_refreshTokenDefault
    property var cfg_clientIdDefault
    property var cfg_clientSecretDefault
    property var cfg_enableNotifications
    property var cfg_enableNotificationsDefault
    property var cfg_enableReminder
    property var cfg_enableReminderDefault
    property var cfg_reminderMinutes
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
    property var cfg_enableDebugLogs
    property var cfg_enableDebugLogsDefault

    ExecUtil {
        id: executable
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.TextField {
                id: clientIdField
                Kirigami.FormData.label: i18n("Client ID:")
                Layout.fillWidth: true
                text: cfg_clientId
                placeholderText: "xxxxx.apps.googleusercontent.com"
                onTextChanged: cfg_clientId = text
                enabled: !isLoggedIn
            }

            QQC2.TextField {
                id: clientSecretField
                Kirigami.FormData.label: i18n("Client Secret:")
                Layout.fillWidth: true
                text: cfg_clientSecret
                echoMode: TextInput.Password
                onTextChanged: cfg_clientSecret = text
                enabled: !isLoggedIn
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.smallSpacing
            visible: !isLoggedIn

            QQC2.Button {
                Layout.alignment: Qt.AlignHCenter
                text: isLoggingIn ? i18n("Connecting...") : i18n("Sign in with Google")
                icon.name: "internet-services"
                enabled: cfg_clientId !== "" && cfg_clientSecret !== "" && !isLoggingIn
                onClicked: startOAuthLogin()
            }

            QQC2.Label {
                Layout.alignment: Qt.AlignHCenter
                text: statusMessage
                color: statusMessage !== "" && !statusMessage.startsWith("OK") ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                visible: statusMessage !== ""
                wrapMode: Text.WordWrap
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.smallSpacing
            visible: isLoggedIn

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Kirigami.Icon {
                    source: "dialog-positive"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                }
                QQC2.Label {
                    text: i18n("Connected to Google Calendar")
                    color: Kirigami.Theme.positiveTextColor
                }
            }

            QQC2.Button {
                Layout.alignment: Qt.AlignHCenter
                text: i18n("Sign out")
                icon.name: "system-log-out"
                onClicked: logout()
            }
        }
    }

    function startOAuthLogin() {
        isLoggingIn = true
        statusMessage = ""

        const scriptPath = Qt.resolvedUrl("../scripts/google_oauth_server.py").toString().replace("file://", "")
        const scope = "https://www.googleapis.com/auth/calendar.readonly"

        Log.log("auth", "Starting OAuth server: " + scriptPath)
        executable.exec(
            ["python3", scriptPath, cfg_clientId, scope],
            function(cmd, exitCode, exitStatus, stdout, stderr) {
                if (exitCode !== 0 || stdout === "") {
                    Log.log("auth", "OAuth server failed: exitCode=" + exitCode + " stderr=" + stderr)
                    isLoggingIn = false
                    statusMessage = i18n("Error: could not retrieve authorization code")
                    return
                }
                Log.log("auth", "Authorization code received, exchanging for tokens")
                exchangeCodeForTokens(stdout)
            }
        )
    }

    function exchangeCodeForTokens(authCode) {
        Requests.postJSON({
            url: "https://oauth2.googleapis.com/token",
            data: {
                client_id: cfg_clientId,
                client_secret: cfg_clientSecret,
                code: authCode,
                grant_type: "authorization_code",
                redirect_uri: "http://127.0.0.1:8400/"
            }
        }, function(err, data) {
            isLoggingIn = false
            if (err || !data || !data.access_token) {
                Log.log("auth", "Token exchange failed: " + (err || "no access_token"))
                statusMessage = i18n("Error: token exchange failed")
                return
            }
            Log.log("auth", "Token exchange successful, expires_in=" + data.expires_in + "s")
            plasmoid.configuration.accessToken = data.access_token
            plasmoid.configuration.refreshToken = data.refresh_token || ""
            plasmoid.configuration.accessTokenExpiresAt = Date.now() + data.expires_in * 1000
            plasmoid.configuration.clientId = cfg_clientId
            plasmoid.configuration.clientSecret = cfg_clientSecret
            cfg_accessToken = data.access_token
            cfg_refreshToken = data.refresh_token || ""
            statusMessage = ""
        })
    }

    function logout() {
        Log.log("auth", "User signed out")
        plasmoid.configuration.accessToken = ""
        plasmoid.configuration.refreshToken = ""
        plasmoid.configuration.accessTokenExpiresAt = 0
        cfg_accessToken = ""
        cfg_refreshToken = ""
        statusMessage = ""
    }
}
