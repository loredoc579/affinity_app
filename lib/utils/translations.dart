// lib/utils/translations.dart

extension GenderTranslation on String {
  /// Traduce la chiave del database nella lingua dell'interfaccia.
  /// Un domani, qui dentro chiamerai il pacchetto di traduzione vero e proprio!
  String get translateGender {
    switch (toLowerCase()) {
      case 'male':
        return 'Uomo'; // o 'Maschio'
      case 'female':
        return 'Donna'; // o 'Femmina'
      case 'other':
        return 'Altro';
      default:
        return 'N.D.';
    }
  }
}

extension UITextTranslation on String {
  /// Usa '.tr' sulle chiavi per ottenere il testo tradotto.
  /// Domani basterà fare: return Localization.of(context).translate(this);
  String get tr {
    switch (this) {
      case 'about_me': return 'Su di me';
      case 'lives_in': return '📍 Vive a ';
      case 'gender_label': return '🚻 Genere: ';
      case 'hobbies_title': return 'Hobby e passioni';
      case 'btn_superlike': return 'SUPERLIKE';
      case 'btn_like': return 'MI PIACE';
      case 'not_available': return 'N.D.';
      default: return this; // Fallback: se dimentichi una chiave, stampa la chiave stessa
    }
  }
}