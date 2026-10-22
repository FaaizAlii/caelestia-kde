import QtQuick
import org.kde.kwin

Item {
    id: root
    property bool wantOverview: false
    property bool busy: false
    // Early trigger; logs allow checking the actual progress received from KWin.
    property real triggerProgress: 0.08

    function requestOverview(visible) {
        if (busy)
            return;
        busy = true;
        wantOverview = visible;
        console.info("Three Finger Overview v3: request", visible ? "open" : "close");
        activeEffects.call();
    }

    DBusCall {
        id: activeEffects
        service: "org.kde.KWin"
        path: "/Effects"
        dbusInterface: "org.freedesktop.DBus.Properties"
        method: "Get"
        arguments: ["org.kde.kwin.Effects", "activeEffects"]
        onFinished: function(returnValue) {
            const active = returnValue[0];
            const open = active && active.indexOf("overview") >= 0;
            if (open !== root.wantOverview)
                toggleOverview.call();
            else
                root.busy = false;
        }
        onFailed: {
            console.warn("Three Finger Overview: could not read active effects");
            root.busy = false;
        }
    }

    DBusCall {
        id: toggleOverview
        service: "org.kde.kglobalaccel"
        path: "/component/kwin"
        dbusInterface: "org.kde.kglobalaccel.Component"
        method: "invokeShortcut"
        arguments: ["Overview"]
        onFinished: root.busy = false
        onFailed: {
            console.warn("Three Finger Overview: could not invoke Overview");
            root.busy = false;
        }
    }

    SwipeGestureHandler {
        deviceType: SwipeGestureHandler.Touchpad
        direction: SwipeGestureHandler.Up
        fingerCount: 3
        property bool fired: false
        property int lastLoggedStep: -1
        onProgressChanged: {
            const step = Math.floor(progress * 20);
            if (step !== lastLoggedStep) {
                lastLoggedStep = step;
                console.info("Three Finger Overview v3: progress", direction, progress);
            }
            if (progress <= 0) {
                fired = false;
            } else if (!fired && progress >= root.triggerProgress) {
                fired = true;
                console.info("Three Finger Overview v3: early trigger", direction, progress);
                root.requestOverview(true);
            }
        }
        onActivated: {
            console.info("Three Finger Overview v3: completed", direction, "early trigger fired:", fired);
            if (!fired)
                root.requestOverview(true);
            fired = false;
        }
        onCancelled: fired = false
    }

    SwipeGestureHandler {
        deviceType: SwipeGestureHandler.Touchpad
        direction: SwipeGestureHandler.Down
        fingerCount: 3
        property bool fired: false
        property int lastLoggedStep: -1
        onProgressChanged: {
            const step = Math.floor(progress * 20);
            if (step !== lastLoggedStep) {
                lastLoggedStep = step;
                console.info("Three Finger Overview v3: progress", direction, progress);
            }
            if (progress <= 0) {
                fired = false;
            } else if (!fired && progress >= root.triggerProgress) {
                fired = true;
                console.info("Three Finger Overview v3: early trigger", direction, progress);
                root.requestOverview(false);
            }
        }
        onActivated: {
            console.info("Three Finger Overview v3: completed", direction, "early trigger fired:", fired);
            if (!fired)
                root.requestOverview(false);
            fired = false;
        }
        onCancelled: fired = false
    }

    Component.onCompleted: console.info("Three Finger Overview v3: loaded, threshold", root.triggerProgress)
}
