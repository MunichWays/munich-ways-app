import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/reviews/app_review_service.dart';
import 'package:munich_ways/ui/widgets/menu_list.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoSheetFeedbackContent extends StatelessWidget {
  const InfoSheetFeedbackContent({
    super.key,
    required this.versionLabel,
    this.reviewService,
    this.launchExternal,
  });

  final String versionLabel;
  final AppReviewService? reviewService;
  final Future<bool> Function(Uri)? launchExternal;

  Future<void> _openReview(BuildContext context) async {
    final opened = await (reviewService ?? appReviewService).openStoreListing();
    if (!opened && context.mounted) {
      _snack(
          context,
          context.l10n.isEnglish
              ? 'Could not open the store. Please try again later.'
              : 'Store konnte nicht geöffnet werden. Bitte später erneut versuchen.');
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
    // `announce` also works with the older Flutter SDK used by the 3.0 CI job.
    // ignore: deprecated_member_use
    SemanticsService.announce(message, TextDirection.ltr);
  }

  Future<void> _openFeedback(BuildContext context) async {
    final body = Uri.encodeComponent('Appversion: $versionLabel\n\n');
    final uri = Uri.parse(
      'mailto:mail@munichways.de?subject=${Uri.encodeComponent('Feedback Munichways App')}&body=$body',
    );
    var opened = false;
    try {
      opened = await (launchExternal?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      // Keep the info menu usable if the platform cannot open an email app.
    }
    if (!opened && context.mounted) {
      _snack(
          context,
          context.l10n.isEnglish
              ? 'No email app found'
              : 'Keine E-Mail-App gefunden');
    }
  }

  Future<void> _openWebsite(BuildContext context) async {
    final uri = Uri.parse('https://www.munichways.de/');
    var opened = false;
    try {
      opened = await (launchExternal?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      // A missing browser must not make the feedback sheet unusable.
    }
    if (!opened && context.mounted) {
      _snack(
          context,
          context.l10n.isEnglish
              ? 'No app found to open this link'
              : 'Keine App zum Öffnen dieses Links gefunden');
    }
  }

  @override
  Widget build(BuildContext context) {
    final english = context.l10n.isEnglish;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(english
            ? 'Do you like MunichWays? Your rating helps others discover the app.'
            : 'Gefällt dir MunichWays? Deine Bewertung hilft anderen, die App zu entdecken.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.star_outline),
          label: Text(english ? 'Rate the app' : 'App bewerten'),
          onPressed: () => _openReview(context),
        ),
        const SizedBox(height: 24),
        Text(english
            ? 'Questions or ideas? Feel free to write to us. We are volunteers, so a reply may take a while.'
            : 'Fragen oder Ideen? Schreib uns gerne. Wir arbeiten ehrenamtlich – eine Antwort kann etwas dauern.'),
        const SizedBox(height: 8),
        Semantics(
          link: true,
          child: TextButton.icon(
            icon: const Icon(Icons.mail_outline),
            label: const Text('mail@munichways.de',
                style: TextStyle(decoration: TextDecoration.underline)),
            onPressed: () => _openFeedback(context),
          ),
        ),
        const SizedBox(height: 16),
        MenuGroup(children: [
          MenuGroupItem(
            icon: Icons.open_in_new,
            label: english ? 'About MunichWays' : 'Über MunichWays',
            onTap: () => _openWebsite(context),
          ),
        ]),
      ],
    );
  }
}
