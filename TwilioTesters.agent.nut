/*
 * IMPORTS
 *
 */
// Load up the Rocky web API management
#require "Rocky.agent.lib.nut:3.0.0"

// Load up the Twilio library
#require "Twilio.class.nut:1.0"

/*
 * CONSTANTS: WEB UI HTML
 *
 */
const HTML_STRING = @"
<!DOCTYPE html>
<html lang='en'>
<head>
    <title>NetTester</title>
    <link rel='stylesheet' href='https://netdna.bootstrapcdn.com/bootstrap/4.1.1/css/bootstrap.min.css'>
    <link href='https://fonts.googleapis.com/css?family=Abel|Audiowide' rel='stylesheet'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <meta charset='UTF-8'>
    <style>
        .center { margin-left: auto; margin-right: auto; margin-bottom: auto; margin-top: auto; }
        body { background-color: #b30000; }
        p {color: white; font-family: Abel, sans-serif; font-size: 18px;}
        p.box {margin-top: 2px; margin-bottom: 2px;}
        p.subhead {color:#ffcc00; font-size: 22px; line-height: 24px; vertical-align: middle;}
        p.postsubhead {margin-top: 15px;}
        p.colophon {font-size: 14px; text-align: center;}
        p.little {font-size: 14px; line-height: 16px; margin-top: 10px;}
        h2 {color: #ffcc00; font-family: Audiowide, sans-serif; font-weight:bold; font-size: 36px; margin-top: 10px;}
        h4 {color: white; font-family: Abel, sans-serif; font-weight:bold; font-size: 30px; margin-bottom: 10px;}
        td {color: white; font-family: Abel, sans-serif;}
        hr {border-color: #ffcc00;}
        .uicontent {border: 2px solid #ffcc00;}
        .container {padding: 20px;}
        .btn-warning {width: 200px;}
        .showhidewlans {-webkit-touch-callout: none; -webkit-user-select: none; -khtml-user-select: none;
                        -moz-user-select: none; -ms-user-select: none; user-select: none; cursor: pointer;
                        margin-bottom:0px; vertical-align: middle;}
        .modal {display: none; position: fixed; z-index: 1; left: 0; top: 0; width: 100%%; height: 100%%; overflow: auto;
                background-color: rgba(0,0,0,0.4)}
    .modal-content-ok {background-color: #37ACD1; margin: 10%% auto; padding: 5px;
                       border: 2px solid #2C8BA9; width: 80%%}

        @media only screen and (max-width: 640px) {
            .container {padding: 5px;}
            .uicontent {border: 0px;}
            .col-1 {max-width: 0%%; flex: 0 0 0%%;}
            .col-3 {max-width: 0%%; flex: 0 0 0%%;}
            .col-5 {max-width: 50%%; flex: 0 0 50%%;}
            .col-6 {max-width: 100%%; flex: 0 0 100%%;}
            .btn-warning {width: 140px;}
        }
    </style>
</head>
<body>
    <!-- Modals -->
   <div id='notify' class='modal'>
       <div class='modal-content-ok'>
           <h3 align='center' style='color: white; font-family: Abel'>Device&nbsp;state&nbsp;changed</h3>
       </div>
   </div>
    <div class='container'>
        <div class='row uicontent' align='center'>
            <div class='col'>
                <!-- Title and Data Readout Row -->
                <div class='row' align='center'>
                    <div class='col-3'></div>
                    <div class='col-6'>
                        <h2 class='text-center'>Net Monitor</h2>
                        <h4 id='status' class='text-center'>Device is <span>disconnected</span></h4>
                        <div class='row' align='center'>
                            <div class='col-1'></div>
                            <div class='col-5'>
                                <p class='box' align='right'><b>Device IP</b></p>
                                <p class='box' align='right'><b>WAN IP</b></p>
                                <p class='box' align='right'><b>Gateway</b></p>
                                <p class='box' align='right'><b>Netmask</b></p>
                                <p class='box' align='right'><b>Broadcast IP</b></p>
                            </div>
                            <div class='col-5'>
                                <p class='box' align='left' id='ip'><span>Unknown</span></p>
                                <p class='box' align='left' id='wip'><span>Unknown</span></p>
                                <p class='box' align='left' id='gw'><span>Unknown</span></p>
                                <p class='box' align='left' id='nm'><span>Unknown</span></p align='left'>
                                <p class='box' align='left' id='bc'><span>Unknown</span></p>
                            </div>
                            <div class='col-1'></div>
                        </div>
                        <hr />
                    </div>
                    <div class='col-3'></div>
                </div>
                <!-- Nearby Networks Readout -->
                <div class='row' align='center'>
                    <div class='col-3'></div>
                    <div class='col-6'>
                        <h4 class='showhidewlans text-center'>Nearby Networks</h4>
                        <div class='wlans'>
                            <p class='network-list text-center'>&nbsp;<br /><span></span></p>
                            <button class='btn btn-warning' style='vertical-align:middle;font-family:Abel;' type='submit' id='search-button'>Get</button>
                        </div>
                        <hr />
                    </div>
                    <div class='col-3'></div>
                </div>
                <p>&nbsp;</p>
            </div>
        </div>
    </div>

    <script src='https://ajax.googleapis.com/ajax/libs/jquery/3.4.1/jquery.min.js'></script>
    <script>
    // Variables
    var agenturl = '%s';
    var state = 0;
    var timer;

    // Get initial readings
    getState(updateReadout);

    // Begin the online status update loop
    var stateTimer = setInterval(checkState, 20000);

    // Set UI click actions
    document.getElementById('search-button').onclick = wsearch;

    // Configure Show/Hide Nearby Networks toggle
    $('.showhidewlans').click(function() {
        $('.wlans').toggle();
    });

    // Functions
    function updateReadout(data) {
        $('#status span').text(data.state);
        $('#ip span').text(data.ip);
        $('#wip span').text(data.wip);
        $('#gw span').text(data.gw);
        $('#nm span').text(data.nm);
        $('#bc span').text(data.bc);

        let newstate = (data.state == 'connected' ? 1 : 2);

        // NOTE check for 'state != 0' stops modal appearing on launch
        if (state !=0 && newstate != state) {
            state = newstate;
            setModal();
        }
    }

    function getState(callback) {
        // Request the current data
        $.ajax({
            url : agenturl + '/current',
            type: 'GET',
            cache: false,
            success : function(response) {
                response = JSON.parse(response);
                if (callback) {
                    callback(response);
                }
            }
        });
    }

    function checkState() {
        // Request the current settings to extract the device's online state
        // NOTE This is called periodically via a timer (stateTimer)
        $.ajax({
            url: agenturl + '/current',
            type: 'GET',
            cache: false,
            success: function(response) {
                getState(updateReadout);
            }
        });
    }

    function wsearch(e) {
        $.ajax({
            url: agenturl + '/list',
            type: 'GET',
            cache: false,
            success: function(response) {
                var d = JSON.parse(response);
                showList(d['list'])
            }
        });
    }

    function showList(networks) {
        // Take the array of alarms sent by the clock and generate a list to present
        if (networks.length == 0) {
            // No alarms so just show a simple message
            $('.network-list span').text('No networks found');
        } else {
            // Build an HTML table to show the alarms
            // NOTE the device will already have ordered these, so the sequene of alarms in the 'alarms' array
            //      will match the stored sequence held by the device and the agent
            var h = '<table width=""100%%"" class=""table table-striped table-sm"">';
            h = h + '<tr><th>SSID</th><th>Channel</th><th>RSSI</th><th>Open?</th></tr>';
            for (var i = 0 ; i < networks.length ; i++) {
                let network = networks[i];

                // Set the signal strength graphic
                let r = network.rssi;
                let s = '&nbsp;'
                if (r > -72) { s = '<img src=""' + agenturl + '/images/s4.png"" width=""16"" />' }
                if (r < -71 && r > -77) { s = '<img src=""' + agenturl + '/images/s3.png"" width=""16"" />' }
                if (r < -76 && r > -82) { s = '<img src=""' + agenturl + '/images/s2.png"" width=""16"" />' }
                if (r < -81 && r > -86) { s = '<img src=""' + agenturl + '/images/s1.png"" width=""16"" />' }

                // Check for missing SSIDs
                if (network.ssid == '') { network.ssid = '[HIDDEN]' }

                h = h + '<tr><td width=""50%%"" align=""center"">' + network.ssid + '</td><td width=""20%%"" align=""center"">' + network.channel + '</td><td width=""20%%"" align=""center"">' + s + '</td><td width=""10%%"" align=""center"">' + (network.open ? ' ' : ('<img src=""' + agenturl + '/images/lock.png"" width=""16"" />')) + '</td></tr>';
            }

            h = h + '</table>';
            $('.network-list span').html(h);
            document.getElementById('search-button').textContent = 'Refresh';
        }
    }

    function setModal() {
        clearTimeout(timer);

        var modal = document.getElementById('notify');
        modal.style.display = 'block';

        timer = setTimeout(function() {
            modal.style.display = 'none';
        }, 6000);

        window.onclick = function(event) {
            if (event.target == modal) {
                clearTimeout(timer);
                modal.style.display = 'none';
            }
        };
    }
    </script>
</body>
</html>";


/*
 * CONSTANTS: IMAGES
 *
 */
const LOCK_PNG = "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\x00\x00\x00\x80\x00\x00\x00\x80\x08\x03\x00\x00\x00\xF4\xE0\x91\xF9\x00\x00\x00\x04\x67\x41\x4D\x41\x00\x00\xB1\x8F\x0B\xFC\x61\x05\x00\x00\x00\x01\x73\x52\x47\x42\x00\xAE\xCE\x1C\xE9\x00\x00\x00\x24\x50\x4C\x54\x45\x47\x70\x4C\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x14\x7A\x5D\x67\x00\x00\x00\x0B\x74\x52\x4E\x53\x00\xC0\x3F\x58\x90\x13\xF2\x77\xA9\xDF\x2A\x3B\xC8\xA4\xD6\x00\x00\x02\xA0\x49\x44\x41\x54\x78\xDA\xED\x9B\xDB\x72\xEB\x20\x0C\x45\x8D\x10\xF7\xFF\xFF\xDF\x93\x76\x9A\x4E\xE2\x38\x53\xD0\x16\x68\xDA\xC3\x7E\xB7\xB5\x0C\x42\x02\x09\x1F\xC7\x96\x48\xD5\xA7\xEC\x5C\x29\xB1\xC5\x52\x9C\xCB\x89\xC2\x3A\xE3\xC4\x2E\xB6\x57\x95\xEC\x57\x40\xF8\x7C\x65\xFC\x2E\xE7\xE7\x5A\x0F\xA9\xB4\x1F\x14\xD3\xBC\x61\x08\x1C\x5B\x87\x22\x4F\x42\xF0\x5D\xE6\x3F\xBD\x61\xC6\x44\x54\xD7\x06\x94\x83\xDD\xE7\x7F\x0D\x02\xE9\xDA\x4F\x6D\x58\xAA\xD3\x90\x9B\x40\x6C\x6C\x5F\x91\x80\x5B\x33\x25\x48\x4D\xAC\xA4\x12\xF9\x1B\x20\x05\x4F\x0C\xEF\x83\x6F\xBC\x65\x41\xBE\xE9\x96\x16\xDF\x2D\xD2\x58\x67\x39\x60\x61\x5F\x9F\xD3\x33\x5F\x92\x16\x34\x22\xF9\xEB\x68\x4F\xD7\x69\x3A\xEA\x3B\x62\x19\x4A\x36\xE1\x62\xC1\x90\xF6\x0A\x70\x61\x2C\x65\x14\xC8\x03\xE3\xF8\xCA\x4A\x9A\x6B\xF1\xE5\x65\x91\xC6\xDD\x26\x06\x3D\x0F\x88\x24\x71\xDC\xA4\xB7\x04\x48\xF4\x9C\x7C\x08\xB2\xF4\x53\x58\x67\x08\xC2\xD9\xFF\xA5\x73\x57\x94\x66\xA0\x8A\x13\x88\x30\x25\x38\x20\xA6\x65\xE9\xD8\x3D\xEA\x14\x04\x86\x5C\x89\x80\x67\xDF\xBC\x83\x91\xE1\xF3\x0A\x51\x88\x10\x07\x72\xB8\x0B\x8C\x7A\xF2\x29\x8A\x07\xD8\x05\x18\xE3\x27\x38\x0A\x10\x36\x83\x0C\x47\x01\xD0\x87\x1D\xEA\x83\x82\x17\x80\x1F\x70\x8A\xE7\x19\x4D\xA5\xE3\xBB\xD3\x8C\xE6\x13\x34\x12\xC0\x91\x24\x83\x5E\x58\x74\x01\x32\x18\x06\x60\x00\x07\x3A\x31\x0C\x50\xC0\x38\x94\x7E\x3D\x40\xEC\xB3\x5A\xC9\xDF\x75\x4A\xC6\x34\xAC\xE7\x65\x14\xBF\x5F\x4C\xF5\x4D\x66\xAA\x5C\xDA\x22\xB9\x8B\x6A\x66\xC8\x6D\xA5\xE2\x79\x4E\x29\xB6\xC5\x7A\x3E\xB8\xFB\xB6\x5E\xE5\x21\x3D\xD4\xD8\x2C\x08\x42\x47\x19\x66\xAA\xB2\x42\x1D\x0C\x13\xBD\xAD\x02\xAC\x5A\x8E\x76\x1E\xF8\xB4\x59\xCE\x76\x00\xFE\xEA\x0C\xB8\x52\x7C\x75\x06\x5C\xBF\x0E\xEC\xEC\x7F\x79\xE1\x06\xD8\x00\x1B\x60\x03\x20\x2F\xC8\xCC\xB9\x58\x01\x7C\x77\xEA\x2B\x9B\x00\x3C\x36\x4E\xAA\x5B\x0F\x90\x34\xBA\xAB\x00\x40\xFA\xA1\xB0\x3B\x1B\xC0\xF5\xB4\x77\x66\x02\x54\x9D\x16\xAF\x18\xC0\x75\x14\xB7\xA7\x02\x78\xA5\x2E\xBF\x18\xA0\x2A\xB5\xD9\xC5\x00\x41\xA9\xCF\x2E\x06\x38\xAC\x01\x42\x77\xA3\x7B\x12\x00\x29\x5D\xF5\x10\x03\x24\xEB\x55\xE0\xFA\x3A\xDD\x13\x23\x21\xE9\x5C\xB6\xD1\xCC\x05\x75\x71\x36\xE4\xFE\xCB\x2E\x93\xF6\x03\xAC\x60\x1F\xDB\x11\xE5\x87\x78\xEC\x85\xFB\x42\x70\x53\x7A\xDF\x94\x91\xB8\xC2\x80\xEE\x8A\x09\xBC\x6C\xF6\xFB\x01\xFC\x7F\x0F\x90\x0E\xB0\xCA\x85\x02\xB8\x03\xAC\x72\xC1\x67\x43\x02\x0B\x9D\x30\x40\x64\xEF\xB9\x19\x02\xEC\xFA\xC0\x06\xD8\x00\x1B\x60\x03\x6C\x80\x0D\xF0\x47\x00\xCC\xFB\x86\xC5\x0E\x80\xAD\x5B\xB7\xC9\xF6\xFA\xC0\xFD\x68\x55\xCD\xEC\x97\xE3\xB0\x9D\x83\x84\x54\x57\x14\x07\x00\x39\xDC\x29\x78\x80\xDD\x25\x8A\x64\x77\x91\xEB\xC5\xFE\xC7\x5A\x5C\x1C\x0F\x5F\x7F\xC9\xEC\xFC\xA7\x56\xC9\xFC\xF5\xFD\x44\xFA\xF8\x6F\x6D\xBE\x38\xE1\xBF\xC0\xFD\x25\xFD\x03\x75\x8C\xCF\xAC\xD4\x63\xE1\x05\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82";

const SIGNAL_1_PNG="\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\x00\x00\x00\x80\x00\x00\x00\x80\x08\x03\x00\x00\x00\xF4\xE0\x91\xF9\x00\x00\x00\x04\x67\x41\x4D\x41\x00\x00\xB1\x8F\x0B\xFC\x61\x05\x00\x00\x00\x01\x73\x52\x47\x42\x00\xAE\xCE\x1C\xE9\x00\x00\x00\x06\x50\x4C\x54\x45\x47\x70\x4C\xFF\xFF\xFF\x9F\x94\xA2\x43\x00\x00\x00\x01\x74\x52\x4E\x53\x00\x40\xE6\xD8\x66\x00\x00\x00\x35\x49\x44\x41\x54\x78\xDA\xED\xCE\x41\x0D\x00\x00\x08\x04\xA0\xB3\x7F\x69\x0B\xF8\xD7\x4D\x48\x40\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x17\xD4\x40\x40\x40\x40\x40\x40\x40\x40\x40\xE0\x57\x00\xD8\xD4\xF1\xF3\x01\x91\x02\xDF\x44\x14\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82";

const SIGNAL_2_PNG="\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\x00\x00\x00\x80\x00\x00\x00\x80\x08\x03\x00\x00\x00\xF4\xE0\x91\xF9\x00\x00\x00\x04\x67\x41\x4D\x41\x00\x00\xB1\x8F\x0B\xFC\x61\x05\x00\x00\x00\x01\x73\x52\x47\x42\x00\xAE\xCE\x1C\xE9\x00\x00\x00\x12\x50\x4C\x54\x45\x47\x70\x4C\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x88\x19\x3C\x7F\x00\x00\x00\x05\x74\x52\x4E\x53\x00\xAA\x55\x1B\xEB\x14\x24\xE3\xE1\x00\x00\x00\x53\x49\x44\x41\x54\x78\xDA\xED\xCE\xB9\x11\x00\x20\x0C\xC0\x30\xBE\xEC\xBF\x32\x03\x40\x41\xC1\x85\x02\x69\x00\x9F\x4B\x01\x00\x00\x00\x00\x00\x00\x00\x00\xE0\x44\x1D\xAB\x96\x3A\x10\x2B\x03\x06\x0C\x18\x30\x60\xC0\x80\x01\x03\x06\x0C\x18\xB8\x39\xD0\x37\x52\x07\x36\xF9\x30\x60\xC0\x80\x01\x03\x06\x0C\x18\x30\xF0\xD7\x00\xF0\xD2\x04\xBF\x49\x19\xF8\xD1\xF6\x2A\x78\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82";

const SIGNAL_3_PNG="\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\x00\x00\x00\x80\x00\x00\x00\x80\x08\x03\x00\x00\x00\xF4\xE0\x91\xF9\x00\x00\x00\x04\x67\x41\x4D\x41\x00\x00\xB1\x8F\x0B\xFC\x61\x05\x00\x00\x00\x01\x73\x52\x47\x42\x00\xAE\xCE\x1C\xE9\x00\x00\x00\x12\x50\x4C\x54\x45\x47\x70\x4C\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x88\x19\x3C\x7F\x00\x00\x00\x05\x74\x52\x4E\x53\x00\x58\xAA\x1B\xEB\x86\xD3\x09\x20\x00\x00\x00\x68\x49\x44\x41\x54\x78\xDA\xED\xCE\xB9\x0D\xC0\x30\x0C\x04\x41\x51\x4F\xFF\x2D\xBB\x00\x31\x24\xA8\xC0\xB3\xF9\x1D\x66\x0C\x49\x92\x24\x49\x92\x24\x49\x2A\x69\x45\x52\x27\x20\xCE\xDD\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x28\xFC\x9F\xFB\x2E\x5A\x01\xC9\x3F\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x40\x25\x60\x25\xB5\x02\x92\xF5\x01\x00\x00\x00\x00\x00\x00\x00\x00\xF8\x17\x40\xD2\xCB\x3E\x35\x42\x38\xAF\x45\x41\xF0\x6C\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82";

const SIGNAL_4_PNG="\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\x00\x00\x00\x80\x00\x00\x00\x80\x08\x03\x00\x00\x00\xF4\xE0\x91\xF9\x00\x00\x00\x04\x67\x41\x4D\x41\x00\x00\xB1\x8F\x0B\xFC\x61\x05\x00\x00\x00\x01\x73\x52\x47\x42\x00\xAE\xCE\x1C\xE9\x00\x00\x00\x12\x50\x4C\x54\x45\x47\x70\x4C\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x88\x19\x3C\x7F\x00\x00\x00\x05\x74\x52\x4E\x53\x00\x58\xAA\xF0\x1B\x86\xE4\xD1\x1B\x00\x00\x00\x7C\x49\x44\x41\x54\x78\xDA\xED\xDA\xB1\x09\xC0\x30\x0C\x45\x41\xCB\x71\xF6\x5F\x39\x0B\x7C\x48\x63\x14\x70\xEE\xF5\x12\x87\x6A\x8D\x21\xE9\x2F\x5D\xA1\x56\xC0\x1D\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x38\x09\xB0\x2A\xD4\x09\xA8\xB0\x7E\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x6C\x04\xCC\xF0\x7F\x51\xAD\x80\x30\x0D\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xB0\x13\xB0\x42\xAD\x80\xD7\xF3\x00\x00\x00\x00\x00\x00\x00\x00\x00\x1C\x0F\x90\xF4\x65\x0F\xC6\x62\x65\x11\x8F\xB9\xE6\x96\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82";


/*
 * GLOBALS
 *
 */
local webAPI = null;
local wifiData = null;
local wlanData = null;
local wlanIP = null;
local savedContext = null;
local isConnected = false;
local twilioClient = null;
local targetNumber = null;


/*
 * FUNCTIONS
 *
 */
function debugAPI(context, next) {
    // Display a UI API activity report - this is useful for agent-served UI debugging
    server.log("API received a request at " + time() + ": " + context.req.method.toupper() + " @ " + context.req.path.tolower());
    if (context.req.rawbody.len() > 0) server.log("Request body: " + context.req.rawbody.tolower());

    // Invoke the next middleware (if any) registered with Rocky
    next();
}

function checkSecure(context) {
    // Verify that the request sent to the agent from a remote source was
    // made using HTTPS (ie. do not support HTTP)
    if (context.req.headers["x-forwarded-proto"] != "https") return false;
    return true;
}

function sorter(a, b) {
    if (a.channel < b.channel) return -1;
    if (a.channel > b.channel) return 1;
    if (a.ssid.toupper() < b.ssid.toupper()) return -1;
    if (a.ssid.toupper() > b.ssid.toupper()) return 1;
    return 0;
}

function watchdog() {
    // Record the device state as recorded by the agent
    local state = device.isconnected();

    if (state != isConnected) {
        // The device state has changed, so send an SMS
        isConnected = state;
        if (targetNumber != null) {
            local message = "Net Monitor is now " + (isConnected ? "connected" : "disconnected");
            twilioClient.send(targetNumber, message, function(response) {
                server.log("Reponse from Twilio: " + response.body + " (code: " + response.statuscode + ")");
            });
        }
    }

    imp.wakeup(15, watchdog);
}


/*
 * RUNTIME START
 *
 */

// Set the Twilio client
twilioClient = Twilio("YOUR_ACCOUNT_SID", "YOUR_AUTH_TOKEN", "YOUR_TWILIO_PHONE_NUMBER");
targetNumber = "YOUR_MOBILE_PHONE_NUMBER";
#import "~/dropbox/programming/imp/codes/twilio.nut"

/*
 * Set handlers for messages sent by the device to the agent
 */
device.on("send.net.status", function(info) {
    // The device has sent its WLAN status data, so record ti
    wlanData = info;
});

device.on("set.wlan.list", function(networks) {
    // The device has reported the list of nearby compatible WiFi networks
    // We return this list to the UI using the Rocky context we saved earlier
    // (see below)
    if (savedContext != null) {
        networks.sort(sorter);
        savedContext.send(200, http.jsonencode({"list": networks}));
        savedContext = null;
    }
});

/*
 * Set up the API that the agent will serve to drive the web UI
 */
webAPI = Rocky.init();

// Register the debug readout middleware
webAPI.use(debugAPI);

// Add a handler for GET requests made to /
// This will return the web UI HTML
webAPI.get("/", function(context) {
    context.send(200, format(HTML_STRING, http.agenturl()));
});

// Add a handler for GET requests made to /current
// This will return status JSON to the web UI.
// NOTE The UI asks for this every 20 seconds
webAPI.get("/current", function(context) {

    if (!checkSecure(context)) {
        context.send(401, "Insecure access forbidden");
        return;
    }

    local sendData = {};
    isConnected = device.isconnected();
    sendData.state <- isConnected ? "connected" : "disconnected";

    // If we have WLAN status data (we may not yet) send that too
    if (wlanData != null) {
        // Add the primary router's WAN IP to the stored info
        wlanData.wip <- context.getHeader("X-Forwarded-For");

        // Add the WLAN data to the requested-data payload
        sendData.ip <- wlanData.address;
        sendData.wip <- wlanData.wip;
        sendData.bc <- wlanData.broadcast;
        sendData.nm <- wlanData.netmask;
        sendData.gw <- wlanData.gateway;
    }

    // Return the status information to the web UI
    server.log(http.jsonencode(sendData));
    context.send(200, http.jsonencode(sendData));
});

// Add a handler for GET requests made to /list
// The web UI has requested a list of WLANs that the device can detect
webAPI.get("/list", function(context) {

    if (!checkSecure(context)) {
        context.send(401, "Insecure access forbidden");
        return;
    }

    // Ask the device for a list of WLANs and preserve the Rocky context object
    // for use when the data comes back from the device.
    // NOTE We don't do it here, but it is good practice to set a timer that will
    //      respond to the web UI request if the device does not return the list
    //      (it may be disconnnected)
    device.send("get.wlan.list", true);
    savedContext = context;
});

// Add a handler for GET requests to /images
// Any call to the endpoint /images is returned the requested PNG data
webAPI.get("/images/([^/]*)", function(context) {
    // Determine which image has been requested and send the appropriate
    // stored data back to the requesting web browser
    local path = context.path;
    local name = path[path.len() - 1];
    local image = LOCK_PNG;

    if (name == "s1.png") image = SIGNAL_1_PNG;
    if (name == "s2.png") image = SIGNAL_2_PNG;
    if (name == "s3.png") image = SIGNAL_3_PNG;
    if (name == "s4.png") image = SIGNAL_4_PNG;

    // Make sure we let the browser know what kind of data we're sending...
    context.setHeader("Content-Type", "image/png");

    // ...and send it
    context.send(200, image);
});

/*
 * Start the SMS alert watchdog
 */
watchdog();