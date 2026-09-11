//@ pragma UseQApplication
//@ pragma ShellId foxy

import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: root

    function envInt(name, fallback) {
        const value = parseInt(Quickshell.env(name), 10);
        return isNaN(value) || value <= 0 ? fallback : value;
    }

    function envReal(name, fallback) {
        const value = parseFloat(Quickshell.env(name));
        return isNaN(value) ? fallback : Math.max(0, Math.min(1, value));
    }

    function envBool(name, fallback) {
        const value = Quickshell.env(name);
        if (value === "" || value === undefined)
            return fallback;
        return value !== "0" && value.toLowerCase() !== "false";
    }

    readonly property int testPeriod: envInt("FOXY_TEST", 0)
    readonly property int tickMs: envInt("FOXY_TICK_MS", 1000)
    readonly property int scareDuration: envInt("FOXY_SCARE_MS", 2000)
    readonly property int frameMs: envInt("FOXY_FRAME_MS", 50)
    readonly property real chance: 1 / envInt("FOXY_CHANCE", 604800)
    readonly property real volume: envReal("FOXY_VOLUME", 1)
    readonly property bool soundEnabled: envBool("FOXY_SOUND", true)

    // FOXY_TEST=N skips the roll and fires every N seconds.
    readonly property int rollMs: testPeriod > 0 ? testPeriod * 1000 : tickMs

    property bool scaring: false

    signal scareStarted
    signal scareStopped

    Timer {
        interval: root.rollMs
        running: true
        repeat: true
        onTriggered: {
            if (root.testPeriod > 0)
                root.startScare();
            else if (!root.scaring && Math.random() < root.chance)
                root.startScare();
        }
    }

    Timer {
        id: scareTimer
        interval: root.scareDuration
        repeat: false
        onTriggered: {
            root.scaring = false;
            root.scareStopped();
        }
    }

    SoundEffect {
        id: scream
        source: Qt.resolvedUrl("assets/scream.wav")
        volume: root.volume
    }

    function startScare() {
        root.scaring = true;
        if (root.soundEnabled)
            scream.play();
        scareTimer.restart();
        root.scareStarted();
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property ShellScreen modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // AnimatedImage keeps its alpha; transparent surfaces show the desktop.
            color: "transparent"
            visible: root.scaring
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "foxy:scare"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            AnimatedImage {
                id: anim
                anchors.fill: parent
                source: Qt.resolvedUrl("assets/foxy.webp")
                fillMode: Image.PreserveAspectCrop
                playing: false

                // Stepped by hand so FOXY_FRAME_MS can retime the clip.
                Timer {
                    id: frameTimer
                    interval: root.frameMs
                    running: false
                    repeat: true
                    onTriggered: {
                        if (anim.currentFrame + 1 >= anim.frameCount)
                            running = false;
                        else
                            anim.currentFrame += 1;
                    }
                }
            }

            Connections {
                target: root

                function onScareStarted() {
                    anim.currentFrame = 0;
                    frameTimer.restart();
                }

                function onScareStopped() {
                    frameTimer.stop();
                }
            }
        }
    }
}
