// Pure model and feedback helpers; never accept provider diagnostics or secrets.
function values(model) {
    return model ? (typeof model.length === "number" ? model : (model.values || [])) : [];
}

function networks(devices) {
    let result = [];
    for (const device of devices) {
        for (const network of values(device.networks))
            result.push(network);
    }
    return result;
}

function failure(category, bluetooth) {
    switch (category) {
    case "permission":
        return "Permission denied. Check system authorization.";
    case "authentication":
        return bluetooth ? "Authentication failed or a Bluetooth pairing agent is required." : "Authentication required. Use an external NetworkManager credential agent.";
    case "lost":
        return "The connection was lost. Select the network again.";
    case "timeout":
        return bluetooth ? "Bluetooth action timed out. Check permission and the system pairing agent; state may still change." : "Network action timed out; state may still change.";
    case "disappeared":
        return "The selected device or network disappeared.";
    case "unavailable":
        return bluetooth ? "Bluetooth adapter unavailable." : "Network service or adapter unavailable.";
    case "disabled":
        return bluetooth ? "Bluetooth was turned off or hardware blocked while the action was pending." : "Wi-Fi was turned off or hardware blocked while the action was pending.";
    default:
        return bluetooth ? "Bluetooth action failed. Check system authorization and the pairing agent." : "Network action failed. Check system authorization.";
    }
}
