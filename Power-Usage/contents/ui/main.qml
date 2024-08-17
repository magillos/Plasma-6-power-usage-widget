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
    property bool hasPowerNow: false
    property bool hasPowerNowChecked: false
    property var errorFlags: ({})
    
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
                if (!root.errorFlags[sourceName]) {
                    console.error("Error reading file:", sourceName, "stderr:", stderr)
                    root.errorFlags[sourceName] = true
                }
                root.processFileContent(sourceName, null)
            }

            disconnectSource(sourceName)
        }
    }
    
    function processFileContent(source, content) {
        if (source.includes("status")) {
            var isCharging = content === "Charging"
            if (root.hasPowerNow) {
                readPowerNow()
            } else {
                readVoltage()
            }
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
        } else if (source.includes("power_now")) {
            if (content === null) {
                root.energyText = "Reading power"
                root.energyTextColor = Kirigami.Theme.negativeTextColor
                return
            }
            powerValue = parseFloat(content) / 1000000
            readACOnline()
        } else if (source.includes("online")) {
            var acOnline = parseInt(content, 10) === 1
            calculateAndDisplayEnergy(acOnline)
        }
    }

    property real voltageValue: 0
    property real currentValue: 0
    property real powerValue: 0

    function readVoltage() {
        dataSource.readFile(root.batteryPath + "/voltage_now")
    }

    function readCurrent() {
        dataSource.readFile(root.batteryPath + "/current_now")
    }

    function readPowerNow() {
        dataSource.readFile(root.batteryPath + "/power_now")
    }

    function readACOnline() {
        if (root.acAdapterPath) {
            dataSource.readFile(root.acAdapterPath + "/online")
        } else {
            calculateAndDisplayEnergy(false)  
        }
    }

    function calculateAndDisplayEnergy(acOnline) {
        var watts = root.hasPowerNow ? powerValue : voltageValue * currentValue
        var isFullyCharged = root.hasPowerNow ? (watts < 0.1) : (Math.abs(currentValue) < 0.01)

        if (isFullyCharged && acOnline) {
            root.energyText = "\u26A1"
            root.energyTextColor = Kirigami.Theme.textColor
        } else {
            var formattedWatts
            if (acOnline) {
                formattedWatts = watts.toLocaleString(Qt.locale(), 'f', 1) + "W"
                root.energyTextColor = Kirigami.Theme.textColor
            } else {
                formattedWatts = "-" + Math.abs(watts).toLocaleString(Qt.locale(), 'f', 1) + "W"
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
                    return item.startsWith('AC') || item.startsWith('ADP') || item.startsWith('USB')
                })

                if (batteries.length > 0) {
                    // Prioritize BAT1 if available, otherwise use BAT0
                    var selectedBattery = batteries.find(bat => bat === 'BAT1') || batteries[0]
                    var newBatteryPath = "/sys/class/power_supply/" + selectedBattery
                    
                    if (newBatteryPath !== root.batteryPath) {
                        root.batteryPath = newBatteryPath
                        console.log("Selected battery: " + root.batteryPath)
                        root.errorFlags = {} // Reset error flags when battery changes
                        root.hasPowerNowChecked = false
                        dataSource.connectSource("ls " + root.batteryPath + "/power_now")
                    }
                } else {
                    if (!root.errorFlags["no_battery"]) {
                        console.error("No battery found")
                        root.errorFlags["no_battery"] = true
                    }
                    root.energyText = "No battery"
                    root.energyTextColor = Kirigami.Theme.negativeTextColor
                }

                if (acAdapters.length > 0) {
                    var newAcAdapterPath = "/sys/class/power_supply/" + acAdapters[0]
                    if (newAcAdapterPath !== root.acAdapterPath) {
                        root.acAdapterPath = newAcAdapterPath
                        console.log("AC adapter found: " + root.acAdapterPath)
                    }
                } else {
                    if (!root.errorFlags["no_ac_adapter"]) {
                        console.warn("No AC adapter found")
                        root.errorFlags["no_ac_adapter"] = true
                    }
                }

                updateEnergyUsage()
                dataSource.disconnectSource(sourceName)
            } else if (sourceName.includes("/power_now") && !hasPowerNowChecked) {
                root.hasPowerNow = (data["exit code"] === 0)
                console.log("Device " + (root.hasPowerNow ? "has" : "does not have") + " power_now file")
                hasPowerNowChecked = true
                dataSource.disconnectSource(sourceName)
            }
        }
    }

    // Add a timer to periodically check for battery changes
    Timer {
        id: batteryCheckTimer
        interval: 5000 // Check every 5 seconds
        running: true
        repeat: true
        onTriggered: findPowerSupplyPaths()
    }
}
