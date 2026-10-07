from __future__ import annotations

# ruff: noqa: RUF001
import re

# A deliberately bounded number grammar, shared by source verification only.
# Unrecognised words are not discarded: the caller must retain review status.
_EN: dict[str, int] = dict(
    zip(
        [
            "zero",
            "one",
            "two",
            "three",
            "four",
            "five",
            "six",
            "seven",
            "eight",
            "nine",
            "ten",
            "eleven",
            "twelve",
            "thirteen",
            "fourteen",
            "fifteen",
            "sixteen",
            "seventeen",
            "eighteen",
            "nineteen",
        ],
        range(20),
        strict=True,
    )
)
_EN.update(
    dict(
        zip(
            ["twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"],
            range(20, 100, 10),
            strict=True,
        )
    )
)
_RU: dict[str, int] = dict(
    zip(
        [
            "ноль",
            "один",
            "два",
            "три",
            "четыре",
            "пять",
            "шесть",
            "семь",
            "восемь",
            "девять",
            "десять",
            "одиннадцать",
            "двенадцать",
            "тринадцать",
            "четырнадцать",
            "пятнадцать",
            "шестнадцать",
            "семнадцать",
            "восемнадцать",
            "девятнадцать",
        ],
        range(20),
        strict=True,
    )
)
_RU.update(
    dict(
        zip(
            ["двадцать", "тридцать", "сорок", "пятьдесят", "шестьдесят", "семьдесят", "восемьдесят", "девяносто"],
            range(20, 100, 10),
            strict=True,
        )
    )
)
_RU.update(
    dict(
        zip(
            ["сто", "двести", "триста", "четыреста", "пятьсот", "шестьсот", "семьсот", "восемьсот", "девятьсот"],
            range(100, 1000, 100),
            strict=True,
        )
    )
)
_RU.update({"одна": 1, "две": 2})
_ORDINALS: dict[str, int] = dict(
    zip(
        [
            "first",
            "second",
            "third",
            "fourth",
            "fifth",
            "sixth",
            "seventh",
            "eighth",
            "ninth",
            "tenth",
            "eleventh",
            "twelfth",
            "thirteenth",
            "fourteenth",
            "fifteenth",
            "sixteenth",
            "seventeenth",
            "eighteenth",
            "nineteenth",
            "twentieth",
            "thirtieth",
            "fortieth",
            "fiftieth",
            "sixtieth",
            "seventieth",
            "eightieth",
            "ninetieth",
        ],
        [*range(1, 20), *range(20, 100, 10)],
        strict=True,
    )
)
for _stem, _value in zip(
    [
        "перв",
        "втор",
        "треть",
        "четвёрт",
        "пят",
        "шест",
        "седьм",
        "восьм",
        "девят",
        "десят",
        "одиннадцат",
        "двенадцат",
        "тринадцат",
        "четырнадцат",
        "пятнадцат",
        "шестнадцат",
        "семнадцат",
        "восемнадцат",
        "девятнадцат",
        "двадцат",
        "тридцат",
        "сороков",
        "пятидесят",
        "шестидесят",
        "семидесят",
        "восьмидесят",
        "девяност",
    ],
    [*range(1, 20), *range(20, 100, 10)],
    strict=True,
):
    for _ending in ("ое", "ого", "ый", "ой", "ая"):
        _ORDINALS[_stem + _ending] = _value
_ORDINALS.update({"третье": 3, "третьего": 3, "двухтысячного": 2000, "двухтысячный": 2000, "девятисотого": 900})
_WORDS: dict[str, int] = {**_EN, **_RU, **_ORDINALS}
_SCALE: dict[str, int] = {"hundred": 100, "thousand": 1000, "тысяча": 1000, "тысячи": 1000}
NUMBER_TOKEN = (
    "(?:"
    + "|".join(re.escape(word).replace("ё", "[её]") for word in sorted([*_WORDS, *_SCALE], key=len, reverse=True))
    + r"|\d+(?:[.,]\d+)?)"
)
NUMBER_PHRASE = NUMBER_TOKEN + r"(?:[\s-]+(?:and\s+)?" + NUMBER_TOKEN + r")*"


def _group(words: list[str]) -> int | None:
    if not words:
        return 0
    if "hundred" in words:
        if words.count("hundred") != 1 or words.index("hundred") != 1:
            return None
        leading = _WORDS.get(words[0], -1)
        tail = _group(words[2:])
        return leading * 100 + tail if 1 <= leading <= 9 and tail is not None and tail < 100 else None
    values = [_WORDS.get(word, -1) for word in words]
    if any(value < 0 for value in values) or len(values) > 3:
        return None
    if len(values) == 1:
        return values[0]
    # hundreds + tens + units, or hundreds + teens/units, or tens + units.
    if values[0] >= 100:
        if values[0] % 100 or values[0] > 900:
            return None
        tail = _group(words[1:])
        return values[0] + tail if tail is not None and 0 < tail < 100 else None
    if len(values) == 2 and 20 <= values[0] <= 90 and values[0] % 10 == 0 and 1 <= values[1] <= 9:
        return sum(values)
    return None


def source_number(text: str) -> float | None:
    """Parse a complete RU/EN cardinal/ordinal phrase; never skip unknown text."""
    text = text.casefold().replace("ё", "е").strip()
    words_map = {key.replace("ё", "е"): value for key, value in _WORDS.items()}
    if re.fullmatch(r"\d+(?:[.,]\d+)?", text):
        return float(text.replace(",", "."))
    decimal = re.split(r"\s+(?:point|запятая)\s+", text)
    if len(decimal) == 2:
        whole = source_number(decimal[0])
        digits = [words_map.get(word, -1) for word in decimal[1].split()]
        if whole is None or not digits or any(not 0 <= digit <= 9 for digit in digits):
            return None
        return whole + float("0." + "".join(map(str, digits)))
    if len(decimal) != 1:
        return None
    words = [word for word in re.split(r"[\s-]+", text) if word != "and"]
    # Canonicalise the two spellings of the Russian vowel, preserving unknown words.
    canonical = {key.replace("ё", "е"): key for key in _WORDS}
    words = [canonical.get(word, word) for word in words]
    scales = [index for index, word in enumerate(words) if _SCALE.get(word) == 1000]
    if scales:
        if len(scales) != 1:
            return None
        index = scales[0]
        leading = _group(words[:index]) if index else 1
        tail = _group(words[index + 1 :])
        return (
            float(leading * 1000 + tail)
            if leading is not None and 1 <= leading <= 9 and tail is not None and tail < 1000
            else None
        )
    value = _group(words)
    return float(value) if value is not None else None


def source_year(text: str) -> int | None:
    words = text.casefold().replace("-", " ").split()
    if words and words[0] in {"nineteen", "twenty"} and len(words) > 1 and words[1] != "thousand":
        tail = source_number(" ".join(words[1:]).removeprefix("oh "))
        value = _EN[words[0]] * 100 + tail if tail is not None and 0 <= tail < 100 else None
    else:
        value = source_number(text)
    return int(value) if value is not None and value.is_integer() and 1800 <= value <= 2099 else None
