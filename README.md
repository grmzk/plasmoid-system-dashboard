# System Dashboard Plasmoid

Native Plasma 6 desktop widget for the Conky dashboard in this workspace.

## Install

From the workspace root:

```sh
kpackagetool6 --type Plasma/Applet --install plasmoid/package
```

For a windowed preview:

```sh
plasmawindowed ru.local.systemdashboard
```

To place it on the desktop, open the desktop context menu, choose **Enter Edit
Mode**, then **Add or Manage Widgets**, and add **System Dashboard**. Its
default size is 448 x 960 logical pixels.

## Update

After editing the package, close the preview and run:

```sh
kpackagetool6 --type Plasma/Applet --upgrade plasmoid/package
```

If an already-added desktop widget still shows the previous version, reload
that instance: remove it from the desktop and add **System Dashboard** again.
If it still looks stale, restart the Plasma shell to clear its QML engine cache:
run `plasmashell --replace` from Konsole or KRunner, or log out and back in.

## Data

The widget reads CPU, memory, and swap sensors through Plasma's System Monitor
sensor API. `contents/code/collector.py` reads `/tmp/conky-external-vars` and
collects load, uptime, filesystem usage, network rates, battery status, and top
CPU/memory processes. Set `CONKY_EXTERNAL_VARS` in the Plasma session
environment to use a different directory.

The network section currently follows the interface names from the Conky file:
`wwan0`, `wlp0s20f3`, and `eth0`.
