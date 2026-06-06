.pragma library
.import "Log.js" as Log

function request(opt, callback) {
    var xhr = new XMLHttpRequest()
    var method = opt.method || "GET"
    Log.log("api", method + " " + opt.url)
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status >= 200 && xhr.status < 300) {
                Log.log("api", method + " " + opt.url + " → " + xhr.status)
                callback(null, xhr.responseText, xhr)
            } else {
                Log.log("api", method + " " + opt.url + " → ERROR " + xhr.status + " " + xhr.statusText)
                callback(xhr.status + " " + xhr.statusText, xhr.responseText, xhr)
            }
        }
    }
    xhr.open(method, opt.url)
    if (opt.headers) {
        for (var key in opt.headers) {
            xhr.setRequestHeader(key, opt.headers[key])
        }
    }
    xhr.send(opt.data || null)
}

function post(opt, callback) {
    opt.method = "POST"
    if (!opt.headers) opt.headers = {}
    opt.headers["Content-Type"] = "application/x-www-form-urlencoded"

    if (typeof opt.data === "object") {
        var parts = []
        for (var key in opt.data) {
            parts.push(encodeURIComponent(key) + "=" + encodeURIComponent(opt.data[key]))
        }
        opt.data = parts.join("&")
    }

    request(opt, callback)
}

function getJSON(opt, callback) {
    request(opt, function(err, data, xhr) {
        if (err) {
            callback(err, null, xhr)
        } else {
            try {
                callback(null, JSON.parse(data), xhr)
            } catch (e) {
                Log.log("api", "JSON parse error: " + e.toString())
                callback(e.toString(), null, xhr)
            }
        }
    })
}

function postJSON(opt, callback) {
    opt.method = "POST"
    if (!opt.headers) opt.headers = {}
    opt.headers["Content-Type"] = "application/x-www-form-urlencoded"

    if (typeof opt.data === "object") {
        var parts = []
        for (var key in opt.data) {
            parts.push(encodeURIComponent(key) + "=" + encodeURIComponent(opt.data[key]))
        }
        opt.data = parts.join("&")
    }

    request(opt, function(err, data, xhr) {
        if (err) {
            callback(err, null, xhr)
        } else {
            try {
                callback(null, JSON.parse(data), xhr)
            } catch (e) {
                Log.log("api", "JSON parse error: " + e.toString())
                callback(e.toString(), null, xhr)
            }
        }
    })
}
