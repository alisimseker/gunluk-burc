"""
Günün gerçek gökyüzü verisini hesaplar (tamamen yerel hesap, internet gerekmez).

Kullanılan kütüphane: astronomy-engine (MIT lisanslı, NASA JPL verileriyle
doğrulanmış, ücretsiz). Konumlar "tropikal zodyak / ecliptic of date" ile
hesaplanır; batı astrolojisinin standart yöntemi budur.

Burç yorumları için "güneş burcu = 1. ev" (whole-sign) sistemi kullanılır:
gazete/uygulama burç yorumlarının standart yöntemi.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone

import astronomy as ast

TZ = timezone(timedelta(hours=3))  # Türkiye saati (UTC+3, yaz saati yok)

SIGNS = [
    ("koc", "Koç"), ("boga", "Boğa"), ("ikizler", "İkizler"), ("yengec", "Yengeç"),
    ("aslan", "Aslan"), ("basak", "Başak"), ("terazi", "Terazi"), ("akrep", "Akrep"),
    ("yay", "Yay"), ("oglak", "Oğlak"), ("kova", "Kova"), ("balik", "Balık"),
]
SIGN_IDS = [s[0] for s in SIGNS]
SIGN_TR = [s[1] for s in SIGNS]

# Burçların -de/-da ekli halleri ("Koç'ta", "Boğa'da"...)
SIGN_LOC = ["Koç'ta", "Boğa'da", "İkizler'de", "Yengeç'te", "Aslan'da", "Başak'ta",
            "Terazi'de", "Akrep'te", "Yay'da", "Oğlak'ta", "Kova'da", "Balık'ta"]
SIGN_DAT = ["Koç'a", "Boğa'ya", "İkizler'e", "Yengeç'e", "Aslan'a", "Başak'a",
            "Terazi'ye", "Akrep'e", "Yay'a", "Oğlak'a", "Kova'ya", "Balık'a"]

BODIES = [
    (ast.Body.Sun, "Güneş"), (ast.Body.Moon, "Ay"), (ast.Body.Mercury, "Merkür"),
    (ast.Body.Venus, "Venüs"), (ast.Body.Mars, "Mars"), (ast.Body.Jupiter, "Jüpiter"),
    (ast.Body.Saturn, "Satürn"), (ast.Body.Uranus, "Uranüs"), (ast.Body.Neptune, "Neptün"),
    (ast.Body.Pluto, "Plüton"),
]
PERSONAL = {"Güneş", "Ay", "Merkür", "Venüs", "Mars"}
SLOW = {"Jüpiter", "Satürn", "Uranüs", "Neptün", "Plüton"}

ASPECTS = [(0, "kavuşum"), (60, "altmışlık (sekstil)"), (90, "kare"),
           (120, "üçgen"), (180, "karşıt")]

HOUSE_THEMES = {
    1: "kişilik, görünüş, yeni başlangıçlar",
    2: "para, kazanç, öz değer",
    3: "iletişim, kardeşler, kısa yolculuklar, öğrenme",
    4: "ev, aile, geçmiş, iç huzur",
    5: "aşk, yaratıcılık, eğlence, çocuklar",
    6: "günlük işler, sağlık, düzen, iş arkadaşları",
    7: "ilişkiler, ortaklıklar, evlilik, anlaşmalar",
    8: "ortak para, borç-alacak, dönüşüm, yakınlık",
    9: "uzak yolculuklar, eğitim, inançlar, yeni ufuklar",
    10: "kariyer, hedefler, statü, otorite",
    11: "arkadaşlar, gruplar, umutlar, sosyal çevre",
    12: "dinlenme, iç dünya, sezgiler, kapanışlar",
}

PHASES = [(0, "Yeniay"), (45, "Büyüyen Hilal"), (90, "İlk Dördün"), (135, "Büyüyen Ay"),
          (180, "Dolunay"), (225, "Küçülen Ay"), (270, "Son Dördün"), (315, "Küçülen Hilal")]


def _time(dt: datetime) -> ast.Time:
    return ast.Time.Make(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second)


def longitude(body: ast.Body, dt_utc: datetime) -> float:
    t = _time(dt_utc)
    vec = ast.GeoVector(body, t, True)
    return ast.Ecliptic(vec).elon % 360.0


def sign_index(lon: float) -> int:
    return int(lon // 30) % 12


def fmt_deg(lon: float) -> str:
    d = lon % 30
    return f"{int(d)}°{int((d - int(d)) * 60):02d}'"


def _sep(a: float, b: float) -> float:
    d = abs(a - b) % 360
    return 360 - d if d > 180 else d


@dataclass
class Planet:
    name: str
    lon: float
    sign: int
    retro: bool
    sign_start: int
    sign_end: int
    station: str | None = None  # "retro başlıyor" / "düz harekete geçiyor"

    @property
    def ingress(self) -> bool:
        return self.sign_start != self.sign_end


@dataclass
class Aspect:
    a: str
    b: str
    angle: int
    name: str
    orb: float
    exact_today: bool
    slow_pair: bool


@dataclass
class Sky:
    day: date
    planets: dict[str, Planet]
    aspects: list[Aspect]
    moon_phase: str
    moon_phase_event: str | None  # bugün olan Yeniay/Dolunay/Dördün
    events: list[str] = field(default_factory=list)


def compute_sky(day: date) -> Sky:
    start = datetime(day.year, day.month, day.day, 0, 0, tzinfo=TZ).astimezone(timezone.utc)
    noon = start + timedelta(hours=12)
    end = start + timedelta(hours=24)

    planets: dict[str, Planet] = {}
    lon_start: dict[str, float] = {}
    lon_end: dict[str, float] = {}
    for body, name in BODIES:
        l0, l1, l2 = longitude(body, start), longitude(body, noon), longitude(body, end)
        lon_start[name], lon_end[name] = l0, l2
        retro = False
        station = None
        if name not in ("Güneş", "Ay"):
            # Günlük hareket yönü: dün→bugün ve bugün→yarın
            prev = longitude(body, noon - timedelta(days=1))
            nxt = longitude(body, noon + timedelta(days=1))
            m_before = ((l1 - prev + 540) % 360) - 180
            m_after = ((nxt - l1 + 540) % 360) - 180
            retro = m_after < 0
            if m_before >= 0 > m_after:
                station = "retro hareketine başlıyor"
            elif m_before < 0 <= m_after:
                station = "düz harekete geçiyor"
        planets[name] = Planet(name, l1, sign_index(l1), retro, sign_index(l0), sign_index(l2), station)

    # Açılar: öğlen konumlarına göre, "bugün tam oluyor" kontrolü gün başı/sonu ile
    names = [n for _, n in BODIES]
    aspects: list[Aspect] = []
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            slow_pair = a in SLOW and b in SLOW
            sep = _sep(planets[a].lon, planets[b].lon)
            for angle, aname in ASPECTS:
                orb_limit = 6.0 if ("Ay" in (a, b) or "Güneş" in (a, b)) else 4.0
                if slow_pair:
                    orb_limit = 1.0
                orb = abs(sep - angle)
                if orb <= orb_limit:
                    d0 = _sep(lon_start[a], lon_start[b]) - angle
                    d1 = _sep(lon_end[a], lon_end[b]) - angle
                    exact = (d0 == 0) or (d1 == 0) or (d0 > 0) != (d1 > 0)
                    aspects.append(Aspect(a, b, angle, aname, round(orb, 1), exact, slow_pair))
    aspects.sort(key=lambda x: (not x.exact_today, x.slow_pair, x.orb))

    # Ay evresi
    phase_angle = ast.MoonPhase(_time(noon))
    phase_name = min(PHASES, key=lambda p: min(abs(phase_angle - p[0]), 360 - abs(phase_angle - p[0])))[1]
    phase_event = None
    for target, label in ((0, "Yeniay"), (90, "İlk Dördün"), (180, "Dolunay"), (270, "Son Dördün")):
        found = ast.SearchMoonPhase(target, _time(start), 1.0)
        if found is not None and found.ut <= _time(end).ut:
            moon_lon = longitude(ast.Body.Moon, found.Utc().replace(tzinfo=timezone.utc))
            phase_event = f"{label} ({SIGN_TR[sign_index(moon_lon)]} burcunda)"
            break

    sky = Sky(day, planets, aspects, phase_name, phase_event)

    # Bugünün öne çıkan olayları (genel)
    if phase_event:
        sky.events.append(f"Bugün {phase_event} gerçekleşiyor.")
    for p in planets.values():
        if p.ingress:
            sky.events.append(f"{p.name} bugün {SIGN_DAT[p.sign_end]} geçiyor.")
        if p.station:
            sky.events.append(f"{p.name} bugün {p.station}.")
    for asp in aspects:
        if asp.exact_today and not asp.slow_pair:
            sky.events.append(f"{asp.a} ile {asp.b} arasında {asp.name} açısı bugün tam oluyor.")
    return sky


def house_of(planet_sign: int, sun_sign: int) -> int:
    return (planet_sign - sun_sign) % 12 + 1


def sign_brief(sky: Sky, s: int) -> list[str]:
    """Bir burç için o günün somut, gerçek verilere dayalı astrolojik notları."""
    notes: list[str] = []
    moon = sky.planets["Ay"]
    if moon.ingress:
        h0, h1 = house_of(moon.sign_start, s), house_of(moon.sign_end, s)
        notes.append(
            f"Ay gün içinde {SIGN_LOC[moon.sign_start]} ({h0}. ev: {HOUSE_THEMES[h0]}) "
            f"{SIGN_DAT[moon.sign_end]} geçiyor ({h1}. ev: {HOUSE_THEMES[h1]})."
        )
    else:
        h = house_of(moon.sign, s)
        notes.append(f"Ay {SIGN_LOC[moon.sign]}, yani {h}. evinde ({HOUSE_THEMES[h]}).")

    for p in sky.planets.values():
        if p.name == "Ay":
            continue
        h = house_of(p.sign, s)
        if p.ingress:
            notes.append(f"{p.name} bugün {SIGN_DAT[p.sign_end]}, yani {house_of(p.sign_end, s)}. evine "
                         f"({HOUSE_THEMES[house_of(p.sign_end, s)]}) geçiyor.")
        if p.station:
            notes.append(f"{p.name} {h}. evinde ({HOUSE_THEMES[h]}) {p.station}.")
        elif p.sign == s and p.name != "Güneş":
            notes.append(f"{p.name} kendi burcunda ({SIGN_TR[s]}){', retro' if p.retro else ''}.")

    # Kişisel gezegen konumları (ev bazında kısa özet)
    for name in ("Güneş", "Merkür", "Venüs", "Mars"):
        p = sky.planets[name]
        h = house_of(p.sign, s)
        notes.append(f"{name} {SIGN_LOC[p.sign]} {fmt_deg(p.lon)}{' (retro)' if p.retro else ''} → "
                     f"{h}. ev ({HOUSE_THEMES[h]}).")

    # Bugün tam olan ya da çok yakın açılar, bu burcun hangi evlerini etkiliyor
    count = 0
    for asp in sky.aspects:
        if asp.slow_pair or count >= 4:
            continue
        if not asp.exact_today and asp.orb > 2.0:
            continue
        ha = house_of(sky.planets[asp.a].sign, s)
        hb = house_of(sky.planets[asp.b].sign, s)
        when = "bugün tam" if asp.exact_today else f"{asp.orb}° orb ile etkin"
        notes.append(f"{asp.a} ({ha}. ev) – {asp.b} ({hb}. ev) {asp.name}, {when}.")
        count += 1

    if sky.moon_phase_event:
        notes.append(f"Ay evresi olayı: {sky.moon_phase_event}.")
    else:
        notes.append(f"Ay evresi: {sky.moon_phase}.")
    return notes


def sky_summary(sky: Sky) -> list[str]:
    """Uygulamada 'Bugünün gökyüzü' bölümünde gösterilecek kısa liste."""
    lines = []
    for p in sky.planets.values():
        lines.append(f"{p.name} {SIGN_LOC[p.sign]} {fmt_deg(p.lon)}{' ℞' if p.retro else ''}")
    return lines


if __name__ == "__main__":
    import sys
    d = date.fromisoformat(sys.argv[1]) if len(sys.argv) > 1 else datetime.now(TZ).date()
    sky = compute_sky(d)
    print("Tarih:", d, "| Ay evresi:", sky.moon_phase)
    print("\n".join(sky_summary(sky)))
    print("\nOlaylar:", *sky.events, sep="\n - ")
    print("\nKoç için:", *sign_brief(sky, 0), sep="\n - ")
