import 'package:flutter_test/flutter_test.dart';

import 'package:clustez/utils/source_regions.dart';

/// Regression guard for the preference gate — the app's core feature.
///
/// Simulates a user for EVERY picker country in EVERY segment and asserts
/// the strict rules the user demanded:
///  - a country-scoped user NEVER sees another country's national outlet
///  - a segment-scoped user NEVER sees another segment's national outlet
///  - native-language (`local`) outlets never leak worldwide, and only
///    reach their own country's users (pan-regional locals reach their
///    whole segment)
///  - every picker country has at least 2 sources to show
Map<String, dynamic> metaFor(String segment, [String? country]) => {
      'news_scope': 'region',
      'preferred_region': segment,
      if (country != null) 'preferred_country': country,
    };

/// Segments whose name doubles as the country (no picker in the UI).
const singleCountrySegments = {
  'United States',
  'United Kingdom',
  'Canada',
  'India',
};

void main() {
  final sources = classifiedSourcesForTest;
  final nationals = {
    for (final e in sources.entries)
      if (e.value.kind == SourceKind.national) e.key: e.value,
  };
  final allSegments = segmentCountries.keys.toSet()..addAll(singleCountrySegments);

  test('every picker country carries at least 2 sources', () {
    segmentCountries.forEach((segment, countries) {
      for (final country in countries) {
        final count = nationals.values
            .where((i) => i.country == country)
            .length;
        expect(count, greaterThanOrEqualTo(2),
            reason: '$segment › $country has only $count source(s)');
      }
    });
  });

  test('every picker country resolves to a segment for location detection',
      () {
    segmentCountries.forEach((segment, countries) {
      for (final country in countries) {
        expect(countryToSegment.containsKey(country), isTrue,
            reason: '$country missing from countryToSegment');
      }
    });
  });

  test('country-scoped users see ONLY their country (+ pan tier + globals)',
      () {
    segmentCountries.forEach((segment, countries) {
      for (final country in countries) {
        final meta = metaFor(segment, country);
        nationals.forEach((name, info) {
          final visible = sourceVisible(name, meta);
          final isOwn = info.country == country;
          final isPanTier = info.country == segment;
          if (visible) {
            expect(isOwn || isPanTier, isTrue,
                reason: 'LEAK: $segment › $country user sees "$name" '
                    '(${info.country}, ${info.segment})');
          } else {
            expect(isOwn, isFalse,
                reason: 'HIDDEN OWN SOURCE: $segment › $country user '
                    'cannot see "$name"');
          }
        });
      }
    });
  });

  test('segment-scoped users never see another segment\'s nationals', () {
    for (final segment in allSegments) {
      final meta = metaFor(segment);
      nationals.forEach((name, info) {
        if (sourceVisible(name, meta)) {
          final inSegment = info.segment == segment ||
              // Egypt sits in both Africa and Middle East pickers.
              (info.country == 'Egypt' && segment == 'Middle East');
          expect(inSegment, isTrue,
              reason: 'LEAK: "All $segment" user sees "$name" '
                  '(${info.segment})');
        }
      });
    }
  });

  test('local-language outlets never leak worldwide or signed out', () {
    for (final meta in [null, metaFor('Worldwide')]) {
      nationals.forEach((name, info) {
        if (info.local) {
          expect(sourceVisible(name, meta), isFalse,
              reason: 'LEAK: local "$name" visible worldwide');
        }
      });
    }
  });

  test('local-language outlets reach only their own country', () {
    segmentCountries.forEach((segment, countries) {
      for (final country in countries) {
        final meta = metaFor(segment, country);
        nationals.forEach((name, info) {
          if (info.local &&
              info.country != country &&
              info.country != segment) {
            expect(sourceVisible(name, meta), isFalse,
                reason: 'LEAK: $segment › $country user sees local "$name" '
                    '(${info.country})');
          }
        });
      }
    });
  });

  test('single-country segments include their locals for every user', () {
    // e.g. French-Canadian dailies show to all Canada users; Hindi dailies
    // to all India users.
    for (final segment in singleCountrySegments) {
      final meta = metaFor(segment);
      nationals.forEach((name, info) {
        if (info.segment == segment) {
          expect(sourceVisible(name, meta), isTrue,
              reason: '"$name" hidden from "All $segment" user');
        }
      });
    }
  });

  test('worldwide shows exactly the curated flagship tier', () {
    final flagships = worldwideFlagshipsForTest;
    // Every flagship key is a real classified national, English (not
    // local), and never from Africa (standing decision).
    for (final key in flagships) {
      final info = sources[key];
      expect(info, isNotNull, reason: 'flagship "$key" not in classifier');
      expect(info!.kind, SourceKind.national,
          reason: 'flagship "$key" is not a national');
      expect(info.local, isFalse, reason: 'flagship "$key" is local-language');
      expect(info.segment, isNot('Africa'),
          reason: 'flagship "$key" is from Africa');
    }
    // The gate admits a national on Worldwide IFF it is a flagship — for
    // signed-out users and explicit Worldwide users alike.
    for (final meta in [null, metaFor('Worldwide')]) {
      nationals.forEach((name, info) {
        expect(sourceVisible(name, meta), flagships.contains(name),
            reason: flagships.contains(name)
                ? 'flagship "$name" hidden on Worldwide'
                : 'LEAK: non-flagship "$name" visible on Worldwide');
      });
    }
  });

  test('golden scenarios', () {
    // Accra user: Ghana + pan-Africa, nothing Nigerian or Filipino.
    final ghana = metaFor('Africa', 'Ghana');
    expect(sourceVisible('GhanaWeb', ghana), isTrue);
    expect(sourceVisible('Africanews', ghana), isTrue);
    expect(sourceVisible('Punch', ghana), isFalse);
    expect(sourceVisible('Philippine Daily Inquirer', ghana), isFalse);

    // Dubai user: UAE outlets incl. Arabic locals, no Saudi press.
    final uae = metaFor('Middle East', 'United Arab Emirates');
    expect(sourceVisible('Gulf News', uae), isTrue);
    expect(sourceVisible('Al-Bayan', uae), isTrue);
    expect(sourceVisible('Al Arabiya', uae), isTrue); // pan tier
    expect(sourceVisible('Okaz', uae), isFalse);

    // Egypt reachable from BOTH segments.
    expect(sourceVisible('Youm7', metaFor('Africa', 'Egypt')), isTrue);
    expect(sourceVisible('Youm7', metaFor('Middle East', 'Egypt')), isTrue);

    // Buenos Aires user: Argentine Spanish press, nothing Brazilian.
    final ar = metaFor('Latin America', 'Argentina');
    expect(sourceVisible('Clarín', ar), isTrue);
    expect(sourceVisible('Telesur', ar), isTrue); // pan tier
    expect(sourceVisible('O Globo', ar), isFalse);

    // Worldwide user: curated flagships only — high-profile nationals yes,
    // city/regional papers, locals, and Africa gated (decision 2026-08-04).
    final world = metaFor('Worldwide');
    expect(sourceVisible('BBC News', world), isTrue);
    expect(sourceVisible('Financial Times', world), isTrue);
    expect(sourceVisible('South China Morning Post', world), isTrue);
    expect(sourceVisible('Okaz', world), isFalse);
    expect(sourceVisible('Punch', world), isFalse);
    expect(sourceVisible('Oxford Mail', world), isFalse);
    expect(sourceVisible('Windsor Star', world), isFalse);
    expect(sourceVisible('Geelong Advertiser', world), isFalse);

    // Globals pass for everyone, everywhere.
    for (final meta in [null, world, ghana, uae, ar]) {
      expect(sourceVisible('Al Jazeera', meta), isTrue);
      expect(sourceVisible('Reuters', meta), isTrue);
    }
  });
}
