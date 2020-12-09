/*
 * IMPORTS
 *
 */

// Load up reporting and other local libraries
// If you are not using Squinter or a similar tool,
// please paste the code from the named files in place
// of the relevant import statement
#import "../generic-squirrel/utilities.nut"      // See https://github.com/smittytone/generic-squirrel
#import "../generic-squirrel/seriallog.nut"      // See https://github.com/smittytone/generic-squirrel
#import "../generic-squirrel/disconnect.nut"     // See https://github.com/smittytone/generic-squirrel

/*
 * CONSTANTS
 *
 */
const TRIAL_TIME = 30;

/*
 * GLOBALS
 *
 */
local networks = null;
local networkIndex = 0;
local isScanning = false;

// Update the following lines for the particular imp type (eg. imp003, imp004m, etc.) you are using
local green = hardware.pinC;
local red = hardware.pinA;
local yellow = hardware.pinD;

/*
 * RUNTIME START
 *
 */

// Configure serial logging
seriallog.configure(hardware.uart12, 115200, 160, true);

// Display the boot message
#import "../generic-squirrel/bootmessage.nut"

// Configure the traffic-light LEDs:
//    GREEN - Connected
//    YELLOW - Connecting
//    RED - Disconnected
green.configure(DIGITAL_OUT, (server.isconnected() ? 1 : 0));
red.configure(DIGITAL_OUT, (server.isconnected() ? 0 : 1));
yellow.configure(DIGITAL_OUT, 0);

// Set up the connectivity state-change handler.
// All the real work is done here, based on the type of connectivity
// event -- eg. on (dis/re)connection, set the LEDs appropriately
disconnectionManager.eventCallback = function(event) {
    if ("message" in event) seriallog.log(event.message + " (Timestamp: " + event.ts + ")");

    if ("type" in event) {
        if (event.type == "connected") {
            green.write(1);
            red.write(0);
            yellow.write(0);

            // Relay connection information
            local i = imp.net.info();
            agent.send("send.net.status", i.ipv4);
            i = "active" in i ? i.interface[i.active] : i.interface[0];
            seriallog.log("Current RSSI " + ("rssi" in i ? i.rssi : "unknown"));
        } else if (event.type == "disconnected") {
            green.write(0);
            red.write(1);
            yellow.write(0);
        } else if (event.type == "connecting") {
            yellow.write(1);
        } else {
            green.write(0);
            red.write(0);
            yellow.write(0);
        }
    }
};

disconnectionManager.reconnectDelay = 61;
disconnectionManager.start();

/*
 * Register agent message handlers
 */

// The agent has sent new WiFi credentials, so apply them, then reboot
agent.on("set.wifi.data", function(wifi) {
    imp.setwificonfiguration(wifi.ssid, wifi.pwd);
    server.log("Changing WiFi to SSID \'" + wifi.ssid + "\' in 10 seconds");
    imp.wakeup(10, function() {
        imp.reset();
    });
});

// The agent has asked for local network information
agent.on("get.wifi.data", function(dummy) {
    local i = imp.net.info();
    foreach (index, item in i.interface) {
        if (item.type == "wifi" && "active" in i && i.active == index) {
            // Update the stored SSID and then send the network info
            agent.send("report.wifi.ssid", [item.ssid, item.macaddress]);
            agent.send("send.net.status", i.ipv4);
        }
    }
});

// The agent has asked for a list of nearby networks, so queue up a WiFi scan
agent.on("get.wlan.list", function(dummy) {
    // Make sure we're not scanning already
    if (!isScanning) {
        isScanning = true;

        // Initiate the scan
        imp.scanwifinetworks(function(networks) {
            // On completing, clear the 'am scanning' flag and send the
            // list of networks to the agent (which will relay it to the UI)
            isScanning = false;
            agent.send("set.wlan.list", networks);
        }.bindenv(this));
    }
}.bindenv(this));

agent.on("do.reset", function(dummy) {
    server.log("Net Monitor restarting in 5 seconds...");
    imp.wakeup(5.0, function() {
        imp.reset();
    });
});