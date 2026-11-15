from __future__ import annotations

import re
import unicodedata
from datetime import date
from decimal import Decimal
from functools import lru_cache

# Independent of the production parser: shared defects must not become agreement
# between the system and its oracle. This is display normalization, not inference.
_ONES = {
    "en": "zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen".split(),
    "ru": "ноль один два три четыре пять шесть семь восемь девять десять одиннадцать двенадцать тринадцать четырнадцать пятнадцать шестнадцать семнадцать восемнадцать девятнадцать".split(),
}
_TENS = {
    "en": ["", "", *"twenty thirty forty fifty sixty seventy eighty ninety".split()],
    "ru": ["", "", *"двадцать тридцать сорок пятьдесят шестьдесят семьдесят восемьдесят девяносто".split()],
}
_HUNDREDS_RU = "сто двести триста четыреста пятьсот шестьсот семьсот восемьсот девятьсот".split()
_ORDINALS = {
    "en": "first second third fourth fifth sixth seventh eighth ninth tenth eleventh twelfth thirteenth fourteenth fifteenth sixteenth seventeenth eighteenth nineteenth".split(),
    "ru": "первый второй третий четвертый пятый шестой седьмой восьмой девятый десятый одиннадцатый двенадцатый тринадцатый четырнадцатый пятнадцатый шестнадцатый семнадцатый восемнадцатый девятнадцатый".split(),
}
_ORDINAL_TENS = {
    "en": "twentieth thirtieth fortieth fiftieth sixtieth seventieth eightieth ninetieth".split(),
    "ru": "двадцатый тридцатый сороковой пятидесятый шестидесятый семидесятый восьмидесятый девяностый".split(),
}
_MONTHS = {
    "en": "january february march april may june july august september october november december".split(),
    "ru": "января февраля марта апреля мая июня июля августа сентября октября ноября декабря".split(),
}
_UNITS = {
    "mm": "mm мм millimeter millimeters millimetre millimetres миллиметр миллиметра миллиметров миллиметры",
    "cm": "cm см centimeter centimeters centimetre centimetres сантиметр сантиметра сантиметров сантиметры",
    "m": "m м meter meters metre metres метр метра метров",
    "kg": "kg кг kilogram kilograms килограмм килограмма килограммов килограммы",
    "g": "g г gram grams грамм грамма граммов",
    "ml": "ml мл milliliter milliliters millilitre millilitres миллилитр миллилитра миллилитров",
    "%": "% percent percentage процентов процента процент",
    "°": "° degree degrees градус градуса градусов",
}
_UNIT_LOOKUP = {word: unit for unit, words in _UNITS.items() for word in words.split()}
_TOKEN = re.compile(
    r"\d{4}-\d{2}-\d{2}|\d{1,2}\.\d{1,2}\.\d{4}|\d+(?:[.,]\d+)?|[^\W\d_]+|[.,;:/+−\-–—×%²³<>=°±≈~*^]", re.UNICODE
)


def _ordinal_forms(word: str, locale: str) -> tuple[str, ...]:
    if locale == "en":
        return (word,)
    if word == "третий":
        return (word, "третье", "третьего")
    return (word, word[:-2] + "ого", word[:-2] + "ое")


@lru_cache(maxsize=2)
def _number_vocabulary(locale: str) -> dict[tuple[str, ...], str]:
    vocabulary: dict[tuple[str, ...], str] = {}
    for value in range(1000):
        hundreds, rest = divmod(value, 100)
        head = []
        if hundreds:
            head = [_HUNDREDS_RU[hundreds - 1]] if locale == "ru" else [_ONES[locale][hundreds], "hundred"]
        if rest < 20:
            tail = [_ONES[locale][rest]] if rest or not head else []
        else:
            tail = [_TENS[locale][rest // 10]] + ([_ONES[locale][rest % 10]] if rest % 10 else [])
        variants = [head + tail]
        if locale == "en" and head and tail:
            variants.append(head + ["and"] + tail)
        if rest:
            ordinal = (
                _ORDINALS[locale][rest - 1]
                if rest < 20
                else (_ORDINALS[locale][rest % 10 - 1] if rest % 10 else _ORDINAL_TENS[locale][rest // 10 - 2])
            )
            variants.extend(head + tail[:-1] + [form] for form in _ordinal_forms(ordinal, locale))
        for variant in variants:
            vocabulary[tuple(variant)] = str(value)
            if locale == "ru" and variant[-1] in ("один", "два"):
                for form in ("одна", "одно") if variant[-1] == "один" else ("две",):
                    vocabulary[(*variant[:-1], form)] = str(value)
    if locale == "ru":
        vocabulary[("нуль",)] = "0"
    return vocabulary


def _small_number(tokens: list[str], start: int, locale: str) -> tuple[str, int] | None:
    vocabulary = _number_vocabulary(locale)
    for end in range(min(len(tokens), start + 6), start, -1):
        if (value := vocabulary.get(tuple(tokens[start:end]))) is not None:
            return value, end
    return None


def _number(tokens: list[str], start: int, locale: str) -> tuple[str, int] | None:
    token = tokens[start]
    if re.fullmatch(r"\d+(?:[.,]\d+)?", token):
        return token.replace(",", "."), start + 1
    digits = {word: str(index) for index, word in enumerate(_ONES[locale][:10])}
    end = start
    while end < len(tokens) and tokens[end] in digits:
        end += 1
    if end - start >= 2:
        return "".join(digits[word] for word in tokens[start:end]), end
    small = _small_number(tokens, start, locale)
    thousands = {"thousand"} if locale == "en" else {"тысяча", "тысячи", "тысяч"}
    if token in thousands:
        small = ("1", start)
    if small is None:
        if locale == "ru" and token in {"двухтысячного", "двухтысячный", "двухтысячное"}:
            return "2000", start + 1
        return None
    value, end = small
    if end < len(tokens) and tokens[end] in thousands:
        remainder = _small_number(tokens, end + 1, locale) if end + 1 < len(tokens) else None
        return str(int(value) * 1000 + (int(remainder[0]) if remainder else 0)), remainder[1] if remainder else end + 1
    return value, end


def _decimal(value: str) -> str:
    return format(Decimal(value).normalize(), "f") if "." in value else value


def _numbers(tokens: list[str], locale: str) -> list[str]:
    result: list[str] = []
    index = 0
    while index < len(tokens):
        parsed = _number(tokens, index, locale)
        if parsed is None:
            result.append(tokens[index])
            index += 1
            continue
        value, end = parsed
        if end < len(tokens) and tokens[end] in {"point", "точка", "запятая"}:
            fraction = _number(tokens, end + 1, locale) if end + 1 < len(tokens) else None
            if fraction and fraction[0].isdigit():
                value, end = value + "." + fraction[0], fraction[1]
        elif end < len(tokens) and tokens[end] in {"целых", "целая", "целое", "целые"}:
            fraction = _number(tokens, end + 1, locale) if end + 1 < len(tokens) else None
            if fraction and fraction[1] < len(tokens):
                precision = {"десятая": 1, "десятых": 1, "сотая": 2, "сотых": 2, "тысячная": 3, "тысячных": 3}.get(
                    tokens[fraction[1]]
                )
                if precision and fraction[0].isdigit() and int(fraction[0]) < 10**precision:
                    value, end = value + "." + fraction[0].zfill(precision), fraction[1] + 1
        result.append(_decimal(value))
        index = end
    return result


def _valid_date(year: str, month: str, day: str) -> str | None:
    if not all(part.isdigit() for part in (year, month, day)) or len(year) != 4:
        return None
    try:
        return "date:" + date(int(year), int(month), int(day)).isoformat()
    except ValueError:
        return None


def _dates(tokens: list[str], locale: str) -> list[str]:
    months = {word: str(index) for index, word in enumerate(_MONTHS[locale], 1)}
    result: list[str] = []
    index = 0
    while index < len(tokens):
        token = tokens[index]
        is_birth_context = bool(
            set(tokens[max(0, index - 7) : index + 8]) & {"birth", "born", "рождения", "родился", "родилась"}
        )
        matched: str | None = None
        end = index + 1
        if re.fullmatch(r"\d{4}-\d{2}-\d{2}", token):
            matched = _valid_date(*token.split("-"))
        elif re.fullmatch(r"\d{1,2}\.\d{1,2}\.\d{4}", token) and locale == "ru":
            day, month, year = token.split(".")
            matched = _valid_date(year, month, day)
        elif len(token) == 8 and token.isdigit() and is_birth_context:
            matched = _valid_date(token[:4], token[4:6], token[6:])
        if matched is None:
            positions = [i for i in range(index, min(len(tokens), index + 9)) if tokens[i] not in {",", "the", "of"}]
            parts = [tokens[i] for i in positions]
            if len(parts) >= 3:
                if parts[0] in months:
                    month, day, year = months[parts[0]], parts[1], parts[2]
                elif parts[1] in months:
                    day, month, year = parts[0], months[parts[1]], parts[2]
                elif is_birth_context and len(parts[0]) == 4:
                    year, month, day = parts[:3]
                else:
                    year = month = day = ""
                year_end = 2
                if len(year) == 2 and year in {"19", "20"} and len(parts) > 3 and re.fullmatch(r"\d{2}", parts[3]):
                    year += parts[3]
                    year_end = 3
                matched = _valid_date(year, month, day)
                if matched:
                    end = positions[year_end] + 1
        if matched:
            result.append(matched)
            index = end + int(end < len(tokens) and tokens[end] in {"года", "год"})
        else:
            result.append(token)
            index += 1
    return result


@lru_cache(maxsize=32768)
def normalize_evaluation_text(text: str, locale: str, *, is_convert_units: bool = False) -> tuple[str, ...]:
    """Normalize explicit RU/EN written/spoken display forms, never clinical facts.

    Ambiguous slash dates and unsupported readings remain literal. Conversion of
    measurement units is opt-in for field comparison, not ordinary WER.
    """
    if locale not in _ONES:
        raise ValueError(f"Unsupported evaluation locale: {locale}")
    text = unicodedata.normalize("NFC", text).casefold().replace("ё", "е")
    text = text.replace("≤", "<=").replace("≥", ">=")
    text = re.sub(r"(?<=[a-zа-я])[-–](?=[a-zа-я])", " ", text)
    text = re.sub(
        r"\b(?:cm\s*/\s*s|cm\s+per\s+second|centimet(?:er|re)s?\s+per\s+second|см\s*/\s*с|см\s+в\s+секунду|сантиметр(?:ов|а|ы)?\s+в\s+секунду)\b",
        " speedunit ",
        text,
    )
    text = re.sub(
        r"\b(?:square millimet(?:er|re)s?|квадратн(?:ых|ый|ого) миллиметр(?:ов|а)?|mm[2²]|мм[2²])\b", " areaunit ", text
    )
    tokens = _dates(_numbers(_TOKEN.findall(text), locale), locale)
    tokens = [_UNIT_LOOKUP.get(token, token) for token in tokens if token not in {".", ",", ";", ":"}]
    tokens = ["-" if token in {"−", "–", "—"} else "×" if token == "x" else token for token in tokens]
    if is_convert_units:
        conversions = {"cm": ("mm", Decimal(10)), "m": ("mm", Decimal(1000)), "kg": ("g", Decimal(1000))}
        for i in range(1, len(tokens)):
            if tokens[i] in conversions and re.fullmatch(r"\d+(?:\.\d+)?", tokens[i - 1]):
                # Shared units on dimensions/ranges, area, volume and rates need
                # a dimension-aware grammar. Leave them literal rather than
                # converting only the last coordinate (11 x 5 cm != 11 x 50 mm).
                before = tokens[i - 2] if i >= 2 else None
                after = tokens[i + 1] if i + 1 < len(tokens) else None
                if before in {"×", "*", "^", "±", "by", "на", "to", "до", "/", "+", "-"} or after in {
                    "²",
                    "³",
                    "^",
                    "*",
                    "/",
                    "per",
                    "в",
                }:
                    continue
                if before and re.fullmatch(r"\d+(?:\.\d+)?", before):
                    continue
                unit, factor = conversions[tokens[i]]
                tokens[i - 1] = format((Decimal(tokens[i - 1]) * factor).normalize(), "f")
                tokens[i] = unit
    return tuple(tokens)
