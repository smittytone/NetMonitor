/*
 * IMPORTS
 *
 */
// Load up the Rocky web API management
#require "Rocky.agent.lib.nut:3.0.0"

// Load up reporting and other local libraries
// If you are not using Squinter or a similar tool,
// please paste the code from the named files in place
// of the relevant import statement
#import "../generic-squirrel/simpleslack.nut"        // See https://github.com/smittytone/generic-squirrel
#import "../generic-squirrel/crashreporter.nut"      // See https://github.com/smittytone/generic-squirrel

// Crash reporting
// Uncomment the next two lines and complete with your own data
// local slack = SimpleSlack("YOUR_SLACK_APP_CODE");
// crashReporter.init(slack.post.bindenv(slack));
#import "~/OneDrive/Programming/nettester/nettester.nut"


/*
 * CONSTANTS: Web UI HTML and images
 *
 */
const HTML_STRING = @"
#import "monitor_ui.html"
";
#import "images.nut";


/*
 * GLOBALS
 *
 */
local api = null;
local data = null;
local savedContext = null;
local sortFunctions = null;
local sortColumn = 1;
local sortDirIsAsc = 1;


/*
 * FUNCTIONS
 *
 */

/*
 * Display an API access activity report, useful for UI debugging
 *
 * See https://github.com/electricimp/Rocky for details of parameters
 *
 */
function debugAPI(context, next) {
    // Display a UI API activity report
    server.log("API received a request at " + time() + ": " + context.req.method.toupper() + " @ " + context.req.path.tolower());
    if (context.req.rawbody.len() > 0) server.log("Request body: " + context.req.rawbody.tolower());

    // Invoke the next middleware
    next();
}

/*
 * Mandate an HTTPS connection. If there isn't one, reject the connection
 *
 * @param {Rocky.context} context - Rocky library context for current HTTP request
 *
 * @return {Boolean} true if the connnection is HTTPS, otherwise false
 *
 */
function checkSecure(context) {
    if (context.req.headers["x-forwarded-proto"] != "https") {
        // Reject the connection on HTTP
        context.send(401, "Insecure access forbidden");
        return false;
    }

    // Indicate we accept the HTTPS connection
    return true;
}

/*
 * Compare the SSIDs of two WLAN records, used by Squirrel's sort() function
 *
 * @param {Table} a - First WLAN record
 * @param {Table} b - Second WLAN record
 *
 * @returns {Integer} -1, 0, 1 as the result of the comparison
 *
 */
function sortSSID(a, b) {
    if (a.ssid.tolower() < b.ssid.tolower()) return sortDirIsAsc * -1;
    if (a.ssid.tolower() > b.ssid.tolower()) return sortDirIsAsc *1;
    return 0;
}

/*
 * Compare the channels of two WLAN records, used by Squirrel's sort() function
 *
 * @param {Table} a - First WLAN record
 * @param {Table} b - Second WLAN record
 *
 * @returns {Integer} -1, 0, 1 as the result of the comparison
 *
 */
function sortChannel(a, b) {
    if (a.channel < b.channel) return sortDirIsAsc * -1;
    if (a.channel > b.channel) return sortDirIsAsc * 1;
    return 0;
}

/*
 * Compare the RSSI values of two WLAN records, used by Squirrel's sort() function
 *
 * @param {Table} a - First WLAN record
 * @param {Table} b - Second WLAN record
 *
 * @returns {Integer} -1, 0, 1 as the result of the comparison
 *
 */
function sortRSSI(a, b) {
    if (a.rssi < b.rssi) return sortDirIsAsc * -1;
    if (a.rssi > b.rssi) return sortDirIsAsc * 1;
    return 0;
}

/*
 * Compare the network openness status of two WLAN records, used by Squirrel's sort() function
 *
 * @param {Table} a - First WLAN record
 * @param {Table} b - Second WLAN record
 *
 * @returns {Integer} -1, 0, 1 as the result of the comparison
 *
 */
function sortOpen(a, b) {
    if (!a.open && b.open) return sortDirIsAsc * -1;
    if (a.open && !b.open) return sortDirIsAsc * 1;
    return 0;
}


/*
 * RUNTIME START
 *
 */

// Set the sort functions into an array for easy future access
// NOTE They will be accessed by index only
sortFunctions = [sortSSID, sortChannel, sortRSSI, sortOpen];

// Initialise application data store
data = {};
data.wifi <- {};
data.networks <- [];
data.network <- {};

// Load stored WiFi settings, if any
local loaded = server.load();

if (loaded.len() != 0) {
    data.wifi = loaded;
} else {
    // No stored data; ask the device for the SSID and
    // initialize the store
    imp.wakeup(10, function() {
        device.send("get.wifi.data", true);
    });

    data.wifi = { "ssid": "", "pwd": "" };
}

/*
 * Message handlers
 */

// Store the device's SSID when it is reported
device.on("report.wifi.ssid", function(value) {
    data.wifi.ssid = value;
    server.save(data.wifi);
    server.log("SSID set from device");
});

// Store the device's network values when they are reported
device.on("send.net.status", function(localLanInfo) {
    data.network = localLanInfo;
});

// Forward the nearby network list to the web UI when it is sent from the device
// NOTE We sort according to current sort column
device.on("set.wlan.list", function(nearbyNetworks) {
    if (savedContext != null) {
        data.networks = nearbyNetworks;
        data.networks.sort(sortFunctions[sortColumn]);
        savedContext.send(200, http.jsonencode({"list": data.networks}));
        savedContext = null;
    }
});

/*
 * Web UI API Configuration
 */

// Set up the API that the agent will serve
api = Rocky.init();
api.use(debugAPI);

// GET at / returns the UI itself
api.get("/", function(context) {
    context.send(200, format(HTML_STRING, http.agenturl()));
});

// GET at /current returns the current data
api.get("/current", function(context) {
    // Check for HTTPS
    if (!checkSecure(context)) return;

    // Collate the data to be sent
    local sendData = {};
    sendData.ssid <- data.wifi.ssid;
    sendData.pwd <- data.wifi.pwd;
    sendData.state <- device.isconnected() ? "connected" : "disconnected";

    if (data.network.len() != 0) {
        // Add the standard imp.net.info().ipv4 data
        sendData.ip <- data.network.address;
        sendData.bc <- data.network.broadcast;
        sendData.nm <- data.network.netmask;
        sendData.gw <- data.network.gateway;

        // Add the WAN IP address, as viewed by the client
        // NOTE For this to be meaningful, the client has to be on
        //      the same network as the net monitor
        data.network.wip <- context.getHeader("X-Forwarded-For");
        sendData.wip <- data.network.wip;
    }

    // Send the data to the Web UI
    context.send(200, http.jsonencode(sendData));
});

// POST at /new inputs new network credentials
api.post("/new", function(context) {
    // Check for HTTPS
    if (!checkSecure(context)) return;

    try {
        // Decode the incoming JSON and check for the keys 'ssid' and/or 'pwd'
        // flagging any change if one was made
        local sentData = http.jsondecode(context.req.rawbody);
        local wasUpdated = false;

        if ("ssid" in sentData) {
            // Make sure the new SSID isn't an empty string
            if (sendData.ssid.len() > 0) {
                data.wifi.ssid = sentData.ssid;
                wasUpdated = true;
            }
        }

        if ("pwd" in sentData) {
            // NOTE 'pwd' value might be an empty string (no password)
            data.wifi.pwd = sentData.pwd;
            wasUpdated = true;
        }

        if (wasUpdated) {
            // Send the changes to the device
            server.log("Sending WiFi data to device");
            device.send("set.wifi.data", data.wifi);
            server.save(data.wifi);
        }
    } catch (err) {
        // Most likely this is a JSON decode error
        server.error(err);
        context.send(400, "Bad data posted");
        return;
    }

    context.send(200, "OK");
});

// GET at /list returns a nearby network list
api.get("/list", function(context) {
    // Check for HTTPS
    if (!checkSecure(context)) return;

    // Ask the device for a list and hold the current Rocky
    // context for use when the device responds
    device.send("get.wlan.list", true);
    savedContext = context;
});

// POST at /relist triggers a re-sort of the current nearby
// networks list. The input data is JSON of the form:
// { "type": "INTEGER_COLUMN_VALUE",
//   "flip": "ANY" }
// NOTE Flip is only present if we are reversing the sort
api.post("/relist", function(context) {
    // Check for HTTPS
    if (!checkSecure(context)) return;

    try {
        local sentData = http.jsondecode(context.req.rawbody);
        if ("type" in sentData) sortColumn = sentData.type.tointeger();

        if ("flip" in sentData) {
            // Reverse the sort direction
            sortDirIsAsc *= -1;
        } else {
            // New column selected, so show ascending
            sortDirIsAsc = 1;
        }

        if (data.networks != null) {
            // Apply the sort instruction and re-send the list data for display
            data.networks.sort(sortFunctions[sortColumn]);
            context.send(200, http.jsonencode({"list": data.networks}));
        } else {
            // We have no nearby network list, so ask the device for one
            // NOTE This is unlikely, as this endpoint can only be called if
            //      the Web UI already has data (ie. a network list) to show
            device.send("get.wlan.list", true);
            savedContext = context;
        }
    } catch (err) {
        server.error(err);
        context.send(400, "Bad data posted");
    }
});

// Any call to the endpoint /images returns the requested PNG data
api.get("/images/([^/]*)", function(context) {
    // Determine which image has been requested and send the appropriate
    // stored data back to the requesting web browser
    local path = context.path;
    local name = path[path.len() - 1];
    local image = LOCK_PNG;

    if (name == "s1.png") image = SIGNAL_1_PNG;
    if (name == "s2.png") image = SIGNAL_2_PNG;
    if (name == "s3.png") image = SIGNAL_3_PNG;
    if (name == "s4.png") image = SIGNAL_4_PNG;

    // Set headers to mark the data as an image, and to cache it
    context.setHeader("Content-Type", "image/png");
    context.setHeader("Cache-Control", "max-age=86400");
    context.send(200, image);
});

api.post("/slack", function(context) {
    local data = context.req.body;
    if ("challenge" in data) {
        if ("type" in data) {
            if (data.type == "url_verification") {
                context.setHeader("Content-Type", "text/plain");
                context.send(200, data.challenge);
            }
        }
    } else {
        context.send(200, "OK");
    }

    if ("event" in data) {
        server.log("Event received");
    }
});