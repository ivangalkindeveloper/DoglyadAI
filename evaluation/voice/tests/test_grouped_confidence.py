from __future__ import annotations

import pytest

from evaluation.voice.scoring.grouped_confidence import grouped_confidence


def test_related_copies_do_not_create_independent_clusters() -> None:
    rows = [{"clusterId": "a", "numerator": 1, "denominator": 1}, {"clusterId": "b", "numerator": 0, "denominator": 1}]
    first = grouped_confidence(rows, samples=200)
    repeated = grouped_confidence(rows * 10, samples=200)
    assert first == repeated
    assert first["clusters"] == 2 and first["estimate"] == 0.5


def test_unannotated_or_single_cluster_does_not_get_an_interval() -> None:
    assert grouped_confidence([{"numerator": 1, "denominator": 1}])["status"] == "missingClusterIds"
    assert grouped_confidence([{"clusterId": "a", "numerator": -1, "denominator": 1}])["interval95"] is None


@pytest.mark.parametrize("numerator,denominator", [(float("nan"), 1), (1, float("inf")), (1, -1), (True, 1), (1, 0)])
def test_invalid_observations_are_rejected(numerator: float, denominator: float) -> None:
    with pytest.raises(ValueError):
        grouped_confidence([{"clusterId": "a", "numerator": numerator, "denominator": denominator}])


def test_zero_denominator_does_not_invent_an_independent_cluster() -> None:
    result = grouped_confidence(
        [{"clusterId": "a", "numerator": 1, "denominator": 1}, {"clusterId": "empty", "numerator": 0, "denominator": 0}]
    )
    assert result["clusters"] == 1 and result["interval95"] is None
