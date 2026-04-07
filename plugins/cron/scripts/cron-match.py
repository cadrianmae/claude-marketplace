#!/usr/bin/env python3
"""Cron expression matcher.

Computes the most recent matching minute <= a given epoch timestamp,
following exact crontab(5) semantics:

- 5 fields: minute(0-59) hour(0-23) day-of-month(1-31) month(1-12) day-of-week(0-7, 0|7=Sun)
- Operators: *, a-b, a,b, */n, a-b/n
- Named months (jan-dec) and days (sun-sat), case-insensitive
- If both day-of-month and day-of-week are restricted (neither is *),
  the match is OR (per crontab(5)), not AND

Usage:
    cron-match.py "<cron-expr>" <now-epoch-seconds>

Output:
    Epoch seconds (integer) of most recent matching minute on stdout.
    Empty output if no match within lookback window.
    Non-zero exit on parse error (message on stderr).
"""

import sys
from datetime import datetime, timedelta

MONTH_NAMES = {
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
    "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
}
DOW_NAMES = {
    "sun": 0, "mon": 1, "tue": 2, "wed": 3, "thu": 4, "fri": 5, "sat": 6,
}


def parse_field(expr, lo, hi, names=None):
    """Parse one cron field into a set of valid integers in [lo, hi]."""
    expr = expr.strip()
    if names:
        lower = expr.lower()
        # Replace longer names first to avoid partial collisions
        for name in sorted(names, key=len, reverse=True):
            lower = lower.replace(name, str(names[name]))
        expr = lower

    result = set()
    for part in expr.split(","):
        step = 1
        if "/" in part:
            part, step_str = part.split("/", 1)
            step = int(step_str)
            if step <= 0:
                raise ValueError(f"step must be positive: {step}")

        if part == "*":
            start, end = lo, hi
        elif "-" in part:
            a, b = part.split("-", 1)
            start, end = int(a), int(b)
        else:
            start = int(part)
            # "N/step" means "N, N+step, N+2*step, ... up to hi"
            end = hi if step != 1 else start

        if start < lo or end > hi or start > end:
            raise ValueError(
                f"value out of range [{lo},{hi}]: {part!r} -> {start}-{end}"
            )
        for v in range(start, end + 1, step):
            result.add(v)
    return result


def parse_cron(expr):
    fields = expr.split()
    if len(fields) != 5:
        raise ValueError(f"expected 5 fields, got {len(fields)}: {expr!r}")
    minute = parse_field(fields[0], 0, 59)
    hour   = parse_field(fields[1], 0, 23)
    dom    = parse_field(fields[2], 1, 31)
    month  = parse_field(fields[3], 1, 12, MONTH_NAMES)
    dow    = parse_field(fields[4], 0, 7, DOW_NAMES)
    # Normalize 7 -> 0 (Sunday)
    if 7 in dow:
        dow.discard(7)
        dow.add(0)
    dom_restricted = fields[2] != "*"
    dow_restricted = fields[4] != "*"
    return minute, hour, dom, month, dow, dom_restricted, dow_restricted


def matches(dt, parsed):
    minute, hour, dom, month, dow, dom_r, dow_r = parsed
    if dt.minute not in minute:
        return False
    if dt.hour not in hour:
        return False
    if dt.month not in month:
        return False
    # Python's weekday(): Mon=0..Sun=6 ; cron: Sun=0..Sat=6
    cron_dow = (dt.weekday() + 1) % 7
    dom_match = dt.day in dom
    dow_match = cron_dow in dow
    if dom_r and dow_r:
        # crontab(5): if both restricted, match is OR
        return dom_match or dow_match
    return dom_match and dow_match


def prev_tick(expr, now_epoch, lookback_minutes=366 * 24 * 60):
    """Return epoch seconds of most recent matching minute <= now_epoch.

    Searches backwards minute by minute up to lookback_minutes.
    Returns None if no match found in window.
    """
    parsed = parse_cron(expr)
    dt = datetime.fromtimestamp(now_epoch).replace(second=0, microsecond=0)
    for _ in range(lookback_minutes + 1):
        if matches(dt, parsed):
            return int(dt.timestamp())
        dt -= timedelta(minutes=1)
    return None


def main():
    if len(sys.argv) != 3:
        print("usage: cron-match.py '<cron-expr>' <now-epoch>", file=sys.stderr)
        sys.exit(2)
    try:
        tick = prev_tick(sys.argv[1], int(sys.argv[2]))
    except ValueError as e:
        print(f"cron parse error: {e}", file=sys.stderr)
        sys.exit(1)
    if tick is not None:
        print(tick)


if __name__ == "__main__":
    main()
