"""
Tekrar kontrolü - tamamen yerel, ücretsiz, ek servis gerektirmez.

İki ölçüm birlikte kullanılır:
  * kelime 3'lü kalıpları (aynı ifade dizilerini yakalar)
  * karakter 5'li kalıpları (eklerle değişmiş ama aynı cümleleri yakalar)
"""
from __future__ import annotations

import re
import unicodedata

_TR = str.maketrans({"İ": "i", "I": "ı"})


def normalize(text: str) -> str:
    t = text.translate(_TR).lower()
    t = unicodedata.normalize("NFC", t)
    t = re.sub(r"[^\w\s]", " ", t)
    return re.sub(r"\s+", " ", t).strip()


def word_ngrams(text: str, n: int = 3) -> set[str]:
    w = normalize(text).split()
    return {" ".join(w[i:i + n]) for i in range(max(0, len(w) - n + 1))}


def char_ngrams(text: str, n: int = 5) -> set[str]:
    t = normalize(text).replace(" ", "_")
    return {t[i:i + n] for i in range(max(0, len(t) - n + 1))}


def jaccard(a: set[str], b: set[str]) -> float:
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def similarity(a: str, b: str) -> float:
    return max(jaccard(word_ngrams(a), word_ngrams(b)) * 1.6,
               jaccard(char_ngrams(a), char_ngrams(b)))


def shared_phrases(a: str, b: str, n: int = 4) -> list[str]:
    """İki metnin ortak 4+ kelimelik ifadeleri (yapay zekâya geri bildirim için)."""
    return sorted(word_ngrams(a, n) & word_ngrams(b, n))


def first_words(text: str, k: int = 3) -> str:
    return " ".join(normalize(text).split()[:k])
