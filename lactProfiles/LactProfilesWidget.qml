import QtQuick
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// Lists LACT profiles from /etc/lact/config.yaml and applies one with
// `sudo -n lact-apply <name>` (NOPASSWD rule in /etc/sudoers.d/lact-apply).
PluginComponent {
    id: root

    property var profiles: []
    property var caps: ({})   // profile -> [3090 W, RX 580 W]
    property string current: "base"
    property string busyProfile: ""
    property string lastResult: ""

    function refresh() { listProc.running = true; capsProc.running = true }
    function apply(name) {
        if (busyProfile !== "") return
        busyProfile = name
        lastResult = "Applying " + name + "..."
        applyProc.command = ["sudo", "-n", "/usr/local/bin/lact-apply", name]
        applyProc.running = true
    }
    function label(name) { return name === "base" ? "Default" : name }
    function capText(name) {
        const c = caps[name]
        if (!c) return ""
        const w = v => v === "-" ? "stock" : v + " W"
        return "3090 " + w(c[0]) + "  ·  RX 580 " + w(c[1])
    }

    Component.onCompleted: refresh()

    Process {
        id: listProc
        command: ["/usr/local/bin/lact-apply", "--list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.length > 0)
                const cur = lines.find(l => l.startsWith("current_profile:"))
                root.current = cur ? cur.replace("current_profile:", "").trim() : "base"
                root.profiles = ["base"].concat(lines.filter(l => !l.startsWith("current_profile:") && l !== "base (no profile)"))
            }
        }
    }

    Process {
        id: capsProc
        command: ["/usr/local/bin/lact-apply", "--caps"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {}
                text.split("\n").filter(l => l.length > 0).forEach(l => {
                    const f = l.split("\t")
                    m[f[0]] = [f[1], f[2]]
                })
                root.caps = m
            }
        }
    }

    Process {
        id: applyProc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                root.lastResult = lines[lines.length - 1] || ""
            }
        }
        onExited: code => {
            if (code !== 0 && root.lastResult.startsWith("Applying")) root.lastResult = "Failed (exit " + code + ")"
            root.busyProfile = ""
            root.refresh()
        }
    }

    horizontalBarPill: Row {
        spacing: Theme.spacingXS
        DankIcon {
            name: "bolt"
            size: Theme.iconSize - 6
            color: root.busyProfile !== "" ? Theme.primary : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
        StyledText {
            text: root.label(root.current)
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    verticalBarPill: Column {
        spacing: Theme.spacingXS
        DankIcon {
            name: "bolt"
            size: Theme.iconSize - 6
            color: root.busyProfile !== "" ? Theme.primary : Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    popoutContent: Component {
        Column {
            spacing: Theme.spacingS
            width: parent ? parent.width : 280

            StyledText {
                text: "GPU power profile"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                leftPadding: Theme.spacingM
                topPadding: Theme.spacingM
            }

            // Same control as the DMS battery popout's power-profile selector
            Item {
                width: parent.width
                height: profileGroup.height * profileGroup.scale

                DankButtonGroup {
                    id: profileGroup
                    size: "small"
                    scale: Math.min(1, (parent.width - Theme.spacingM * 2) / implicitWidth)
                    transformOrigin: Item.Center
                    anchors.horizontalCenter: parent.horizontalCenter
                    model: root.profiles.map(p => root.label(p))
                    currentIndex: root.profiles.indexOf(root.busyProfile !== "" ? root.busyProfile : root.current)
                    selectionMode: "single"
                    enabled: root.busyProfile === ""
                    onSelectionChanged: (index, selected) => {
                        if (selected && root.profiles[index] !== root.current)
                            root.apply(root.profiles[index])
                    }
                }
            }

            // Power limits per profile; current one highlighted
            Column {
                width: parent.width - Theme.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2

                Repeater {
                    model: root.profiles
                    Item {
                        required property string modelData
                        readonly property bool active: modelData === root.current
                        width: parent.width
                        height: nameText.implicitHeight
                        StyledText {
                            id: nameText
                            text: root.label(modelData)
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: active ? Font.Medium : Font.Normal
                            color: active ? Theme.primary : Theme.surfaceText
                        }
                        StyledText {
                            anchors.right: parent.right
                            text: root.capText(modelData)
                            font.pixelSize: Theme.fontSizeSmall
                            color: active ? Theme.primary : Theme.surfaceVariantText
                        }
                    }
                }
            }

            StyledText {
                text: root.lastResult
                visible: root.lastResult !== ""
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width - Theme.spacingM * 2
                leftPadding: Theme.spacingM
                bottomPadding: Theme.spacingM
            }
        }
    }

    popoutWidth: 520
    popoutHeight: 130 + profiles.length * 20
}
