import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/lookup_status.dart';
import '../../domain/entities/recent_lookup.dart';
import '../providers/recent_lookups_provider.dart';

/// Lookup history from `GET /lookups`. Desktop has no pull-to-refresh, so a
/// button in the header re-fetches instead.
class RecentLookupsList extends ConsumerWidget {
  const RecentLookupsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentLookups = ref.watch(recentLookupsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Recent lookups', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(recentLookupsProvider),
            ),
          ],
        ),
        Expanded(
          child: recentLookups.when(
            data: (lookups) => lookups.isEmpty
                ? const Center(child: Text('No lookups yet.'))
                : ListView.separated(
                    itemCount: lookups.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) => _RecentLookupTile(lookup: lookups[index]),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Could not load history: $error')),
          ),
        ),
      ],
    );
  }
}

class _RecentLookupTile extends StatelessWidget {
  final RecentLookup lookup;
  const _RecentLookupTile({required this.lookup});

  @override
  Widget build(BuildContext context) {
    final color = switch (lookup.status) {
      LookupStatus.found => Colors.green,
      LookupStatus.unknown => Colors.orange,
      LookupStatus.error => Colors.red,
    };

    return ListTile(
      dense: true,
      leading: Icon(Icons.circle, size: 10, color: color),
      title: Text('${lookup.ipAddress}  ·  ${lookup.macAddress}'),
      subtitle: Text(lookup.vendor ?? 'Unknown vendor'),
      trailing: Text(_relativeTime(lookup.createdAt)),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
