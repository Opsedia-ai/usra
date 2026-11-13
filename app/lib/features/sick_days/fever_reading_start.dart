import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';

/// The Add sheet's "سخونية": straight to a temperature reading, not the list
/// of sick days (end-to-end test #21). Uses the sick day going on, or starts
/// one now, then opens it with the reading sheet up. Back returns to where
/// the Add sheet was opened.
class FeverReadingStart extends ConsumerStatefulWidget {
  const FeverReadingStart({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<FeverReadingStart> createState() => _FeverReadingStartState();
}

class _FeverReadingStartState extends ConsumerState<FeverReadingStart> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _go());
  }

  Future<void> _go() async {
    final db = ref.read(databaseProvider);
    final router = GoRouter.of(context);
    final id = widget.profileId;
    String? episode;
    try {
      final episodes = await db.watchEpisodes(id).first;
      episode =
          episodes.where((e) => e.endedAt == null).firstOrNull?.id ??
          await db.saveEpisode(
            profileId: id,
            startedAt: ref.read(clockProvider)(),
          );
    } catch (_) {
      // Couldn't read or start one: the list explains and offers to start.
    }
    if (!mounted) return;
    router.replace(
      episode == null
          ? '/family/$id/sick-days'
          : '/family/$id/sick-days/$episode?reading=1',
    );
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
