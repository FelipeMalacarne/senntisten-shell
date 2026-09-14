.pragma library

var catalog = [
    {
        id: "catppuccin-mocha",
        name: "Catppuccin Mocha",
        description: "Cool stone. Soft lavender.",
        palette: {
            background: "#11111b", surface: "#1e1e2e", elevated: "#313244",
            overlay: "#45475a", border: "#45475a", text: "#cdd6f4",
            muted: "#a6adc8", subtle: "#7f849c", accent: "#cba6f7",
            accentText: "#181825", success: "#a6e3a1", warning: "#f9e2af",
            error: "#f38ba8"
        }
    },
    {
        id: "gruvbox",
        name: "Gruvbox",
        description: "Warm earth. Burnished gold.",
        palette: {
            background: "#1d2021", surface: "#282828", elevated: "#3c3836",
            overlay: "#504945", border: "#665c54", text: "#ebdbb2",
            muted: "#d5c4a1", subtle: "#a89984", accent: "#d8a657",
            accentText: "#1d2021", success: "#b8bb26", warning: "#fabd2f",
            error: "#fb4934"
        }
    }
];

function decodeState(text) {
    if (!text.trim()) {
        return { settings: { theme: "catppuccin-mocha", reducedMotion: false },
            status: "default", message: "", writable: true };
    }
    var parsed;
    try { parsed = JSON.parse(text); } catch (error) { parsed = null; }
    if (parsed && typeof parsed.schemaVersion === "number" && parsed.schemaVersion > 1) {
        return { settings: { theme: "catppuccin-mocha", reducedMotion: false },
            status: "blocked", message: "Unsupported newer appearance schema. Saving is disabled.", writable: false };
    }
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)
            || parsed.schemaVersion !== 1 || !isKnownTheme(parsed.theme)
            || typeof parsed.reducedMotion !== "boolean") {
        return { settings: { theme: "catppuccin-mocha", reducedMotion: false },
            status: "recovered", message: "Invalid appearance state. Defaults are in use.", writable: true };
    }
    return { settings: { theme: parsed.theme, reducedMotion: parsed.reducedMotion },
        status: "saved", message: "", writable: true };
}

function isKnownTheme(id) {
    return catalog.some(function (entry) { return entry.id === id; });
}

function encodeState(settings) {
    if (!settings || !isKnownTheme(settings.theme) || typeof settings.reducedMotion !== "boolean")
        throw new Error("Invalid appearance settings");
    return JSON.stringify({ schemaVersion: 1, theme: settings.theme,
        reducedMotion: settings.reducedMotion }, null, 2) + "\n";
}

function listThemes() {
    return catalog.map(function (entry) {
        return { id: entry.id, name: entry.name, description: entry.description };
    });
}

function paletteFor(id) {
    var entry = catalog.filter(function (candidate) { return candidate.id === id; })[0];
    return Object.assign({}, (entry || catalog[0]).palette);
}
