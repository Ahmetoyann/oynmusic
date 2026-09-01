extension TurkishStringExtension on String {
  String toSearchableString() {
    return this
        .replaceAll('I', 'ı')
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .replaceAll('ı', 'ı')
        .toLowerCase()
        .trim();
  }
}
