import QtQuick
import qs.Modules.Plugins

PluginSettings {
    pluginId: "lactProfiles"

    StringSetting {
        settingKey: "firstProfile"
        label: "First profile"
        description: "LACT profile shown first in the popout; Default takes its place. Empty keeps the order from /etc/lact/config.yaml."
        placeholder: "Eco"
        defaultValue: ""
    }
}
