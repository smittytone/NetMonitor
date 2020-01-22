// IMPORTS
#require "Rocky.agent.lib.nut:3.0.0"

#import "~/Documents/GitHub/generic/simpleslack.nut"
#import "~/Documents/GitHub/generic/crashreporter.nut"
#import "~/OneDrive/Programming/nettester/nettester.nut"


// CONSTANTS
const HTML_STRING = @"
#import "tester_ui.html"
";
#import "images.nut";


// GLOBALS
local api = null;
local data = null;
local wanIP = null;
local ipdata = null;
local networks = null;
local savedContext = null;
local sortFunctions = null;
local sortType = 1;
local sortDirIsAsc = 1;


// FUNCTIONS
function debugAPI(context, next) {
    // Display a UI API activity report
    server.log("API received a request at " + time() + ": " + context.req.method.toupper() + " @ " + context.req.path.tolower());
    if (context.req.rawbody.len() > 0) server.log("Request body: " + context.req.rawbody.tolower());

    // Invoke the next middleware
    next();
}

function checkSecure(context) {
    if (context.req.headers["x-forwarded-proto"] != "https") return false;
    return true;
}

function sortSSID(a, b) {
    if (a.ssid.tolower() < b.ssid.tolower()) return sortDirIsAsc * -1;
    if (a.ssid.tolower() > b.ssid.tolower()) return sortDirIsAsc *1;
    return 0;
}

function sortChannel(a, b) {
    if (a.channel < b.channel) return sortDirIsAsc * -1;
    if (a.channel > b.channel) return sortDirIsAsc * 1;
    return 0;
}

function sortRSSI(a, b) {
    if (a.rssi < b.rssi) return sortDirIsAsc * -1;
    if (a.rssi > b.rssi) return sortDirIsAsc * 1;
    return 0;
}

function sortOpen(a, b) {
    if (!a.open && b.open) return sortDirIsAsc * -1;
    if (a.open && !b.open) return sortDirIsAsc * 1;
    return 0;
}


// RUNTIME START

// Set sort functions
sortFunctions = [sortSSID, sortChannel, sortRSSI, sortOpen];

// Load settings
local loaded = server.load();

if (loaded.len() != 0) {
    data = loaded;
} else {
    imp.wakeup(10, function() {
        device.send("get.wifi.data", true);
    });

    data = {};
    data.ssid <- "";
    data.pwd <- "";
}

device.on("report.wifi.ssid", function(value) {
    data.ssid = value;
    server.log("SSID set from device");
    server.save(data);
});

device.on("send.net.status", function(info) {
    ipdata = info;
});

device.on("set.wlan.list", function(wlans) {
    if (savedContext != null) {
        networks = wlans;
        networks.sort(sortFunctions[sortType]);
        savedContext.send(200, http.jsonencode({"list": networks}));
        savedContext = null;
    }
});

// Set up the API that the agent will server
api = Rocky.init();
api.use(debugAPI);

// GET at / returns the UI
api.get("/", function(context) {
    context.send(200, format(HTML_STRING, http.agenturl()));
});

api.get("/current", function(context) {

    if (!checkSecure(context)) {
        context.send(401, "Insecure access forbidden");
        return;
    }

    local sendData = {};
    sendData.ssid <- data.ssid;
    sendData.pwd <- data.pwd;
    sendData.state <- device.isconnected() ? "connected" : "disconnected or unknown";

    if (ipdata != null) {
        sendData.ip <- ipdata.address;
        ipdata.wip <- context.getHeader("X-Forwarded-For");
        sendData.wip <- ipdata.wip;
        sendData.bc <- ipdata.broadcast;
        sendData.nm <- ipdata.netmask;
        sendData.gw <- ipdata.gateway;
    }

    context.send(200, http.jsonencode(sendData));
});

api.post("/new", function(context) {

    if (!checkSecure(context)) {
        context.send(401, "Insecure access forbidden");
        return;
    }

    try {
        local sentData = http.jsondecode(context.req.rawbody);
        local wasUpdated = false;

        if ("ssid" in sentData) {
            data.ssid = sentData.ssid;
            wasUpdated = true;
        }

        if ("pwd" in sentData) {
            data.pwd = sentData.pwd;
            wasUpdated = true;
        }

        if (wasUpdated) {
            server.log("Sending WiFi data to device");
            device.send("set.wifi.data", data);
            server.save(data);
        }
    } catch (err) {
        server.error(err);
        context.send(400, "Bad data posted");
        return;
    }

    context.send(200, "OK");
});

api.get("/list", function(context) {

    if (!checkSecure(context)) {
        context.send(401, "Insecure access forbidden");
        return;
    }

    device.send("get.wlan.list", true);
    savedContext = context;
});

api.post("/relist", function(context) {

    if (!checkSecure(context)) {
        context.send(401, "Insecure access forbidden");
        return;
    }

    try {
        local sentData = http.jsondecode(context.req.rawbody);
        if ("type" in sentData) sortType = sentData.type.tointeger();
        if ("flip" in sentData) {
            // Reverse the sort direction
            sortDirIsAsc *= -1;
        } else {
            // New column selected, so show ascending
            sortDirIsAsc = 1;
        }

        if (networks != null) {
            networks.sort(sortFunctions[sortType]);
            context.send(200, http.jsonencode({"list": networks}));
        } else {
            device.send("get.wlan.list", true);
            savedContext = context;
        }
    } catch (err) {
        server.error(err);
        context.send(400, "Bad data posted");
    }
});

// Any call to the endpoint /images is sent the correct PNG data
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
