import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasma5support 2.0 as P5Support

PlasmoidItem {
    id: root
    
    property string energyText: "-- W" 
    property color energyTextColor: Kirigami.Theme.textColor 
    property string batteryPath: ""
    property string acAdapterPath: ""
    
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
    
    P5Support.DataSource {
        id: dataSource
        engine: "executable"
        connectedSources: []

        function readFile(path) {
            connectSource("cat " + path)
        }

        onNewData: (sourceName, data) => {
            var exitCode = data["exit code"]
            var exitStatus = data["exit status"]
            var stdout = data["stdout"]
            var stderr = data["stderr"]

            if (exitCode == 0) {
                root.processFileContent(sourceName, stdout.trim())
            } else {
                console.error("Error reading file:", sourceName, "stderr:", stderr)
                root.processFileContent(sourceName, null)
            }

            disconnectSource(sourceName)
        }
    }
    
    function processFileContent(source, content) {
        if (source.includes("status")) {
            var isCharging = content === "Charging"
            readVoltage()
        } else if (source.includes("voltage_now")) {
            if (content === null) {
                root.energyText = "Reading voltage"
                root.energyTextColor = Kirigami.Theme.negativeTextColor
                return
            }
            voltageValue = parseFloat(content) / 1000000
            readCurrent()
        } else if (source.includes("current_now")) {
            if (content === null) {
                root.energyText = "Reading current"
                root.energyTextColor = Kirigami.Theme.negativeTextColor
                return
            }
            currentValue = parseFloat(content) / 1000000
            readACOnline()
        } else if (source.includes("online")) {
            var acOnline = parseInt(content, 10) === 1
            calculateAndDisplayEnergy(acOnline)
        }
    }

    property real voltageValue: 0
    property real currentValue: 0

    function readVoltage() {
        dataSource.readFile(root.batteryPath + "/voltage_now")
    }

    function readCurrent() {
        dataSource.readFile(root.batteryPath + "/current_now")
    }

    function readACOnline() {
        if (root.acAdapterPath) {
            dataSource.readFile(root.acAdapterPath + "/online")
        } else {
            calculateAndDisplayEnergy(false)  // Assume not plugged in if we can't find AC adapter
        }
    }

    function calculateAndDisplayEnergy(acOnline) {
        var watts = voltageValue * currentValue
        var isFullyCharged = Math.abs(currentValue) < 0.01

        if (isFullyCharged && acOnline) {
            root.energyText = "\u26A1"
            root.energyTextColor = Kirigami.Theme.textColor
        } else {
            var formattedWatts
            if (acOnline) {
                formattedWatts = watts.toFixed(1) + "W"
                root.energyTextColor = Kirigami.Theme.textColor
            } else {
               // formattedWatts = "-" + watts.toFixed(1).replace(".", ",") + "W" // use this if you prefer coma and remove the line below. I wasn't able to force it other way. YMMV
                formattedWatts = "-" + watts.toFixed(1) + "W"
                var threshold = plasmoid.configuration.wattageThreshold
                root.energyTextColor = watts >= threshold ? "red" : Kirigami.Theme.textColor
            }
            
            root.energyText = formattedWatts + (acOnline ? "\u26A1" : "")
        }
    }

    function findPowerSupplyPaths() {
        dataSource.connectSource("ls /sys/class/power_supply")
    }

    function updateEnergyUsage() {
        if (root.batteryPath) {
            dataSource.readFile(root.batteryPath + "/status")
        } else {
            findPowerSupplyPaths()
        }
    }

    Timer {
        id: updateTimer
        interval: plasmoid.configuration.updateInterval
        running: true
        repeat: true
        onTriggered: updateEnergyUsage()
    }

    Component.onCompleted: {
        findPowerSupplyPaths()
    }

    Connections {
        target: plasmoid.configuration
        function onUpdateIntervalChanged() {
            updateTimer.interval = plasmoid.configuration.updateInterval
        }
    }

    Connections {
        target: dataSource
        function onNewData(sourceName, data) {
            if (sourceName === "ls /sys/class/power_supply") {
                var devices = data.stdout.split('\n')
                var batteries = devices.filter(function(item) {
                    return item.startsWith('BAT')
                })
                var acAdapters = devices.filter(function(item) {
                    return item.startsWith('AC') || item.startsWith('ADP') || item === 'ACAD' || item.startsWith('USB')
                })

                if (batteries.length > 0) {
                    root.batteryPath = "/sys/class/power_supply/" + batteries[0]
                    console.log("Battery found: " + root.batteryPath)
                } else {
                    console.error("No battery found")
                    root.energyText = "No battery"
                    root.energyTextColor = Kirigami.Theme.negativeTextColor
                }

                if (acAdapters.length > 0) {
                    root.acAdapterPath = "/sys/class/power_supply/" + acAdapters[0]
                    console.log("AC adapter found: " + root.acAdapterPath)
                } else {
                    console.warn("No AC adapter found")
                }

                updateEnergyUsage()
                dataSource.disconnectSource(sourceName)
            }
        }
    }
}
