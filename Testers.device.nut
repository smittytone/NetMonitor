/*
 * IMPORTS
 *
 */
#import "~/documents/github/generic/utilities.nut"
#import "~/documents/github/generic/seriallog.nut"
#import "~/documents/github/generic/disconnect.nut"

/*
 * CONSTANTS
 *
 */
const TRIAL_TIME = 30;

/*
 * GLOBALS
 *
 */
local green = hardware.pinC;
local red = hardware.pinA;
local yellow = hardware.pinD;
local networks = null;
local networkIndex = 0;
local isScanning = false;

/*
 * RUNTIME START
 *
 */

// Configure serial logging
seriallog.configure(hardware.uart12, 115200, 160, true);

#import "~/documents/github/generic/bootmessage.nut"

// Configure LEDs:
//    GREEN - Connected
//    YELLOW - Connecting
//    RED - Disconnected
green.configure(DIGITAL_OUT, (server.isconnected() ? 1 : 0));
red.configure(DIGITAL_OUT, (server.isconnected() ? 0 : 1));
yellow.configure(DIGITAL_OUT, 0);

// Set up connectivity policy
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
 *
 */
agent.on("set.wifi.data", function(wifi) {
    imp.setwificonfiguration(wifi.ssid, wifi.pwd);
    server.log("Changing WiFi to SSID \'" + wifi.ssid + "\' in 10 seconds");
    imp.wakeup(10, function() {
        imp.reset();
    });
});

agent.on("get.wifi.data", function(dummy) {
    local i = imp.net.info();
    foreach (index, item in i.interface) {
        if (item.type == "wifi" && "active" in i && i.active == index) {
            agent.send("report.wifi.ssid", item.ssid);
            agent.send("send.net.status", i.ipv4);
        }
    }
});

agent.on("get.wlan.list", function(dummy) {
    if (!isScanning) {
        isScanning = true;
        imp.scanwifinetworks(function(networks) {
            isScanning = false;
            agent.send("set.wlan.list", networks);
        }.bindenv(this));
    }
}.bindenv(this));
