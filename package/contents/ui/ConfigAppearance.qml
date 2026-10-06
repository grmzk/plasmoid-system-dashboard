import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property alias cfg_backgroundOpacity: opacitySlider.value

    Kirigami.FormLayout {
        RowLayout {
            Kirigami.FormData.label: i18n("Background opacity:")

            QQC2.Slider {
                id: opacitySlider
                Layout.preferredWidth: implicitWidth * 2
                from: 0
                to: 100
                stepSize: 1
            }

            QQC2.Label {
                text: Math.round(opacitySlider.value) + "%"
            }
        }
    }
}
