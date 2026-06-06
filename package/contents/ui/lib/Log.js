.pragma library

var enabled = false;

function log(category, message) {
    if (!enabled) return;
    console.log("[eventbar] [" + category + "] " + message);
}
