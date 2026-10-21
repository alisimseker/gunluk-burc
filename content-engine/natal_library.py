"""
Doğum haritası yorum kütüphanesi (bir kez üretilir, eksikler her çalıştırmada tamamlanır).

Telefon, kullanıcının haritasını kendisi HESAPLAR (gerçek gezegen konumları, yükselen, evler).
Bu betik her olası yerleşim için yapay zekâya yorum yazdırır:
  - gezegen × burç      (11 × 12)
  - gezegen × ev        (11 × 12)
  - yükselen burç       (12, uzun)
  - Ay burcu            (12, uzun - "Ay burcun" özelliği)
  - MC burcu            (12)
Uygulama yalnızca kullanıcının haritasına uyan yorumları gösterir.

Kullanım: GEMINI_API_KEY=... python natal_library.py   (ya da --mock)
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

import similarity as sim
from generate import Gemini, MockWriter, save_json, load_json

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "v1" / "natal" / "tr.json"
MAX_REQUESTS = int(os.environ.get("NATAL_MAX_REQUESTS", "12"))

SIGNS = ["Koç", "Boğa", "İkizler", "Yengeç", "Aslan", "Başak", "Terazi", "Akrep", "Yay", "Oğlak", "Kova", "Balık"]
SIGN_LOC = ["Koç'ta", "Boğa'da", "İkizler'de", "Yengeç'te", "Aslan'da", "Başak'ta", "Terazi'de", "Akrep'te",
            "Yay'da", "Oğlak'ta", "Kova'da", "Balık'ta"]
PLANETS = {
    "sun": ("Güneş", "temel kimlik, yaşam enerjisi, öz ifade"),
    "moon": ("Ay", "duygular, iç ihtiyaçlar, güvenlik duygusu, alışkanlıklar"),
    "mercury": ("Merkür", "düşünce tarzı, iletişim, öğrenme"),
    "venus": ("Venüs", "sevgi dili, ilişkiler, zevkler, değerler"),
    "mars": ("Mars", "harekete geçme biçimi, enerji, cesaret, öfke"),
    "jupiter": ("Jüpiter", "büyüme, şans alanları, inançlar"),
    "saturn": ("Satürn", "sorumluluk, sınırlar, olgunlaşma alanı"),
    "uranus": ("Uranüs", "özgürlük, değişim, sıra dışılık (kuşak etkisi)"),
    "neptune": ("Neptün", "hayal gücü, sezgi, idealler (kuşak etkisi)"),
    "pluto": ("Plüton", "dönüşüm, güç, derin değişim (kuşak etkisi)"),
    "node": ("Kuzey Ay Düğümü", "hayat yönü, gelişim yolu"),
}
HOUSES = {
    1: "kişilik, görünüş, kendini ortaya koyma", 2: "para, kazanç, öz değer", 3: "iletişim, kardeşler, yakın çevre, öğrenme",
    4: "ev, aile, kökler", 5: "aşk, yaratıcılık, çocuklar, eğlence", 6: "iş düzeni, sağlık alışkanlıkları, hizmet",
    7: "evlilik, ortaklıklar, yakın ilişkiler", 8: "ortak kaynaklar, yakınlık, dönüşüm", 9: "yüksek öğrenim, yolculuklar, inançlar",
    10: "kariyer, toplumsal konum, hedefler", 11: "arkadaşlar, topluluklar, gelecek umutları", 12: "iç dünya, dinlenme, bilinçaltı",
}

SYSTEM = """Sen deneyimli bir astrolog ve usta bir Türkçe yazarsın. Doğum haritası yorumları yazıyorsun.
KURALLAR:
- Klasik batı astrolojisinin yerleşik anlamlarına sadık kal; uydurma bilgi verme.
- Sıcak, net, "sen" diliyle yaz. Güçlü yönleri ve dikkat edilmesi gereken yönleri dengeli anlat.
- Kesin kehanet, korkutma, sağlık/para konusunda kesin yönlendirme yok.
- Her metin diğerlerinden farklı açılış ve cümle yapısıyla başlasın; klişe kalıplar yok
  ("yıldızlar senin için", "evren sana", "harika bir enerji").
- Yalnızca istenen yerleşimi anlat; başka gezegen veya burç konumu hakkında iddiada bulunma.
- Çıktı yalnızca istenen JSON."""


def all_items() -> list[tuple[str, str, int]]:
    """(anahtar, istek açıklaması, hedef uzunluk)"""
    items = []
    for i, s in enumerate(SIGNS):
        items.append((f"asc:{i}", f"Yükselen burç {s}: dış görünüş, ilk izlenim, hayata yaklaşım, güçlü ve zorlayıcı yönler. "
                                  f"İki paragraf.", 900))
    for i, s in enumerate(SIGNS):
        items.append((f"moonsign:{i}", f"Ay burcu {s} (Ay {SIGN_LOC[i]}): duygusal doğa, iç ihtiyaçlar, kendini güvende "
                                       f"hissetme biçimi, ilişkilerde duygusal beklentiler. İki paragraf.", 900))
    for i, s in enumerate(SIGNS):
        items.append((f"mc:{i}", f"MC (Gökyüzü Ortası) {s} burcunda: kariyer yönelimi, toplumdaki imaj, hedefler.", 450))
    for pk, (pn, theme) in PLANETS.items():
        for i in range(12):
            items.append((f"ps:{pk}:{i}", f"{pn} {SIGN_LOC[i]} ({theme}).", 450))
    for pk, (pn, theme) in PLANETS.items():
        for h, ht in HOUSES.items():
            items.append((f"ph:{pk}:{h}", f"{pn} {h}. evde ({h}. ev: {ht}; {pn}: {theme}).", 400))
    return items


def validate(key: str, text: str, target: int, lib: dict) -> list[str]:
    errs = []
    if not isinstance(text, str) or not text.strip():
        return ["boş"]
    n = len(text)
    if n < target * 0.6 or n > target * 1.7:
        errs.append(f"uzunluk {n}; yaklaşık {target} karakter olmalı")
    # yanlış burç iddiası: ps/moonsign/asc/mc metninde başka burç adı geçmesin (yerleşimin kendisi hariç)
    if key.startswith(("ps:", "moonsign:", "asc:", "mc:")):
        idx = int(key.rsplit(":", 1)[1])
        for j, s in enumerate(SIGNS):
            if j != idx and re.search(rf"\b{s}\b", text) and s not in ("Yay",):  # "yay" sıradan kelime olabilir
                errs.append(f"başka bir burçtan ({s}) bahsetme")
                break
    opening = sim.first_words(text, 3)
    for k, t in lib.items():
        if sim.first_words(t, 3) == opening:
            errs.append(f"açılış '{opening}' başka metinde kullanıldı")
            break
        if sim.similarity(t, text) > 0.30:
            errs.append("başka bir metne çok benziyor")
            break
    return errs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--mock", action="store_true")
    args = ap.parse_args()
    lib: dict = load_json(OUT, {}).get("texts", {})
    items = [it for it in all_items() if it[0] not in lib]
    print(f"Kütüphane: {len(lib)} hazır, {len(items)} eksik.")
    if not items:
        return 0
    writer = MockWriter() if args.mock else Gemini(os.environ.get("GEMINI_API_KEY", "").strip(), prefer_lite=True)
    if not args.mock and not writer.key:
        print("GEMINI_API_KEY yok", file=sys.stderr)
        return 2

    feedback: dict[str, list[str]] = {}
    requests = 0
    while items and requests < MAX_REQUESTS:
        batch = items[:12]
        lines = ["Aşağıdaki her yerleşim için Türkçe yorum yaz. JSON: {\"anahtar\": \"metin\", ...}", ""]
        for key, desc, target in batch:
            lines.append(f"- {key}: {desc} Yaklaşık {target} karakter.")
            if feedback.get(key):
                lines.append(f"  (önceki denemedeki sorunlar, düzelt: {'; '.join(feedback[key])})")
        used = [sim.first_words(t, 3) for t in list(lib.values())[-80:]]
        if used:
            lines += ["", "Şu açılışları KULLANMA: " + " | ".join(used)]
        try:
            if args.mock:
                res = {k: ("Deneme metni " + k + " ") * (t // 20) for k, _, t in batch}
            else:
                res, _ = writer.generate("\n".join(lines), system=SYSTEM)
        except RuntimeError as e:
            print("Üretim durdu:", e, file=sys.stderr)
            break
        requests += 1
        ok = 0
        for key, desc, target in batch:
            text = str(res.get(key, "")).strip() if isinstance(res, dict) else ""
            errs = [] if args.mock else validate(key, text, target, lib)
            if errs and feedback.get(f"{key}#n", 0) < 2:
                feedback[key] = errs
                feedback[f"{key}#n"] = feedback.get(f"{key}#n", 0) + 1
                continue
            if errs and any("başka bir burç" in e or e == "boş" for e in errs):
                continue  # gerçek hata: kabul etme, sonraki çalıştırmada yeniden denenir
            lib[key] = text
            ok += 1
        items = [it for it in all_items() if it[0] not in lib]
        print(f"İstek {requests}: {ok} kabul, kalan {len(items)}")
        save_json(OUT, {"version": 1, "count": len(lib), "complete": not items, "texts": lib})
    save_json(OUT, {"version": 1, "count": len(lib), "complete": not items, "texts": lib})
    print(f"Toplam {len(lib)} / {len(all_items())}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
