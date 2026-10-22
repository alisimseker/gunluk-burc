"""
Günlük burç içeriği üretici.

Her çalıştığında:
  1. Bugünden itibaren BUFFER_DAYS gün için eksik günleri bulur.
  2. Her gün için gerçek gökyüzünü hesaplar (sky.py).
  3. Ücretsiz Gemini API'ye 12 burcu tek istekte yazdırır.
  4. Yazılanları kontrol eder:
       - gezegen/burç iddiaları gerçek veriyle uyuşuyor mu (uydurma kontrolü)
       - geçmiş yorumlara ve aynı günün diğer burçlarına benziyor mu
       - motivasyon cümlesi daha önce kullanılmış mı
     Geçemeyen burçları, nedenini söyleyerek yeniden yazdırır.
  5. data/archive/ altına kaydeder, docs/v1/ altına uygulamanın okuyacağı JSON'ları yazar.

Kullanım:
  GEMINI_API_KEY=... python generate.py          # gerçek üretim
  python generate.py --mock                       # API anahtarı olmadan deneme
"""
from __future__ import annotations

import argparse
import json
import os
import random
import re
import sys
import time
import urllib.error
import urllib.request
from collections import Counter
from datetime import date, datetime, timedelta
from pathlib import Path

import similarity as sim
from sky import (BODIES, HOUSE_THEMES, SIGN_IDS, SIGN_LOC, SIGN_TR, TZ, Sky, compute_sky,
                 sign_brief, sky_summary)

ROOT = Path(__file__).resolve().parent.parent
ARCHIVE = ROOT / "data" / "archive"
PUBLIC = ROOT / "docs" / "v1"

BUFFER_DAYS = int(os.environ.get("BUFFER_DAYS", "8"))          # bugün + 7 gün
MAX_DAYS_PER_RUN = int(os.environ.get("MAX_DAYS_PER_RUN", "3"))  # ücretsiz kotayı korur
HISTORY_DAYS = 120
MAX_ROUNDS = 3

# Eşikler
TEXT_SIM_MAX = 0.30        # geçmiş yorumlarla benzerlik
SHORT_SIM_MAX = 0.45
MOTIVATION_SIM_MAX = 0.60
PLANET_NAMES = [n for _, n in BODIES]
SIGN_ID_TO_INDEX = {sid: i for i, sid in enumerate(SIGN_IDS)}

SYSTEM_PROMPT = """Sen deneyimli bir astrolog ve usta bir Türkçe yazarsın. Günlük burç yorumları yazıyorsun.

KESİN KURALLAR:
1. YALNIZCA sana verilen gerçek gökyüzü verisine dayan. Verilerde olmayan bir gezegen konumu, açı,
   retro, Yeniay/Dolunay veya burç geçişi ASLA uydurma. Bir gezegenden bahsediyorsan, verideki
   burcunu ve durumunu doğru yaz.
2. Her yorum o burcun o günkü verisinden en az bir somut astrolojik olayı temel alsın ve
   "basis" alanında bu olayı kısaca belirt.
3. Her burcun yorumu diğerlerinden tamamen farklı olsun: farklı konu, farklı açılış, farklı cümle yapısı.
4. Sana verilen "kullanma" listelerindeki açılışları, ifadeleri ve motivasyon cümlelerini tekrar etme,
   benzerlerini de yazma.
5. Ton: sıcak, samimi, net, pratik. "Sen" diye hitap et. Somut bir öneri ver.
   Korkutma, kehanet etme, kesin söz verme ("kesinlikle", "mutlaka olacak" gibi ifadeler yok).
   Sağlık ve para konusunda tavsiye niteliğinde kesin yönlendirme yapma.
6. Klişe yasak: "yıldızlar senin için", "evren sana", "enerjin çok yüksek", "harika bir gün seni bekliyor"
   gibi kalıplar kullanma.

ALANLAR:
- "focus": günün konusu, 1-3 kelime (ör. "Ortak kararlar", "Ev düzeni").
- "short": kilit ekranında görünecek tek cümle, EN FAZLA 85 karakter.
- "text": 3-5 cümlelik yorum, 300-600 karakter.
- "motivation": 2-6 kelimelik, özgün, akılda kalıcı motivasyon cümlesi. Daha önce kullanılmamış olmalı.
- "basis": yorumun dayandığı gökyüzü olayı, tek kısa cümle (ör. "Ay 11. evinde, Satürn ile altmışlık açıda.").

Çıktı yalnızca JSON olsun, başka hiçbir şey yazma."""


# ----------------------------------------------------------------------------- yardımcılar

def today_tr() -> date:
    return datetime.now(TZ).date()


def load_json(p: Path, default):
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return default


def save_json(p: Path, data) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    tmp.replace(p)


def load_history(before: date) -> list[dict]:
    """Verilen tarihten önceki HISTORY_DAYS günlük arşiv (yeniden eskiye)."""
    out = []
    for p in sorted(ARCHIVE.glob("*.json"), reverse=True):
        try:
            d = date.fromisoformat(p.stem)
        except ValueError:
            continue
        if d >= before:
            continue
        if (before - d).days > HISTORY_DAYS:
            break
        out.append(load_json(p, {}))
    return out


def all_motivations() -> list[str]:
    """Bugüne kadar kullanılmış TÜM motivasyon cümleleri (asla tekrar edilmez)."""
    items = []
    for p in sorted(ARCHIVE.glob("*.json")):
        for s in load_json(p, {}).get("signs", {}).values():
            if s.get("motivation"):
                items.append(s["motivation"])
    return items


def overused_phrases(history: list[dict], days: int = 30, min_count: int = 3) -> list[str]:
    c: Counter[str] = Counter()
    for day in history[:days]:
        for s in day.get("signs", {}).values():
            c.update(sim.word_ngrams(s.get("text", ""), 3))
    return [p for p, n in c.most_common(40) if n >= min_count]


# ----------------------------------------------------------------------------- doğrulama

def fact_check(text: str, sky: Sky) -> list[str]:
    """Metindeki 'Gezegen + Burç' ve 'Gezegen retro' iddialarını gerçek veriyle karşılaştırır."""
    problems = []
    for name in PLANET_NAMES:
        p = sky.planets[name]
        for m in re.finditer(re.escape(name), text):
            window = text[m.end(): m.end() + 30]
            # Bir sonraki gezegen adına kadar olan kısmı değerlendir
            cut = min([window.find(n) for n in PLANET_NAMES if window.find(n) > 0] + [len(window)])
            window = window[:cut]
            for i, loc in enumerate(SIGN_LOC):
                if loc in window and i not in (p.sign_start, p.sign, p.sign_end):
                    problems.append(f"{name} {SIGN_TR[i]} burcunda DEĞİL; gerçekte {SIGN_LOC[p.sign]}.")
            if re.search(r"\bretro", window, re.I) and not p.retro and not p.station:
                problems.append(f"{name} şu anda retro DEĞİL.")
    return problems


def validate_sign(sid: str, item: dict, sky: Sky, history: list[dict], same_day: dict,
                  used_motivations: list[str], relax: float = 1.0) -> list[str]:
    """relax > 1 yalnızca son çare: benzerlik eşiklerini biraz gevşetir (uydurma/motivasyon kuralları asla)."""
    text_max, short_max = TEXT_SIM_MAX * relax, SHORT_SIM_MAX * relax
    errors: list[str] = []
    for key in ("focus", "short", "text", "motivation", "basis"):
        if not isinstance(item.get(key), str) or not item[key].strip():
            errors.append(f"'{key}' alanı eksik.")
    if errors:
        return errors

    text, short, mot = item["text"].strip(), item["short"].strip(), item["motivation"].strip()
    if not 250 <= len(text) <= 700:
        errors.append(f"'text' {len(text)} karakter; 300-600 arası olmalı.")
    if len(short) > 95:
        errors.append(f"'short' {len(short)} karakter; en fazla 85 olmalı.")
    nw = len(sim.normalize(mot).split())
    if not 2 <= nw <= 7 or len(mot) > 48:
        errors.append("'motivation' 2-6 kelime olmalı.")

    for f in fact_check(text + " " + short + " " + item["basis"], sky):
        errors.append("Uydurma bilgi: " + f)
    if not any(n in item["basis"] for n in PLANET_NAMES):
        errors.append("'basis' verideki gerçek bir gökyüzü olayına dayanmalı.")

    # Motivasyon: daha önce birebir ya da çok benzeri kullanılmış mı
    nm = sim.normalize(mot)
    for old in used_motivations:
        if sim.normalize(old) == nm or sim.similarity(old, mot) >= MOTIVATION_SIM_MAX:
            errors.append(f"Motivasyon cümlesi daha önce kullanıldı/çok benzer: \"{old}\".")
            break

    # Geçmişle benzerlik (aynı burç: 120 gün, diğer burçlar: 30 gün)
    opening = sim.first_words(text)
    for i, day in enumerate(history):
        for osid, old in day.get("signs", {}).items():
            if osid != sid and i >= 30:
                continue
            s = sim.similarity(old.get("text", ""), text)
            if s >= text_max:
                common = sim.shared_phrases(old["text"], text)[:3]
                errors.append(f"Yorum {day.get('date')} tarihli bir yorumla çok benzer"
                              + (f"; tekrar eden ifadeler: {common}" if common else "") + ".")
                break
            if sim.similarity(old.get("short", ""), short) >= short_max:
                errors.append(f"'short' {day.get('date')} tarihli bir cümleye çok benzer.")
                break
            if osid == sid and i < 14 and sim.first_words(old.get("text", "")) == opening:
                errors.append(f"Açılış \"{opening}\" yakın zamanda kullanıldı.")
                break
        if len(errors) > 4:
            break

    # Aynı günün diğer burçlarıyla benzerlik
    for osid, other in same_day.items():
        if osid == sid:
            continue
        if sim.similarity(other.get("text", ""), text) >= text_max:
            errors.append(f"{SIGN_TR[SIGN_ID_TO_INDEX[osid]]} yorumuna çok benzer.")
        if sim.first_words(other.get("text", "")) == opening:
            errors.append(f"{SIGN_TR[SIGN_ID_TO_INDEX[osid]]} yorumuyla aynı açılış.")
        if sim.normalize(other.get("motivation", "")) == nm:
            errors.append("Motivasyon aynı günün başka burcunda var.")
    return errors


# ----------------------------------------------------------------------------- prompt

def build_prompt(day: date, sky: Sky, history: list[dict], signs: list[str],
                 feedback: dict[str, list[str]], used_motivations: list[str]) -> str:
    lines = [f"TARİH: {day.strftime('%d.%m.%Y')}", "", "GENEL GÖKYÜZÜ (gerçek, hesaplanmış veri):"]
    lines += [f"- {x}" for x in sky_summary(sky)]
    if sky.events:
        lines += ["", "BUGÜNÜN ÖNE ÇIKAN OLAYLARI:"] + [f"- {e}" for e in sky.events]

    lines += ["", "EV ANLAMLARI: " + "; ".join(f"{k}. ev: {v}" for k, v in HOUSE_THEMES.items())]

    over = overused_phrases(history)
    if over:
        lines += ["", "SON GÜNLERDE ÇOK KULLANILAN, KULLANMA: " + " | ".join(over)]
    recent_mot = used_motivations[-150:]
    if recent_mot:
        lines += ["", "DAHA ÖNCE KULLANILMIŞ MOTİVASYONLAR (bunları ve benzerlerini KULLANMA): "
                  + " | ".join(recent_mot)]

    for sid in signs:
        i = SIGN_ID_TO_INDEX[sid]
        lines += ["", f"### {SIGN_TR[i]} ({sid})", "Bugünkü veri:"]
        lines += [f"- {n}" for n in sign_brief(sky, i)]
        recent = [d["signs"][sid] for d in history[:10] if sid in d.get("signs", {})]
        if recent:
            lines.append("Son günlerin konuları (farklı bir konu seç): "
                         + ", ".join(r.get("focus", "") for r in recent[:6]))
            lines.append("Son açılışlar (KULLANMA): "
                         + " | ".join(sim.first_words(r.get("text", ""), 4) for r in recent))
        if feedback.get(sid):
            lines.append("ÖNCEKİ DENEMEDEKİ HATALAR, DÜZELT: " + " ".join(feedback[sid]))

    schema = "{" + ", ".join(f'"{s}": {{"focus": "...", "short": "...", "text": "...", '
                             f'"motivation": "...", "basis": "..."}}' for s in signs[:2])
    lines += ["", f"Şu burçlar için yaz: {', '.join(signs)}.",
              f"JSON biçimi (tüm istenen burçlar için): {schema}" + (", ...}" if len(signs) > 2 else "}")]
    return "\n".join(lines)


# ----------------------------------------------------------------------------- Gemini

class Gemini:
    BASE = "https://generativelanguage.googleapis.com/v1beta"

    def __init__(self, key: str, prefer_lite: bool = False, gemma_first: bool = False):
        self.key = key
        self.prefer_lite = prefer_lite
        self.gemma_first = gemma_first
        self.exhausted: set[str] = set()   # bugün kotası biten modeller
        self.models = self._pick_models()
        self.requests = 0

    def _req(self, method: str, url: str, body: dict | None = None, timeout: int = 180) -> dict:
        data = json.dumps(body).encode() if body is not None else None
        r = urllib.request.Request(url, data=data, method=method,
                                   headers={"x-goog-api-key": self.key, "Content-Type": "application/json"})
        with urllib.request.urlopen(r, timeout=timeout) as resp:
            return json.loads(resp.read().decode())

    def _pick_models(self) -> list[str]:
        forced = os.environ.get("GEMINI_MODEL", "").strip()
        names: list[str] = []
        try:
            res = self._req("GET", f"{self.BASE}/models?pageSize=1000")
            names = [m["name"].split("/", 1)[1] for m in res.get("models", [])
                     if "generateContent" in m.get("supportedGenerationMethods", [])]
        except Exception as e:  # noqa: BLE001
            print("Model listesi alınamadı:", e, file=sys.stderr)
        bad = ("tts", "live", "image", "audio", "embed", "transcribe", "translate", "thinking-exp", "robotics",
               "computer-use", "gemma", "omni")

        def version(n: str) -> tuple:
            m = re.search(r"gemini-(\d+)(?:\.(\d+))?", n)
            return (int(m.group(1)), int(m.group(2) or 0)) if m else (0, 0)

        flash = [n for n in names if "flash" in n and not any(b in n for b in bad)]
        full = sorted([n for n in flash if "lite" not in n],
                      key=lambda n: (version(n), "preview" not in n, "latest" in n), reverse=True)
        lite = sorted([n for n in flash if "lite" in n],
                      key=lambda n: (version(n), "preview" not in n), reverse=True)
        order = ([forced] if forced else []) + ((lite[:2] + full[:3]) if self.prefer_lite else (full[:3] + lite[:2]))
        if not order:
            order = ["gemini-flash-latest", "gemini-flash-lite-latest"]
        seen, out = set(), []
        for n in order:
            if n not in seen:
                seen.add(n)
                out.append(n)
        # Son çare: Gemma (aynı ücretsiz anahtar, Gemini'den ayrı ve çok daha geniş günlük kota).
        # Gemini kotası bitince devreye girer; yazdıkları aynı uydurma/tekrar kontrollerinden geçer.
        def gver(n: str) -> tuple:
            m = re.search(r"gemma-(\d+)(?:n)?-(\d+)b", n)
            return (int(m.group(1)), int(m.group(2))) if m else (0, 0)
        gemma = sorted([n for n in names if n.startswith("gemma-") and n.endswith("-it") and gver(n)[1] >= 12],
                       key=gver, reverse=True)
        if not names:
            gemma = ["gemma-3-27b-it"]
        g = [x for x in gemma[:1] if x not in seen]
        out = g + out if self.gemma_first else out + g
        print("Kullanılacak modeller (sırayla):", out)
        return out

    def generate(self, prompt: str, system: str | None = None) -> tuple[dict, str]:
        body = {
            "systemInstruction": {"parts": [{"text": system or SYSTEM_PROMPT}]},
            "contents": [{"role": "user", "parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": 1.0, "responseMimeType": "application/json"},
        }
        # Gemma sistem talimatını ve JSON modunu desteklemez: talimat isteğin başına eklenir
        gemma_body = {
            "contents": [{"role": "user", "parts": [{"text": (system or SYSTEM_PROMPT) + "\n\n" + prompt
                                                     + "\n\nYanıtı YALNIZCA geçerli JSON olarak ver."}]}],
            "generationConfig": {"temperature": 0.9},
        }
        last_err: Exception | None = None
        for model in self.models:
            if model in self.exhausted:
                continue
            for attempt in range(3):
                try:
                    self.requests += 1
                    if model.startswith("gemma-"):
                        time.sleep(2.5)  # dakikada en fazla ~30 istek
                    res = self._req("POST", f"{self.BASE}/models/{model}:generateContent",
                                    gemma_body if model.startswith("gemma-") else body)
                    parts = res["candidates"][0]["content"]["parts"]
                    raw = "".join(p.get("text", "") for p in parts if not p.get("thought"))
                    raw = re.sub(r"^```(?:json)?|```$", "", raw.strip(), flags=re.M).strip()
                    if not raw.startswith(("{", "[")):
                        m = re.search(r"[\[{].*[\]}]", raw, flags=re.S)
                        raw = m.group(0) if m else raw
                    return json.loads(raw), model
                except urllib.error.HTTPError as e:
                    last_err = e
                    detail = e.read().decode(errors="replace")
                    print(f"  {model}: HTTP {e.code} {detail[:400]}", file=sys.stderr)
                    if e.code in (400, 403, 404):
                        break               # bu model kullanılamıyor → sıradaki
                    if e.code == 429:
                        if "PerDay" in detail or "per day" in detail.lower() or "limit: 0" in detail:
                            print(f"  {model}: günlük kota bitti, sıradaki modele geçiliyor", file=sys.stderr)
                            self.exhausted.add(model)
                            break           # günlük kota bitti → sıradaki model
                        time.sleep(20 * (attempt + 1))
                    else:
                        time.sleep(10 * (attempt + 1))
                except (json.JSONDecodeError, KeyError, IndexError, urllib.error.URLError, TimeoutError) as e:
                    last_err = e
                    print(f"  {model}: geçersiz yanıt ({e})", file=sys.stderr)
                    time.sleep(5)
        raise RuntimeError(f"Hiçbir model yanıt vermedi: {last_err}")


class MockWriter:
    """API anahtarı olmadan sistemi denemek için sahte yazar."""
    models = ["mock"]
    requests = 0
    WORDS = ["denge", "cesaret", "sabır", "netlik", "merak", "şefkat", "odak", "esneklik", "sezgi", "kararlılık",
             "sadelik", "umut", "nezaket", "ritim", "özgüven", "dinginlik", "yaratıcılık", "dürüstlük"]
    VERBS = ["Kendine", "Bugün", "Şimdi", "Adım adım", "Sessizce", "İçtenlikle", "Bir nefeste", "Gülümseyerek"]

    def __init__(self, sky: Sky | None = None):
        self.rng = random.Random()

    def generate(self, prompt: str) -> tuple[dict, str]:
        self.requests += 1
        vocab = sorted({w for t in HOUSE_THEMES.values() for w in re.findall(r"\w+", t)} | set(self.WORDS))
        out = {}
        for sid in re.findall(r"### .+? \((\w+)\)", prompt):
            r = self.rng
            sent = lambda k: " ".join(r.sample(vocab, k)).capitalize() + "."  # noqa: E731
            out[sid] = {
                "focus": r.choice(self.WORDS).capitalize(),
                "short": sent(7),
                "text": " ".join(sent(r.randint(9, 13)) for _ in range(4)),
                "motivation": " ".join(r.sample(vocab, r.randint(3, 5))).capitalize(),
                "basis": "Ay bugünkü gerçek konumunda (deneme verisi).",
            }
        return out, "mock"


# ----------------------------------------------------------------------------- ana akış

def generate_day(day: date, writer) -> dict | None:
    sky = compute_sky(day)
    history = load_history(day)
    used_mot = all_motivations()
    accepted: dict[str, dict] = {}
    best_effort: dict[str, tuple[dict, list[str]]] = {}
    feedback: dict[str, list[str]] = {}
    model_used = None

    for rnd in range(1, MAX_ROUNDS + 1):
        todo = [s for s in SIGN_IDS if s not in accepted]
        if not todo:
            break
        prompt = build_prompt(day, sky, history, todo, feedback, used_mot)
        try:
            result, model_used = writer.generate(prompt)
        except RuntimeError as e:
            print(f"{day}: üretim başarısız: {e}", file=sys.stderr)
            break
        feedback = {}
        for sid in todo:
            item = result.get(sid) if isinstance(result, dict) else None
            if not isinstance(item, dict):
                feedback[sid] = ["Bu burç yanıtta yoktu."]
                continue
            item = {k: str(v).strip() for k, v in item.items()
                    if k in ("focus", "short", "text", "motivation", "basis")}
            errs = validate_sign(sid, item, sky, history, accepted, used_mot)
            if errs:
                feedback[sid] = errs
                prev = best_effort.get(sid)
                if prev is None or len(errs) < len(prev[1]):
                    best_effort[sid] = (item, errs)
            else:
                accepted[sid] = item
                used_mot.append(item["motivation"])
        print(f"{day} tur {rnd}: {len(accepted)}/12 kabul"
              + (f", düzeltilecek: {list(feedback)}" if feedback else ""))

    # Son çare: en iyi denemeyi biraz gevşetilmiş benzerlik eşiğiyle yeniden kontrol et.
    # Uydurma, biçim ve motivasyon kuralları gevşetilmez.
    for sid in SIGN_IDS:
        if sid in accepted or sid not in best_effort:
            continue
        item = best_effort[sid][0]
        errs = validate_sign(sid, item, sky, history, accepted, used_mot, relax=1.35)
        if not errs:
            print(f"  {sid}: son çare kontrolünden geçti.")
            accepted[sid] = item
            used_mot.append(item["motivation"])

    if len(accepted) < 12:
        print(f"{day}: {12 - len(accepted)} burç tamamlanamadı, bir sonraki çalıştırmada tekrar denenecek.",
              file=sys.stderr)
        return None

    return {
        "date": day.isoformat(),
        "generated_at": datetime.now(TZ).isoformat(timespec="seconds"),
        "model": model_used,
        "sky": {"summary": sky_summary(sky), "events": sky.events, "moon_phase": sky.moon_phase},
        "signs": {sid: accepted[sid] for sid in SIGN_IDS},
    }


def publish(today: date) -> None:
    """Uygulamanın indireceği dosyalar: her burç için dünden itibaren hazır tüm günler."""
    days = []
    d = today - timedelta(days=1)
    while True:
        rec = load_json(ARCHIVE / f"{d.isoformat()}.json", None)
        if rec is None:
            if d > today:
                break
        else:
            days.append(rec)
        d += timedelta(days=1)
        if d > today + timedelta(days=BUFFER_DAYS + 2):
            break

    now = datetime.now(TZ).isoformat(timespec="seconds")
    for i, sid in enumerate(SIGN_IDS):
        save_json(PUBLIC / f"{sid}.json", {
            "sign": sid, "name": SIGN_TR[i], "updated": now,
            "days": [{
                "date": r["date"],
                **r["signs"][sid],
                "sky_events": r["sky"]["events"],
                "sky_summary": r["sky"]["summary"],
                "moon_phase": r["sky"].get("moon_phase", ""),
            } for r in days],
        })
    save_json(PUBLIC / "index.json", {
        "updated": now,
        "available_dates": [r["date"] for r in days],
        "signs": [{"id": s, "name": n} for s, n in zip(SIGN_IDS, SIGN_TR)],
    })
    print(f"Yayınlandı: {len(days)} gün ({days[0]['date'] if days else '-'} → {days[-1]['date'] if days else '-'})")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--mock", action="store_true", help="API olmadan deneme")
    ap.add_argument("--today", help="Test için bugünün tarihi (YYYY-AA-GG)")
    args = ap.parse_args()

    today = date.fromisoformat(args.today) if args.today else today_tr()
    if args.mock:
        writer = MockWriter()
    else:
        key = os.environ.get("GEMINI_API_KEY", "").strip()
        if not key:
            print("GEMINI_API_KEY tanımlı değil.", file=sys.stderr)
            return 2
        writer = Gemini(key)

    missing = [today + timedelta(days=k) for k in range(BUFFER_DAYS)
               if not (ARCHIVE / f"{(today + timedelta(days=k)).isoformat()}.json").exists()]
    print(f"Eksik günler: {[d.isoformat() for d in missing]}")

    made = 0
    for day in missing[:MAX_DAYS_PER_RUN]:
        rec = generate_day(day, writer)
        if rec:
            save_json(ARCHIVE / f"{day.isoformat()}.json", rec)
            made += 1
    publish(today)
    print(f"Bu çalıştırmada {made} gün üretildi, {writer.requests} istek yapıldı.")

    # Bugünün içeriği hiç yoksa hata ver (GitHub e-posta ile haber verir)
    if not (ARCHIVE / f"{today.isoformat()}.json").exists():
        print("UYARI: bugünün içeriği yok!", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
