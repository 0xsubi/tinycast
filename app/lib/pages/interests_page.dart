import 'package:flutter/cupertino.dart';

import '../playback/playback.dart';
import '../podcast/interests.dart';
import '../ui/chrome.dart';
import '../ui/metal_ui.dart';
import '../ui/style.dart';

/// Shows [child] once the user has been asked about their interests, and the
/// question until then.
class FirstRun extends StatelessWidget {
  const FirstRun({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) => chosenInterests(library) == null ? const InterestsPage(welcome: true) : child,
    );
  }
}

/// Asks which topics the user likes, to fill the home page with their top shows.
class InterestsPage extends StatefulWidget {
  const InterestsPage({super.key, this.welcome = false});

  /// The first-run version: a greeting and a way to skip.
  final bool welcome;

  @override
  State<InterestsPage> createState() => _InterestsPageState();
}

class _InterestsPageState extends State<InterestsPage> {
  /// In the order picked; the home page lists them so.
  late final List<Interest> _picked = [...?chosenInterests(AppScope.of(context).library)];

  void _toggle(Interest interest) =>
      setState(() => _picked.contains(interest) ? _picked.remove(interest) : _picked.add(interest));

  Future<void> _save(List<Interest> interests) async {
    final navigator = Navigator.of(context);
    await chooseInterests(AppScope.of(context).library, interests);
    if (!widget.welcome) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final top = widget.welcome ? MediaQuery.paddingOf(context).top + 44 : appBarClearance(context);
    return PageFrame(
      body: SingleChildScrollView(
        padding: EdgeInsets.only(top: top, bottom: bottomClearance(context)),
        child: ContentColumn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.welcome ? 'WELCOME TO TINYCAST' : 'YOUR INTERESTS', style: eyebrow(color: accentInk)),
              const SizedBox(height: 6),
              Text(
                'What do you like to listen to?',
                style: textStyle(size: 36, weight: FontWeight.w300, height: 1.1, spacing: -0.3),
              ),
              const SizedBox(height: 10),
              Text(
                'Pick a few topics and your home page fills with the top shows in each.',
                style: textStyle(size: 15, alpha: 0.6),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final interest in allInterests)
                    _InterestKey(
                      key: ValueKey('interest-${interest.genre}'),
                      interest: interest,
                      picked: _picked.contains(interest),
                      onTap: () => _toggle(interest),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  _DoneButton(
                    label: widget.welcome ? 'Continue' : 'Save',
                    enabled: _picked.isNotEmpty || !widget.welcome,
                    onTap: () => _save(_picked),
                  ),
                  if (widget.welcome) ...[
                    const SizedBox(width: 22),
                    GestureDetector(
                      key: const Key('skip-interests'),
                      onTap: () => _save(const []),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Text('Skip for now', style: textStyle(size: 15, weight: FontWeight.w600, alpha: 0.65)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.label, required this.enabled, required this.onTap});

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: enabled ? 1 : 0.4,
    duration: const Duration(milliseconds: 150),
    child: IgnorePointer(
      ignoring: !enabled,
      child: MetalButton(
        key: const Key('save-interests'),
        onPressed: onTap,
        height: 52,
        accent: true,
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Text(label, style: const TextStyle(fontSize: 16)),
      ),
    ),
  );
}

/// A topic as a key that latches down, its lamp lit, while picked.
class _InterestKey extends StatelessWidget {
  const _InterestKey({super.key, required this.interest, required this.picked, required this.onTap});

  final Interest interest;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MetalButton(
    onPressed: onTap,
    height: 42,
    radius: 12,
    latched: picked,
    lit: picked,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_icons[interest.genre] ?? CupertinoIcons.circle, size: 15),
        const SizedBox(width: 8),
        Text(interest.name, style: const TextStyle(fontSize: 14.5)),
        const SizedBox(width: 10),
        Lamp(on: picked, size: 6),
      ],
    ),
  );
}

const Map<int, IconData> _icons = {
  1318: CupertinoIcons.desktopcomputer,
  1321: CupertinoIcons.briefcase,
  1459: CupertinoIcons.sparkles,
  1487: CupertinoIcons.hourglass,
  1533: CupertinoIcons.lab_flask,
  1489: CupertinoIcons.news,
  1303: CupertinoIcons.smiley,
  1488: CupertinoIcons.eye,
  1545: CupertinoIcons.sportscourt,
  1512: CupertinoIcons.heart,
  1324: CupertinoIcons.person_3,
  1310: CupertinoIcons.music_note_2,
  1309: CupertinoIcons.film,
  1304: CupertinoIcons.lightbulb,
  1301: CupertinoIcons.paintbrush,
  1402: CupertinoIcons.pencil_outline,
  1482: CupertinoIcons.book,
  1306: CupertinoIcons.flame,
  1305: CupertinoIcons.house,
  1314: CupertinoIcons.moon_stars,
  1483: CupertinoIcons.wand_stars,
};
