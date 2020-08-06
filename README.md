# NetMonitor 1.0.2 #

This is a simple network status monitor based on the Electric Imp Platform. It gives you an at-a-glance check if your wireless network and broadband connection are up and running. This can be handy when someone at home yells at you: “Why can’t my `insert device type` connect to the Internet?!?!”.

## Hardware ##

Building the monitor requires:

- One imp of any type.
- One red, yellow and green LED.

Attach the LEDs to three imp pins and a common GND. You will need to add the pin names to the device code. Look for the section:

```squirrel
// Update the following lines for the particular imp type (eg. imp003, imp004m, etc.) you are using
local green = hardware.pinC;
local red = hardware.pinA;
local yellow = hardware.pinD;
```

and update the three local variables with the **hardware** object properties for the imp pins you have chosen.

See the Electric Imp [generic getting started guide](https://developer.electricimp.com/gettingstarted/generic) to find out how to connect a new imp to your network.

## Software ##

**Note** The monitor code makes use of certain files imported from my [generic Squirrel code repo](https://github.com/smittytone/generic), but it does not depend on the imported code. Unless you are using Squinter, the `#import` statements will be ignored by impCentral when you upload or paste in the code.

## Monitor Usage ##

When the monitor is up and running, it will light the green LED to show that its local network is operational and has a connection to the Internet. If either WiFi or broadband goes down, the monitor will signal this with a red LED (green goes off). It may take up to 60s for the loss of connectivity to be displayed.

Upon disconnection, the monitor periodically attempts to reconnect to the Electric Imp impCloud. While trying to connect, the yellow LED is lit. If the attempt succeeds only the green LED is lit, otherwise red remains lit.

## The Web UI ##

Using impCentral or a similar tool, you can get the monitor’s agent URL. Access this URL in a browser for a remote network status report.

You can also get a list of nearby WiFi networks compatible with your imp. Click on the table headings to sort; repeated clicks switch from ascending to descending sort columns.

The WiFi Settings section (click the title to show the controls) allows you to reprogram your imp’s WiFi settings. But take care: if you enter incorrect details, your imp will require local BlinkUp to regain the correct credentials.

## Alternative Code ##

The primary app is embodied in the Squirrel files `monitors.device.nut` and `monitors.agent.nut`. The files `twiliomonitors.device.nut` and `twiliomonitors.agent.nut` provide an alternative version that makes use of the [Twilio](https://twilio.com) communications platform to send SMS messages when the network state changes. Usage requires a Twilio account and phone number, and a target number to which the status messages will be sent.

## Release Notes ##

- 1.0.2 *06 August 2020*
    - Minor UI tweaks.
    - Remove horizontal scrolling with better CSS.
- 1.0.1 *21 May 2020*
    - Update Jquery to 3.5.x.
    - Update Bootstrap to 4.5.x.
    - Update included repo names.
- 1.0.0 *26 February 2020*
    - Initial public release.

## License ##

License: [MIT](./LICENSE).<br />Copyright &copy; 2020, Tony Smith (@smittytone).