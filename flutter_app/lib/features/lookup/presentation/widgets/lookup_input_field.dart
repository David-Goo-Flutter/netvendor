import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/local_ip_address_provider.dart';
import '../providers/lookup_controller_provider.dart';

class LookupInputField extends ConsumerStatefulWidget {
  const LookupInputField({super.key});

  @override
  ConsumerState<LookupInputField> createState() => _LookupInputFieldState();
}

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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'IP address',
              hintText: '192.168.1.1',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: isLoading ? null : _submit,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Look up'),
          ),
        ),
      ],
    );
  }
}
