.pragma library

function aspectOf(toplevel) {
    var ipc = toplevel && toplevel.lastIpcObject ? toplevel.lastIpcObject : null
    var size = ipc && ipc.size ? ipc.size : null
    return size && size.length >= 2 && size[0] > 0 && size[1] > 0
        ? size[0] / size[1]
        : 16 / 10
}

function fit(toplevels, availableWidth, availableHeight, gap, labelHeight) {
    var count = toplevels ? toplevels.length : 0
    if (count < 1) return { columns: 1, rows: 1, cardWidth: 0, cardHeight: 0 }

    var width = Math.max(1, availableWidth)
    var height = Math.max(1, availableHeight)
    var spacing = Math.max(0, gap || 0)
    var label = Math.max(0, labelHeight || 0)
    var aspects = new Array(count)
    for (var i = 0; i < count; i++) aspects[i] = aspectOf(toplevels[i])

    var best = null
    for (var columns = 1; columns <= count; columns++) {
        var rows = Math.ceil(count / columns)
        var cardWidth = Math.max(1, (width - spacing * (columns - 1)) / columns)
        var cardHeight = Math.max(1, (height - spacing * (rows - 1)) / rows)
        var thumbHeight = Math.max(1, cardHeight - label)
        var area = 0

        for (var j = 0; j < count; j++) {
            var fittedWidth = Math.min(cardWidth, thumbHeight * aspects[j])
            area += fittedWidth * (fittedWidth / aspects[j])
        }

        var score = area - rows * width * height * 0.00001
        if (!best || score > best.score) {
            best = { columns: columns, rows: rows, cardWidth: cardWidth, cardHeight: cardHeight, score: score }
        }
    }
    return best
}
