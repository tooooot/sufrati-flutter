// الاسم الأول للتحية: «أبو سعد» و«أم عبدالله» و«عبد الرحمن» اسم من كلمتين، فلا تُقطع الأولى وحدها («أبو»/«أم»/«عبد»).
String firstName(String full) {
  final parts = full.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  const joiners = {'أبو', 'ابو', 'أبا', 'أم', 'ام', 'ابن', 'بن', 'بنت', 'عبد', 'عبدال', 'ذو', 'آل', 'ال'};
  return (joiners.contains(parts.first) && parts.length > 1) ? '${parts[0]} ${parts[1]}' : parts.first;
}
