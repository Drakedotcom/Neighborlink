///LuS
import '../../core/errors/app_exception.dart';
import '../../core/logging/app_logger.dart';
import '../../core/security/password_hasher.dart';
import '../database/schema/core_schema.dart';
import '../models/app_user.dart';
import 'base_repository.dart';

///only place for password hash!
class UserRepository extends BaseRepository {
  const UserRepository({PasswordHasher hasher = const PasswordHasher()})
    : _hasher = hasher;

  final PasswordHasher _hasher;

  Future<AppUser> register({
    required String fullName,
    required String email,
    required String plainPassword,
    required String streetAddress,
    required String postalCode,
    required int neighborhoodId,
  }) {
    return guard('register($email)', () async {
      final database = await db;
      final normalisedEmail = email.trim().toLowerCase();

      if (await existsByEmail(normalisedEmail)) {
        throw const ValidationException(
          'Für diese E-Mail-Adresse existiert bereits ein Konto.',
        );
      }

      final credentials = _hasher.hashPassword(plainPassword);
      final createdAt = DateTime.now();

      final id = await database.insert(CoreSchema.tableUsers, {
        'full_name': fullName.trim(),
        'email': normalisedEmail,
        'password_hash': credentials.hash,
        'password_salt': credentials.salt,
        'street_address': streetAddress.trim(),
        'postal_code': postalCode.trim(),
        'neighborhood_id': neighborhoodId,
        'about_me': '',
        'created_at': createdAt.toIso8601String(),
      });

      AppLogger.instance.info(logTag, 'New account created with id $id.');

      return AppUser(
        id: id,
        fullName: fullName.trim(),
        email: normalisedEmail,
        streetAddress: streetAddress.trim(),
        postalCode: postalCode.trim(),
        neighborhoodId: neighborhoodId,
        aboutMe: '',
        createdAt: createdAt,
      );
    });
  }

  Future<AppUser> authenticate({
    required String email,
    required String plainPassword,
  }) {
    return guard('authenticate($email)', () async {
      final database = await db;
      final rows = await database.query(
        CoreSchema.tableUsers,
        where: 'email = ?',
        whereArgs: <Object?>[email.trim().toLowerCase()],
        limit: 1,
      );
      ///throw same error for both to avoid attacks
      const genericFailure = AuthException(
        'E-Mail-Adresse oder Passwort ist nicht korrekt.',
      );

      if (rows.isEmpty) {
        AppLogger.instance.warning(logTag, 'Login attempt for unknown e-mail.');
        throw genericFailure;
      }

      final row = rows.first;
      final passwordIsValid = _hasher.verifyPassword(
        plainPassword: plainPassword,
        expectedHash: row['password_hash']! as String,
        storedSalt: row['password_salt']! as String,
      );

      if (!passwordIsValid) {
        AppLogger.instance.warning(logTag, 'Login failed: wrong password.');
        throw genericFailure;
      }

      AppLogger.instance.info(logTag, 'Login succeeded for user #${row['id']}.');
      return AppUser.fromMap(row);
    });
  }

  Future<bool> existsByEmail(String email) {
    return guard('existsByEmail($email)', () async {
      final database = await db;
      final rows = await database.query(
        CoreSchema.tableUsers,
        columns: <String>['id'],
        where: 'email = ?',
        whereArgs: <Object?>[email.trim().toLowerCase()],
        limit: 1,
      );
      return rows.isNotEmpty;
    });
  }

  Future<AppUser> findById(int userId) {
    return guard('findById($userId)', () async {
      final database = await db;
      final rows = await database.query(
        CoreSchema.tableUsers,
        where: 'id = ?',
        whereArgs: <Object?>[userId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw NotFoundException('Benutzer #$userId wurde nicht gefunden.');
      }
      return AppUser.fromMap(rows.first);
    });
  }

  ///update editable parts of profile
  Future<AppUser> updateProfile(AppUser user) {
    return guard('updateProfile(#${user.id})', () async {
      final database = await db;
      final affectedRows = await database.update(
        CoreSchema.tableUsers,
        <String, Object?>{
          'full_name': user.fullName,
          'street_address': user.streetAddress,
          'about_me': user.aboutMe,
        },
        where: 'id = ?',
        whereArgs: <Object?>[user.id],
      );
      if (affectedRows == 0) {
        throw NotFoundException('Das Profil konnte nicht gefunden werden.');
      }
      return user;
    });
  }

  Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) {
    return guard('changePassword(#$userId)', () async {
      final database = await db;
      final rows = await database.query(
        CoreSchema.tableUsers,
        where: 'id = ?',
        whereArgs: <Object?>[userId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw NotFoundException('Das Konto wurde nicht gefunden.');
      }

      final isCurrentValid = _hasher.verifyPassword(
        plainPassword: currentPassword,
        expectedHash: rows.first['password_hash']! as String,
        storedSalt: rows.first['password_salt']! as String,
      );
      if (!isCurrentValid) {
        throw const AuthException('Das aktuelle Passwort ist nicht korrekt.');
      }

      final credentials = _hasher.hashPassword(newPassword);
      await database.update(
        CoreSchema.tableUsers,
        <String, Object?>{
          'password_hash': credentials.hash,
          'password_salt': credentials.salt,
        },
        where: 'id = ?',
        whereArgs: <Object?>[userId],
      );
      AppLogger.instance.info(logTag, 'Password changed for user #$userId.');
    });
  }
}