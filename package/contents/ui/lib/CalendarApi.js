// Google Calendar API helpers (no i18n, pure logic)

.pragma library
.import "Log.js" as Log

// Refresh access token if expired, then call callback with valid token
function ensureAccessToken(config, Requests, callback) {
    var expiresAt = config.accessTokenExpiresAt || 0
    if (config.accessToken && Date.now() < expiresAt - 5000) {
        Log.log("auth", "Token still valid, expires in " + Math.round((expiresAt - Date.now()) / 1000) + "s")
        callback(config.accessToken)
        return
    }

    Log.log("auth", "Token expired or missing, refreshing...")
    Requests.postJSON({
        url: "https://oauth2.googleapis.com/token",
        data: {
            client_id: config.clientId,
            client_secret: config.clientSecret,
            refresh_token: config.refreshToken,
            grant_type: "refresh_token"
        }
    }, function(err, data) {
        if (err || !data || !data.access_token) {
            Log.log("auth", "Token refresh failed: " + (err || "no access_token in response"))
            callback(null)
            return
        }
        config.accessToken = data.access_token
        config.accessTokenExpiresAt = Date.now() + data.expires_in * 1000
        Log.log("auth", "Token refreshed, expires_in=" + data.expires_in + "s")
        callback(data.access_token)
    })
}

// Fetch event color palette and primary calendar background color (cached via colorsLoaded flag)
function loadColors(token, Requests, callback) {
    Log.log("api", "Loading calendar colors...")
    Requests.getJSON({
        url: "https://www.googleapis.com/calendar/v3/colors",
        headers: { "Authorization": "Bearer " + token }
    }, function(err, data) {
        var eventColors = {}
        if (!err && data && data.event) {
            for (var id in data.event) {
                eventColors[id] = data.event[id].background
            }
        } else {
            Log.log("api", "Failed to load event colors: " + (err || "no data"))
        }
        Requests.getJSON({
            url: "https://www.googleapis.com/calendar/v3/users/me/calendarList/primary",
            headers: { "Authorization": "Bearer " + token }
        }, function(err2, calData) {
            var calColor = ""
            if (!err2 && calData && calData.backgroundColor) {
                calColor = calData.backgroundColor
            } else {
                Log.log("api", "Failed to load calendar color: " + (err2 || "no data"))
            }
            callback(eventColors, calColor)
        })
    })
}

// Fetch upcoming events from Google Calendar (next 7 days, max 20)
function fetchEvents(token, Requests, callback) {
    var now = new Date()
    var end = new Date(now)
    end.setDate(end.getDate() + 7)

    var url = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
        + "?timeMin=" + encodeURIComponent(now.toISOString())
        + "&timeMax=" + encodeURIComponent(end.toISOString())
        + "&singleEvents=true"
        + "&orderBy=startTime"
        + "&maxResults=20"

    Log.log("api", "Fetching events from " + now.toISOString() + " to " + end.toISOString())
    Requests.getJSON({
        url: url,
        headers: { "Authorization": "Bearer " + token }
    }, function(err, data) {
        if (err || !data || !data.items) {
            Log.log("api", "fetchEvents failed: " + (err || "no items in response"))
            callback(null)
            return
        }
        Log.log("api", "fetchEvents returned " + data.items.length + " events")
        callback(data.items)
    })
}

// Extract user's response status from an event's attendees list
function getResponseStatus(event) {
    if (!event.attendees) return "accepted"
    for (var j = 0; j < event.attendees.length; j++) {
        if (event.attendees[j].self) {
            return event.attendees[j].responseStatus || "needsAction"
        }
    }
    return "accepted"
}
