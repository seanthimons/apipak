"""Convert the downloaded primary corpus to temporary JSON without resolving refs."""
import csv
import datetime
import json
from pathlib import Path
import sys

from ruamel.yaml import YAML


def prepare(root, output):
    root, output = Path(root), Path(output)
    output.mkdir(parents=True, exist_ok=True)
    yaml = YAML(typ="safe")
    yaml.version = (1, 2)
    with (root / "manifest.csv").open(encoding="utf-8-sig", newline="") as stream:
        entries = [row for row in csv.DictReader(stream) if row["tier"] != "reference"]
    rows = []
    for i, entry in enumerate(entries, 1):
        source = root / entry["file"]
        target = output / f"{i:02}.json"
        error = ""
        try:
            with source.open(encoding="utf-8") as stream:
                doc = json.load(stream) if source.suffix == ".json" else yaml.load(stream)
            def date_string(value):
                if isinstance(value, (datetime.date, datetime.datetime)):
                    return value.isoformat()
                raise TypeError(type(value).__name__)
            target.write_text(json.dumps(doc, ensure_ascii=False, allow_nan=False,
                                         default=date_string), encoding="utf-8")
        except Exception as exc:
            error = str(exc)
        rows.append(dict(entry, source=str(source), prepared=str(target), conversion_error=error))
    with (output / "inputs.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    assert len(rows) == 33 and len({row["source"] for row in rows}) == 33


if __name__ == "__main__":
    prepare(*sys.argv[1:])
