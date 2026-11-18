String _two(int v) => v.toString().padLeft(2, '0');

/// `18.11.2026`
String formatDate(DateTime d) {
  final l = d.toLocal();
  return '${_two(l.day)}.${_two(l.month)}.${l.year}';
}

/// `18.11.2026 14:05`
String formatDateTime(DateTime d) {
  final l = d.toLocal();
  return '${formatDate(l)} ${_two(l.hour)}:${_two(l.minute)}';
}
