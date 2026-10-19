import '../library/library.dart';

/// A topic the user can follow: an Apple Podcasts genre.
class Interest {
  const Interest(this.genre, this.name);

  /// The Apple Podcasts genre id.
  final int genre;
  final String name;

  @override
  bool operator ==(Object other) => other is Interest && other.genre == genre;

  @override
  int get hashCode => genre.hashCode;
}

/// What onboarding offers, roughly most asked-for first.
const List<Interest> allInterests = [
  Interest(1318, 'Technology'),
  Interest(1321, 'Business'),
  Interest(1459, 'Fashion & Beauty'),
  Interest(1487, 'History'),
  Interest(1533, 'Science'),
  Interest(1489, 'News'),
  Interest(1303, 'Comedy'),
  Interest(1488, 'True Crime'),
  Interest(1545, 'Sports'),
  Interest(1512, 'Health & Fitness'),
  Interest(1324, 'Society & Culture'),
  Interest(1310, 'Music'),
  Interest(1309, 'TV & Film'),
  Interest(1304, 'Education'),
  Interest(1301, 'Arts'),
  Interest(1402, 'Design'),
  Interest(1482, 'Books'),
  Interest(1306, 'Food'),
  Interest(1305, 'Kids & Family'),
  Interest(1314, 'Religion & Spirituality'),
  Interest(1483, 'Fiction'),
];

/// The library setting holding the chosen genre ids, comma-separated; empty
/// once the user has skipped choosing.
const String interestsSetting = 'interests';

/// The user's interests in the order they picked them, or null before they
/// have been asked.
List<Interest>? chosenInterests(Library library) {
  final value = library.setting(interestsSetting);
  if (value == null) return null;
  final byGenre = {for (final i in allInterests) '${i.genre}': i};
  return [for (final id in value.split(',')) ?byGenre[id]];
}

Future<void> chooseInterests(Library library, List<Interest> interests) =>
    library.setSetting(interestsSetting, interests.map((i) => i.genre).join(','));
