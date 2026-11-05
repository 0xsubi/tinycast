import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../podcast/format.dart';
import 'style.dart';

/// Opens [uri] in the browser, or whichever app handles it.
Future<void> openLink(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

/// Selectable show notes whose links, written by [plainText], open when
/// tapped.
class NotesText extends StatefulWidget {
  const NotesText(this.notes, {super.key, required this.style, this.onOpen = openLink});

  final String notes;
  final TextStyle style;

  /// Follows a tapped link.
  final Future<void> Function(Uri) onOpen;

  @override
  State<NotesText> createState() => _NotesTextState();
}

class _NotesTextState extends State<NotesText> {
  final List<TapGestureRecognizer> _taps = [];

  @override
  void dispose() {
    _drop();
    super.dispose();
  }

  void _drop() {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
  }

  /// A recognizer that opens [link], disposed with the next build.
  TapGestureRecognizer _tap(Uri link) {
    final tap = TapGestureRecognizer()..onTap = () => widget.onOpen(link);
    _taps.add(tap);
    return tap;
  }

  @override
  Widget build(BuildContext context) {
    _drop();
    final linkStyle = widget.style.copyWith(
      color: accentInk,
      decoration: TextDecoration.underline,
      decorationColor: accentInk.withValues(alpha: 0.4),
    );
    return SelectableText.rich(
      TextSpan(
        style: widget.style,
        children: [
          for (final run in noteRuns(widget.notes))
            if (run.link case final link?)
              TextSpan(text: run.text, style: linkStyle, mouseCursor: SystemMouseCursors.click, recognizer: _tap(link))
            else
              TextSpan(text: run.text),
        ],
      ),
    );
  }
}
