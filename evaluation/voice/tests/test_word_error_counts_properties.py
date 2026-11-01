import random

from evaluation.voice.scoring.word_error_counts import word_error_counts


def test_counts_against_separate_full_matrix_reference() -> None:
    rng = random.Random(99137)
    for _ in range(1500):
        a = tuple(rng.choices(("a", "b", "12", "-", "mm"), k=rng.randrange(18)))
        b = tuple(rng.choices(("a", "b", "12", "-", "mm"), k=rng.randrange(18)))
        matrix = [[0] * (len(b) + 1) for _ in range(len(a) + 1)]
        for i in range(len(a) + 1):
            matrix[i][0] = i
        for j in range(len(b) + 1):
            matrix[0][j] = j
        for i in range(1, len(a) + 1):
            for j in range(1, len(b) + 1):
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1, matrix[i][j - 1] + 1, matrix[i - 1][j - 1] + (a[i - 1] != b[j - 1])
                )
        score = word_error_counts(a, b)
        assert (
            score["errors"] == matrix[-1][-1] == sum(score[key] for key in ("substitutions", "deletions", "insertions"))
        )
