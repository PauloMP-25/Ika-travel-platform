from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone

from fastapi import Query

from src.modules.analytics.exceptions import (
    DateRangeTooLargeException,
    InvalidDateRangeException,
)

LIMA_TZ = timezone(timedelta(hours=-5))  # Perú no aplica horario de verano
MAX_RANGE_DAYS = 366
DEFAULT_RANGE_DAYS = 30


@dataclass(frozen=True, slots=True)
class DateRange:
    start: date
    end: date  # inclusivo

    @property
    def start_dt(self) -> datetime:
        return datetime.combine(self.start, time.min, tzinfo=LIMA_TZ)

    @property
    def end_dt_exclusive(self) -> datetime:
        return datetime.combine(self.end + timedelta(days=1), time.min, tzinfo=LIMA_TZ)


def get_date_range(
    date_from: date | None = Query(default=None),
    date_to: date | None = Query(default=None),
) -> DateRange:
    end = date_to or datetime.now(LIMA_TZ).date()
    start = date_from or end - timedelta(days=DEFAULT_RANGE_DAYS - 1)
    if start > end:
        raise InvalidDateRangeException()
    if (end - start).days + 1 > MAX_RANGE_DAYS:
        raise DateRangeTooLargeException()
    return DateRange(start=start, end=end)
