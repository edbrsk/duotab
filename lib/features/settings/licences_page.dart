import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/design/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/widgets/app_logo_header.dart';

/// Every bundled package's licence. Flutter's own licence page can't drop
/// its "Powered by Flutter" line.
class LicencesPage extends StatefulWidget {
  const LicencesPage({super.key});

  @override
  State<LicencesPage> createState() => _LicencesPageState();
}

class _LicencesPageState extends State<LicencesPage> {
  late final Future<Map<String, List<LicenseEntry>>> _byPackage = _load();

  static Future<Map<String, List<LicenseEntry>>> _load() async {
    final byPackage = <String, List<LicenseEntry>>{};
    await for (final entry in LicenseRegistry.licenses) {
      for (final package in entry.packages) {
        (byPackage[package] ??= []).add(entry);
      }
    }
    final names = byPackage.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return {for (final name in names) name: byPackage[name]!};
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context)!.licences)),
    body: SafeArea(
      child: FutureBuilder(
        future: _byPackage,
        builder: (context, snapshot) {
          final byPackage = snapshot.data;
          if (byPackage == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: [
              const AppLogoHeader(),
              for (final MapEntry(key: package, value: entries)
                  in byPackage.entries)
                ListTile(
                  title: Text(package),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          _PackageLicences(package: package, entries: entries),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _PackageLicences extends StatelessWidget {
  final String package;
  final List<LicenseEntry> entries;

  const _PackageLicences({required this.package, required this.entries});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Scaffold(
      appBar: AppBar(title: Text(package)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            for (final (i, entry) in entries.indexed) ...[
              if (i > 0) const Divider(height: Spacing.xl),
              for (final paragraph in entry.paragraphs)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: Spacing.sm,
                    left: paragraph.indent == LicenseParagraph.centeredIndent
                        ? 0
                        : Spacing.md * paragraph.indent,
                  ),
                  child: Text(
                    paragraph.text,
                    style: style,
                    textAlign:
                        paragraph.indent == LicenseParagraph.centeredIndent
                        ? TextAlign.center
                        : TextAlign.start,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
