"""
One-time repair script for camerounhopitals.xlsx.

The source file has French accented characters mangled (e.g. "Santé" stored
as "Sant├⌐"). This is the classic signature of UTF-8 bytes being decoded as
CP437 (DOS/OEM code page) at some point in the data's history — the fix is
to reverse that: re-encode as CP437, then decode as UTF-8.

Run once with:
    python fix_encoding.py
It overwrites camerounhopitals.xlsx in place after backing up the original
to camerounhopitals.xlsx.bak.
"""
import shutil
import pandas as pd

SOURCE = "camerounhopitals.xlsx"
BACKUP = "camerounhopitals.xlsx.bak"
TEXT_COLUMNS = ["Facility_n", "Facility_t", "Admin1", "Ownership"]


def fix_mojibake(value):
    if not isinstance(value, str):
        return value
    try:
        repaired = value.encode("cp437").decode("utf-8")
    except (UnicodeDecodeError, UnicodeEncodeError):
        # Value wasn't actually mis-decoded this way — leave it alone.
        return value
    return repaired


def main():
    shutil.copy(SOURCE, BACKUP)
    df = pd.read_excel(SOURCE)

    for col in TEXT_COLUMNS:
        if col in df.columns:
            df[col] = df[col].apply(fix_mojibake)

    df.to_excel(SOURCE, index=False)

    remaining = 0
    for col in TEXT_COLUMNS:
        if col in df.columns:
            remaining += df[col].astype(str).str.contains("├|┬", na=False).sum()

    print(f"Repaired {SOURCE}. Backup saved to {BACKUP}.")
    print(f"Remaining suspicious mojibake markers: {remaining}")


if __name__ == "__main__":
    main()
