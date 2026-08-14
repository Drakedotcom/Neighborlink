///NiS
/// DDL statements for the community feed, ride sharing and events.
///
/// Design note: participation is modelled through dedicated join tables
/// instead of a counter column. That way "free seats" is always derived from
/// real rows and can never drift out of sync.
class CommunitySchema {
  const CommunitySchema._();

  static const String tablePosts = 'posts';
  static const String tableRides = 'rides';
  static const String tableRideParticipants = 'ride_participants';
  static const String tableEvents = 'events';
  static const String tableEventParticipants = 'event_participants';

  static const List<String> createStatements = <String>[
    //the community feed
    '''
    CREATE TABLE $tablePosts (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      neighborhood_id INTEGER NOT NULL,
      author_id       INTEGER NOT NULL,
      title           TEXT    NOT NULL,
      description     TEXT    NOT NULL,
      category        TEXT    NOT NULL,
      created_at      TEXT    NOT NULL,
      FOREIGN KEY (neighborhood_id) REFERENCES neighborhoods (id) ON DELETE CASCADE,
      FOREIGN KEY (author_id)       REFERENCES users (id)         ON DELETE CASCADE
    )
    ''',
    'CREATE INDEX idx_posts_feed ON $tablePosts (neighborhood_id, created_at)',

    //rides
    '''
    CREATE TABLE $tableRides (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      neighborhood_id INTEGER NOT NULL,
      driver_id       INTEGER NOT NULL,
      origin          TEXT    NOT NULL,
      destination     TEXT    NOT NULL,
      departure_date  TEXT    NOT NULL,
      departure_time  TEXT    NOT NULL,
      total_seats     INTEGER NOT NULL,
      note            TEXT    NOT NULL DEFAULT '',
      created_at      TEXT    NOT NULL,
      FOREIGN KEY (neighborhood_id) REFERENCES neighborhoods (id) ON DELETE CASCADE,
      FOREIGN KEY (driver_id)       REFERENCES users (id)         ON DELETE CASCADE,
      CHECK (total_seats > 0)
    )
    ''',
    '''
    CREATE TABLE $tableRideParticipants (
      id        INTEGER PRIMARY KEY AUTOINCREMENT,
      ride_id   INTEGER NOT NULL,
      user_id   INTEGER NOT NULL,
      joined_at TEXT    NOT NULL,
      UNIQUE (ride_id, user_id),
      FOREIGN KEY (ride_id) REFERENCES $tableRides (id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users (id)       ON DELETE CASCADE
    )
    ''',

    //events
    '''
    CREATE TABLE $tableEvents (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      neighborhood_id INTEGER NOT NULL,
      organizer_id    INTEGER NOT NULL,
      title           TEXT    NOT NULL,
      location        TEXT    NOT NULL,
      event_date      TEXT    NOT NULL,
      event_time      TEXT    NOT NULL DEFAULT '18:00',
      description     TEXT    NOT NULL,
      created_at      TEXT    NOT NULL,
      FOREIGN KEY (neighborhood_id) REFERENCES neighborhoods (id) ON DELETE CASCADE,
      FOREIGN KEY (organizer_id)    REFERENCES users (id)         ON DELETE CASCADE
    )
    ''',
    'CREATE INDEX idx_events_date ON $tableEvents (neighborhood_id, event_date)',
    '''
    CREATE TABLE $tableEventParticipants (
      id        INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id  INTEGER NOT NULL,
      user_id   INTEGER NOT NULL,
      joined_at TEXT    NOT NULL,
      UNIQUE (event_id, user_id),
      FOREIGN KEY (event_id) REFERENCES $tableEvents (id) ON DELETE CASCADE,
      FOREIGN KEY (user_id)  REFERENCES users (id)        ON DELETE CASCADE
    )
    ''',
  ];
}
