.pragma library

function findBestEventIndex(model, todayLabel, preferHours, msPerHour) {
    let bestIdx = -1
    const now = Date.now()
    for (let i = 0; i < model.count; i++) {
        const event = model.get(i)
        if (event.sectionDate !== todayLabel) continue
        if (event.responseStatus !== "accepted") continue
        if (bestIdx < 0) bestIdx = i
        if (preferHours > 0 && event.startMs > 0 && event.startMs - now < preferHours * msPerHour) {
            bestIdx = i
            break
        }
    }
    return bestIdx
}

function resolveEventColor(event, colorMap, defaultColor) {
    if (event.colorId && colorMap[event.colorId]) {
        return colorMap[event.colorId]
    }
    return defaultColor
}
