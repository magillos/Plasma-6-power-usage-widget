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
    property var batteryPaths: []
    property string acAdapterPath: ""
    property bool hasPowerNow: false
    property bool hasPowerNowChecked: false
    
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
    
    property var batteryData: ({})

    function processFileContent(source, content) {
        var batteryIndex = source.includes("BAT0") ? 0 : (source.includes("BAT1") ? 1 : -1)
        
        if (source.includes("status")) {
            if (batteryIndex !== -1) {
                batteryData[batteryIndex] = batteryData[batteryIndex] || {}
                batteryData[batteryIndex].isCharging = content === "Charging"
            }
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
            if (batteryIndex !== -1) {
                batteryData[batteryIndex] = batteryData[batteryIndex] || {}
                batteryData[batteryIndex].voltage = parseFloat(content) / 1000000
            }
            readCurrent()
        } else if (source.includes("current_now")) {
            if (content === null) {
                root.energyText = "Reading current"
                root.energyTextColor = Kirigami.Theme.negativeTextColor
                return
            }
            if (batteryIndex !== -1) {
                batteryData[batteryIndex] = batteryData[batteryIndex] || {}
                batteryData[batteryIndex].current = parseFloat(content) / 1000000
            }
            readACOnline()
        } else if (source.includes("power_now")) {
            if (content === null) {
                root.energyText = "Reading power"
                root.energyTextColor = Kirigami.Theme.negativeTextColor
                return
            }
            if (batteryIndex !== -1) {
                batteryData[batteryIndex] = batteryData[batteryIndex] || {}
                batteryData[batteryIndex].power = parseFloat(content) / 1000000
            }
            readACOnline()
        } else if (source.includes("online")) {
            var acOnline = parseInt(content, 10) === 1
            calculateAndDisplayEnergy(acOnline)
        }
    }

    function readVoltage() {
        root.batteryPaths.forEach(path => dataSource.readFile(path + "/voltage_now"))
    }

    function readCurrent() {
        root.batteryPaths.forEach(path => dataSource.readFile(path + "/current_now"))
    }

    function readPowerNow() {
        root.batteryPaths.forEach(path => dataSource.readFile(path + "/power_now"))
    }

    function readACOnline() {
        if (root.acAdapterPath) {
            dataSource.readFile(root.acAdapterPath + "/online")
        } else {
            calculateAndDisplayEnergy(false)  
        }
    }

    function calculateAndDisplayEnergy(acOnline) {
        var totalWatts = 0
        var isFullyCharged = true

        for (var i = 0; i < root.batteryPaths.length; i++) {
            if (batteryData[i]) {
                var batteryWatts = root.hasPowerNow ? batteryData[i].power : (batteryData[i].voltage * batteryData[i].current)
                totalWatts += batteryWatts
                isFullyCharged = isFullyCharged && (root.hasPowerNow ? (batteryWatts < 0.1) : (Math.abs(batteryData[i].current) < 0.01))
            }
        }

        if (isFullyCharged && acOnline) {
            root.energyText = "\u26A1"
            root.energyTextColor = Kirigami.Theme.textColor
        } else {
            var formattedWatts
            if (acOnline) {
                formattedWatts = totalWatts.toLocaleString(Qt.locale(), 'f', 1) + "W"
                root.energyTextColor = Kirigami.Theme.textColor
            } else {
                formattedWatts = "-" + Math.abs(totalWatts).toLocaleString(Qt.locale(), 'f', 1) + "W"
                var threshold = plasmoid.configuration.wattageThreshold
                root.energyTextColor = totalWatts >= threshold ? "red" : Kirigami.Theme.textColor
            }
            
            root.energyText = formattedWatts + (acOnline ? "\u26A1" : "")
        }
    }

    function findPowerSupplyPaths() {
        dataSource.connectSource("ls /sys/class/power_supply")
    }

    function updateEnergyUsage() {
        if (root.batteryPaths.length > 0) {
            root.batteryPaths.forEach(path => dataSource.readFile(path + "/status"))
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
                    root.batteryPaths = batteries.map(function(bat) {
                        return "/sys/class/power_supply/" + bat
                    })
                    console.log("Batteries found: " + root.batteryPaths.join(", "))
                    
                    root.batteryPaths.forEach(function(path, index) {
                        dataSource.connectSource("ls " + path + "/power_now")
                    })
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
            } else if (sourceName.includes("/power_now") && !hasPowerNowChecked) {
                root.hasPowerNow = (data["exit code"] === 0)
                console.log("Device " + (root.hasPowerNow ? "has" : "does not have") + " power_now file")
                hasPowerNowChecked = true
                dataSource.disconnectSource(sourceName)
            }
        }
    }
}
