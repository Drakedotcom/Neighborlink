///LuS DDL statements identity
///namespace for tables
class CoreSchema {
  const CoreSchema._();

  static const String tableNeighborhoods = 'neighborhoods';
  static const String tableUsers = 'users';
  static const String tableNotifications = 'notifications';

  static const List<String> createStatements = <String>[
    ///mvp: postal code = neighborrhood
    '''
    CREATE TABLE $tableNeighborhoods (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      postal_code  TEXT    NOT NULL UNIQUE,
      city_name    TEXT    NOT NULL,
      description  TEXT    NOT NULL DEFAULT '',
      created_at   TEXT    NOT NULL
    )
    ''',

    '''
    CREATE TABLE $tableUsers (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      full_name       TEXT    NOT NULL,
      email           TEXT    NOT NULL UNIQUE COLLATE NOCASE,
      password_hash   TEXT    NOT NULL,
      password_salt   TEXT    NOT NULL,
      street_address  TEXT    NOT NULL,
      postal_code     TEXT    NOT NULL,
      neighborhood_id INTEGER NOT NULL,
      about_me        TEXT    NOT NULL DEFAULT '',
      created_at      TEXT    NOT NULL,
      FOREIGN KEY (neighborhood_id)
        REFERENCES $tableNeighborhoods (id) ON DELETE CASCADE
    )
    ''',
    'CREATE INDEX idx_users_neighborhood ON $tableUsers (neighborhood_id)',

    '''
    CREATE TABLE $tableNotifications (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      recipient_id INTEGER NOT NULL,
      title        TEXT    NOT NULL,
      message      TEXT    NOT NULL,
      category     TEXT    NOT NULL,
      is_read      INTEGER NOT NULL DEFAULT 0,
      created_at   TEXT    NOT NULL,
      FOREIGN KEY (recipient_id)
        REFERENCES $tableUsers (id) ON DELETE CASCADE
    )
    ''',
    'CREATE INDEX idx_notifications_recipient '
        'ON $tableNotifications (recipient_id, is_read)',
  ];
}