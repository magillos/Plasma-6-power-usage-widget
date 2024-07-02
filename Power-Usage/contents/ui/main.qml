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
            font.pointSize: plasmoid.configuration.fontSize
            font.bold: plasmoid.configuration.fontBold
            font.family: plasmoid.configuration.fontFamily || font.family
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
                    readFile("file:///sys/class/power_supply/AC/online", function(acOnlineStr) {
                        var acOnline = parseInt(acOnlineStr, 10) === 1;
                        
                        var isFullyCharged = Math.abs(current) < 0.01;
                        
                        if (isFullyCharged && acOnline) {
                            root.energyText = "\u26A1";
                            root.energyTextColor = Kirigami.Theme.textColor;
                        } else {
                            var formattedWatts;
                            if (acOnline || isCharging) {
                                formattedWatts = watts.toFixed(1) + "W";
                                root.energyTextColor = Kirigami.Theme.textColor;
                            } else {
                                formattedWatts = "-" + watts.toFixed(1).replace(".", ",") + "W";
                                var threshold = plasmoid.configuration.wattageThreshold;
                                root.energyTextColor = watts >= threshold ? "red" : Kirigami.Theme.textColor;
                            }
                            
                            root.energyText = formattedWatts + (isCharging || acOnline ? "\u26A1" : "");
                        }
                    });
                });
            });
        });
    }

   Timer {
        id: updateTimer
        interval: plasmoid.configuration.updateInterval
        running: true
        repeat: true
        onTriggered: updateEnergyUsage()
    }

    Component.onCompleted: {
        updateEnergyUsage()
    }

    Connections {
        target: plasmoid.configuration
        function onUpdateIntervalChanged() {
            updateTimer.interval = plasmoid.configuration.updateInterval
        }
    }
}
