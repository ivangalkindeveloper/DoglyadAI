from __future__ import annotations

import random
import math
from collections import defaultdict
from typing import Any


def grouped_confidence(rows: list[dict[str, Any]], *, seed: int = 20261025, samples: int = 2000) -> dict[str, Any]:
    """Percentile bootstrap of a ratio (or paired difference), resampling families.

    Each row supplies clusterId, numerator and denominator. For a paired
    difference, numerator is A - B on the SAME cases. Never infer independence
    from filenames or treat translated/noisy takes as independent patients.
    """
    if samples < 100:
        raise ValueError("At least 100 bootstrap samples are required")
    groups: dict[str, list[float]] = defaultdict(lambda: [0.0, 0.0])
    for row in rows:
        if any(
            isinstance(row.get(key), bool) or not isinstance(row.get(key), (int, float)) or not math.isfinite(row[key])
            for key in ("numerator", "denominator")
        ):
            raise ValueError("Bootstrap inputs must be finite numbers")
        if row["denominator"] < 0 or (row["denominator"] == 0 and row["numerator"] != 0):
            raise ValueError("Invalid denominator")
        if not row.get("clusterId"):
            return {"status": "missingClusterIds", "interval95": None}
        if row["denominator"] == 0:
            continue
        group = groups[row["clusterId"]]
        group[0] += row["numerator"]
        group[1] += row["denominator"]
    denominator = sum(value[1] for value in groups.values())
    point = sum(value[0] for value in groups.values()) / denominator if denominator else None
    result: dict[str, Any] = {
        "clusters": len(groups),
        "estimate": point,
        "interval95": None,
        "clusterMacroEstimate": sum(value[0] / value[1] for value in groups.values()) / len(groups) if groups else None,
    }
    if len(groups) < 2 or point is None:
        return {**result, "status": "insufficientClusters"}
    rng = random.Random(seed)
    values = list(groups.values())
    estimates = []
    for _ in range(samples):
        selected = rng.choices(values, k=len(values))
        total = sum(item[1] for item in selected)
        if total:
            estimates.append(sum(item[0] for item in selected) / total)
    estimates.sort()
    result.update(
        status="estimated",
        interval95=[estimates[int(0.025 * (len(estimates) - 1))], estimates[int(0.975 * (len(estimates) - 1))]],
        seed=seed,
        samples=samples,
        method="paired-cluster-percentile-bootstrap",
    )
    return result
