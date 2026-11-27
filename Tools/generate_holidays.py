"""Rebuild the offline snapshot: uv run --with holidays==0.109 Tools/generate_holidays.py"""

import json
from importlib.metadata import distribution
from pathlib import Path

import holidays

ROOT = Path(__file__).resolve().parents[1] / "MagnetBoard"
YEARS = range(2025, 2031)
VERSION = "0.109"


def generate():
    if holidays.__version__ != VERSION:
        raise SystemExit(f"Expected holidays {VERSION}, got {holidays.__version__}")
    calendars = {}
    for country, regions in sorted(holidays.list_supported_countries(include_aliases=False).items()):
        for region in [None, *(regions if country in ("DE", "GB") else [])]:
            dates = holidays.country_holidays(country, subdiv=region, years=YEARS, language="en_US")
            entries = {d.isoformat(): title for d, title in sorted(dates.items()) if d.year in YEARS}
            if entries:
                calendars[country if not region else f"{country}-{region}"] = entries
    payload = {"version": VERSION, "firstYear": YEARS.start, "lastYear": YEARS.stop - 1, "calendars": calendars}
    (ROOT / "TravelHolidays.json").write_text(json.dumps(payload, ensure_ascii=False, sort_keys=True, indent=1) + "\n",
                                             encoding="utf-8", newline="\n")
    dist = distribution("holidays")
    license_path = next(path for path in dist.files if str(path).endswith("/licenses/LICENSE"))
    (ROOT / "HolidayCalendarLicense.txt").write_bytes(dist.locate_file(license_path).read_bytes())
    print(f"{len(calendars)} calendars, {sum(map(len, calendars.values()))} holiday dates")


if __name__ == "__main__":
    generate()
