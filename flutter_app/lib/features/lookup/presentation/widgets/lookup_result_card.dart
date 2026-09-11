import 'package:flutter/material.dart';

import '../../domain/entities/lookup_result.dart';
import '../../domain/entities/lookup_status.dart';

/// Shows the outcome of a lookup: a placeholder before the first attempt,
/// then a distinct look for success, "vendor unknown", and error.
class LookupResultCard extends StatelessWidget {
  final LookupResult? result;
  final Object? error;

  const LookupResultCard({super.key, this.result, this.error});

  @override
  Widget build(BuildContext context) {
    if (error != null) return _StatusCard(icon: Icons.error_outline, color: Colors.red, message: error.toString());

    // Nothing looked up yet -- the input field's own hint text already says
    // "Enter an IP address and press \"Look up\".", so there's nothing to
    // show here before a first result or error exists.
    final result = this.result;
    if (result == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(context, 'IP address', result.ipAddress),
            const SizedBox(height: 8),
            _row(context, 'MAC address', result.macAddress),
            const SizedBox(height: 8),
            _row(context, 'Vendor', result.vendor ?? 'Unknown', trailing: _StatusChip(status: result.status)),
            if (result.cached) ...[
              const SizedBox(height: 8),
              Text('(from a previous lookup of this MAC)', style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {Widget? trailing}) {
    return Row(
      children: [
        SizedBox(width: 96, child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
        Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyLarge)),
        ?trailing,
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final LookupStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      LookupStatus.found => ('found', Colors.green),
      LookupStatus.unknown => ('unknown', Colors.orange),
      LookupStatus.error => ('lookup failed', Colors.red),
    };

    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color),
      labelStyle: TextStyle(color: color),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  const _StatusCard({required this.icon, required this.color, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
