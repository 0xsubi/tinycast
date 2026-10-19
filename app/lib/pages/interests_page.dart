import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../playback/playback.dart';
import '../podcast/interests.dart';
import '../ui/chrome.dart';
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
    return GlassPageFrame(
      body: SingleChildScrollView(
        padding: EdgeInsets.only(top: top, bottom: bottomClearance(context)),
        child: ContentColumn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.welcome ? 'WELCOME TO TINYCAST' : 'YOUR INTERESTS', style: eyebrow(color: accent)),
              const SizedBox(height: 6),
              Text('What do you like to listen to?', style: textStyle(size: 34, weight: FontWeight.w700, height: 1.1)),
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
                    GlassChip(
                      key: ValueKey('interest-${interest.genre}'),
                      label: interest.name,
                      icon: Icon(_icons[interest.genre] ?? CupertinoIcons.circle),
                      iconSize: 15,
                      iconColor: _picked.contains(interest) ? ink : inkAt(0.7),
                      labelStyle: textStyle(size: 14.5, weight: FontWeight.w600),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      selected: _picked.contains(interest),
                      selectedColor: accent.withValues(alpha: 0.85),
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
                        child: Text('Skip for now', style: textStyle(size: 15, weight: FontWeight.w600, alpha: 0.6)),
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
      child: GlassButton.custom(
        key: const Key('save-interests'),
        onTap: onTap,
        height: 52,
        shape: const LiquidRoundedSuperellipse(borderRadius: 26),
        settings: accentGlass,
        glowColor: accent.withValues(alpha: 0.5),
        stretch: 0.25,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Text(label, style: textStyle(size: 16, weight: FontWeight.w600, alpha: 1)),
        ),
      ),
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
