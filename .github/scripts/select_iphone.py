"""Read simctl's device inventory on stdin and print one compatible iPhone UDID."""

import json
import re
import sys


def select_iphone(devices, sdk):
    sdk_version = tuple(map(int, sdk.split(".")[:2]))
    candidates = []
    for runtime, entries in devices.items():
        match = re.fullmatch(r"com\.apple\.CoreSimulator\.SimRuntime\.iOS-(\d+)-(\d+)(?:-\d+)?", runtime)
        if not match:
            continue
        version = tuple(map(int, match.groups()))
        if not (17, 0) <= version <= sdk_version:
            continue
        for device in entries:
            if device.get("isAvailable") and device["name"].startswith("iPhone "):
                candidates.append((version, "Pro Max" in device["name"], device["name"], device["udid"]))
    if not candidates:
        raise SystemExit(f"No available iPhone with iOS 17 or later compatible with SDK {sdk}")
    return max(candidates)


if __name__ == "__main__":
    devices = json.load(sys.stdin)["devices"]
    version, _, name, udid = select_iphone(devices, sys.argv[1])
    if "--runtime" in sys.argv[2:]:
        print(next(runtime for runtime, entries in devices.items() if any(d["udid"] == udid for d in entries)))
        sys.exit(0)
    print(f"Testing on {name}, iOS {version[0]}.{version[1]} ({udid})", file=sys.stderr)
    print(udid)
