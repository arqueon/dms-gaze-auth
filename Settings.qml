// Settings.qml — getting-started guide for the Gaze Authentication plugin
//
// The Control Center tile only reports status; this page tells a new user how
// to reach a working setup. Every command is copy-only: the plugin never runs
// installers or edits PAM itself — the user reviews and runs them in a
// terminal, at their own decision.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginSettings {
    id: root

    pluginId: "gazeAuth"

    readonly property string pluginRoot: {
        const path = PluginService.getPluginPath("gazeAuth");
        if (!path)
            return "~/.config/DankMaterialShell/plugins/gazeAuth";

        const home = Quickshell.env("HOME");
        return home && path.startsWith(home) ? "~" + path.substring(home.length) : path;
    }
    readonly property var steps: [{
        "num": "1",
        "title": "Install Gaze",
        "desc": "Print the install plan for your distro first (official Gundu Labs packages; AUR helper on Arch). Read it, then re-run with --apply if you agree. Alternatively follow the official guide linked below.",
        "cmd": "bash " + pluginRoot + "/scripts/install-gaze.sh --plan",
        "warn": "Arch note: the AUR has an unrelated package also named 'gaze' (a file watcher). After installing, add 'IgnorePkg = gaze gaze-gui' to /etc/pacman.conf or an AUR helper upgrade may silently replace Gaze and disable facial auth."
    }, {
        "num": "2",
        "title": "Enroll your face",
        "desc": "Guided multi-angle capture from the terminal. You can also enroll graphically with gaze-gui — the 'Manage faces' button in the Control Center tile opens it once Gaze is installed.",
        "cmd": "gaze add-face",
        "warn": ""
    }, {
        "num": "3",
        "title": "Connect the DMS lock screen",
        "desc": "Installs the dedicated dankshell-gaze-grosshack PAM service and selects it in DMS. Face auth and the password field then run simultaneously: the right password wins during the scan, and a face match wins over a pending password. Dry plan by default — re-run with --apply to commit. Requires a Gaze build with the prompt-answering service gate. Coverage for sudo, polkit, and greetd is documented in the repository.",
        "cmd": "bash " + pluginRoot + "/scripts/configure-dms-pam.sh --plan",
        "warn": ""
    }, {
        "num": "4",
        "title": "Verify everything",
        "desc": "Sixteen read-only checks: daemon, camera, TPM, PAM coverage, and enrollment. Also available as 'Run doctor' in the Control Center tile.",
        "cmd": "gaze doctor",
        "warn": ""
    }]
    readonly property var pamIntegrations: [{
        "title": "sudo",
        "desc": "Back up /etc/pam.d/sudo, then add pam_gaze.so before the existing authentication include. Keep fingerprint and password fallback; test a fresh transaction.",
        "cmd": "sudo -k && sudo -v"
    }, {
        "title": "Polkit",
        "desc": "On Arch-compatible systems, review and install a local polkit-1 PAM service with Gaze before system-auth. Restart Polkit and test a real graphical request.",
        "cmd": "pkexec /usr/bin/true"
    }, {
        "title": "greetd / DMS Greeter",
        "desc": "Add pam_gaze.so outside DMS's managed markers and before fallback auth. Validate the file before logging out; a real later login is the final UI test.",
        "cmd": "dms auth validate --path /etc/pam.d/greetd --purpose password --json"
    }]

    function copyCommand(cmd) {
        Quickshell.execDetached(["dms", "cl", "copy", cmd]);
        ToastService.showInfo("Gaze Authentication", "Command copied to clipboard.");
    }

    function openUrl(url) {
        Quickshell.execDetached(["xdg-open", url]);
    }

    StyledText {
        width: parent.width
        text: "Getting started"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "A working setup needs four things: the Gaze packages installed, the gazed service running, at least one enrolled face, and the PAM surfaces you want covered. The tile in the Control Center shows how far along you are; the steps below get you there. Copy each command and run it in your terminal."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: root.steps

        Rectangle {
            required property var modelData

            width: parent.width
            implicitHeight: stepColumn.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            Column {
                id: stepColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingS

                    Rectangle {
                        width: 22
                        height: 22
                        radius: 11
                        color: Theme.primary

                        StyledText {
                            anchors.centerIn: parent
                            text: modelData.num
                            color: Theme.onPrimary
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                        }

                    }

                    StyledText {
                        text: modelData.title
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                    }

                }

                StyledText {
                    width: parent.width
                    text: modelData.desc
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width
                    implicitHeight: commandRow.implicitHeight + Theme.spacingS * 2
                    radius: Theme.cornerRadiusSmall
                    color: Theme.nestedSurface
                    border.color: Theme.outlineMedium
                    border.width: Theme.layerOutlineWidth

                    RowLayout {
                        id: commandRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingS
                        spacing: Theme.spacingS

                        StyledText {
                            text: modelData.cmd
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: SettingsData.monoFontFamily
                            wrapMode: Text.WrapAnywhere
                            Layout.fillWidth: true
                        }

                        DankActionButton {
                            iconName: "content_copy"
                            tooltipText: "Copy command"
                            onClicked: root.copyCommand(modelData.cmd)
                        }

                    }

                }

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: modelData.warn !== ""

                    DankIcon {
                        name: "warning"
                        size: Theme.iconSizeSmall
                        color: Theme.warning
                        Layout.alignment: Qt.AlignTop
                    }

                    StyledText {
                        text: modelData.warn
                        color: Theme.warning
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                }

            }

        }

    }

    StyledText {
        width: parent.width
        text: "Optional PAM integrations"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
        topPadding: Theme.spacingL
    }

    StyledText {
        width: parent.width
        text: "The plugin only detects these surfaces. Configure one at a time after direct Gaze authentication works. Back up the target PAM file, preserve password and fingerprint fallback, and read docs/PAM_INTEGRATIONS.md before editing anything. The commands below are tests, not installers."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: root.pamIntegrations

        Rectangle {
            required property var modelData

            width: parent.width
            implicitHeight: pamColumn.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            Column {
                id: pamColumn

                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                StyledText {
                    width: parent.width
                    text: modelData.title
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                }

                StyledText {
                    width: parent.width
                    text: modelData.desc
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width
                    implicitHeight: pamCommandRow.implicitHeight + Theme.spacingS * 2
                    radius: Theme.cornerRadiusSmall
                    color: Theme.nestedSurface
                    border.color: Theme.outlineMedium
                    border.width: Theme.layerOutlineWidth

                    RowLayout {
                        id: pamCommandRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingS
                        spacing: Theme.spacingS

                        StyledText {
                            text: modelData.cmd
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: SettingsData.monoFontFamily
                            wrapMode: Text.WrapAnywhere
                            Layout.fillWidth: true
                        }

                        DankActionButton {
                            iconName: "content_copy"
                            tooltipText: "Copy test command"
                            onClicked: root.copyCommand(modelData.cmd)
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        width: parent.width
        spacing: Theme.spacingS

        DankButton {
            text: "Open repository"
            iconName: "code"
            Layout.fillWidth: true
            onClicked: root.openUrl("https://github.com/arqueon/dms-gaze-auth")
        }

        DankButton {
            text: "Official install guide"
            iconName: "open_in_new"
            Layout.fillWidth: true
            onClicked: root.openUrl("https://gaze.gundulabs.com/guide/installation")
        }

    }

    StyledText {
        width: parent.width
        text: "Your system, your call"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
        topPadding: Theme.spacingL
    }

    StyledText {
        width: parent.width
        text: "This plugin is read-only: it never installs packages, edits PAM, or touches biometric data on your behalf. The commands above run in your terminal, under your own review and responsibility. Both scripts default to a dry --plan run — read the plan before re-running with --apply. PAM changes affect how you authenticate: keep your password fallback working, and see docs/SECURITY.md in the repository before applying anything."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }

}
