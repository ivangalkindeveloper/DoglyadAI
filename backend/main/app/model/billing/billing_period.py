from __future__ import annotations

from enum import StrEnum


class BillingPeriod(StrEnum):
    WEEKLY = "weekly"
    MONTHLY = "monthly"
    SIX_MONTH = "sixMonth"
    ANNUAL = "annual"

    @property
    def interval_months(
        self,
    ) -> int:
        return {self.WEEKLY: 0, self.MONTHLY: 1, self.SIX_MONTH: 6, self.ANNUAL: 12}[self]

    @property
    def interval_days(
        self,
    ) -> int:
        return 7 if self is self.WEEKLY else 0

    @property
    def locale_key(
        self,
    ) -> str:
        return {
            self.WEEKLY: "paywallWeeklyLabel",
            self.MONTHLY: "paywallMonthlyLabel",
            self.SIX_MONTH: "paywallSixMonthLabel",
            self.ANNUAL: "paywallAnnualLabel",
        }[self]

    @classmethod
    def from_interval(
        cls,
        months: int,
        days: int,
    ) -> BillingPeriod:
        for period in cls:
            if (period.interval_months, period.interval_days) == (months, days):
                return period
        raise ValueError(
            "Unsupported billing period",
        )
