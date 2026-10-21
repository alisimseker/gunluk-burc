class Zodiac {
  final String id;
  final String name;
  final String range;
  final String element;
  final String quality;
  final String ruler;
  const Zodiac(this.id, this.name, this.range, this.element, this.quality, this.ruler);
}

const List<Zodiac> kZodiacs = [
  Zodiac('koc', 'Koç', '21 Mart – 19 Nisan', 'Ateş', 'Öncü', 'Mars'),
  Zodiac('boga', 'Boğa', '20 Nisan – 20 Mayıs', 'Toprak', 'Sabit', 'Venüs'),
  Zodiac('ikizler', 'İkizler', '21 Mayıs – 20 Haziran', 'Hava', 'Değişken', 'Merkür'),
  Zodiac('yengec', 'Yengeç', '21 Haziran – 22 Temmuz', 'Su', 'Öncü', 'Ay'),
  Zodiac('aslan', 'Aslan', '23 Temmuz – 22 Ağustos', 'Ateş', 'Sabit', 'Güneş'),
  Zodiac('basak', 'Başak', '23 Ağustos – 22 Eylül', 'Toprak', 'Değişken', 'Merkür'),
  Zodiac('terazi', 'Terazi', '23 Eylül – 22 Ekim', 'Hava', 'Öncü', 'Venüs'),
  Zodiac('akrep', 'Akrep', '23 Ekim – 21 Kasım', 'Su', 'Sabit', 'Plüton'),
  Zodiac('yay', 'Yay', '22 Kasım – 21 Aralık', 'Ateş', 'Değişken', 'Jüpiter'),
  Zodiac('oglak', 'Oğlak', '22 Aralık – 19 Ocak', 'Toprak', 'Öncü', 'Satürn'),
  Zodiac('kova', 'Kova', '20 Ocak – 18 Şubat', 'Hava', 'Sabit', 'Uranüs'),
  Zodiac('balik', 'Balık', '19 Şubat – 20 Mart', 'Su', 'Değişken', 'Neptün'),
];

Zodiac zodiacById(String id) => kZodiacs.firstWhere((z) => z.id == id, orElse: () => kZodiacs.first);

const Map<String, String> kPlanetNames = {
  'sun': 'Güneş',
  'moon': 'Ay',
  'mercury': 'Merkür',
  'venus': 'Venüs',
  'mars': 'Mars',
  'jupiter': 'Jüpiter',
  'saturn': 'Satürn',
  'uranus': 'Uranüs',
  'neptune': 'Neptün',
  'pluto': 'Plüton',
  'node': 'Kuzey Ay Düğümü',
};

const List<String> kSignLoc = [
  "Koç'ta", "Boğa'da", "İkizler'de", "Yengeç'te", "Aslan'da", "Başak'ta",
  "Terazi'de", "Akrep'te", "Yay'da", "Oğlak'ta", "Kova'da", "Balık'ta"
];

const _months = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
];
const _weekdays = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String trLongDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}, ${_weekdays[d.weekday - 1]}';
String trDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
String trDayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// Doğum tarihinden güneş burcu (yaklaşık sınırlar; sınır günlerinde hesaplama motoru kullanılır)
int sunSignByDate(DateTime d) {
  const starts = [
    [1, 20, 10], [2, 19, 11], [3, 21, 0], [4, 20, 1], [5, 21, 2], [6, 21, 3],
    [7, 23, 4], [8, 23, 5], [9, 23, 6], [10, 23, 7], [11, 22, 8], [12, 22, 9],
  ];
  var sign = 9; // Oğlak (yılbaşı)
  for (final s in starts) {
    if (d.month > s[0] || (d.month == s[0] && d.day >= s[1])) sign = s[2];
  }
  return sign;
}
