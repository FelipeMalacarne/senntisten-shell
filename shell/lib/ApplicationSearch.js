.pragma library

function normalized(value) {
    return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function fieldScore(text, needle, weight) {
    if (text === needle)
        return weight;
    if (text.startsWith(needle))
        return weight + 1;
    return text.includes(needle) ? weight + 2 : Infinity;
}

function search(entries, query, limit) {
    const count = typeof limit === "number" && isFinite(limit) ? Math.max(0, Math.min(50, Math.floor(limit))) : 8;
    const needle = normalized(query);
    const words = needle.split(/\s+/);
    return Array.from(entries || []).filter(entry => entry && !entry.noDisplay && normalized(entry.name)).map(entry => {
        const name = normalized(entry.name);
        const generic = normalized(entry.genericName);
        const keywords = Array.from(entry.keywords || [], normalized);
        let score = 0;
        for (const word of words) {
            let best = Math.min(fieldScore(name, word, 0), fieldScore(generic, word, 3));
            for (const keyword of keywords)
                best = Math.min(best, fieldScore(keyword, word, 6));
            score += best;
        }
        // A complete name match takes precedence over matches scattered across fields.
        if (name === needle)
            score = -2;
        else if (name.startsWith(needle))
            score = -1;
        return { entry: entry, name: name, score: score };
    }).filter(match => isFinite(match.score))
        .sort((a, b) => a.score - b.score || compareText(a.name, b.name) || compareText(a.entry.id, b.entry.id))
        .slice(0, count)
        .map(match => match.entry);
}

// Avoid locale-dependent ordering (and preserve case-sensitive desktop IDs).
function compareText(a, b) {
    return a < b ? -1 : a > b ? 1 : 0;
}
