/// Parses numbers typed with Western, Arabic-Indic or Persian digits.
///
/// Normalization happens when validating/submitting, so it does not interrupt
/// the keyboard's composing text or move the cursor while the user types.
double? parseLocalizedDecimal(String? text) {
  final normalized = _normalizeNumber(text);
  return normalized == null ? null : double.tryParse(normalized);
}

int? parseLocalizedInteger(String? text) {
  final normalized = _normalizeNumber(text);
  return normalized == null ? null : int.tryParse(normalized);
}

String? _normalizeNumber(String? text) {
  if (text == null) return null;
  var normalized = String.fromCharCodes(
    text.trim().runes.map((rune) {
      if (rune >= 0x0660 && rune <= 0x0669) return rune - 0x0660 + 0x30;
      if (rune >= 0x06F0 && rune <= 0x06F9) return rune - 0x06F0 + 0x30;
      if (rune == 0x066B) return 0x2E; // Arabic decimal separator.
      return rune;
    }),
  );

  if (normalized.contains('\u066C')) {
    // Only remove correctly placed Arabic thousands separators. A misplaced
    // separator must not silently change the amount the user intended.
    if (!RegExp(r'^[+-]?[0-9]{1,3}(?:\u066C[0-9]{3})+(?:\.[0-9]+)?$')
        .hasMatch(normalized)) {
      return null;
    }
    normalized = normalized.replaceAll('\u066C', '');
  }
  return normalized;
}
