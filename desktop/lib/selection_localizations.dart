import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'localization.dart';

/// Localizes only the seven standard selection commands. Other Material
/// messages retain Flutter's default English wording.
class SelectionLocalizations extends DefaultMaterialLocalizations {
  SelectionLocalizations(this.preferences);
  final Map<String, dynamic> preferences;
  @override
  String get copyButtonLabel => localizePreferences(preferences, 'Copy');
  @override
  String get cutButtonLabel => localizePreferences(preferences, 'Cut');
  @override
  String get pasteButtonLabel => localizePreferences(preferences, 'Paste');
  @override
  String get selectAllButtonLabel =>
      localizePreferences(preferences, 'Select all');
  @override
  String get lookUpButtonLabel => localizePreferences(preferences, 'Look Up');
  @override
  String get searchWebButtonLabel =>
      localizePreferences(preferences, 'Search Web');
  @override
  String get shareButtonLabel => localizePreferences(preferences, 'Share');
}

class SelectionLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  SelectionLocalizationsDelegate(Map<String, dynamic> preferences)
    : language = preferences['language'] ?? 'en',
      vocabulary = Map<String, String>.unmodifiable(
        preferences['privateVocabulary'] is Map
            ? Map<String, String>.from(preferences['privateVocabulary'] as Map)
            : const <String, String>{},
      );
  final Object language;
  final Map<String, String> vocabulary;
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<MaterialLocalizations> load(Locale locale) => SynchronousFuture(
    SelectionLocalizations({
      'language': language,
      'privateVocabulary': vocabulary,
    }),
  );
  @override
  bool shouldReload(SelectionLocalizationsDelegate old) =>
      language != old.language || !mapEquals(vocabulary, old.vocabulary);
}
