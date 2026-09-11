import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/local_ip_address_provider.dart';
import '../providers/lookup_controller_provider.dart';

class LookupInputField extends ConsumerStatefulWidget {
  const LookupInputField({super.key});

  @override
  ConsumerState<LookupInputField> createState() => _LookupInputFieldState();
}

// Shared by the text field's border and the button's shape so the two read
// as one control, not two mismatched shapes glued together.
const _fieldRadius = 12.0;

class _LookupInputFieldState extends ConsumerState<LookupInputField> {
  final _controller = TextEditingController();
  bool _prefilled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final ipAddress = _controller.text.trim();
    if (ipAddress.isEmpty) return;
    ref.read(lookupControllerProvider.notifier).lookup(ipAddress);
  }

  @override
  Widget build(BuildContext context) {
    // Pre-fill once with this machine's own IP, without clobbering anything
    // the user has already typed.
    ref.listen(localIpAddressProvider, (previous, next) {
      final detected = next.valueOrNull;
      if (detected != null && !_prefilled && _controller.text.isEmpty) {
        _controller.text = detected;
        _prefilled = true;
      }
    });

    final isLoading = ref.watch(lookupControllerProvider).isLoading;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'IP address',
                hintText: 'Enter an IP address and press "Look up".',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(_fieldRadius)),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(_fieldRadius)),
              ),
            ),
            onPressed: isLoading ? null : _submit,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Look up'),
          ),
        ],
      ),
    );
  }
}
