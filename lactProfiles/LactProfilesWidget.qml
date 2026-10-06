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
    property var gpuLabels: []   // from lact-apply --caps (GPU0, GPU1, ... or /etc/lact-apply.conf)
    property var caps: ({})      // profile -> [W per GPU, "-" = stock]
    // Profile shown first (plugin setting); Default takes its place. "" keeps the LACT config order.
    property string firstProfile: (pluginData.firstProfile ?? "").trim()
    property string current: "base"
    property string busyProfile: ""
    property string lastResult: ""
    property bool scriptMissing: false
    readonly property string readme: "https://github.com/philipplinux/dms-lact-profiles-widget"

    function refresh() { listProc.running = true; capsProc.running = true }
    function apply(name) {
        if (busyProfile !== "") return
        busyProfile = name
        lastResult = "Applying " + name + "..."
        applyProc.command = ["sudo", "-n", "/usr/local/bin/lact-apply", name]
        applyProc.running = true
    }
    function label(name) { return name === "base" ? "Default" : name }
    // One cell per GPU plus a total (when there are 2+ GPUs and all caps are set)
    function capCells(name) {
        const c = caps[name]
        if (!c) return []
        const cells = c.map((v, i) => gpuLabels[i] + " " + (v === "-" ? "stock" : v + " W"))
        if (c.length > 1)
            cells.push(c.includes("-") ? "" : "total " + c.reduce((s, v) => s + Number(v), 0) + " W")
        return cells
    }

    Component.onCompleted: refresh()

    Process {
        id: listProc
        command: ["sh", "-c", "[ -x /usr/local/bin/lact-apply ] && exec /usr/local/bin/lact-apply --list || echo '#missing'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.length > 0)
                root.scriptMissing = lines[0] === "#missing"
                if (root.scriptMissing) {
                    root.profiles = []
                    root.lastResult = "lact-apply is not installed. This widget needs manual setup: see " + root.readme
                    return
                }
                const cur = lines.find(l => l.startsWith("current_profile:"))
                root.current = cur ? cur.replace("current_profile:", "").trim() : "base"
                const list = ["base"].concat(lines.filter(l => !l.startsWith("current_profile:") && l !== "base (no profile)"))
                const first = root.firstProfile !== "" ? list.indexOf(root.firstProfile) : -1
                if (first > 0) { list[first] = "base"; list[0] = root.firstProfile }
                root.profiles = list
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
                    if (f[0] === "#gpus") root.gpuLabels = f.slice(1)
                    else m[f[0]] = f.slice(1)
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
            if (code !== 0 && root.lastResult.startsWith("Applying")) root.lastResult = "Failed (exit " + code + "). Is the sudoers rule installed? See " + root.readme
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
                text: "GPU Power Profile"
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                topPadding: Theme.spacingM
            }

            // Same control as the DMS battery popout's power-profile selector.
            // Labels shrink in whole px steps to fit (a fractional scale blurs the glyphs).
            Item {
                id: groupBox
                width: parent.width
                visible: !root.scriptMissing
                height: profileGroup.height
                readonly property int basePx: Theme.fontSizeSmall + 1
                readonly property int labelPx: groupProbe.implicitWidth <= 0 ? basePx
                    : Math.max(8, Math.floor(basePx * Math.min(1, (width - Theme.spacingM * 2) / groupProbe.implicitWidth)))

                // Same group at full size, only measured
                DankButtonGroup {
                    id: groupProbe
                    visible: false
                    size: "small"
                    textSize: groupBox.basePx
                    model: profileGroup.model
                }

                DankButtonGroup {
                    id: profileGroup
                    size: "small"
                    textSize: groupBox.labelPx
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

            // Widest cell text, measured with the same component the cells use
            StyledText {
                id: cellProbe
                visible: false
                font.pixelSize: Theme.fontSizeSmall
                text: root.gpuLabels.reduce((a, l) => l.length > a.length ? l : a, "total") + " 0000 W"
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
                        // Right-aligned fixed-width cells so the W columns line up
                        Row {
                            anchors.right: parent.right
                            spacing: Theme.spacingL
                            Repeater {
                                model: root.capCells(modelData)
                                StyledText {
                                    required property string modelData
                                    width: cellProbe.implicitWidth
                                    wrapMode: Text.NoWrap
                                    horizontalAlignment: Text.AlignRight
                                    text: modelData
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: active ? Theme.primary : Theme.surfaceVariantText
                                }
                            }
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

    popoutWidth: 600
    popoutHeight: 130 + profiles.length * 20
}
