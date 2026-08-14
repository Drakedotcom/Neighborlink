/// LuL DDL statements for sharing and care
class SharingSchema {
  const SharingSchema._();

  static const String tableFoodShares = 'food_shares';
  static const String tableFoodInterests = 'food_interests';
  static const String tableFurnitureOffers = 'furniture_offers';
  static const String tableFurnitureRequests = 'furniture_requests';
  static const String tableChildcareRequests = 'childcare_requests';
  static const String tableChildcareOffers = 'childcare_offers';
  static const String tablePetcareRequests = 'petcare_requests';
  static const String tablePetcareOffers = 'petcare_offers';

  static const List<String> createStatements = <String>[

    '''
    CREATE TABLE $tableFoodShares (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      neighborhood_id INTEGER NOT NULL,
      owner_id        INTEGER NOT NULL,
      title           TEXT    NOT NULL,
      description     TEXT    NOT NULL,
      quantity        TEXT    NOT NULL,
      expires_on      TEXT    NOT NULL,
      status          TEXT    NOT NULL DEFAULT 'available',
      reserved_by_id  INTEGER,
      created_at      TEXT    NOT NULL,
      FOREIGN KEY (neighborhood_id) REFERENCES neighborhoods (id) ON DELETE CASCADE,
      FOREIGN KEY (owner_id)        REFERENCES users (id)         ON DELETE CASCADE,
      FOREIGN KEY (reserved_by_id)  REFERENCES users (id)         ON DELETE SET NULL,
      CHECK (status IN ('available', 'reserved', 'picked_up'))
    )
    ''',

    '''
    CREATE TABLE $tableFoodInterests (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      food_share_id INTEGER NOT NULL,
      user_id       INTEGER NOT NULL,
      created_at    TEXT    NOT NULL,
      UNIQUE (food_share_id, user_id),
      FOREIGN KEY (food_share_id) REFERENCES $tableFoodShares (id) ON DELETE CASCADE,
      FOREIGN KEY (user_id)       REFERENCES users (id)            ON DELETE CASCADE
    )
    ''',

    '''
    CREATE TABLE $tableFurnitureOffers (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      neighborhood_id INTEGER NOT NULL,
      owner_id        INTEGER NOT NULL,
      title           TEXT    NOT NULL,
      description     TEXT    NOT NULL,
      condition_label TEXT    NOT NULL,
      status          TEXT    NOT NULL DEFAULT 'available',
      reserved_by_id  INTEGER,
      created_at      TEXT    NOT NULL,
      FOREIGN KEY (neighborhood_id) REFERENCES neighborhoods (id) ON DELETE CASCADE,
      FOREIGN KEY (owner_id)        REFERENCES users (id)         ON DELETE CASCADE,
      FOREIGN KEY (reserved_by_id)  REFERENCES users (id)         ON DELETE SET NULL,
      CHECK (status IN ('available', 'reserved', 'given_away'))
    )
    ''',

    '''
    CREATE TABLE $tableFurnitureRequests (
      id                  INTEGER PRIMARY KEY AUTOINCREMENT,
      furniture_offer_id  INTEGER NOT NULL,
      requester_id        INTEGER NOT NULL,
      message             TEXT    NOT NULL DEFAULT '',
      status              TEXT    NOT NULL DEFAULT 'pending',
      created_at          TEXT    NOT NULL,
      UNIQUE (furniture_offer_id, requester_id),
      FOREIGN KEY (furniture_offer_id)
        REFERENCES $tableFurnitureOffers (id) ON DELETE CASCADE,
      FOREIGN KEY (requester_id) REFERENCES users (id) ON DELETE CASCADE,
      CHECK (status IN ('pending', 'accepted', 'declined'))
    )
    ''',

    '''
    CREATE TABLE $tableChildcareRequests (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      neighborhood_id INTEGER NOT NULL,
      requester_id    INTEGER NOT NULL,
      care_date       TEXT    NOT NULL,
      care_time       TEXT    NOT NULL,
      description     TEXT    NOT NULL,
      status          TEXT    NOT NULL DEFAULT 'open',
      created_at      TEXT    NOT NULL,
      FOREIGN KEY (neighborhood_id) REFERENCES neighborhoods (id) ON DELETE CASCADE,
      FOREIGN KEY (requester_id)    REFERENCES users (id)         ON DELETE CASCADE,
      CHECK (status IN ('open', 'covered'))
    )
    ''',
    '''
    CREATE TABLE $tableChildcareOffers (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      request_id INTEGER NOT NULL,
      helper_id  INTEGER NOT NULL,
      message    TEXT    NOT NULL DEFAULT '',
      created_at TEXT    NOT NULL,
      UNIQUE (request_id, helper_id),
      FOREIGN KEY (request_id) REFERENCES $tableChildcareRequests (id) ON DELETE CASCADE,
      FOREIGN KEY (helper_id)  REFERENCES users (id)                   ON DELETE CASCADE
    )
    ''',

    '''
    CREATE TABLE $tablePetcareRequests (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      neighborhood_id INTEGER NOT NULL,
      requester_id    INTEGER NOT NULL,
      pet_type        TEXT    NOT NULL,
      start_date      TEXT    NOT NULL,
      end_date        TEXT    NOT NULL,
      description     TEXT    NOT NULL,
      status          TEXT    NOT NULL DEFAULT 'open',
      created_at      TEXT    NOT NULL,
      FOREIGN KEY (neighborhood_id) REFERENCES neighborhoods (id) ON DELETE CASCADE,
      FOREIGN KEY (requester_id)    REFERENCES users (id)         ON DELETE CASCADE,
      CHECK (status IN ('open', 'covered'))
    )
    ''',
    '''
    CREATE TABLE $tablePetcareOffers (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      request_id INTEGER NOT NULL,
      helper_id  INTEGER NOT NULL,
      message    TEXT    NOT NULL DEFAULT '',
      created_at TEXT    NOT NULL,
      UNIQUE (request_id, helper_id),
      FOREIGN KEY (request_id) REFERENCES $tablePetcareRequests (id) ON DELETE CASCADE,
      FOREIGN KEY (helper_id)  REFERENCES users (id)                 ON DELETE CASCADE
    )
    ''',
  ];
}
