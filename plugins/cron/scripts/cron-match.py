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


def _cron_dow(dt):
    # Python's weekday(): Mon=0..Sun=6 ; cron: Sun=0..Sat=6
    return (dt.weekday() + 1) % 7


def _day_matches(dt, parsed):
    _, _, dom, _, dow, dom_r, dow_r = parsed
    dom_match = dt.day in dom
    dow_match = _cron_dow(dt) in dow
    if dom_r and dow_r:
        # crontab(5): if both restricted, match is OR
        return dom_match or dow_match
    return dom_match and dow_match


def matches(dt, parsed):
    minute, hour, _, month, _, _, _ = parsed
    if dt.minute not in minute:
        return False
    if dt.hour not in hour:
        return False
    if dt.month not in month:
        return False
    return _day_matches(dt, parsed)


def _prev_allowed(values, current):
    """Return the largest v in values with v <= current, or None."""
    for v in reversed(values):
        if v <= current:
            return v
    return None


def _days_in_month(year, month):
    if month == 12:
        next_month = datetime(year + 1, 1, 1)
    else:
        next_month = datetime(year, month + 1, 1)
    return (next_month - timedelta(days=1)).day


def prev_tick(expr, now_epoch, lookback_minutes=4 * 366 * 24 * 60):
    """Return epoch seconds of most recent matching minute <= now_epoch.

    Searches backwards using field-aware jumps rather than minute-by-minute,
    so sparse expressions (e.g. yearly) resolve in microseconds instead of
    iterating up to half a million minutes. Returns None if no match found
    within lookback_minutes.
    """
    parsed = parse_cron(expr)
    minute_set, hour_set, _, month_set, _, _, _ = parsed
    allowed_minutes = sorted(minute_set)
    allowed_hours = sorted(hour_set)
    allowed_months = sorted(month_set)

    dt = datetime.fromtimestamp(now_epoch).replace(second=0, microsecond=0)
    min_dt = dt - timedelta(minutes=lookback_minutes)

    while dt >= min_dt:
        # Month mismatch: jump to the last minute of the previous allowed month.
        if dt.month not in month_set:
            prev_month = _prev_allowed(allowed_months, dt.month - 1)
            year = dt.year
            if prev_month is None:
                prev_month = allowed_months[-1]
                year -= 1
            dt = datetime(
                year, prev_month, _days_in_month(year, prev_month), 23, 59
            )
            continue

        # Day mismatch (DOM/DOW OR-rule handled in _day_matches): jump to
        # the last minute of the previous day.
        if not _day_matches(dt, parsed):
            dt = datetime(dt.year, dt.month, dt.day, 0, 0) - timedelta(minutes=1)
            continue

        # Hour mismatch: jump to the previous allowed hour within this day,
        # or roll into the previous day.
        if dt.hour not in hour_set:
            prev_hour = _prev_allowed(allowed_hours, dt.hour - 1)
            if prev_hour is not None:
                dt = dt.replace(hour=prev_hour, minute=59)
            else:
                dt = datetime(dt.year, dt.month, dt.day, 0, 0) - timedelta(
                    minutes=1
                )
            continue

        # Minute mismatch: jump to the previous allowed minute within the
        # hour, or roll into the previous hour.
        if dt.minute not in minute_set:
            prev_minute = _prev_allowed(allowed_minutes, dt.minute - 1)
            if prev_minute is not None:
                dt = dt.replace(minute=prev_minute)
            else:
                dt = dt.replace(minute=0) - timedelta(minutes=1)
            continue

        return int(dt.timestamp())

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
