import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    width: 450
    height: 900
    Layout.minimumWidth: 450
    Layout.minimumHeight: 900
    Layout.maximumWidth: 450
    Layout.maximumHeight: 900
    readonly property real hostsColumnSpacing: 18
    readonly property real hostsColumnWidth: Math.max(
        0, (width - 14 * 2 - hostsColumnSpacing * 2) / 3
    )
    property var snapshot: ({})
    readonly property string collectorCommand:
        "/usr/bin/python3 "
        + decodeURIComponent(Qt.resolvedUrl("../code/collector.py").toString()
                             .replace("file://", ""))

    Rectangle {
        anchors.fill: parent
        z: -1
        color: Qt.rgba(
            Kirigami.Theme.backgroundColor.r,
            Kirigami.Theme.backgroundColor.g,
            Kirigami.Theme.backgroundColor.b,
            0.8
        )
    }

    Plasma5Support.DataSource {
        id: collector
        engine: "executable"
        interval: 1000
        connectedSources: [root.collectorCommand]

        onNewData: function(sourceName, data) {
            if (sourceName !== root.collectorCommand || !data["stdout"]) {
                return
            }
            try {
                root.snapshot = JSON.parse(data["stdout"])
            } catch (error) {
                console.warn("Dashboard collector returned invalid JSON", error)
            }
        }
    }

    Sensors.Sensor {
        id: cpuSensor
        sensorId: "cpu/all/usage"
        updateRateLimit: 1000
    }

    Sensors.Sensor {
        id: memoryUsedSensor
        sensorId: "memory/physical/used"
        updateRateLimit: 1000
    }

    Sensors.Sensor {
        id: memoryTotalSensor
        sensorId: "memory/physical/total"
        updateRateLimit: 1000
    }

    Sensors.Sensor {
        id: swapUsedSensor
        sensorId: "memory/swap/used"
        updateRateLimit: 1000
    }

    Sensors.Sensor {
        id: swapTotalSensor
        sensorId: "memory/swap/total"
        updateRateLimit: 1000
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 14
        anchors.bottomMargin: 14
        spacing: 9

        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                spacing: 1

                Text {
                    text: "SYSTEM DASHBOARD"
                    color: Kirigami.Theme.textColor
                    font.bold: true
                    font.pixelSize: 14
                }

                Text {
                    text: Qt.formatDate(new Date(), "ddd, dd MMM yyyy")
                    color: Kirigami.Theme.textColor
                    font.pixelSize: 12
                }
            }

            Item { Layout.fillWidth: true }

            ColumnLayout {
                spacing: 0
                Layout.preferredWidth: 140

                Text {
                    id: clock
                    color: Kirigami.Theme.textColor
                    font.family: Qt.fontFamilies().indexOf("Digital Dismay") >= 0
                        ? "Digital Dismay"
                        : "monospace"
                    font.pixelSize: 28
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: Qt.formatTime(new Date(), "HH:mm:ss")

                    Timer {
                        interval: 1000
                        repeat: true
                        running: true
                        onTriggered: clock.text = Qt.formatTime(new Date(), "HH:mm:ss")
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "UPTIME"
                        color: Kirigami.Theme.textColor
                        font.family: "monospace"
                        font.bold: true
                        font.pixelSize: 11
                    }

                    TextMetrics {
                        id: uptimeMetrics
                        font.family: "monospace"
                        font.pixelSize: 11
                        text: "99d 23h 59m 59s"
                    }

                    Text {
                        text: root.formatUptime(root.snapshot.uptime_seconds || 0)
                        color: Kirigami.Theme.textColor
                        font.family: "monospace"
                        font.pixelSize: 11
                        Layout.minimumWidth: uptimeMetrics.width
                        Layout.preferredWidth: uptimeMetrics.width
                        Layout.maximumWidth: uptimeMetrics.width
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
                    color: Kirigami.Theme.textColor
            opacity: 0.35
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "CPU"
                    color: Kirigami.Theme.textColor
                    font.bold: true
                    font.pixelSize: 13
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "LOAD"
                        color: Kirigami.Theme.textColor
                        font.bold: true
                        font.family: "monospace"
                        font.pixelSize: 11
                    }

                    Text {
                        text: (root.snapshot.load_average || ["—", "—", "—"]).join("  ")
                        color: Kirigami.Theme.textColor
                        font.family: "monospace"
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Item { Layout.fillWidth: true }
                }

                RowLayout {
                    Layout.preferredWidth: 88
                    spacing: 14

                    Text {
                        text: "TEMP"
                        color: Kirigami.Theme.textColor
                        font.bold: true
                        font.family: "monospace"
                        font.pixelSize: 11
                    }

                    Text {
                        text: root.externalValue("cpu_temp_packageid0")
                        color: Kirigami.Theme.textColor
                        font.family: "monospace"
                        font.pixelSize: 11
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideLeft
                    }
                }

                Text {
                    text: cpuSensor.status === Sensors.Sensor.Ready
                        ? cpuSensor.formattedValue
                        : "—"
                    color: Kirigami.Theme.highlightColor
                    font.bold: true
                    font.pixelSize: 13
                    Layout.preferredWidth: 56
                    horizontalAlignment: Text.AlignRight
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 5
                radius: 2
                color: Qt.rgba(
                    Kirigami.Theme.textColor.r,
                    Kirigami.Theme.textColor.g,
                    Kirigami.Theme.textColor.b,
                    0.25
                )

                Rectangle {
                    width: parent.width * (cpuSensor.value || 0) / 100
                    height: parent.height
                    radius: parent.radius
                    color: Kirigami.Theme.highlightColor
                    opacity: 0.9
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: 4
                columnSpacing: 8

                Repeater {
                    model: 8

                    delegate: ColumnLayout {
                        id: coreDelegate
                        required property int index
                        Layout.fillWidth: true
                        spacing: 2

                        Sensors.Sensor {
                            id: coreSensor
                            sensorId: "cpu/cpu" + coreDelegate.index + "/usage"
                            updateRateLimit: 1000
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "CPU" + coreDelegate.index
                                color: Kirigami.Theme.textColor
                                font.bold: true
                                font.family: "monospace"
                                font.pixelSize: 11
                                Layout.preferredWidth: 40
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: coreSensor.status === Sensors.Sensor.Ready
                                    ? Math.round(coreSensor.value) + "%"
                                    : "—"
                                color: Kirigami.Theme.textColor
                                font.pixelSize: 11
                                Layout.preferredWidth: 42
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 3
                            radius: 1
                            color: Qt.rgba(
                                Kirigami.Theme.textColor.r,
                                Kirigami.Theme.textColor.g,
                                Kirigami.Theme.textColor.b,
                                0.25
                            )

                            Rectangle {
                                width: parent.width * (coreSensor.value || 0) / 100
                                height: parent.height
                                radius: parent.radius
                                color: Kirigami.Theme.highlightColor
                                opacity: 0.9
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.row: 2
                    Layout.column: 0
                    Layout.fillWidth: true

                    Text {
                        text: "FAN"
                        color: Kirigami.Theme.textColor
                        font.bold: true
                        font.family: "monospace"
                        font.pixelSize: 11
                        Layout.preferredWidth: 36
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.externalValue("cpu_fan")
                        color: Kirigami.Theme.textColor
                        font.family: "monospace"
                        font.pixelSize: 11
                        Layout.preferredWidth: 42
                        horizontalAlignment: Text.AlignRight
                    }
                }

                RowLayout {
                    Layout.row: 2
                    Layout.column: 1
                    Layout.columnSpan: 3
                    Layout.fillWidth: true

                    Repeater {
                        model: [
                            { label: "core0", value: root.externalValue("cpu_temp_core0") },
                            { label: "core1", value: root.externalValue("cpu_temp_core1") },
                            { label: "core2", value: root.externalValue("cpu_temp_core2") },
                            { label: "core3", value: root.externalValue("cpu_temp_core3") },
                        ].filter(core => core.value !== "—")

                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: modelData.label
                                color: Kirigami.Theme.textColor
                                font.bold: true
                                font.family: "monospace"
                                font.pixelSize: 11
                            }

                            Text {
                                text: modelData.value
                                color: Kirigami.Theme.textColor
                                font.family: "monospace"
                                font.pixelSize: 11
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Kirigami.Theme.textColor
            opacity: 0.35
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: Boolean(root.snapshot.external && root.snapshot.external.gpu_model)

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "GPU"
                    color: Kirigami.Theme.textColor
                    font.bold: true
                    font.pixelSize: 13
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "POWER"
                        color: Kirigami.Theme.textColor
                        font.bold: true
                        font.family: "monospace"
                        font.pixelSize: 11
                    }

                    Text {
                        text: root.externalValue("gpu_power_ppt")
                        color: Kirigami.Theme.textColor
                        font.family: "monospace"
                        font.pixelSize: 11
                        Layout.preferredWidth: 56
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideRight
                    }

                    Item { Layout.fillWidth: true }
                }

                Text {
                    text: root.snapshot.external?.gpu_model || ""
                    color: Kirigami.Theme.textColor
                    font.family: "monospace"
                    font.bold: true
                    font.pixelSize: 11
                    Layout.preferredWidth: 220
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: "GPU"
                    color: Kirigami.Theme.textColor
                    font.bold: true
                    font.family: "monospace"
                    font.pixelSize: 11
                    Layout.preferredWidth: 38
                }

                Item { Layout.preferredWidth: 6 }

                ProgressTrack { ratio: root.percentRatio("gpu_busy_percent") }

                Item { Layout.preferredWidth: 6 }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    columnSpacing: 2

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 54
                        Layout.preferredWidth: 54
                        text: root.externalValue("gpu_freq_sclk")
                        color: Kirigami.Theme.textColor
                        font.family: "monospace"
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 54
                        Layout.preferredWidth: 54
                        text: root.externalValue("gpu_freq_sclk_max")
                        color: Kirigami.Theme.textColor
                        font.family: "monospace"
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 34
                        Layout.preferredWidth: 34
                        text: root.externalValue("gpu_temp_edge")
                        color: Kirigami.Theme.textColor
                        font.family: "monospace"
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 27
                        Layout.preferredWidth: 27
                        text: root.externalValue("gpu_busy_percent")
                        color: Kirigami.Theme.highlightColor
                        font.family: "monospace"
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: "VRAM"
                    color: Kirigami.Theme.textColor
                    font.bold: true
                    font.family: "monospace"
                    font.pixelSize: 11
                    Layout.preferredWidth: 38
                }

                Item { Layout.preferredWidth: 6 }

                ProgressTrack { ratio: root.vramRatio() }

                Item { Layout.preferredWidth: 6 }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    columnSpacing: 2

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 54
                        Layout.preferredWidth: 54
                        text: root.formatExternalGiB("gpu_vram_used")
                        color: Kirigami.Theme.textColor
                        font.family: "monospace"
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 54
                        Layout.preferredWidth: 54
                        text: root.formatExternalGiB("gpu_vram_total")
                        color: Kirigami.Theme.textColor
                        font.family: "monospace"
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 34
                        Layout.preferredWidth: 34
                        text: root.externalValue("gpu_temp_mem")
                        color: Kirigami.Theme.textColor
                        font.family: "monospace"
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 27
                        Layout.preferredWidth: 27
                        text: Math.round(root.vramRatio() * 100) + "%"
                        color: Kirigami.Theme.highlightColor
                        font.family: "monospace"
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 1
                        Layout.row: 0
                        Layout.column: 2
                        Layout.minimumWidth: 0

                Text {
                    text: "FAN"
                    color: Kirigami.Theme.textColor
                    font.bold: true
                    font.family: "monospace"
                    font.pixelSize: 11
                    Layout.preferredWidth: 38
                }

                Item { Layout.preferredWidth: 6 }

                ProgressTrack { ratio: root.percentRatio("gpu_fan") }

                Item { Layout.preferredWidth: 6 }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    columnSpacing: 2

                    Item { Layout.fillWidth: true; Layout.minimumWidth: 54; Layout.preferredWidth: 54 }
                    Item { Layout.fillWidth: true; Layout.minimumWidth: 54; Layout.preferredWidth: 54 }
                    Item { Layout.fillWidth: true; Layout.minimumWidth: 34; Layout.preferredWidth: 34 }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 27
                        Layout.preferredWidth: 27
                        text: root.externalValue("gpu_fan")
                        color: Kirigami.Theme.highlightColor
                        font.family: "monospace"
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Kirigami.Theme.textColor
            opacity: 0.35
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

            SensorMeter {
                Layout.fillWidth: true
                label: "RAM"
                sensor: memoryUsedSensor
                totalSensor: memoryTotalSensor
            }

            SensorMeter {
                Layout.fillWidth: true
                label: "SWAP"
                sensor: swapUsedSensor
                totalSensor: swapTotalSensor
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Kirigami.Theme.textColor
            opacity: 0.35
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "FILESYSTEMS"
                    color: Kirigami.Theme.textColor
                    font.bold: true
                    font.pixelSize: 13
                    Layout.preferredWidth: 88
                }

                GridLayout {
                    id: filesystemMetrics
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 12
                    readonly property real usableWidth: Math.max(0, root.width - 142)
                    readonly property real currentTempColumnWidth: Math.max(
                        0, (root.width - 126) * 2 / 12 * 1.3
                    )
                    readonly property real tempColumnWidth: Math.max(
                        0, currentTempColumnWidth
                    )
                    readonly property real readWriteColumnWidth: Math.max(
                        0, (usableWidth - currentTempColumnWidth) / 2
                    )

                    RowLayout {
                        Layout.row: 0
                        Layout.column: 0
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: filesystemMetrics.readWriteColumnWidth
                        Layout.maximumWidth: filesystemMetrics.readWriteColumnWidth

                        Text {
                            text: "READ"
                            color: Kirigami.Theme.textColor
                            font.bold: true
                            font.family: "monospace"
                            font.pixelSize: 11
                            Layout.preferredWidth: 28
                        }

                        Text {
                            text: root.formatRate(
                                root.snapshot.nvme_rates?.read_rate || 0
                            )
                            color: Kirigami.Theme.textColor
                            font.family: "monospace"
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideLeft
                        }
                    }

                    RowLayout {
                        Layout.row: 0
                        Layout.column: 1
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: filesystemMetrics.readWriteColumnWidth
                        Layout.maximumWidth: filesystemMetrics.readWriteColumnWidth

                        Text {
                            text: "WRITE"
                            color: Kirigami.Theme.textColor
                            font.bold: true
                            font.family: "monospace"
                            font.pixelSize: 11
                            Layout.preferredWidth: 34
                        }

                        Text {
                            text: root.formatRate(
                                root.snapshot.nvme_rates?.write_rate || 0
                            )
                            color: Kirigami.Theme.textColor
                            font.family: "monospace"
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideLeft
                        }
                    }

                    RowLayout {
                        Layout.row: 0
                        Layout.column: 2
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: filesystemMetrics.tempColumnWidth
                        Layout.maximumWidth: filesystemMetrics.tempColumnWidth

                        Text {
                            text: "TEMP"
                            color: Kirigami.Theme.textColor
                            font.bold: true
                            font.family: "monospace"
                            font.pixelSize: 11
                            Layout.preferredWidth: 28
                        }

                        Text {
                            text: root.externalValue("nvme_temp_composite")
                            color: Kirigami.Theme.textColor
                            font.family: "monospace"
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideLeft
                        }
                    }
                }
            }

            Repeater {
                model: root.snapshot.filesystems || []

                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: modelData.mount
                        color: Kirigami.Theme.textColor
                        font.bold: true
                        font.family: "monospace"
                        font.pixelSize: 11
                        Layout.preferredWidth: 38
                    }

                    Item {
                        Layout.preferredWidth: 6
                        Layout.minimumWidth: 6
                        Layout.maximumWidth: 6
                    }

                    ProgressTrack {
                        ratio: Math.max(0, Math.min(1, modelData.percent / 100))
                    }

                    Item {
                        Layout.preferredWidth: 6
                        Layout.minimumWidth: 6
                        Layout.maximumWidth: 6
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: root.formatGiB(modelData.used)
                            color: Kirigami.Theme.textColor
                            font.family: "monospace"
                            font.pixelSize: 11
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 54
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideLeft
                        }

                        Item {
                            Layout.preferredWidth: 6
                            Layout.minimumWidth: 6
                            Layout.maximumWidth: 6
                        }

                        Text {
                            text: root.formatGiB(modelData.total)
                            color: Kirigami.Theme.textColor
                            font.family: "monospace"
                            font.pixelSize: 11
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 54
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideLeft
                        }

                        Text {
                            text: modelData.percent + "%"
                            color: Kirigami.Theme.highlightColor
                            font.pixelSize: 11
                            Layout.minimumWidth: 40
                            Layout.preferredWidth: 40
                            Layout.maximumWidth: 40
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Kirigami.Theme.textColor
            opacity: 0.35
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "NETWORK"
                    color: Kirigami.Theme.textColor
                    font.bold: true
                    font.pixelSize: 13
                    Layout.preferredWidth: 88
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "IP"
                            color: Kirigami.Theme.textColor
                            font.bold: true
                            font.family: "monospace"
                            font.pixelSize: 11
                            Layout.preferredWidth: 14
                        }

                        Text {
                            text: root.snapshot.network_route?.ip || "—"
                            color: Kirigami.Theme.textColor
                            font.family: "monospace"
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignLeft
                            elide: Text.ElideLeft
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "GATEWAY"
                            color: Kirigami.Theme.textColor
                            font.bold: true
                            font.family: "monospace"
                            font.pixelSize: 11
                            Layout.preferredWidth: 48
                        }

                        Text {
                            text: root.snapshot.network_route?.gateway || "—"
                            color: Kirigami.Theme.textColor
                            font.family: "monospace"
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignLeft
                            elide: Text.ElideLeft
                        }
                    }
                }
            }

            Repeater {
                model: root.snapshot.interfaces || []

                delegate: GridLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    columns: 6
                    columnSpacing: 3

                    Text {
                        text: modelData.name
                        color: modelData.state === "up"
                            ? Kirigami.Theme.textColor
                            : Kirigami.Theme.disabledTextColor
                        font.bold: true
                        font.family: "monospace"
                        font.pixelSize: 11
                        Layout.minimumWidth: 48
                        Layout.preferredWidth: 70
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.minimumWidth: 40
                        Layout.preferredWidth: 40
                        Layout.maximumWidth: 40
                        spacing: 0

                        Text {
                            text: modelData.state
                            color: modelData.state === "up"
                                ? Kirigami.Theme.textColor
                                : Kirigami.Theme.disabledTextColor
                            font.family: "monospace"
                            font.pixelSize: 11
                            Layout.minimumWidth: 27
                            Layout.preferredWidth: 27
                            Layout.maximumWidth: 27
                            horizontalAlignment: Text.AlignRight
                        }

                        Item {
                            Layout.minimumWidth: 13
                            Layout.preferredWidth: 13
                            Layout.maximumWidth: 13
                        }
                    }

                    RowLayout {
                        Layout.minimumWidth: 40
                        Layout.preferredWidth: 40
                        Layout.maximumWidth: 40
                        spacing: 0

                        Text {
                            text: modelData.state === "up"
                                && modelData.signal_percent !== null
                                && modelData.signal_percent !== undefined
                                ? modelData.signal_percent + "%"
                                : "---"
                            color: modelData.state === "up"
                                ? Kirigami.Theme.textColor
                                : Kirigami.Theme.disabledTextColor
                            font.family: "monospace"
                            font.pixelSize: 11
                            Layout.minimumWidth: 27
                            Layout.preferredWidth: 27
                            Layout.maximumWidth: 27
                            horizontalAlignment: Text.AlignRight
                        }

                        Item {
                            Layout.minimumWidth: 13
                            Layout.preferredWidth: 13
                            Layout.maximumWidth: 13
                        }
                    }

                    Text {
                        text: modelData.state === "up"
                            && modelData.technology
                            && modelData.technology !== "—"
                            ? modelData.technology
                            : "---"
                        color: modelData.state === "up"
                            ? Kirigami.Theme.textColor
                            : Kirigami.Theme.disabledTextColor
                        font.family: "monospace"
                        font.pixelSize: 11
                        Layout.minimumWidth: 34
                        Layout.preferredWidth: 55
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.minimumWidth: 62
                        Layout.preferredWidth: 100
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: root.formatRate(modelData.transmit_rate)
                            color: modelData.state === "up"
                                ? Kirigami.Theme.textColor
                                : Kirigami.Theme.disabledTextColor
                            font.family: "monospace"
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideLeft
                        }

                        Text {
                            text: "↑"
                            color: modelData.state === "up"
                                ? Kirigami.Theme.textColor
                                : Kirigami.Theme.disabledTextColor
                            font.family: "monospace"
                            font.pixelSize: 16
                            Layout.preferredWidth: 12
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    RowLayout {
                        Layout.minimumWidth: 62
                        Layout.preferredWidth: 100
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: root.formatRate(modelData.receive_rate)
                            color: modelData.state === "up"
                                ? Kirigami.Theme.textColor
                                : Kirigami.Theme.disabledTextColor
                            font.family: "monospace"
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideLeft
                        }

                        Text {
                            text: "↓"
                            color: modelData.state === "up"
                                ? Kirigami.Theme.textColor
                                : Kirigami.Theme.disabledTextColor
                            font.family: "monospace"
                            font.pixelSize: 16
                            Layout.preferredWidth: 12
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Kirigami.Theme.textColor
            opacity: 0.35
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: Boolean(root.snapshot.external)

            SectionTitle {
                title: "HOSTS"
                font.pixelSize: 13
            }

            GridLayout {
                id: hostsGrid
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 2
                columnSpacing: root.hostsColumnSpacing

                Repeater {
                    model: [
                        { label: "m4nb", fixedValue: "on", updates: "host_m4nb_updates" },
                        { label: "bsmp1-ord", status: "host_bsmp1-ord_status" },
                        { label: "fampc", status: "host_fampc_status", updates: "host_famnb_updates" },
                        { label: "m4vps-msk", status: "host_m4vps-msk_status", updates: "host_m4vps-msk_updates" },
                        { label: "bsmp1-pit", status: "host_bsmp1-pit_status" },
                        { label: "rel-nb", status: "host_relnb_status" },
                        { label: "m4vps-de", status: "host_m4vps-de_status", updates: "host_m4vps-de_updates" },
                        { label: "bsmp1-ad", status: "host_bsmp1-ad_status" },
                        { label: "rel-phone", status: "host_relphn_status" },
                        { label: "m4wrt", status: "host_m4wrt_status" },
                        { label: "bsmp1-rean", status: "host_bsmp1-reanzal_status" },
                        { label: "m4phone", status: "host_m4phn_status" },
                    ]

                    delegate: RowLayout {
                        id: hostDelegate
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.minimumWidth: root.hostsColumnWidth
                        Layout.preferredWidth: root.hostsColumnWidth
                        Layout.maximumWidth: root.hostsColumnWidth
                        spacing: 0

                        Text {
                            text: hostDelegate.modelData.label
                            color: Kirigami.Theme.textColor
                            font.bold: true
                            font.family: "monospace"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.minimumWidth: 68
                            Layout.preferredWidth: 68
                            Layout.maximumWidth: 68
                        }

                        Item { Layout.preferredWidth: 8 }

                        Text {
                            text: hostDelegate.modelData.fixedValue
                                || root.externalValue(hostDelegate.modelData.status)
                            color: Kirigami.Theme.textColor
                            font.family: "monospace"
                            font.pixelSize: 11
                            Layout.minimumWidth: 24
                            Layout.preferredWidth: 24
                            Layout.maximumWidth: 24
                            horizontalAlignment: Text.AlignRight
                        }

                        Item { Layout.preferredWidth: 4 }

                        Text {
                            text: hostDelegate.modelData.updates
                                ? "[" + root.externalValue(
                                    hostDelegate.modelData.updates
                                ) + "]"
                                : ""
                            color: Kirigami.Theme.textColor
                            font.family: "monospace"
                            font.pixelSize: 11
                            Layout.preferredWidth: 28
                            horizontalAlignment: Text.AlignLeft
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Kirigami.Theme.textColor
            opacity: 0.35
        }

        ColumnLayout {
            id: processUsageSection
            Layout.fillWidth: true
            spacing: 4

            SectionTitle {
                title: "TOP CPU / MEMORY"
                font.pixelSize: 13
            }

            readonly property real percentColumnWidth: Math.max(
                cpuPercentMetrics.width, memoryPercentMetrics.width
            )
            readonly property real tableColumnWidth: Math.max(
                0, (width - 24) / 2
            )

            TextMetrics {
                id: cpuPercentMetrics
                font.family: "monospace"
                font.pixelSize: 10
                text: (root.snapshot.cpu_count || 1) + "00.0%"
            }

            TextMetrics {
                id: memoryPercentMetrics
                font.family: "monospace"
                font.pixelSize: 10
                text: "100.0%"
            }

            GridLayout {
                id: processTablesGrid
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 24
                rowSpacing: 2

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: processUsageSection.tableColumnWidth
                    Layout.preferredWidth: processUsageSection.tableColumnWidth
                    Layout.maximumWidth: processUsageSection.tableColumnWidth
                    spacing: 2

                    Text {
                        text: "CPU %"
                        color: Kirigami.Theme.textColor
                        font.bold: true
                        font.pixelSize: 10
                    }

                    Repeater {
                        model: root.snapshot.top_cpu || []

                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: modelData.name
                                color: Kirigami.Theme.textColor
                                font.family: "monospace"
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.minimumWidth: 0
                                Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.cpu + "%"
                                color: Kirigami.Theme.textColor
                                font.family: "monospace"
                                font.pixelSize: 10
                                Layout.minimumWidth: processUsageSection.percentColumnWidth
                                Layout.preferredWidth: processUsageSection.percentColumnWidth
                                Layout.maximumWidth: processUsageSection.percentColumnWidth
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: processUsageSection.tableColumnWidth
                    Layout.preferredWidth: processUsageSection.tableColumnWidth
                    Layout.maximumWidth: processUsageSection.tableColumnWidth
                    spacing: 2

                    Text {
                        text: "MEM %"
                        color: Kirigami.Theme.textColor
                        font.bold: true
                        font.pixelSize: 10
                    }

                    Repeater {
                        model: root.snapshot.top_memory || []

                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: modelData.name
                                color: Kirigami.Theme.textColor
                                font.family: "monospace"
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.minimumWidth: 0
                                Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.memory + "%"
                                color: Kirigami.Theme.textColor
                                font.family: "monospace"
                                font.pixelSize: 10
                                Layout.minimumWidth: processUsageSection.percentColumnWidth
                                Layout.preferredWidth: processUsageSection.percentColumnWidth
                                Layout.maximumWidth: processUsageSection.percentColumnWidth
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Kirigami.Theme.textColor
            opacity: 0.35
        }

        ColumnLayout {
            id: batterySection
            Layout.fillWidth: true
            spacing: 4
            readonly property real chargeTrackWidth: Math.max(
                60, Math.min(188, (root.width - 298) * 1.25)
            )

            RowLayout {
                id: batteryRow
                Layout.fillWidth: true
                spacing: 3
                readonly property real metricColumnWidth: Math.max(
                    0, (root.width - 28 - 54 - spacing * 3) / 3
                )
                readonly property real batteryEtaColumnWidth: Math.max(
                    0, metricColumnWidth - 21
                )

                Text {
                    text: "BATTERY"
                    color: Kirigami.Theme.textColor
                    font.bold: true
                    font.pixelSize: 13
                    Layout.minimumWidth: 54
                    Layout.preferredWidth: 54
                    Layout.maximumWidth: 54
                }

                Item { Layout.preferredWidth: 21 }

                RowLayout {
                    Layout.minimumWidth: batteryRow.metricColumnWidth
                    Layout.preferredWidth: batteryRow.metricColumnWidth
                    Layout.maximumWidth: batteryRow.metricColumnWidth
                    spacing: 12

                    TextMetrics {
                        id: powerLabelMetrics
                        font.bold: true
                        font.family: "monospace"
                        font.pixelSize: 11
                        text: "POWER"
                    }

                    Text {
                        text: "POWER"
                        visible: root.formatBatteryPower(
                            root.snapshot.battery?.power_w
                        ) !== ""
                        color: Kirigami.Theme.textColor
                        font.bold: true
                        font.family: "monospace"
                        font.pixelSize: 11
                        Layout.minimumWidth: powerLabelMetrics.width
                        Layout.preferredWidth: powerLabelMetrics.width
                        Layout.maximumWidth: powerLabelMetrics.width
                    }

                    Text {
                        text: root.formatBatteryPower(
                            root.snapshot.battery?.power_w
                        )
                        color: Kirigami.Theme.textColor
                        font.family: "monospace"
                        font.pixelSize: 11
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideLeft
                    }
                }

                Text {
                    text: root.snapshot.battery?.status || ""
                    color: Kirigami.Theme.textColor
                    font.family: "monospace"
                    font.pixelSize: 11
                    Layout.minimumWidth: batteryRow.metricColumnWidth
                    Layout.preferredWidth: batteryRow.metricColumnWidth
                    Layout.maximumWidth: batteryRow.metricColumnWidth
                    elide: Text.ElideRight
                }

                Text {
                    text: root.formatBatteryEta(root.snapshot.battery)
                    color: Kirigami.Theme.textColor
                    font.family: "monospace"
                    font.pixelSize: 11
                    Layout.minimumWidth: batteryRow.batteryEtaColumnWidth
                    Layout.preferredWidth: batteryRow.batteryEtaColumnWidth
                    Layout.maximumWidth: batteryRow.batteryEtaColumnWidth
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                }
            }

            Repeater {
                model: root.snapshot.batteries || []

                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: modelData.name
                        color: Kirigami.Theme.textColor
                        font.bold: true
                        font.family: "monospace"
                        font.pixelSize: 11
                        Layout.minimumWidth: 44
                        Layout.preferredWidth: 44
                        Layout.maximumWidth: 44
                    }

                    Item {
                        Layout.preferredWidth: 6
                        Layout.minimumWidth: 6
                        Layout.maximumWidth: 6
                    }

                    ProgressTrack {
                        ratio: Math.max(
                            0, Math.min(1, (modelData.capacity || 0) / 100)
                        )
                        Layout.minimumWidth: batterySection.chargeTrackWidth
                        Layout.preferredWidth: batterySection.chargeTrackWidth
                        Layout.maximumWidth: batterySection.chargeTrackWidth
                    }

                    Item {
                        Layout.preferredWidth: 6
                        Layout.minimumWidth: 6
                        Layout.maximumWidth: 6
                    }

                    Text {
                        text: modelData.energy_wh !== null
                            && modelData.energy_wh !== undefined
                            ? Number(modelData.energy_wh).toFixed(1) + " Wh"
                            : ""
                        color: Kirigami.Theme.textColor
                        font.family: "monospace"
                        font.pixelSize: 11
                        Layout.minimumWidth: 52
                        Layout.preferredWidth: 52
                        Layout.maximumWidth: 52
                        horizontalAlignment: Text.AlignRight
                    }

                    Item {
                        Layout.preferredWidth: 24
                        Layout.minimumWidth: 24
                        Layout.maximumWidth: 24
                    }

                    RowLayout {
                        Layout.minimumWidth: 58
                        Layout.preferredWidth: 58
                        Layout.maximumWidth: 58
                        spacing: 2

                        Text {
                            text: "Health"
                            color: Kirigami.Theme.textColor
                            font.bold: true
                            font.family: "monospace"
                            font.pixelSize: 11
                            Layout.preferredWidth: 32
                            horizontalAlignment: Text.AlignRight
                        }

                        Text {
                            text: modelData.energy_full_wh !== null
                                && modelData.energy_full_wh !== undefined
                                && modelData.energy_full_design_wh > 0
                                ? (modelData.energy_full_wh
                                   / modelData.energy_full_design_wh * 100).toFixed(0) + "%"
                                : ""
                            color: Kirigami.Theme.textColor
                            font.family: "monospace"
                            font.pixelSize: 11
                            Layout.minimumWidth: 24
                            Layout.preferredWidth: 24
                            Layout.maximumWidth: 24
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                    }

                    Text {
                        text: modelData.capacity !== null
                            && modelData.capacity !== undefined
                            ? modelData.capacity + "%"
                            : ""
                        color: Kirigami.Theme.highlightColor
                        font.family: "monospace"
                        font.pixelSize: 11
                        Layout.minimumWidth: 42
                        Layout.preferredWidth: 42
                        Layout.maximumWidth: 42
                        Layout.alignment: Qt.AlignRight
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Text {
            Layout.fillWidth: true
            text: "Plasma 6 · live sensors"
            color: Kirigami.Theme.textColor
            font.pixelSize: 11
            horizontalAlignment: Text.AlignRight
        }
    }

    component SensorMeter: RowLayout {
        id: meter
        required property string label
        required property var sensor
        required property var totalSensor
        spacing: 2

        readonly property real ratio: totalSensor.value > 0
            ? Math.max(0, Math.min(1, sensor.value / totalSensor.value))
            : 0

        Layout.fillWidth: true

        Text {
            text: label
            color: Kirigami.Theme.textColor
            font.bold: true
            font.pixelSize: 12
            Layout.preferredWidth: 38
        }

        Item {
            Layout.preferredWidth: 6
            Layout.minimumWidth: 6
            Layout.maximumWidth: 6
        }

        ProgressTrack { ratio: meter.ratio }

        Item {
            Layout.preferredWidth: 6
            Layout.minimumWidth: 6
            Layout.maximumWidth: 6
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: sensor.status === Sensors.Sensor.Ready
                    ? root.formatGiB(sensor.value)
                    : "Sensor unavailable"
                color: Kirigami.Theme.textColor
                font.family: "monospace"
                font.pixelSize: 12
                Layout.minimumWidth: 0
                Layout.preferredWidth: 54
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideLeft
            }

            Item {
                Layout.preferredWidth: 6
                Layout.minimumWidth: 6
                Layout.maximumWidth: 6
            }

            Text {
                text: totalSensor.status === Sensors.Sensor.Ready
                    ? root.formatGiB(totalSensor.value)
                    : "—"
                color: Kirigami.Theme.textColor
                font.family: "monospace"
                font.pixelSize: 12
                Layout.minimumWidth: 0
                Layout.preferredWidth: 54
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideLeft
            }

            Text {
                text: sensor.status === Sensors.Sensor.Ready
                    && totalSensor.value > 0
                    ? Math.round(sensor.value / totalSensor.value * 100) + "%"
                    : ""
                color: Kirigami.Theme.highlightColor
                font.bold: true
                font.pixelSize: 12
                Layout.minimumWidth: 40
                Layout.preferredWidth: 40
                Layout.maximumWidth: 40
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    component SectionTitle: Text {
        required property string title
        text: title
        color: Kirigami.Theme.textColor
        font.bold: true
        font.pixelSize: 11
        Layout.fillWidth: true
    }

    component ProgressTrack: Rectangle {
        id: progressTrack
        required property real ratio

        Layout.fillWidth: false
        Layout.minimumWidth: 60
        Layout.preferredWidth: Math.max(60, Math.min(188, (root.width - 298) * 1.25))
        Layout.maximumWidth: Math.max(60, Math.min(188, (root.width - 298) * 1.25))
        height: 5
        radius: 2
        color: Qt.rgba(
            Kirigami.Theme.textColor.r,
            Kirigami.Theme.textColor.g,
            Kirigami.Theme.textColor.b,
            0.25
        )

        Rectangle {
            width: parent.width * progressTrack.ratio
            height: parent.height
            radius: parent.radius
            color: Kirigami.Theme.highlightColor
            opacity: 0.9
        }
    }

    function externalValue(name) {
        return root.snapshot.external?.[name] || "—"
    }

    function percentRatio(name) {
        const percent = Number(root.externalValue(name).replace("%", "").trim())
        return Number.isFinite(percent)
            ? Math.max(0, Math.min(1, percent / 100))
            : 0
    }

    function sizeInBytes(value) {
        const match = String(value).trim().match(/^([\d.]+)\s*([kmgt]?i?b)?$/i)
        if (!match) {
            return 0
        }

        const multipliers = {
            b: 1,
            kb: 1000,
            mb: 1000 ** 2,
            gb: 1000 ** 3,
            tb: 1000 ** 4,
            kib: 1024,
            mib: 1024 ** 2,
            gib: 1024 ** 3,
            tib: 1024 ** 4,
        }
        return Number(match[1]) * (multipliers[(match[2] || "b").toLowerCase()] || 1)
    }

    function vramRatio() {
        const total = sizeInBytes(root.externalValue("gpu_vram_total"))
        return total > 0
            ? Math.max(0, Math.min(1, sizeInBytes(root.externalValue("gpu_vram_used")) / total))
            : 0
    }

    function formatExternalGiB(name) {
        const value = root.externalValue(name)
        return value === "—" ? value : root.formatGiB(sizeInBytes(value))
    }

    function formatUptime(seconds) {
        const days = Math.floor(seconds / 86400)
        const hours = Math.floor((seconds % 86400) / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        const remainingSeconds = Math.floor(seconds % 60)
        return days > 0
            ? days + "d " + hours + "h " + minutes + "m " + remainingSeconds + "s"
            : hours + "h " + minutes + "m " + remainingSeconds + "s"
    }

    function formatBatteryEta(battery) {
        if (!battery || !battery.status) {
            return ""
        }

        if (battery.status !== "Charging" && battery.status !== "Discharging") {
            return battery.status === "Full" ? "Full" : ""
        }

        const minutes = Number(battery.minutes_remaining)
        if (!Number.isFinite(minutes) || minutes <= 0) {
            return ""
        }

        const hours = Math.floor(minutes / 60)
        const remainingMinutes = minutes % 60
        const duration = hours > 0
            ? hours + "h " + remainingMinutes + "m"
            : minutes + "m"
        return duration + (battery.status === "Charging" ? " to full" : " to empty")
    }

    function formatBatteryPower(value) {
        const watts = Number(value)
        if (!Number.isFinite(watts) || Number(watts.toFixed(1)) === 0) {
            return ""
        }
        return watts.toFixed(1) + " W"
    }

    function formatGiB(bytes) {
        return (Number(bytes) / (1024 * 1024 * 1024)).toFixed(1) + " GiB"
    }

    function formatBytes(bytes) {
        const units = ["B", "KiB", "MiB", "GiB", "TiB"]
        let value = Number(bytes)
        let unit = 0
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024
            unit++
        }
        return value.toFixed(unit === 0 ? 0 : 1) + " " + units[unit]
    }

    function formatRate(bytesPerSecond) {
        return (Number(bytesPerSecond) / (1024 * 1024)).toFixed(1) + " MiB/s"
    }
}