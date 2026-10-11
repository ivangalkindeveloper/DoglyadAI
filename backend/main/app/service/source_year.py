from __future__ import annotations

from app.service.source_number import _EN, source_number


def source_year(text: str) -> int | None:
    words = text.casefold().replace("-", " ").split()
    if words and words[0] in {"nineteen", "twenty"} and len(words) > 1 and words[1] != "thousand":
        tail = source_number(" ".join(words[1:]).removeprefix("oh "))
        value = _EN[words[0]] * 100 + tail if tail is not None and 0 <= tail < 100 else None
    else:
        value = source_number(text)
    return int(value) if value is not None and value.is_integer() and 1800 <= value <= 2099 else None
