import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0
import org.kde.kirigami 2.20 as Kirigami


PlasmoidItem {
    id: root
    
    property string energyText: "-- W" 
    
    property color energyTextColor: Kirigami.Theme.textColor 
    preferredRepresentation: fullRepresentation
    
    fullRepresentation: ColumnLayout {
        id: fullRep
        Layout.minimumWidth: Kirigami.Units.gridUnit * 10
        Layout.minimumHeight: Kirigami.Units.gridUnit * 4
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            id: energyLabel
            Layout.alignment: Qt.AlignHCenter
            text: root.energyText
            font.pointSize: 10
            color: root.energyTextColor 
        }
    }

    function readFile(url, callback) {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    callback(xhr.responseText.trim());
                } else {
                    console.error("Failed to read file:", url);
                    callback(null);
                }
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }
    
   
  function updateEnergyUsage() {
    readFile("file:///sys/class/power_supply/BAT0/status", function(statusStr) {
        var isCharging = statusStr === "Charging";
        readFile("file:///sys/class/power_supply/BAT0/voltage_now", function(voltageStr) {
            if (voltageStr === null) {
                root.energyText = "Error reading voltage";
                root.energyTextColor = Kirigami.Theme.negativeTextColor;
                return;
            }
            readFile("file:///sys/class/power_supply/BAT0/current_now", function(currentStr) {
                if (currentStr === null) {
                    root.energyText = "Error reading current";
                    root.energyTextColor = Kirigami.Theme.negativeTextColor;
                    return;
                }
                var voltage = parseFloat(voltageStr) / 1000000; 
                var current = parseFloat(currentStr) / 1000000; 
                var watts = voltage * current;
                // Check if AC is online to determine if the symbol should be shown
                readFile("file:///sys/class/power_supply/AC/online", function(acOnlineStr) {
                    var acOnline = parseInt(acOnlineStr, 10) === 1; // Assuming 1 means online
                    
                    // Check if the battery is fully charged (current is very close to 0)
                    var isFullyCharged = Math.abs(current) < 0.01; // Threshold of 0.01A
                    
                    if (isFullyCharged && acOnline) {
                        root.energyText = "\u26A1"; // Only show the lightning bolt
                        root.energyTextColor = Kirigami.Theme.textColor;
                    } else {
                        // Format the watts value
                        var formattedWatts;
                        if (acOnline || isCharging) {
                            formattedWatts = watts.toFixed(1) + "W";
                            root.energyTextColor = Kirigami.Theme.textColor;
                        } else {
                            formattedWatts = "-" + watts.toFixed(1).replace(".", ",") + "W";
                            // Set color to red if power draw is above 12W
                            root.energyTextColor = watts > 12 ? "red" : Kirigami.Theme.textColor;
                        }
                        
                        root.energyText = formattedWatts + (isCharging || acOnline ? "\u26A1" : "");
                    }
                });
            });
        });
    });
}


    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: updateEnergyUsage()
    }

    Component.onCompleted: {
        updateEnergyUsage()
    }
}
