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
                root.energyText = "Error reading voltage"
                root.energyTextColor = Kirigami.Theme.negativeTextColor
                return
            }
            voltageValue = parseFloat(content) / 1000000
            readCurrent()
        } else if (source.includes("current_now")) {
            if (content === null) {
                root.energyText = "Error reading current"
                root.energyTextColor = Kirigami.Theme.negativeTextColor
                return
            }
            currentValue = parseFloat(content) / 1000000
            readACOnline()
        } else if (source.includes("AC/online")) {
            var acOnline = parseInt(content, 10) === 1
            calculateAndDisplayEnergy(acOnline)
        }
    }

    property real voltageValue: 0
    property real currentValue: 0

    function readVoltage() {
        dataSource.readFile("/sys/class/power_supply/BAT0/voltage_now")
    }

    function readCurrent() {
        dataSource.readFile("/sys/class/power_supply/BAT0/current_now")
    }

    function readACOnline() {
        dataSource.readFile("/sys/class/power_supply/AC/online")
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
                formattedWatts = "-" + watts.toFixed(1).replace(".", ",") + "W"
                var threshold = plasmoid.configuration.wattageThreshold
                root.energyTextColor = watts >= threshold ? "red" : Kirigami.Theme.textColor
            }
            
            root.energyText = formattedWatts + (acOnline ? "\u26A1" : "")
        }
    }

    function updateEnergyUsage() {
        dataSource.readFile("/sys/class/power_supply/BAT0/status")
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
