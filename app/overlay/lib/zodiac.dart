class Zodiac {
  final String id;
  final String name;
  final String symbol;
  final String range;
  final String element;
  const Zodiac(this.id, this.name, this.symbol, this.range, this.element);
}

const List<Zodiac> kZodiacs = [
  Zodiac('koc', 'Koç', '♈', '21 Mart – 19 Nisan', 'Ateş'),
  Zodiac('boga', 'Boğa', '♉', '20 Nisan – 20 Mayıs', 'Toprak'),
  Zodiac('ikizler', 'İkizler', '♊', '21 Mayıs – 20 Haziran', 'Hava'),
  Zodiac('yengec', 'Yengeç', '♋', '21 Haziran – 22 Temmuz', 'Su'),
  Zodiac('aslan', 'Aslan', '♌', '23 Temmuz – 22 Ağustos', 'Ateş'),
  Zodiac('basak', 'Başak', '♍', '23 Ağustos – 22 Eylül', 'Toprak'),
  Zodiac('terazi', 'Terazi', '♎', '23 Eylül – 22 Ekim', 'Hava'),
  Zodiac('akrep', 'Akrep', '♏', '23 Ekim – 21 Kasım', 'Su'),
  Zodiac('yay', 'Yay', '♐', '22 Kasım – 21 Aralık', 'Ateş'),
  Zodiac('oglak', 'Oğlak', '♑', '22 Aralık – 19 Ocak', 'Toprak'),
  Zodiac('kova', 'Kova', '♒', '20 Ocak – 18 Şubat', 'Hava'),
  Zodiac('balik', 'Balık', '♓', '19 Şubat – 20 Mart', 'Su'),
];

Zodiac zodiacById(String id) =>
    kZodiacs.firstWhere((z) => z.id == id, orElse: () => kZodiacs.first);

const _months = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
];
const _weekdays = [
  'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'
];

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String trLongDate(DateTime d) =>
    '${d.day} ${_months[d.month - 1]} ${d.year}, ${_weekdays[d.weekday - 1]}';
