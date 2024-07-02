import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: configGeneral

    property alias cfg_wattageThreshold: wattageThresholdSpinBox.value
    property alias cfg_fontSize: fontSizeSpinBox.value
    property alias cfg_fontBold: fontBoldCheckBox.checked
    property alias cfg_fontFamily: fontFamilyComboBox.currentText
    property alias cfg_updateInterval: updateIntervalSpinBox.value

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.SpinBox {
            id: wattageThresholdSpinBox
            Kirigami.FormData.label: i18n("Threshold for red color on battery (W):")
            from: 0
            to: 100
            stepSize: 1
            value: plasmoid.configuration.wattageThreshold
            editable: true

            textFromValue: function(value, locale) {
                return value.toLocaleString(locale, 'f', 1)
            }

            valueFromText: function(text, locale) {
                return Number.fromLocaleString(locale, text)
            }
        }

        QQC2.SpinBox {
            id: fontSizeSpinBox
            Kirigami.FormData.label: i18n("Font size:")
            from: 6
            to: 72
            value: plasmoid.configuration.fontSize
        }

        QQC2.CheckBox {
            id: fontBoldCheckBox
            text: i18n("Bold font")
            checked: plasmoid.configuration.fontBold
        }

        QQC2.ComboBox {
            id: fontFamilyComboBox
            Kirigami.FormData.label: i18n("Font:")
            model: Qt.fontFamilies()
            currentIndex: model.indexOf(plasmoid.configuration.fontFamily) !== -1 ? model.indexOf(plasmoid.configuration.fontFamily) : 0
            onActivated: cfg_fontFamily = currentText
        }

        QQC2.SpinBox {
            id: updateIntervalSpinBox
            Kirigami.FormData.label: i18n("Update interval (ms):")
            from: 500
            to: 60000
            stepSize: 500
            value: plasmoid.configuration.updateInterval
        }
    }
}
