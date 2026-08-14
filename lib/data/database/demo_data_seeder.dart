///LuS demo content for "fake" database. GENERATED DATA.

import 'package:sqflite/sqflite.dart' as sqflite;

import '../../core/logging/app_logger.dart';
import '../../core/security/password_hasher.dart';
import 'schema/community_schema.dart';
import 'schema/core_schema.dart';
import 'schema/sharing_schema.dart';

///insert demot data set
class DemoDataSeeder {
  const DemoDataSeeder();

  static const String _logTag = 'DemoDataSeeder';
  static const String demoPassword = 'Demo1234';
  static const String demoEmail = 'anna.klein@neighborlink.de';

  Future<void> seed(sqflite.Database db) async {
    AppLogger.instance.info(_logTag, 'Seeding demo data ...');
    const hasher = PasswordHasher();
    final now = DateTime.now();

    String isoDaysAgo(int days) =>
        now.subtract(Duration(days: days)).toIso8601String();
    String dateInDays(int days) {
      final date = now.add(Duration(days: days));
      return '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
    }

    await db.transaction((txn) async {
      final muensterId = await txn.insert(CoreSchema.tableNeighborhoods, {
        'postal_code': '48149',
        'city_name': 'Münster',
        'description':
            'Kreuzviertel & Umgebung – eine aktive Nachbarschaft mit vielen '
            'Studierenden, Familien und Gärten.',
        'created_at': isoDaysAgo(120),
      });
      final berlinId = await txn.insert(CoreSchema.tableNeighborhoods, {
        'postal_code': '10115',
        'city_name': 'Berlin',
        'description': 'Mitte – dicht besiedelt, viel Wechsel, viel Potenzial.',
        'created_at': isoDaysAgo(90),
      });
      Future<int> insertUser({
        required String fullName,
        required String email,
        required String street,
        required String postalCode,
        required int neighborhoodId,
        required String aboutMe,
        required int registeredDaysAgo,
      }) async {
        final credentials = hasher.hashPassword(demoPassword);
        return txn.insert(CoreSchema.tableUsers, {
          'full_name': fullName,
          'email': email,
          'password_hash': credentials.hash,
          'password_salt': credentials.salt,
          'street_address': street,
          'postal_code': postalCode,
          'neighborhood_id': neighborhoodId,
          'about_me': aboutMe,
          'created_at': isoDaysAgo(registeredDaysAgo),
        });
      }

      final anna = await insertUser(
        fullName: 'Anna Klein',
        email: demoEmail,
        street: 'Kanalstraße 12',
        postalCode: '48149',
        neighborhoodId: muensterId,
        aboutMe: 'Backe zu viel, teile gerne. Erreichbar meistens abends.',
        registeredDaysAgo: 100,
      );
      final tobias = await insertUser(
        fullName: 'Tobias Wagner',
        email: 'tobias.wagner@neighborlink.de',
        street: 'Melchersstraße 4',
        postalCode: '48149',
        neighborhoodId: muensterId,
        aboutMe: 'Pendle täglich nach Osnabrück – zwei Plätze sind immer frei.',
        registeredDaysAgo: 88,
      );
      final sarah = await insertUser(
        fullName: 'Sarah Öztürk',
        email: 'sarah.oeztuerk@neighborlink.de',
        street: 'Nordstraße 88',
        postalCode: '48149',
        neighborhoodId: muensterId,
        aboutMe: 'Zwei Kinder, ein Hund, wenig Zeit – aber viel Hilfsbereitschaft.',
        registeredDaysAgo: 71,
      );
      final markus = await insertUser(
        fullName: 'Markus Feld',
        email: 'markus.feld@neighborlink.de',
        street: 'Grevener Straße 21',
        postalCode: '48149',
        neighborhoodId: muensterId,
        aboutMe: 'Schreiner im Ruhestand. Möbel reparieren statt wegwerfen.',
        registeredDaysAgo: 64,
      );
      final leyla = await insertUser(
        fullName: 'Leyla Demir',
        email: 'leyla.demir@neighborlink.de',
        street: 'Wilhelmstraße 7',
        postalCode: '48149',
        neighborhoodId: muensterId,
        aboutMe: 'Studiere Biologie und passe gerne auf Tiere auf.',
        registeredDaysAgo: 40,
      );
      final peter = await insertUser(
        fullName: 'Peter Haas',
        email: 'peter.haas@neighborlink.de',
        street: 'Kanalstraße 30',
        postalCode: '48149',
        neighborhoodId: muensterId,
        aboutMe: 'Organisiere das jährliche Straßenfest.',
        registeredDaysAgo: 33,
      );
      final nina = await insertUser(
        fullName: 'Nina Brahms',
        email: 'nina.brahms@neighborlink.de',
        street: 'Steinfurter Straße 55',
        postalCode: '48149',
        neighborhoodId: muensterId,
        aboutMe: 'Neu zugezogen und auf der Suche nach Anschluss.',
        registeredDaysAgo: 12,
      );
      await insertUser(
        fullName: 'Jonas Berger',
        email: 'jonas.berger@neighborlink.de',
        street: 'Invalidenstraße 3',
        postalCode: '10115',
        neighborhoodId: berlinId,
        aboutMe: 'Testkonto für eine zweite Nachbarschaft.',
        registeredDaysAgo: 20,
      );

      Future<void> insertPost({
        required int authorId,
        required String title,
        required String description,
        required String category,
        required int daysAgo,
      }) async {
        await txn.insert(CommunitySchema.tablePosts, {
          'neighborhood_id': muensterId,
          'author_id': authorId,
          'title': title,
          'description': description,
          'category': category,
          'created_at': isoDaysAgo(daysAgo),
        });
      }

      await insertPost(
        authorId: nina,
        title: 'Neu im Kreuzviertel – hallo zusammen!',
        description:
            'Ich bin letzte Woche in die Steinfurter Straße gezogen und freue '
            'mich, die Nachbarschaft kennenzulernen. Gibt es einen '
            'Stammtisch?',
        category: 'general',
        daysAgo: 3,
      );
      await insertPost(
        authorId: anna,
        title: 'Zu viel Sauerteigbrot gebacken',
        description:
            'Zwei Laibe warten auf Abnehmer. Details stehen unter Food Sharing.',
        category: 'food_sharing',
        daysAgo: 2,
      );
      await insertPost(
        authorId: markus,
        title: 'Werkzeug zum Ausleihen',
        description:
            'Bohrmaschine, Stichsäge und Schraubzwingen können jederzeit '
            'ausgeliehen werden – einfach klingeln.',
        category: 'furniture',
        daysAgo: 5,
      );
      await insertPost(
        authorId: tobias,
        title: 'Mitfahrgelegenheit nach Osnabrück',
        description:
            'Ich fahre mehrmals pro Woche. Wer regelmäßig mit will, meldet '
            'sich am besten direkt.',
        category: 'ride_sharing',
        daysAgo: 4,
      );
      await insertPost(
        authorId: peter,
        title: 'Planung Straßenfest',
        description:
            'Wir treffen uns zur Vorbereitung. Wer Lust hat mitzuhelfen, '
            'trägt sich bitte beim Event ein.',
        category: 'events',
        daysAgo: 6,
      );
      await insertPost(
        authorId: sarah,
        title: 'Babysitting-Kreis?',
        description:
            'Hat jemand Interesse an einem festen Babysitting-Kreis, in dem '
            'wir uns gegenseitig aushelfen?',
        category: 'child_care',
        daysAgo: 7,
      );
      await insertPost(
        authorId: leyla,
        title: 'Katzenbetreuung im Urlaub',
        description:
            'Ich übernehme gerne die Betreuung von Katzen, wenn ihr im Urlaub '
            'seid. Erfahrung ist vorhanden.',
        category: 'pet_care',
        daysAgo: 9,
      );

      final breadId = await txn.insert(SharingSchema.tableFoodShares, {
        'neighborhood_id': muensterId,
        'owner_id': anna,
        'title': 'Sauerteigbrot (2 Laibe)',
        'description': 'Heute Morgen gebacken, Roggen-Weizen-Mischung.',
        'quantity': '2 Laibe',
        'expires_on': dateInDays(3),
        'status': 'available',
        'created_at': isoDaysAgo(2),
      });
      await txn.insert(SharingSchema.tableFoodShares, {
        'neighborhood_id': muensterId,
        'owner_id': sarah,
        'title': 'Tomaten aus dem Garten',
        'description': 'Die Ernte war zu groß, ca. 3 kg San Marzano.',
        'quantity': '3 kg',
        'expires_on': dateInDays(5),
        'status': 'reserved',
        'reserved_by_id': nina,
        'created_at': isoDaysAgo(1),
      });
      await txn.insert(SharingSchema.tableFoodShares, {
        'neighborhood_id': muensterId,
        'owner_id': peter,
        'title': 'Apfelkuchen vom Straßenfest',
        'description': 'Reste vom letzten Treffen – noch komplett frisch.',
        'quantity': '1 Blech',
        'expires_on': dateInDays(1),
        'status': 'picked_up',
        'reserved_by_id': leyla,
        'created_at': isoDaysAgo(6),
      });
      await txn.insert(SharingSchema.tableFoodInterests, {
        'food_share_id': breadId,
        'user_id': nina,
        'created_at': isoDaysAgo(1),
      });
      await txn.insert(SharingSchema.tableFoodInterests, {
        'food_share_id': breadId,
        'user_id': leyla,
        'created_at': isoDaysAgo(1),
      });

      final deskId = await txn.insert(SharingSchema.tableFurnitureOffers, {
        'neighborhood_id': muensterId,
        'owner_id': markus,
        'title': 'Massiver Schreibtisch aus Eiche',
        'description':
            'Selbst gebaut, 140 x 70 cm. Muss abgeholt werden, ist schwer!',
        'condition_label': 'Gebraucht, sehr gut',
        'status': 'available',
        'created_at': isoDaysAgo(8),
      });
      await txn.insert(SharingSchema.tableFurnitureOffers, {
        'neighborhood_id': muensterId,
        'owner_id': anna,
        'title': 'Bücherregal (weiß, 5 Fächer)',
        'description': 'Passt nicht mehr in die neue Wohnung.',
        'condition_label': 'Gebraucht, gut',
        'status': 'reserved',
        'reserved_by_id': nina,
        'created_at': isoDaysAgo(4),
      });
      await txn.insert(SharingSchema.tableFurnitureOffers, {
        'neighborhood_id': muensterId,
        'owner_id': tobias,
        'title': 'Zwei Küchenstühle',
        'description': 'Holz, stabil, kleine Kratzer an den Beinen.',
        'condition_label': 'Gebraucht',
        'status': 'given_away',
        'reserved_by_id': leyla,
        'created_at': isoDaysAgo(14),
      });
      await txn.insert(SharingSchema.tableFurnitureRequests, {
        'furniture_offer_id': deskId,
        'requester_id': nina,
        'message': 'Ich könnte ihn am Samstag mit einem Transporter abholen.',
        'status': 'pending',
        'created_at': isoDaysAgo(2),
      });

      final rideOsnabrueck = await txn.insert(CommunitySchema.tableRides, {
        'neighborhood_id': muensterId,
        'driver_id': tobias,
        'origin': 'Münster, Kanalstraße',
        'destination': 'Osnabrück Hauptbahnhof',
        'departure_date': dateInDays(2),
        'departure_time': '07:30',
        'total_seats': 3,
        'note': 'Rückfahrt gegen 17:00 Uhr möglich.',
        'created_at': isoDaysAgo(3),
      });
      final rideBaumarkt = await txn.insert(CommunitySchema.tableRides, {
        'neighborhood_id': muensterId,
        'driver_id': markus,
        'origin': 'Kreuzviertel',
        'destination': 'Baumarkt Gievenbeck',
        'departure_date': dateInDays(4),
        'departure_time': '10:00',
        'total_seats': 2,
        'note': 'Kombi, es passt auch Sperriges rein.',
        'created_at': isoDaysAgo(1),
      });
      await txn.insert(CommunitySchema.tableRideParticipants, {
        'ride_id': rideOsnabrueck,
        'user_id': anna,
        'joined_at': isoDaysAgo(2),
      });
      await txn.insert(CommunitySchema.tableRideParticipants, {
        'ride_id': rideOsnabrueck,
        'user_id': nina,
        'joined_at': isoDaysAgo(1),
      });
      await txn.insert(CommunitySchema.tableRideParticipants, {
        'ride_id': rideBaumarkt,
        'user_id': leyla,
        'joined_at': isoDaysAgo(1),
      });

      final streetParty = await txn.insert(CommunitySchema.tableEvents, {
        'neighborhood_id': muensterId,
        'organizer_id': peter,
        'title': 'Straßenfest Kreuzviertel',
        'location': 'Kanalstraße, zwischen Nr. 10 und 30',
        'event_date': dateInDays(9),
        'event_time': '15:00',
        'description':
            'Grill, Kuchentheke und Flohmarkt für Kinder. Jede:r bringt etwas '
            'zu essen mit.',
        'created_at': isoDaysAgo(6),
      });
      final gardenDay = await txn.insert(CommunitySchema.tableEvents, {
        'neighborhood_id': muensterId,
        'organizer_id': sarah,
        'title': 'Gemeinsamer Gartentag',
        'location': 'Hinterhof Nordstraße 88',
        'event_date': dateInDays(3),
        'event_time': '10:00',
        'description': 'Hochbeete bauen und bepflanzen. Werkzeug ist da.',
        'created_at': isoDaysAgo(5),
      });
      for (final participant in <int>[anna, markus, nina, leyla]) {
        await txn.insert(CommunitySchema.tableEventParticipants, {
          'event_id': streetParty,
          'user_id': participant,
          'joined_at': isoDaysAgo(4),
        });
      }
      for (final participant in <int>[anna, peter]) {
        await txn.insert(CommunitySchema.tableEventParticipants, {
          'event_id': gardenDay,
          'user_id': participant,
          'joined_at': isoDaysAgo(3),
        });
      }

      final childcareId = await txn.insert(
        SharingSchema.tableChildcareRequests,
        {
          'neighborhood_id': muensterId,
          'requester_id': sarah,
          'care_date': dateInDays(2),
          'care_time': '16:00 – 19:00',
          'description':
              'Arzttermin für meinen Sohn, meine Tochter (6) müsste solange '
              'betreut werden.',
          'status': 'open',
          'created_at': isoDaysAgo(2),
        },
      );
      await txn.insert(SharingSchema.tableChildcareRequests, {
        'neighborhood_id': muensterId,
        'requester_id': nina,
        'care_date': dateInDays(6),
        'care_time': '08:00 – 12:00',
        'description': 'Handwerkertermin, Kind (3) kann nicht in die Kita.',
        'status': 'covered',
        'created_at': isoDaysAgo(4),
      });
      await txn.insert(SharingSchema.tableChildcareOffers, {
        'request_id': childcareId,
        'helper_id': leyla,
        'message': 'Ich habe an dem Nachmittag frei und kann einspringen.',
        'created_at': isoDaysAgo(1),
      });

      final petcareId = await txn.insert(SharingSchema.tablePetcareRequests, {
        'neighborhood_id': muensterId,
        'requester_id': sarah,
        'pet_type': 'Hund (Labrador, 4 Jahre)',
        'start_date': dateInDays(12),
        'end_date': dateInDays(19),
        'description':
            'Wir sind eine Woche im Urlaub. Zweimal täglich Gassi gehen, sehr '
            'verträglich mit anderen Hunden.',
        'status': 'open',
        'created_at': isoDaysAgo(3),
      });
      await txn.insert(SharingSchema.tablePetcareRequests, {
        'neighborhood_id': muensterId,
        'requester_id': peter,
        'pet_type': 'Zwei Katzen',
        'start_date': dateInDays(1),
        'end_date': dateInDays(4),
        'description': 'Nur füttern und Katzenklo, die beiden sind sehr scheu.',
        'status': 'open',
        'created_at': isoDaysAgo(1),
      });
      await txn.insert(SharingSchema.tablePetcareOffers, {
        'request_id': petcareId,
        'helper_id': leyla,
        'message': 'Sehr gerne! Ich wohne zwei Straßen weiter.',
        'created_at': isoDaysAgo(2),
      });

      Future<void> notify(
        int recipientId,
        String title,
        String message,
        String category,
        int daysAgo, {
        bool isRead = false,
      }) async {
        await txn.insert(CoreSchema.tableNotifications, {
          'recipient_id': recipientId,
          'title': title,
          'message': message,
          'category': category,
          'is_read': isRead ? 1 : 0,
          'created_at': isoDaysAgo(daysAgo),
        });
      }

      await notify(
        anna,
        'Neues Interesse an deinem Angebot',
        'Nina Brahms interessiert sich für "Sauerteigbrot (2 Laibe)".',
        'reservation',
        1,
      );
      await notify(
        anna,
        'Anfrage für dein Bücherregal',
        'Nina Brahms hat dein Bücherregal reserviert.',
        'request',
        2,
      );
      await notify(
        anna,
        'Neues Event in deiner Nachbarschaft',
        'Peter Haas hat "Straßenfest Kreuzviertel" angelegt.',
        'event',
        6,
        isRead: true,
      );
      await notify(
        markus,
        'Anfrage für deinen Schreibtisch',
        'Nina Brahms möchte den Schreibtisch abholen.',
        'request',
        2,
      );
      await notify(
        sarah,
        'Unterstützung bei der Kinderbetreuung',
        'Leyla Demir bietet Hilfe für deine Anfrage an.',
        'care',
        1,
      );
      await notify(
        tobias,
        'Neue Mitfahrerin',
        'Anna Klein ist deiner Fahrt nach Osnabrück beigetreten.',
        'ride',
        2,
      );
    });

    AppLogger.instance.info(_logTag, 'Demo data inserted successfully.');
  }
}