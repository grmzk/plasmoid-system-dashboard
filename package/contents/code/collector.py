import json
import os
import subprocess
import sys
import time
from pathlib import Path

HOSTS_STATE = Path("/tmp/systemdashboard-hosts.json")
GPU_MODEL_STATE = Path("/tmp/systemdashboard-gpu-model.txt")
SYSTEM_VERSION_STATE = Path("/tmp/systemdashboard-versions.json")
SYSTEM_VERSION_INTERVAL = 60
HOSTS = {
    "m4vps-msk": "msk.m4vps.ru",
    "m4vps-de": "de.m4vps.ru",
    "m4wrt": "192.168.254.11",
    "bsmp1-ord": "192.168.254.41",
    "bsmp1-pit": "192.168.255.6",
    "bsmp1-ad": "192.168.255.5",
    "bsmp1-reanzal": "192.168.255.7",
    "fampc": "192.168.254.3",
    "relnb": "192.168.254.4",
    "relphn": "192.168.253.22",
    "m4phn": "192.168.253.21",
}
HOSTS_UPDATE = ("m4vps-msk", "m4vps-de", "famnb")
HOSTS_STATUS_INTERVAL = 30
HOSTS_UPDATE_INTERVAL = 300
CPU_HWMON = "/sys/devices/platform/coretemp.0/hwmon/hwmon*"
CPU_FAN_HWMON = "/sys/devices/platform/thinkpad_hwmon/hwmon/hwmon*"
GPU_HWMON = "/sys/class/drm/card0/device/hwmon/hwmon*"
GPU_DEVICE = Path("/sys/class/drm/card0/device")
NVME_HWMON = "/sys/block/nvme0n1/device/hwmon*"
MAX_FAN_RPM = 3989
NETWORK_STATE = Path("/tmp/systemdashboard-network.json")
NVME_STATE = Path("/tmp/systemdashboard-nvme.json")
MOUNT_POINTS = ("/", "/var", "/home", "/tmp")
NETWORK_INTERFACES = {"wwan0", "wlp0s20f3", "eth0"}
IW_COMMAND = next(
    (
        command
        for command in ("/usr/sbin/iw", "/usr/bin/iw", "/sbin/iw")
        if Path(command).is_file()
    ),
    None,
)


def first_glob(pattern: str) -> Path | None:
    matches = sorted(Path("/").glob(pattern.lstrip("/")))
    return matches[0] if matches else None


def read_int(path: Path) -> int | None:
    try:
        return int(path.read_text(encoding="utf-8").strip())
    except OSError, ValueError:
        return None


def read_label(path: Path) -> str:
    try:
        label = path.read_text(encoding="utf-8").strip()
    except OSError:
        return ""
    return label.lower().replace(" ", "")


def read_system_versions() -> dict[str, str]:
    now = time.time()
    try:
        state = json.loads(SYSTEM_VERSION_STATE.read_text(encoding="utf-8"))
    except OSError, json.JSONDecodeError:
        state = {}
    if now - state.get("time", 0) < SYSTEM_VERSION_INTERVAL and "description" in state:
        return {
            "kernel": state.get("kernel", "—"),
            "plasma": state.get("plasma", "—"),
            "description": state.get("description", "—"),
        }

    kernel = os.uname().release
    plasma = "—"
    description = "—"
    try:
        result = subprocess.run(
            ["plasmashell", "--version"],
            capture_output=True,
            check=False,
            text=True,
            timeout=5,
        )
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                fields = line.split()
                if fields and fields[0] == "plasmashell" and len(fields) > 1:
                    plasma = fields[-1]
                    break
    except OSError, subprocess.TimeoutExpired:
        pass

    try:
        result = subprocess.run(
            ["lsb_release", "--description", "--short"],
            capture_output=True,
            check=False,
            text=True,
            timeout=5,
        )
        if result.returncode == 0:
            description = result.stdout.strip().strip('"') or "—"
    except OSError, subprocess.TimeoutExpired:
        pass

    state = {
        "time": now,
        "kernel": kernel,
        "plasma": plasma,
        "description": description,
    }
    temporary = SYSTEM_VERSION_STATE.with_suffix(".tmp")
    try:
        temporary.write_text(json.dumps(state), encoding="utf-8")
        temporary.replace(SYSTEM_VERSION_STATE)
    except OSError:
        pass
    return {"kernel": kernel, "plasma": plasma, "description": description}


def read_fan(pattern: str, name: str, variables: dict[str, str]) -> None:
    hwmon = first_glob(pattern)
    rpm = read_int(hwmon / "fan1_input") if hwmon else None
    variables[name] = f"{rpm * 100 // MAX_FAN_RPM}%" if rpm is not None else "---"


def read_hwmon_sensors(
    pattern: str,
    sensors: range,
    prefix: str,
    kind: str,
    suffix: str,
    convert,
    variables: dict[str, str],
) -> None:
    hwmon = first_glob(pattern)
    if hwmon is None:
        return
    for sensor in sensors:
        label = read_label(hwmon / f"{kind}{sensor}_label")
        if not label:
            continue
        value = read_int(hwmon / f"{kind}{sensor}_{suffix}")
        variables[f"{prefix}_{label}"] = convert(value) if value is not None else "---"


def read_temperatures(
    pattern: str, sensors: range, prefix: str, variables: dict[str, str]
) -> None:
    read_hwmon_sensors(
        pattern,
        sensors,
        prefix,
        "temp",
        "input",
        lambda value: f"+{value // 1000}°C",
        variables,
    )


def read_gpu_model() -> str:
    try:
        return GPU_MODEL_STATE.read_text(encoding="utf-8").strip()
    except OSError:
        pass
    try:
        result = subprocess.run(
            ["glxinfo"],
            capture_output=True,
            check=False,
            text=True,
            timeout=5,
        )
    except OSError, subprocess.TimeoutExpired:
        return "GPU model info was not found!"
    model = ""
    for line in result.stdout.splitlines():
        if "Device:" in line:
            model = line.split(":", maxsplit=1)[1].strip()
            # Drop the trailing "(...) (...)" groups.
            model = model.rsplit(" (", maxsplit=2)[0]
            break
    if not model:
        return "GPU model info was not found!"
    try:
        GPU_MODEL_STATE.write_text(model, encoding="utf-8")
    except OSError:
        pass
    return model


def read_gpu_variables(variables: dict[str, str]) -> None:
    variables["gpu_model"] = read_gpu_model()
    read_fan(GPU_HWMON, "gpu_fan", variables)
    read_temperatures(GPU_HWMON, range(1, 4), "gpu_temp", variables)

    busy = read_int(GPU_DEVICE / "gpu_busy_percent")
    used = read_int(GPU_DEVICE / "mem_info_vram_used")
    total = read_int(GPU_DEVICE / "mem_info_vram_total")
    mib = 1024 * 1024
    variables["gpu_busy_percent"] = f"{busy}%" if busy is not None else "---"
    variables["gpu_vram_used"] = f"{used // mib}MiB" if used is not None else "---"
    variables["gpu_vram_total"] = f"{total // mib}MiB" if total is not None else "---"
    variables["gpu_vram_used_percent"] = (
        f"{used * 100 // total}%" if used is not None and total else "---"
    )
    read_hwmon_sensors(
        GPU_HWMON,
        range(1, 3),
        "gpu_freq",
        "freq",
        "input",
        lambda value: f"{value // 1_000_000}MHz",
        variables,
    )
    read_hwmon_sensors(
        GPU_HWMON,
        range(1, 2),
        "gpu_power",
        "power",
        "average",
        lambda value: f"{value // 1_000_000}.00W",
        variables,
    )


def read_hosts_state() -> dict:
    try:
        return json.loads(HOSTS_STATE.read_text(encoding="utf-8"))
    except OSError, json.JSONDecodeError:
        return {}


def write_hosts_state(state: dict) -> None:
    temporary = HOSTS_STATE.with_suffix(".tmp")
    try:
        temporary.write_text(json.dumps(state), encoding="utf-8")
        temporary.replace(HOSTS_STATE)
    except OSError:
        pass


def refresh_hosts_status() -> None:
    status = {}
    for name, address in HOSTS.items():
        try:
            result = subprocess.run(
                ["ping", "-c", "1", "-W", "2", address],
                capture_output=True,
                check=False,
                timeout=5,
            )
            status[name] = "on" if result.returncode == 0 else "off"
        except OSError, subprocess.TimeoutExpired:
            status[name] = "off"
    state = read_hosts_state()
    state["status"] = status
    state["status_time"] = time.time()
    write_hosts_state(state)


def refresh_hosts_updates() -> None:
    updates = {}
    try:
        result = subprocess.run(
            ["sudo", "apt-get", "dist-upgrade", "--just-print"],
            capture_output=True,
            check=False,
            text=True,
            timeout=300,
        )
        ignored = (" libre2_11 ", " libtommath ", " libtomcrypt ")
        updates["m4nb"] = str(
            sum(
                1
                for line in result.stdout.splitlines()
                if line.startswith("Inst ")
                and not any(item in line for item in ignored)
            )
        )
    except OSError, subprocess.TimeoutExpired:
        updates["m4nb"] = "-"

    for host in HOSTS_UPDATE:
        try:
            result = subprocess.run(
                ["ssh", "m4vps-msk", f"cat /tmp/updpkgs_{host}"],
                capture_output=True,
                check=False,
                text=True,
                timeout=300,
            )
            value = result.stdout.strip()
            updates[host] = value if result.returncode == 0 else "-"
        except OSError, subprocess.TimeoutExpired:
            updates[host] = "-"
    state = read_hosts_state()
    state["updates"] = updates
    state["updates_time"] = time.time()
    write_hosts_state(state)


def spawn_refresh(option: str) -> None:
    try:
        subprocess.Popen(
            [sys.executable, os.path.abspath(__file__), option],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError:
        pass


def read_hosts_variables(variables: dict[str, str]) -> None:
    # Slow checks run in detached workers; results are cached on disk.
    state = read_hosts_state()
    now = time.time()
    # Stamp before spawning so concurrent runs don't start duplicates.
    stale = False
    if now - state.get("status_time", 0) > HOSTS_STATUS_INTERVAL:
        state["status_time"] = now
        stale = True
        spawn_status = True
    else:
        spawn_status = False
    if now - state.get("updates_time", 0) > HOSTS_UPDATE_INTERVAL:
        state["updates_time"] = now
        stale = True
        spawn_updates = True
    else:
        spawn_updates = False
    if stale:
        write_hosts_state(state)
    if spawn_status:
        spawn_refresh("--refresh-hosts-status")
    if spawn_updates:
        spawn_refresh("--refresh-hosts-updates")

    for name in HOSTS:
        variables[f"host_{name}_status"] = state.get("status", {}).get(name, "off")
    for name, value in state.get("updates", {}).items():
        variables[f"host_{name}_updates"] = value


def read_external_variables() -> dict[str, str]:
    variables: dict[str, str] = {}
    read_fan(CPU_FAN_HWMON, "cpu_fan", variables)
    read_temperatures(CPU_HWMON, range(1, 6), "cpu_temp", variables)
    read_gpu_variables(variables)
    read_temperatures(NVME_HWMON, range(1, 2), "nvme_temp", variables)
    read_hosts_variables(variables)
    return variables


def read_gpu_max_frequency() -> str:
    frequencies = []
    for path in sorted(Path("/sys/class/drm").glob("card*/device/pp_dpm_sclk")):
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except OSError:
            continue
        for line in lines:
            fields = line.split()
            if len(fields) < 2 or not fields[1].lower().endswith("mhz"):
                continue
            try:
                frequencies.append(int(fields[1][:-3]))
            except ValueError:
                continue
    return f"{max(frequencies)}MHz" if frequencies else "—"


def read_network_route() -> dict[str, str]:
    try:
        result = subprocess.run(
            ["ip", "-4", "route", "show", "default"],
            capture_output=True,
            check=False,
            text=True,
            timeout=2,
        )
    except OSError, subprocess.TimeoutExpired:
        return {"ip": "—", "gateway": "—"}

    routes = [line.split() for line in result.stdout.splitlines() if line.strip()]
    if result.returncode != 0 or not routes:
        return {"ip": "—", "gateway": "—"}

    first_route_fields = routes[0]
    last_route_fields = routes[-1]

    def route_value(route_fields: list[str], name: str) -> str:
        try:
            return route_fields[route_fields.index(name) + 1]
        except ValueError, IndexError:
            return "—"

    device = route_value(last_route_fields, "dev")
    ip_address = route_value(last_route_fields, "src")
    if ip_address == "—" and device != "—":
        try:
            address_result = subprocess.run(
                ["ip", "-o", "-4", "addr", "show", "dev", device],
                capture_output=True,
                check=False,
                text=True,
                timeout=2,
            )
        except OSError, subprocess.TimeoutExpired:
            address_result = None
        if address_result and address_result.returncode == 0:
            for line in address_result.stdout.splitlines():
                address_fields = line.split()
                if "inet" in address_fields:
                    ip_address = address_fields[address_fields.index("inet") + 1].split(
                        "/", maxsplit=1
                    )[0]
                    break

    return {
        "ip": ip_address,
        "gateway": route_value(first_route_fields, "via"),
    }


def read_nvme_rates() -> dict[str, float]:
    now = time.time()
    try:
        previous = json.loads(NVME_STATE.read_text(encoding="utf-8"))
    except OSError, json.JSONDecodeError:
        previous = {}

    read_sectors = 0
    written_sectors = 0
    for device in sorted(Path("/sys/block").glob("nvme*n*")):
        try:
            stats = [
                int(value)
                for value in (device / "stat").read_text(encoding="utf-8").split()
            ]
        except OSError, ValueError:
            continue
        if len(stats) < 7:
            continue
        read_sectors += stats[2]
        written_sectors += stats[6]

    elapsed = max(now - previous.get("time", now), 0.001)
    rates = {
        "read_rate": (
            max(0, read_sectors - previous.get("read_sectors", read_sectors))
            * 512
            / elapsed
        ),
        "write_rate": (
            max(
                0,
                written_sectors - previous.get("written_sectors", written_sectors),
            )
            * 512
            / elapsed
        ),
    }
    try:
        NVME_STATE.write_text(
            json.dumps(
                {
                    "time": now,
                    "read_sectors": read_sectors,
                    "written_sectors": written_sectors,
                }
            ),
            encoding="utf-8",
        )
    except OSError:
        pass
    return rates


def read_interface_state(name: str) -> str:
    interface = Path("/sys/class/net") / name
    try:
        state = (interface / "operstate").read_text(encoding="utf-8").strip()
    except OSError:
        state = "unknown"
    if state in {"up", "down"}:
        return state

    try:
        carrier = (interface / "carrier").read_text(encoding="utf-8").strip()
    except OSError:
        carrier = ""
    if carrier in {"0", "1"}:
        return "up" if carrier == "1" else "down"

    try:
        flags = int((interface / "flags").read_text(encoding="utf-8").strip(), 16)
    except OSError, ValueError:
        return "down"
    return "up" if flags & 0x1 else "down"


def read_ethernet_link_mode(name: str) -> str:
    try:
        speed = int(
            (Path("/sys/class/net") / name / "speed")
            .read_text(encoding="utf-8")
            .strip()
        )
    except OSError, ValueError:
        return "Ethernet"
    if speed <= 0:
        return "Ethernet"

    ethernet_modes = {
        10: "10-T",
        100: "100-TX",
        1000: "1000-T",
        2500: "2.5G-T",
        5000: "5G-T",
        10000: "10G-T",
    }
    return ethernet_modes.get(speed, f"{speed}Mb/s")


def read_network_manager_states() -> dict[str, str]:
    try:
        result = subprocess.run(
            ["nmcli", "-t", "-f", "DEVICE,STATE", "device", "status"],
            capture_output=True,
            check=False,
            text=True,
            timeout=2,
        )
    except OSError, subprocess.TimeoutExpired:
        return {}
    if result.returncode != 0:
        return {}

    states = {}
    for line in result.stdout.splitlines():
        device, separator, state = line.partition(":")
        if separator:
            states[device] = "up" if state.startswith("connected") else "down"
    return states


def read_wwan_metrics() -> tuple[int, str]:
    try:
        modem_list = subprocess.run(
            ["/usr/bin/mmcli", "-L"],
            capture_output=True,
            check=False,
            text=True,
            timeout=2,
        )
    except OSError, subprocess.TimeoutExpired:
        return 0, "—"
    if modem_list.returncode != 0:
        return 0, "—"

    modem_id = None
    for line in modem_list.stdout.splitlines():
        for field in line.split():
            if "/Modem/" in field:
                modem_id = field.rstrip(".,:").rsplit("/", maxsplit=1)[-1]
                break
        if modem_id is not None:
            break
    if modem_id is None:
        return 0, "—"

    try:
        modem_info = subprocess.run(
            ["/usr/bin/mmcli", "-m", modem_id, "--output-keyvalue"],
            capture_output=True,
            check=False,
            text=True,
            timeout=2,
        )
    except OSError, subprocess.TimeoutExpired:
        return 0, "—"
    if modem_info.returncode != 0:
        return 0, "—"

    signal_percent = 0
    technology = "—"
    for line in modem_info.stdout.splitlines():
        key, separator, value = line.partition(":")
        if not separator:
            continue
        key = key.strip()
        if key == "modem.generic.signal-quality.value":
            try:
                signal_percent = max(0, min(100, int(float(value.strip()))))
            except ValueError:
                signal_percent = 0
        elif key == "modem.generic.access-technologies" or key.startswith(
            "modem.generic.access-technologies.value["
        ):
            access = value.strip().lower()
            if "5gnr" in access or "nr5g" in access or "5g-nr" in access:
                technology = "5G"
            elif "lte" in access:
                technology = "LTE"
            elif any(mode in access for mode in ("umts", "hspa", "wcdma")):
                technology = "3G"
            elif any(mode in access for mode in ("edge", "gprs", "gsm")):
                technology = "2G"
    return signal_percent, technology


def read_wireless_metrics(name: str) -> tuple[int, str]:
    if IW_COMMAND is None:
        return 0, "—"

    try:
        result = subprocess.run(
            [IW_COMMAND, "dev", name, "link"],
            capture_output=True,
            check=False,
            text=True,
            timeout=2,
        )
    except OSError, subprocess.TimeoutExpired:
        return 0, "—"
    if result.returncode != 0:
        return 0, "—"

    signal_percent = 0
    frequency_mhz = 0
    connected = False
    for line in result.stdout.splitlines():
        line = line.strip()
        if line.startswith("Connected to "):
            connected = True
        elif line.startswith("freq:"):
            fields = line.split()
            if len(fields) > 1:
                try:
                    frequency_mhz = round(float(fields[1]))
                except ValueError:
                    frequency_mhz = 0
        elif line.startswith("signal:"):
            fields = line.split()
            if len(fields) < 2:
                continue
            try:
                signal_dbm = float(fields[1])
            except ValueError:
                continue
            signal_percent = max(0, min(100, round((signal_dbm + 100) * 2)))
    technology = wireless_frequency_band(frequency_mhz)
    return (signal_percent, technology) if connected else (0, "—")


def wireless_frequency_band(frequency_mhz: int) -> str:
    if 2400 <= frequency_mhz < 2500:
        return "2.4GHz"
    if 4900 <= frequency_mhz < 5925:
        return "5GHz"
    if 5925 <= frequency_mhz < 7125:
        return "6GHz"
    return "—"


def read_interface_radio_metrics(
    name: str,
) -> tuple[int | None, str | None]:
    if name == "wwan0":
        return read_wwan_metrics()
    if name == "eth0":
        return None, read_ethernet_link_mode(name)

    interface = Path("/sys/class/net") / name
    if not (interface / "wireless").is_dir():
        return None, None
    return read_wireless_metrics(name)


def read_network_stats() -> list[dict[str, int | float | str | None]]:
    now = time.time()
    network_manager_states = read_network_manager_states()
    try:
        previous = json.loads(NETWORK_STATE.read_text(encoding="utf-8"))
    except OSError, json.JSONDecodeError:
        previous = {}

    interfaces = []
    current = {}
    try:
        lines = Path("/proc/net/dev").read_text(encoding="utf-8").splitlines()[2:]
    except OSError:
        lines = []

    for line in lines:
        name, counters = line.split(":", maxsplit=1)
        values = counters.split()
        name = name.strip()
        received, transmitted = int(values[0]), int(values[8])
        current[name] = {"received": received, "transmitted": transmitted}
        if name not in NETWORK_INTERFACES:
            continue
        old = previous.get(name, {})
        elapsed = max(now - old.get("time", now), 0.001)
        signal_percent, technology = read_interface_radio_metrics(name)
        interface_state = (
            network_manager_states[name]
            if name in network_manager_states
            else read_interface_state(name)
        )
        interfaces.append(
            {
                "name": name,
                "received": received,
                "transmitted": transmitted,
                "state": interface_state,
                "signal_percent": signal_percent,
                "technology": technology,
                "receive_rate": max(0, received - old.get("received", received))
                / elapsed,
                "transmit_rate": max(
                    0, transmitted - old.get("transmitted", transmitted)
                )
                / elapsed,
            }
        )

    state = {name: {**counters, "time": now} for name, counters in current.items()}
    try:
        NETWORK_STATE.write_text(json.dumps(state), encoding="utf-8")
    except OSError:
        pass
    interface_order = {"eth0": 0, "wlp0s20f3": 1, "wwan0": 2}
    interfaces.sort(key=lambda interface: interface_order.get(interface["name"], 1))
    return interfaces


def read_filesystems() -> list[dict[str, int | str]]:
    filesystems = []
    for mount_point in MOUNT_POINTS:
        try:
            stats = os.statvfs(mount_point)
        except OSError:
            continue
        total = stats.f_blocks * stats.f_frsize
        available = stats.f_bavail * stats.f_frsize
        filesystems.append(
            {
                "mount": mount_point,
                "used": total - available,
                "total": total,
                "percent": (round((total - available) * 100 / total) if total else 0),
            }
        )
    return filesystems


def read_processes(sort_by: str) -> list[dict[str, int | float | str]]:
    try:
        result = subprocess.run(
            [
                "ps",
                "-eo",
                "pid=,comm=,pcpu=,pmem=",
                f"--sort=-{sort_by}",
            ],
            capture_output=True,
            check=False,
            text=True,
            timeout=2,
        )
    except OSError, subprocess.TimeoutExpired:
        return []

    processes = []
    for line in result.stdout.splitlines()[:10]:
        fields = line.split()
        if len(fields) < 4:
            continue
        processes.append(
            {
                "pid": int(fields[0]),
                "name": fields[1],
                "cpu": float(fields[2]),
                "memory": float(fields[3]),
            }
        )
    return processes


def read_battery(battery: Path) -> dict[str, float | int | str | None]:
    def read_number(name: str) -> int:
        try:
            return int((battery / name).read_text(encoding="utf-8").strip())
        except OSError, ValueError:
            return 0

    capacity = read_number("capacity") if (battery / "capacity").exists() else None
    energy = read_number("energy_now")
    energy_full = read_number("energy_full")
    energy_full_design = read_number("energy_full_design")
    charge = read_number("charge_now")
    charge_full = read_number("charge_full")
    charge_full_design = read_number("charge_full_design")
    power = abs(read_number("power_now"))
    current = abs(read_number("current_now"))
    voltage = read_number("voltage_now")
    energy_wh = None
    if (battery / "energy_now").exists():
        energy_wh = energy / 1_000_000
    elif (battery / "charge_now").exists() and voltage:
        energy_wh = charge * voltage / 1_000_000_000_000
    energy_full_wh = (
        energy_full / 1_000_000
        if energy_full
        else (
            charge_full * voltage / 1_000_000_000_000
            if charge_full and voltage
            else None
        )
    )
    energy_full_design_wh = (
        energy_full_design / 1_000_000
        if energy_full_design
        else (
            charge_full_design * voltage / 1_000_000_000_000
            if charge_full_design and voltage
            else None
        )
    )
    try:
        status = (battery / "status").read_text(encoding="utf-8").strip()
    except OSError:
        status = "Unknown"

    upower_rate = None
    try:
        upower_result = subprocess.run(
            [
                "upower",
                "-i",
                f"/org/freedesktop/UPower/devices/battery_{battery.name}",
            ],
            capture_output=True,
            check=False,
            text=True,
            timeout=1,
        )
    except OSError, subprocess.TimeoutExpired:
        pass
    else:
        if upower_result.returncode == 0:
            for line in upower_result.stdout.splitlines():
                key, separator, value = line.strip().partition(":")
                if key == "energy-rate" and separator:
                    try:
                        upower_rate = float(value.strip().split()[0].replace(",", "."))
                    except ValueError, IndexError:
                        pass
                    break

    power_w = (
        power / 1_000_000
        if power
        else (
            current * voltage / 1_000_000_000_000
            if current and voltage
            else upower_rate
        )
    )
    if energy_full:
        level, full = energy, energy_full
        rate = power or (round(power_w * 1_000_000) if power_w is not None else 0)
    elif charge_full:
        level, full = charge, charge_full
        rate = current or (
            round(power_w * 1_000_000_000_000 / voltage)
            if power_w is not None and voltage
            else 0
        )
    else:
        level, full, rate = 0, 0, 0

    remaining = (
        level
        if status == "Discharging"
        else max(full - level, 0) if status == "Charging" else 0
    )

    return {
        "name": battery.name,
        "capacity": capacity,
        "energy_wh": round(energy_wh, 1) if energy_wh is not None else None,
        "energy_full_wh": (
            round(energy_full_wh, 1) if energy_full_wh is not None else None
        ),
        "energy_full_design_wh": (
            round(energy_full_design_wh, 1)
            if energy_full_design_wh is not None
            else None
        ),
        "status": status,
        "power_w": round(power_w, 1) if power_w is not None else None,
        "health": (
            round(energy_full * 100 / energy_full_design) if energy_full_design else 0
        ),
        "minutes_remaining": int(remaining * 60 / rate) if rate else 0,
    }


def read_batteries() -> list[dict[str, float | int | str | None]]:
    return [
        read_battery(battery)
        for battery in sorted(Path("/sys/class/power_supply").glob("BAT*"))
    ]


def collect() -> dict:
    try:
        uptime_seconds = float(
            Path("/proc/uptime").read_text(encoding="utf-8").split()[0]
        )
    except OSError, ValueError, IndexError:
        uptime_seconds = 0
    try:
        load_average = Path("/proc/loadavg").read_text(encoding="utf-8").split()[:3]
    except OSError:
        load_average = []

    external = read_external_variables()
    external["gpu_freq_sclk_max"] = read_gpu_max_frequency()
    cpu_count = (
        len(os.sched_getaffinity(0))
        if hasattr(os, "sched_getaffinity")
        else (os.cpu_count() or 1)
    )
    batteries = read_batteries()

    return {
        "external": external,
        "versions": read_system_versions(),
        "cpu_count": cpu_count,
        "uptime_seconds": int(uptime_seconds),
        "load_average": load_average,
        "filesystems": read_filesystems(),
        "interfaces": read_network_stats(),
        "network_route": read_network_route(),
        "nvme_rates": read_nvme_rates(),
        "top_cpu": read_processes("pcpu"),
        "top_memory": read_processes("pmem"),
        "battery": batteries[0] if batteries else None,
        "batteries": batteries,
    }


if __name__ == "__main__":
    if "--refresh-hosts-status" in sys.argv:
        refresh_hosts_status()
        sys.exit()
    if "--refresh-hosts-updates" in sys.argv:
        refresh_hosts_updates()
        sys.exit()
    print(json.dumps(collect(), ensure_ascii=False, separators=(",", ":")))
