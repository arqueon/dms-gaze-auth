import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginComponent {
    id: root

    property var popoutService: null
    readonly property var emptyStatus: ({
        "installed": "0",
        "version": "Not installed",
        "gui_available": "0",
        "daemon_active": "0",
        "daemon_enabled": "0",
        "enrolled": "unknown",
        "face_summary": "Run doctor to verify",
        "config_present": "0",
        "pam_lock": "0",
        "pam_sudo": "0",
        "pam_polkit": "0",
        "pam_greetd": "0",
        "dms_path_selected": "0",
        "distro_id": "unknown",
        "distro_name": "Unknown Linux"
    })
    property var status: emptyStatus
    property bool busy: false
    property bool doctorBusy: false
    property string doctorOutput: "Run the read-only doctor when you need the complete Gaze report."
    readonly property bool ready: status.installed === "1" && status.daemon_active === "1"
    // Live auth-phase mirror from the Gaze observer channel (see the
    // `gaze-observe` helper shipped with DMS). Only elevation surfaces are
    // reported here; the lock screen and polkit modal render their own
    // in-process feedback.
    property string livePhase: ""
    property string liveSurface: ""
    readonly property bool liveAuthActive: livePhase !== "" && livePhase !== "idle" && liveSurface === "elevation"
    readonly property int pamCount: Number(status.pam_lock || 0) + Number(status.pam_sudo || 0) + Number(status.pam_polkit || 0) + Number(status.pam_greetd || 0)
    readonly property string nextStepHint: {
        if (status.installed !== "1")
            return "Next step: install Gaze. The plugin settings (Settings → Plugins → Gaze Authentication) walk you through it with copyable commands.";

        if (status.daemon_active !== "1")
            return "Next step: start the service — sudo systemctl enable --now gazed";

        if (status.enrolled === "0")
            return "Next step: enroll your face — run 'gaze add-face' in a terminal or use Manage faces.";

        if (status.pam_lock !== "1" || status.dms_path_selected !== "1")
            return "Next step: connect the DMS lock — see the guided checklist in the plugin settings.";

        return "";
    }

    function helperPath() {
        if (!pluginService || !pluginId)
            return "";

        return pluginService.getPluginPath(pluginId) + "/scripts/gaze-status";
    }

    function parseStatus(text) {
        const next = {
        };
        String(text || "").split("\n").forEach((line) => {
            const separator = line.indexOf("=");
            if (separator <= 0)
                return ;

            next[line.substring(0, separator)] = line.substring(separator + 1);
        });
        return Object.assign({
        }, status, next);
    }

    function applyDoctorFacts(text) {
        const match = String(text || "").match(/Enrollment:\s+([0-9]+) face profile/);
        if (!match)
            return ;

        const count = Number(match[1]);
        status = Object.assign({
        }, status, {
            "enrolled": count > 0 ? "1" : "0",
            "face_summary": count > 0 ? count + " profile(s) enrolled" : "No enrollment detected"
        });
    }

    function refreshStatus() {
        const helper = helperPath();
        if (!helper || busy)
            return ;

        busy = true;
        statusProcess.running = true;
    }

    function runDoctor() {
        const helper = helperPath();
        if (!helper || doctorBusy)
            return ;

        doctorBusy = true;
        doctorOutput = "Running gaze doctor…";
        doctorProcess.running = true;
    }

    function openGazeGui() {
        if (status.gui_available !== "1") {
            ToastService.showWarning("Gaze GUI", "gaze-gui is not installed.");
            return ;
        }
        Quickshell.execDetached(["gaze-gui"]);
    }

    function openInstallGuide() {
        Quickshell.execDetached(["xdg-open", "https://gaze.gundulabs.com/guide/installation"]);
    }

    function statusRows() {
        return [{
            "icon": "deployed_code",
            "label": "Package",
            "value": status.installed === "1" ? status.version : "Not installed",
            "ok": status.installed === "1"
        }, {
            "icon": "settings_input_component",
            "label": "Daemon",
            "value": status.daemon_active === "1" ? "Active" : "Inactive",
            "ok": status.daemon_active === "1"
        }, {
            "icon": "face",
            "label": "Enrollment",
            "value": status.enrolled === "1" ? status.face_summary : (status.enrolled === "0" ? "None detected" : "Run doctor to verify"),
            "ok": status.enrolled === "1"
        }, {
            "icon": "lock",
            "label": "DMS Lock",
            "value": status.pam_lock === "1" ? (status.dms_path_selected === "1" ? "Configured and selected" : "PAM service present") : "Not configured",
            "ok": status.pam_lock === "1" && status.dms_path_selected === "1"
        }];
    }

    pluginId: "gazeAuth"
    pluginService: PluginService
    ccWidgetIcon: ready ? "face" : (status.installed === "1" ? "face_retouching_off" : "person_off")
    ccWidgetPrimaryText: "Gaze Authentication"
    ccWidgetSecondaryText: {
        if (busy)
            return "Checking…";

        if (root.liveAuthActive) {
            switch (root.livePhase) {
            case "matched":
                return "Face matched · elevation";
            case "not-recognized":
                return "Face not recognized";
            case "unavailable":
                return "Face auth unavailable";
            default:
                return "Waiting for face";
            }
        }

        if (status.installed !== "1")
            return "Gaze not installed";

        if (status.daemon_active !== "1")
            return "Daemon inactive";

        if (status.enrolled === "0")
            return "No enrolled face";

        if (status.enrolled === "1")
            return "Ready · " + pamCount + "/4 PAM surfaces";

        return "Service ready · " + pamCount + "/4 PAM surfaces";
    }
    ccWidgetIsActive: ready
    ccWidgetIsToggle: false
    ccDetailHeight: 520
    onCcWidgetToggled: refreshStatus()
    onCcWidgetExpanded: refreshStatus()

    Timer {
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            if (root.axis === null)
                root.refreshStatus();

        }
    }

    Process {
        id: statusProcess

        command: ["bash", root.helperPath(), "status"]
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.busy = false;
                const message = String(statusStderr.text || "The local status probe did not complete.").trim();
                ToastService.showError("Gaze status", message);
            }
        }

        stdout: StdioCollector {
            id: statusStdout

            onStreamFinished: {
                root.status = root.parseStatus(text);
                root.busy = false;
            }
        }

        stderr: StdioCollector {
            id: statusStderr
        }

    }

    Process {
        id: doctorProcess

        command: ["bash", root.helperPath(), "doctor"]
        running: false
        onExited: function(exitCode) {
            root.doctorBusy = false;
            const output = String(doctorStdout.text || doctorStderr.text || "No output returned.").trim();
            root.doctorOutput = output;
            if (exitCode === 0) {
                root.applyDoctorFacts(output);
                ToastService.showInfo("Gaze doctor", "Diagnostic completed.");
            } else {
                ToastService.showWarning("Gaze doctor", "Review the diagnostic output.");
            }
        }

        stdout: StdioCollector {
            id: doctorStdout

            onStreamFinished: {
                root.doctorOutput = String(text || "No output returned.").trim();
                root.applyDoctorFacts(root.doctorOutput);
            }
        }

        stderr: StdioCollector {
            id: doctorStderr
        }

    }

    // Live auth-phase observer. The helper exits non-zero when the daemon or
    // its observer API is unavailable; the mirror then stays empty and the
    // widget falls back to the static status rows.
    Process {
        id: observerProcess

        command: ["gaze-observe"]
        running: false
        property string buffer: ""
        property int consumed: 0

        stdout: StdioCollector {
            id: observerOutput

            waitForEnd: false
            onDataChanged: observerProcess.drain()
        }

        onRunningChanged: {
            if (!observerProcess.running) {
                root.livePhase = "";
                root.liveSurface = "";
                observerRetry.restart();
            }
        }

        function drain(): void {
            const text = observerOutput.text;
            if (text.length > consumed) {
                buffer += text.substring(consumed);
                consumed = text.length;
            }
            let idx = -1;
            while ((idx = buffer.indexOf("\n")) >= 0) {
                const line = buffer.substring(0, idx);
                buffer = buffer.substring(idx + 1);
                applyObserverLine(line);
            }
        }

        function applyObserverLine(line: string): void {
            const values = {};
            for (const field of String(line).trim().split(" ")) {
                const eq = field.indexOf("=");
                if (eq <= 0)
                    continue;
                values[field.substring(0, eq)] = field.substring(eq + 1);
            }
            if (values["phase"] !== undefined)
                root.livePhase = values["phase"];
            if (values["surface"] !== undefined)
                root.liveSurface = values["surface"];
        }
    }

    Timer {
        id: observerRetry

        interval: 10000
        repeat: false
        onTriggered: observerProcess.running = true
    }

    Timer {
        interval: 100
        running: true
        repeat: false
        onTriggered: observerProcess.running = true
    }

    ccDetailContent: Component {
        Rectangle {
            id: detailRoot

            implicitHeight: detailColumn.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.nestedSurface
            border.color: Theme.outlineMedium
            border.width: Theme.layerOutlineWidth

            Column {
                id: detailColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingS

                    Column {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXS

                        StyledText {
                            text: "Gaze Authentication"
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.DemiBold
                        }

                        StyledText {
                            width: parent.width
                            text: root.status.distro_name + " · read-only status"
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                        }

                    }

                    DankActionButton {
                        iconName: root.busy ? "progress_activity" : "refresh"
                        tooltipText: "Refresh status"
                        enabled: !root.busy
                        onClicked: root.refreshStatus()
                    }

                }

                Repeater {
                    model: root.statusRows()

                    Rectangle {
                        required property var modelData

                        width: detailColumn.width
                        height: statusRow.implicitHeight + Theme.spacingS * 2
                        radius: Theme.cornerRadius / 2
                        color: Theme.surfaceContainerHigh

                        RowLayout {
                            id: statusRow

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.spacingM
                            anchors.rightMargin: Theme.spacingM
                            spacing: Theme.spacingS

                            DankIcon {
                                name: modelData.icon
                                size: Theme.iconSizeSmall
                                color: modelData.ok ? Theme.success : Theme.warning
                            }

                            StyledText {
                                text: modelData.label
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                                Layout.preferredWidth: 100
                            }

                            StyledText {
                                text: modelData.value
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                        }

                    }

                }

                StyledText {
                    width: parent.width
                    text: "PAM coverage: sudo " + (root.status.pam_sudo === "1" ? "✓" : "–") + "  Polkit " + (root.status.pam_polkit === "1" ? "✓" : "–") + "  greetd " + (root.status.pam_greetd === "1" ? "✓" : "–")
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingS

                    DankButton {
                        text: root.doctorBusy ? "Running…" : "Run doctor"
                        iconName: "health_and_safety"
                        enabled: root.status.installed === "1" && !root.doctorBusy
                        Layout.fillWidth: true
                        onClicked: root.runDoctor()
                    }

                    DankButton {
                        text: "Manage faces"
                        iconName: "face_retouching_natural"
                        enabled: root.status.gui_available === "1"
                        Layout.fillWidth: true
                        onClicked: root.openGazeGui()
                    }

                    DankButton {
                        text: "Install guide"
                        iconName: "open_in_new"
                        Layout.fillWidth: true
                        onClicked: root.openInstallGuide()
                    }

                }

                Rectangle {
                    width: parent.width
                    height: 130
                    radius: Theme.cornerRadius / 2
                    color: Theme.surfaceContainerHigh
                    visible: root.doctorOutput !== ""

                    Flickable {
                        id: doctorFlickable

                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        contentWidth: width
                        contentHeight: doctorText.implicitHeight
                        clip: true

                        StyledText {
                            id: doctorText

                            width: doctorFlickable.width
                            text: root.doctorOutput
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: SettingsData.monoFontFamily
                            wrapMode: Text.WrapAnywhere
                        }

                    }

                }

                StyledText {
                    width: parent.width
                    text: root.nextStepHint !== "" ? root.nextStepHint : "This plugin never edits PAM, enrolls faces, or stores biometric data. Installation and PAM changes remain explicit terminal operations with password fallback."
                    color: root.nextStepHint !== "" ? Theme.warning : Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }

            }

        }

    }

}
