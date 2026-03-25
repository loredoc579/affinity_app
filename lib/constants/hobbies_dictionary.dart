class HobbiesDictionary {
  // Mappa divisa per categorie
  static const Map<String, List<String>> categorizedHobbies = {
    'Sport & Fitness': [
      'Palestra', 'Trekking', 'Corsa', 'Yoga', 'Calcio', 'Nuoto', 'Arrampicata'
    ],
    'Creatività & Arte': [
      'Fotografia', 'Pittura', 'Scrittura', 'Design', 'Teatro', 'Fai da te'
    ],
    'Intrattenimento': [
      'Netflix', 'Cinema', 'Videogiochi', 'Anime', 'Giochi da Tavolo', 'Concerti'
    ],
    'Food & Drink': [
      'Sushi', 'Vino', 'Cucinare', 'Birra Artigianale', 'Cibo di Strada', 'Caffè'
    ],
    'Stile di Vita': [
      'Viaggi', 'Cani', 'Gatti', 'Astrologia', 'Sostenibilità', 'Moda'
    ]
  };

  // Funzione comodità per avere tutti gli hobby in una singola lista piatta (utile per il backend)
  static List<String> get allHobbies {
    return categorizedHobbies.values.expand((element) => element).toList();
  }
}