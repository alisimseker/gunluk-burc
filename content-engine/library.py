"""
Yapay zekâ yorum kütüphaneleri (bir kez üretilir; eksikler her çalıştırmada tamamlanır).

Telefon her şeyi kendisi HESAPLAR (doğum haritası, günün etkileri, uyum, takvim, yıllık harita).
Bu betik her olası yerleşim/olay için Gemini'ye bir kez yorum yazdırır; uygulama yalnızca kullanıcının
hesaplanan durumuna uyan yorumları gösterir. Kullanıcı verisi hiçbir zaman Gemini'ye gitmez.

Kütüphaneler (docs/v1/<ad>/tr.json):
  natal     - gezegen×burç, gezegen×ev, yükselen, Ay burcu, MC          (300)
  events    - retro/düz, Yeniay/Dolunay, tutulma, burç geçişleri        (114)
  transits  - günün gezegeni × açı × doğum noktası                      (450)
  synastry  - iki harita arası gezegen açıları + güneş burcu uyumu       (218)
  solar     - yıllık (güneş dönüşü) haritası                             (84)

Kullanım: GEMINI_API_KEY=... python library.py   (ya da --mock)
"""
from __future__ import annotations

import argparse
import os
import time
import re
import sys
from pathlib import Path

import similarity as sim
from generate import Gemini, load_json, save_json

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs" / "v1"
MAX_REQUESTS = int(os.environ.get("NATAL_MAX_REQUESTS", "12"))
# İş akışı süre sınırına takılmadan kaydedebilsin diye üretim bu kadar dakika sonra durur
TIME_LIMIT_MIN = float(os.environ.get("LIBRARY_TIME_LIMIT_MIN", "35"))
_START = time.time()

SIGNS = ["Koç", "Boğa", "İkizler", "Yengeç", "Aslan", "Başak", "Terazi", "Akrep", "Yay", "Oğlak", "Kova", "Balık"]
SIGN_LOC = ["Koç'ta", "Boğa'da", "İkizler'de", "Yengeç'te", "Aslan'da", "Başak'ta", "Terazi'de", "Akrep'te",
            "Yay'da", "Oğlak'ta", "Kova'da", "Balık'ta"]
SIGN_DAT = ["Koç'a", "Boğa'ya", "İkizler'e", "Yengeç'e", "Aslan'a", "Başak'a", "Terazi'ye", "Akrep'e",
            "Yay'a", "Oğlak'a", "Kova'ya", "Balık'a"]
PLANETS = {
    "sun": ("Güneş", "temel kimlik, yaşam enerjisi, öz ifade"),
    "moon": ("Ay", "duygular, iç ihtiyaçlar, güvenlik duygusu, alışkanlıklar"),
    "mercury": ("Merkür", "düşünce tarzı, iletişim, öğrenme"),
    "venus": ("Venüs", "sevgi dili, ilişkiler, zevkler, değerler"),
    "mars": ("Mars", "harekete geçme biçimi, enerji, cesaret, öfke"),
    "jupiter": ("Jüpiter", "büyüme, şans alanları, inançlar"),
    "saturn": ("Satürn", "sorumluluk, sınırlar, olgunlaşma alanı"),
    "uranus": ("Uranüs", "özgürlük, değişim, sıra dışılık"),
    "neptune": ("Neptün", "hayal gücü, sezgi, idealler"),
    "pluto": ("Plüton", "dönüşüm, güç, derin değişim"),
    "node": ("Kuzey Ay Düğümü", "hayat yönü, gelişim yolu"),
}
POINTS = {"asc": ("Yükselen", "kişilik, beden, dışa yansıyan tavır"), "mc": ("MC", "kariyer, hedefler, toplumdaki imaj")}
HOUSES = {
    1: "kişilik, görünüş, kendini ortaya koyma", 2: "para, kazanç, öz değer", 3: "iletişim, kardeşler, yakın çevre, öğrenme",
    4: "ev, aile, kökler", 5: "aşk, yaratıcılık, çocuklar, eğlence", 6: "iş düzeni, sağlık alışkanlıkları, hizmet",
    7: "evlilik, ortaklıklar, yakın ilişkiler", 8: "ortak kaynaklar, yakınlık, dönüşüm", 9: "yüksek öğrenim, yolculuklar, inançlar",
    10: "kariyer, toplumsal konum, hedefler", 11: "arkadaşlar, topluluklar, gelecek umutları", 12: "iç dünya, dinlenme, bilinçaltı",
}
ASPECTS = {"conj": "kavuşum", "sextile": "altmışlık (sekstil)", "square": "kare", "trine": "üçgen", "opp": "karşıt"}
ASPECT_TONE = {"conj": "yoğunlaştırıcı", "sextile": "destekleyici, fırsat sunan", "square": "zorlayıcı, harekete geçiren",
               "trine": "akıcı, uyumlu", "opp": "dengelenmesi gereken, karşılaştırıcı"}

SYSTEMS = {
    "natal": "Doğum haritası yorumları yazıyorsun.",
    "events": "Gökyüzü takvimi için olay açıklamaları yazıyorsun: olay herkesi nasıl etkiler, ne yapılabilir.",
    "transits": "Kişiye özel GÜNLÜK etki yorumları yazıyorsun: günün gezegeni kişinin doğum haritasındaki bir noktaya "
                "açı yapıyor. Kısa, o güne dair somut ve pratik yaz.",
    "synastry": "İki kişinin haritaları arasındaki uyum (sinastri) yorumları yazıyorsun. 'Siz', 'aranızda', 'ilişkinizde' "
                "diliyle yaz; iki kişiye birlikte hitap et.",
    "solar": "Yıllık öngörü (güneş dönüşü haritası) yorumları yazıyorsun: doğum gününden sonraki 12 ayın teması.",
}
BASE_SYSTEM = """Sen deneyimli bir astrolog ve usta bir Türkçe yazarsın. {role}
KURALLAR:
- Klasik batı astrolojisinin yerleşik anlamlarına sadık kal; uydurma bilgi verme.
- Sıcak ve net yaz. {voice} Güçlü ve dikkat gerektiren yönleri dengeli anlat.
- Kesin kehanet, korkutma, sağlık/para konusunda kesin yönlendirme yok.
- Her metin diğerlerinden farklı açılış ve cümle yapısıyla başlasın; klişe kalıplar yok
  ("yıldızlar senin için", "evren sana", "harika bir enerji").
- Yalnızca istenen yerleşim/olayı anlat; başka gezegen veya burç konumu hakkında iddiada bulunma.
- Çıktı yalnızca istenen JSON."""


# --------------------------------------------------------------------------- öğeler
# (anahtar, açıklama, hedef uzunluk, izin verilen burç indeksleri ya da None = denetleme yok)
Item = tuple[str, str, int, "set[int] | None"]


def natal_items() -> list[Item]:
    items: list[Item] = []
    for i, s in enumerate(SIGNS):
        items.append((f"asc:{i}", f"Yükselen burç {s}: dış görünüş, ilk izlenim, hayata yaklaşım, güçlü ve zorlayıcı yönler. "
                                  f"İki paragraf.", 900, {i}))
    for i, s in enumerate(SIGNS):
        items.append((f"moonsign:{i}", f"Ay burcu {s} (Ay {SIGN_LOC[i]}): duygusal doğa, iç ihtiyaçlar, kendini güvende "
                                       f"hissetme biçimi, ilişkilerde duygusal beklentiler. İki paragraf.", 900, {i}))
    for i, s in enumerate(SIGNS):
        items.append((f"mc:{i}", f"MC (Gökyüzü Ortası) {s} burcunda: kariyer yönelimi, toplumdaki imaj, hedefler.", 450, {i}))
    for pk, (pn, theme) in PLANETS.items():
        for i in range(12):
            items.append((f"ps:{pk}:{i}", f"{pn} {SIGN_LOC[i]} ({theme}).", 450, {i}))
    for pk, (pn, theme) in PLANETS.items():
        for h, ht in HOUSES.items():
            items.append((f"ph:{pk}:{h}", f"{pn} {h}. evde ({h}. ev: {ht}; {pn}: {theme}).", 400, None))
    return items


def event_items() -> list[Item]:
    items: list[Item] = []
    for pk in ("mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto"):
        pn, theme = PLANETS[pk]
        items.append((f"ev:retro:{pk}", f"{pn} retrosu başlıyor ({theme}): bu dönemde neler yavaşlar, nelere dikkat edilir, "
                                        f"ne için iyi bir zamandır.", 380, None))
        items.append((f"ev:direct:{pk}", f"{pn} düz harekete geçiyor: retro dönemi bitince neler açılır, nasıl ilerlenir.",
                      300, None))
    for i, s in enumerate(SIGNS):
        items.append((f"ev:newmoon:{i}", f"Yeniay {s} burcunda: yeni başlangıç teması, niyet koymak için uygun konular.", 320, {i}))
        items.append((f"ev:fullmoon:{i}", f"Dolunay {s} burcunda: tamamlanma, farkındalık, duygusal doruk teması.", 320, {i}))
    items.append(("ev:solar_eclipse", "Güneş tutulması: güçlü yeni başlangıçlar, beklenmedik dönüm noktaları.", 320, None))
    items.append(("ev:lunar_eclipse", "Ay tutulması: kapanışlar, duygusal açığa çıkışlar, bırakma.", 320, None))
    for pk in ("sun", "mercury", "venus", "mars", "jupiter", "saturn"):
        pn, theme = PLANETS[pk]
        for i, s in enumerate(SIGNS):
            items.append((f"ev:ingress:{pk}:{i}", f"{pn} {SIGN_DAT[i]} geçiyor ({theme}): bu geçişin herkese genel etkisi.",
                          260, {i}))
    return items


TRANSIT_PLANETS = ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto"]
NATAL_POINTS = ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn", "asc", "mc"]


def _pname(k: str) -> tuple[str, str]:
    return PLANETS.get(k) or POINTS[k]


def transit_items() -> list[Item]:
    items: list[Item] = []
    for t in TRANSIT_PLANETS:
        tn, tt = _pname(t)
        for a, an in ASPECTS.items():
            for n in NATAL_POINTS:
                nn, nt = _pname(n)
                items.append((f"tr:{t}:{a}:{n}",
                              f"Günün {tn}'i ({tt}) doğum haritandaki {nn}'e ({nt}) {an} açısı yapıyor; etki {ASPECT_TONE[a]}. "
                              f"Bugün için kısa, somut yorum ve küçük bir öneri.", 230, None))
    return items


SYN_PLANETS = ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn"]


def synastry_items() -> list[Item]:
    items: list[Item] = []
    for i, a in enumerate(SYN_PLANETS):
        for b in SYN_PLANETS[i:]:
            an, at = _pname(a)
            bn, bt = _pname(b)
            for k, kn in ASPECTS.items():
                desc = (f"Birinin {an}'i ({at}) diğerinin {bn}'ine ({bt}) {kn} açısı yapıyor; etki {ASPECT_TONE[k]}. "
                        f"İlişkideki anlamı.") if a != b else (
                        f"İki kişinin {an}'leri ({at}) arasında {kn} açısı; etki {ASPECT_TONE[k]}. İlişkideki anlamı.")
                items.append((f"sy:{a}:{k}:{b}", desc, 220, None))
    for i in range(12):
        for j in range(i, 12):
            items.append((f"sc:{i}:{j}", f"{SIGNS[i]} ve {SIGNS[j]} güneş burçlarının uyumu: güçlü yanlar ve dikkat "
                                         f"edilmesi gerekenler.", 380, {i, j}))
    return items


def solar_items() -> list[Item]:
    items: list[Item] = []
    for i, s in enumerate(SIGNS):
        items.append((f"sr:asc:{i}", f"Yıllık haritada yükselen {s}: yılın genel havası ve kendini ortaya koyma biçimi.",
                      280, {i}))
    for pk in ("sun", "moon", "venus", "mars", "jupiter", "saturn"):
        pn, theme = PLANETS[pk]
        for h, ht in HOUSES.items():
            items.append((f"sr:{pk}:{h}", f"Yıllık haritada {pn} {h}. evde ({ht}): bu yıl {theme} açısından ne öne çıkar.",
                          260, None))
    return items


LIBRARIES = [  # öncelik sırasıyla
    ("natal", natal_items),
    ("events", event_items),
    ("transits", transit_items),
    ("synastry", synastry_items),
    ("solar", solar_items),
]


# --------------------------------------------------------------------------- yanıtı okuma
def extract_texts(res, keys: list[str]) -> dict[str, str]:
    """Gemini yanıtı farklı biçimlerde gelebilir: {anahtar: metin}, [{anahtar, metin}], iç içe nesneler.
    Hepsini düz bir {anahtar: metin} sözlüğüne çevirir."""
    flat: dict[str, str] = {}

    def norm_key(k: str) -> str:
        return re.sub(r"\s+", "", str(k)).strip("-*.`'\"").lower()

    def walk(x, parent: str = ""):
        if isinstance(x, dict):
            k = x.get("anahtar") or x.get("key") or x.get("id") or x.get("kod")
            t = x.get("metin") or x.get("text") or x.get("yorum") or x.get("content")
            if isinstance(k, str) and isinstance(t, str):
                flat[norm_key(k)] = t
            for kk, v in x.items():
                full = f"{parent}:{kk}" if parent else str(kk)
                if isinstance(v, str):
                    flat.setdefault(norm_key(kk), v)
                    flat.setdefault(norm_key(full), v)
                else:
                    walk(v, full)
        elif isinstance(x, list):
            for v in x:
                walk(v, parent)

    walk(res)
    out = {}
    for k in keys:
        nk = norm_key(k)
        if nk in flat:
            out[k] = flat[nk]
            continue
        cands = [v for fk, v in flat.items() if fk.endswith(nk) or nk.endswith(fk) and len(fk) > 4]
        if len(cands) == 1:
            out[k] = cands[0]
    return out


# --------------------------------------------------------------------------- doğrulama
# "Siz" hitabı: zamir, -iniz/-sınız ekleri ve -in/-ın/-yin emir kipi (uyum yorumları hariç hepsi "sen" diliyle)
FORMAL = re.compile(r"\b(siz|sizin|size|sizi|sizde|sizden|sizce)\b"
                    r"|\w{2,}(ınız|iniz|unuz|ünüz|sınız|siniz|sunuz|sünüz)\b", re.I)
FORMAL_IMP = re.compile(r"\b\w+[aeıioöuü]y(ın|in|un|ün)\b|\b\w+(ma|me)y(ın|in)\b", re.I)
IMP_OK = {"şeyin", "tayin", "oyun", "koyun", "boyun", "beyin", "kayın", "hiçbir şeyin", "deyin"}
VOICE = "sen"   # yayınlanan dosyada bu hitapla yazıldığı işaretlenir


def is_formal(text: str) -> bool:
    if FORMAL.search(text):
        return True
    return any(m.group(0).lower() not in IMP_OK for m in FORMAL_IMP.finditer(text))


def validate(text: str, target: int, allowed: set[int] | None, lib: dict, informal: bool = True,
             self_key: str | None = None) -> list[str]:
    errs = []
    if not isinstance(text, str) or not text.strip():
        return ["boş"]
    if informal and is_formal(text):
        return ["'siz' değil 'sen' diliyle yaz (ör. enerjin, yapabilirsin, dene)"]
    n = len(text)
    if n < target * 0.55 or n > target * 1.8:
        errs.append(f"uzunluk {n}; yaklaşık {target} karakter olmalı")
    if allowed is not None:
        for j, s in enumerate(SIGNS):
            if j not in allowed and s != "Yay" and re.search(rf"\b{s}\b", text):
                errs.append(f"başka bir burçtan ({s}) bahsetme")
                break
    opening = sim.first_words(text, 3)
    for k, t in lib.items():
        if k == self_key:
            continue
        if sim.first_words(t, 3) == opening:
            errs.append(f"açılış '{opening}' başka metinde kullanıldı")
            break
        if sim.similarity(t, text) > 0.32:
            errs.append("başka bir metne çok benziyor")
            break
    return errs


def run_library(name: str, items_fn, writer, budget: int, mock: bool) -> int:
    out = DOCS / name / "tr.json"
    stored = load_json(out, {})
    lib: dict = stored.get("texts", {})
    informal = name != "synastry"
    # Yeniden yazılacaklar: "sen" diliyle işaretlenmemiş transitlerin hepsi, diğerlerinde "siz" hitaplı olanlar
    if informal and stored.get("voice") != VOICE:
        redo = set(lib) if name == "transits" else {k for k, v in lib.items() if is_formal(v)}
    else:
        redo = set(stored.get("redo", []))
    redo &= set(lib)
    all_it = items_fn()

    def pending() -> list:
        return [it for it in all_it if it[0] not in lib or it[0] in redo]

    def save() -> None:
        left = pending()
        data = {"version": 1, "count": len(lib), "complete": not left, "texts": lib}
        if informal:
            data["voice"] = VOICE
            if redo:
                data["redo"] = sorted(redo)
        save_json(out, data)

    skip: set = set()
    todo = pending()
    print(f"[{name}] {len(lib)}/{len(all_it)} hazır" + (f", {len(redo)} tanesi 'sen' diliyle yeniden yazılacak." if redo else "."))
    if not todo or budget <= 0:
        save()
        return 0
    system = BASE_SYSTEM.format(role=SYSTEMS[name], voice=(
        "Okura tek kişi olarak 'sen' diye hitap et (ör. 'enerjin', 'yapabilirsin', 'bugün dene'); "
        "'siz', '-iniz/-ınız/-sınız' ekleri ve 'deneyin/yapın' gibi emirler KULLANMA." if name != "synastry"
        else "İki kişiye birlikte 'siz' diye hitap et."))
    feedback: dict[str, list[str]] = {}
    tries: dict[str, int] = {}
    used = 0
    while todo and used < budget:
        if time.time() - _START > TIME_LIMIT_MIN * 60:
            print(f"[{name}] süre sınırı ({TIME_LIMIT_MIN:.0f} dk) doldu, kalanlar sonraki çalışmada.")
            used = budget + 1
            break
        size = 16 if todo[0][2] <= 300 else 12
        batch = todo[:size]
        lines = ["Aşağıdaki her madde için Türkçe metin yaz. JSON: {\"anahtar\": \"metin\", ...}", ""]
        for key, desc, target, _ in batch:
            lines.append(f"- {key}: {desc} Yaklaşık {target} karakter.")
            if feedback.get(key):
                lines.append(f"  (önceki denemedeki sorunlar, düzelt: {'; '.join(feedback[key])})")
        recent = [sim.first_words(t, 3) for t in list(lib.values())[-80:]]
        if recent:
            lines += ["", "Şu açılışları KULLANMA: " + " | ".join(recent)]
        try:
            if mock:
                res = {k: (f"Deneme {k} " * 40)[:t] for k, _, t, _ in batch}
            else:
                t0 = time.time()
                res, model_used = writer.generate("\n".join(lines), system=system)
                print(f"[{name}] {model_used} {time.time() - t0:.0f} sn")
        except RuntimeError as e:
            print("Üretim durdu:", e, file=sys.stderr)
            used = budget + 1
            break
        used += 1
        ok = 0
        got = extract_texts(res, [b[0] for b in batch])
        if not got:
            print(f"[{name}] yanıt okunamadı; örnek: {str(res)[:300]}", file=sys.stderr)
        rejected = []
        for key, desc, target, allowed in batch:
            text = str(got.get(key, "")).strip()
            errs = [] if mock else validate(text, target, allowed, lib, informal, key)
            if errs:
                rejected.append(f"{key}: {errs[0]}")
            if errs and tries.get(key, 0) < 2:
                feedback[key] = errs
                tries[key] = tries.get(key, 0) + 1
                continue
            if errs and any("başka bir burç" in e or e == "boş" or "'sen' diliyle" in e for e in errs):
                skip.add(key)       # bu çalışmada tekrar deneme; sonraki çalışmada yeniden denenir
                continue
            lib[key] = text
            redo.discard(key)
            ok += 1
        todo = [it for it in pending() if it[0] not in skip]
        print(f"[{name}] istek {used}: {ok} kabul, kalan {len(todo)}"
              + (f" | ret örnekleri: {rejected[:3]}" if rejected else ""))
        save()
    save()
    return used


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--mock", action="store_true")
    args = ap.parse_args()
    writer = None
    if not args.mock:
        key = os.environ.get("GEMINI_API_KEY", "").strip()
        if not key:
            print("GEMINI_API_KEY yok", file=sys.stderr)
            return 2
        # Kütüphane önce Gemma'yı kullanır: Gemini'nin küçük günlük kotası her günkü burç yorumlarına kalsın
        writer = Gemini(key, prefer_lite=True, gemma_first=True)
    budget = MAX_REQUESTS
    for name, fn in LIBRARIES:
        used = run_library(name, fn, writer, budget, args.mock)
        budget -= used
    return 0


if __name__ == "__main__":
    sys.exit(main())
