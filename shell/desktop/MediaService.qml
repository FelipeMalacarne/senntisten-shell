import QtQuick
import Quickshell.Services.Mpris

Item {
    id: root
    property var mpris: Mpris
    readonly property var players: mpris && mpris.players ? Array.from(mpris.players.values).sort((a, b) => a.dbusName < b.dbusName ? -1 : a.dbusName > b.dbusName ? 1 : 0) : []
    property var preferredPlayer: null
    readonly property var player: players.includes(preferredPlayer) ? preferredPlayer : players.find(candidate => candidate.isPlaying) || players[0] || null
    readonly property bool available: !!player
    readonly property string playerName: player ? player.identity || player.dbusName : ""
    readonly property string title: player ? player.trackTitle : ""
    readonly property string artist: player ? player.trackArtist : ""
    readonly property string album: player ? player.trackAlbum : ""
    readonly property bool playing: !!player && player.isPlaying
    readonly property bool canTogglePlaying: !!player && player.canControl && player.canTogglePlaying && (playing ? player.canPause : player.canPlay)
    readonly property bool canNext: !!player && player.canControl && player.canGoNext
    readonly property bool canPrevious: !!player && player.canControl && player.canGoPrevious
    readonly property string artwork: {
        const url = player ? player.trackArtUrl : "";
        // Never let Image fetch remote metadata URLs, including file://host paths.
        return /^(file:\/\/\/[^/]|image:\/\/|qrc:\/)/.test(url) ? url : "";
    }
    property string error: ""
    readonly property string status: !mpris ? "Media provider unavailable" : !available ? "No media players (MPRIS or session bus may be unavailable)" : error || (!title ? "No track metadata from player" : !player.canControl ? "Player does not support playback controls" : "")

    onPlayersChanged: {
        if (!players.includes(preferredPlayer))
            preferredPlayer = null;
    }
    onPlayerChanged: error = ""

    function selectPlayer(candidate) {
        if (!mpris || !mpris.players.values.includes(candidate))
            return false;
        preferredPlayer = candidate;
        error = "";
        return true;
    }
    function dispatch(action, candidate) {
        // Read the native model again, not cached UI capabilities or a removed selection.
        if (!candidate || candidate !== player || !mpris || !mpris.players.values.includes(candidate) || !candidate.canControl)
            return false;
        if (action === "togglePlaying" && (!candidate.canTogglePlaying || !(candidate.isPlaying ? candidate.canPause : candidate.canPlay)))
            return false;
        if (action === "next" && !candidate.canGoNext || action === "previous" && !candidate.canGoPrevious)
            return false;
        if (!["togglePlaying", "next", "previous"].includes(action))
            return false;
        try {
            candidate[action]();
            error = "";
            return true;
        } catch (failure) {
            error = "Media action failed: " + String(failure);
            return false;
        }
    }
    // true means dispatched, not acknowledged: the pinned native API has no async error signal.
    function togglePlaying(candidate = player) {
        return dispatch("togglePlaying", candidate);
    }
    function next(candidate = player) {
        return dispatch("next", candidate);
    }
    function previous(candidate = player) {
        return dispatch("previous", candidate);
    }
}
