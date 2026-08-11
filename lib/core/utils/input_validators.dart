///form validators

///LuS
class InputValidators {
  const InputValidators._();

  static final RegExp _emailPattern = RegExp(
    r'^[\w.+-]+@[\w-]+\.[\w.-]{2,}$',
  );
  static final RegExp _postalCodePattern = RegExp(r'^\d{5}$');
  ///requires non empty
  static String? required(String? value, {String field = 'Dieses Feld'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field darf nicht leer sein.';
    }
    return null;
  }

  ///at least x characters
  static String? minLength(String? value, int min, {String field = 'Eingabe'}) {
    final emptyError = required(value, field: field);
    if (emptyError != null) return emptyError;
    if (value!.trim().length < min) {
      return '$field muss mindestens $min Zeichen lang sein.';
    }
    return null;
  }

  ///syntactically plausible e-mail address.
  static String? email(String? value) {
    final emptyError = required(value, field: 'E-Mail');
    if (emptyError != null) return emptyError;
    if (!_emailPattern.hasMatch(value!.trim())) {
      return 'Bitte eine gültige E-Mail-Adresse eingeben.';
    }
    return null;
  }

  ///password policy: at least 8 characters, one letter, one digit.
  static String? password(String? value) {
    final emptyError = required(value, field: 'Passwort');
    if (emptyError != null) return emptyError;

    final password = value!;
    if (password.length < 8) {
      return 'Das Passwort muss mindestens 8 Zeichen haben.';
    }
    final hasLetter = password.contains(RegExp(r'[A-Za-zÄÖÜäöüß]'));
    final hasDigit = password.contains(RegExp(r'\d'));
    if (!hasLetter || !hasDigit) {
      return 'Das Passwort braucht Buchstaben und mindestens eine Ziffer.';
    }
    return null;
  }

  ///postal code user -> neighbourhood
  static String? postalCode(String? value) {
    final emptyError = required(value, field: 'Postleitzahl');
    if (emptyError != null) return emptyError;
    if (!_postalCodePattern.hasMatch(value!.trim())) {
      return 'Die Postleitzahl muss aus genau 5 Ziffern bestehen.';
    }
    return null;
  }

  ///positive whole number
  static String? positiveInteger(String? value, {String field = 'Wert'}) {
    final emptyError = required(value, field: field);
    if (emptyError != null) return emptyError;
    final parsed = int.tryParse(value!.trim());
    if (parsed == null) return '$field muss eine ganze Zahl sein.';
    if (parsed <= 0) return '$field muss größer als 0 sein.';
    return null;
  }

  static String? matches(String? value, String other, {String field = 'Werte'}) {
    if (value != other) return '$field stimmen nicht überein.';
    return null;
  }
}
