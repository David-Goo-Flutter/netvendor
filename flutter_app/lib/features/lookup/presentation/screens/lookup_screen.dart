import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/lookup_controller_provider.dart';
import '../widgets/lookup_input_field.dart';
import '../widgets/lookup_result_card.dart';
import '../widgets/recent_lookups_list.dart';

class LookupScreen extends ConsumerWidget {
  const LookupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookupState = ref.watch(lookupControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('NetVendor')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LookupInputField(),
            const SizedBox(height: 16),
            LookupResultCard(
              result: lookupState.valueOrNull,
              error: lookupState.hasError ? lookupState.error : null,
            ),
            const SizedBox(height: 24),
            const Expanded(child: RecentLookupsList()),
          ],
        ),
      ),
    );
  }
}
