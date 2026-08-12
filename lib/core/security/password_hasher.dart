import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

///LuS
class HashedPassword {
  const HashedPassword({required this.hash, required this.salt});
  ///base64
  final String hash;
  final String salt;
}

/// Password hashing based on PBKDF2-HMAC-SHA256.
class PasswordHasher {
  const PasswordHasher();

  ///PBKDF2 rounds
  static const int _iterations = 20000;
  static const int _keyLengthInBytes = 32; ///256 bit.
  static const int _saltLengthInBytes = 16; ///128 bit

  HashedPassword hashPassword(String plainPassword) {
    final salt = _generateSalt();
    final derivedKey = _deriveKey(plainPassword, salt);
    return HashedPassword(
      hash: base64Encode(derivedKey),
      salt: base64Encode(salt),
    );
  }

  bool verifyPassword({
    required String plainPassword,
    required String expectedHash,
    required String storedSalt,
  }) {
    try {
      final salt = base64Decode(storedSalt);
      final derivedKey = _deriveKey(plainPassword, salt);
      return _constantTimeEquals(base64Decode(expectedHash), derivedKey);
    } on FormatException {
      return false;
    }
  }

  Uint8List _generateSalt() {
    final random = Random.secure();
    final salt = Uint8List(_saltLengthInBytes);
    for (var i = 0; i < salt.length; i++) {
      salt[i] = random.nextInt(256);
    }
    return salt;
  }

  ///PBKDF2 key derivation
  Uint8List _deriveKey(String password, Uint8List salt) {
    final hmac = Hmac(sha256, utf8.encode(password));
    const hashLength = 32; ///SHA-256 output size
    final blockCount = (_keyLengthInBytes / hashLength).ceil();
    final derivedKey = BytesBuilder();

    for (var blockIndex = 1; blockIndex <= blockCount; blockIndex++) {
      final block = Uint8List(salt.length + 4)
        ..setRange(0, salt.length, salt)
        ..buffer.asByteData().setUint32(salt.length, blockIndex, Endian.big);

      var previous = Uint8List.fromList(hmac.convert(block).bytes);
      final accumulator = Uint8List.fromList(previous);

      for (var round = 1; round < _iterations; round++) {
        previous = Uint8List.fromList(hmac.convert(previous).bytes);
        for (var i = 0; i < accumulator.length; i++) {
          accumulator[i] ^= previous[i];
        }
      }
      derivedKey.add(accumulator);
    }

    return Uint8List.fromList(
      derivedKey.takeBytes().sublist(0, _keyLengthInBytes),
    );
  }
  ///vs timing attack
  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}