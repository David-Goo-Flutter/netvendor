import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/lookup/presentation/screens/lookup_screen.dart';

void main() {
  runApp(const ProviderScope(child: NetVendorApp()));
}

class NetVendorApp extends StatelessWidget {
  const NetVendorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NetVendor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
      home: const LookupScreen(),
    );
  }
}
