// Google Calendar API helpers (no i18n, pure logic)

.pragma library
.import "Log.js" as Log

var TOKEN_EXPIRY_BUFFER_MS = 5000
var FETCH_DAYS_AHEAD = 7
var MAX_RESULTS = 20

function ensureAccessToken(config, Requests, callback) {
    const expiresAt = config.accessTokenExpiresAt || 0
    if (config.accessToken && Date.now() < expiresAt - TOKEN_EXPIRY_BUFFER_MS) {
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

function loadColors(token, Requests, callback) {
    Log.log("api", "Loading calendar colors...")
    loadEventColors(token, Requests, function(eventColors) {
        loadCalendarColor(token, Requests, function(calColor) {
            callback(eventColors, calColor)
        })
    })
}

function loadEventColors(token, Requests, callback) {
    Requests.getJSON({
        url: "https://www.googleapis.com/calendar/v3/colors",
        headers: { "Authorization": "Bearer " + token }
    }, function(err, data) {
        const colors = {}
        if (!err && data && data.event) {
            for (const id in data.event) {
                colors[id] = data.event[id].background
            }
        } else {
            Log.log("api", "Failed to load event colors: " + (err || "no data"))
        }
        callback(colors)
    })
}

function loadCalendarColor(token, Requests, callback) {
    Requests.getJSON({
        url: "https://www.googleapis.com/calendar/v3/users/me/calendarList/primary",
        headers: { "Authorization": "Bearer " + token }
    }, function(err, calData) {
        let calColor = ""
        if (!err && calData && calData.backgroundColor) {
            calColor = calData.backgroundColor
        } else {
            Log.log("api", "Failed to load calendar color: " + (err || "no data"))
        }
        callback(calColor)
    })
}

function fetchEvents(token, Requests, callback) {
    const now = new Date()
    const end = new Date(now)
    end.setDate(end.getDate() + FETCH_DAYS_AHEAD)

    const url = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
        + "?timeMin=" + encodeURIComponent(now.toISOString())
        + "&timeMax=" + encodeURIComponent(end.toISOString())
        + "&singleEvents=true"
        + "&orderBy=startTime"
        + "&maxResults=" + MAX_RESULTS

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

function getResponseStatus(event) {
    if (!event.attendees) return "accepted"
    for (let i = 0; i < event.attendees.length; i++) {
        if (event.attendees[i].self) {
            return event.attendees[i].responseStatus || "needsAction"
        }
    }
    return "accepted"
}
