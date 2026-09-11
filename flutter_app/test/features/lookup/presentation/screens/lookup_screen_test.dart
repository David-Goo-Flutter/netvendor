import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:netvendor/features/lookup/domain/entities/lookup_result.dart';
import 'package:netvendor/features/lookup/domain/entities/lookup_status.dart';
import 'package:netvendor/features/lookup/domain/entities/recent_lookup.dart';
import 'package:netvendor/features/lookup/domain/exceptions/lookup_exceptions.dart';
import 'package:netvendor/features/lookup/domain/repositories/lookup_repository.dart';
import 'package:netvendor/features/lookup/presentation/providers/lookup_repository_provider.dart';
import 'package:netvendor/features/lookup/presentation/screens/lookup_screen.dart';

class _MockLookupRepository extends Mock implements LookupRepository {}

Future<void> _pumpScreen(WidgetTester tester, LookupRepository repository) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [lookupRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: LookupScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late _MockLookupRepository repository;

  setUp(() {
    repository = _MockLookupRepository();
    when(() => repository.detectLocalIpAddress()).thenAnswer((_) async => null);
    when(() => repository.fetchRecentLookups()).thenAnswer((_) async => <RecentLookup>[]);
  });

  testWidgets('looking up an IP shows the resolved vendor', (tester) async {
    when(() => repository.lookup('192.168.1.1')).thenAnswer(
      (_) async => LookupResult(
        id: 1,
        ipAddress: '192.168.1.1',
        macAddress: 'aa:bb:cc:dd:ee:ff',
        vendor: 'Arcadyan Corporation',
        status: LookupStatus.found,
        createdAt: DateTime.utc(2026, 1, 1),
        cached: false,
      ),
    );

    await _pumpScreen(tester, repository);

    expect(find.text('Enter an IP address and press "Look up".'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '192.168.1.1');
    await tester.tap(find.widgetWithText(FilledButton, 'Look up'));
    await tester.pumpAndSettle();

    expect(find.text('Arcadyan Corporation'), findsOneWidget);
    expect(find.text('aa:bb:cc:dd:ee:ff'), findsOneWidget);
    expect(find.text('found'), findsOneWidget);
  });

  testWidgets('a failed lookup shows the error message', (tester) async {
    when(() => repository.lookup('10.0.0.99')).thenThrow(ArpEntryNotFoundException('10.0.0.99'));

    await _pumpScreen(tester, repository);

    await tester.enterText(find.byType(TextField), '10.0.0.99');
    await tester.tap(find.widgetWithText(FilledButton, 'Look up'));
    await tester.pumpAndSettle();

    expect(find.textContaining('is not visible on the local network'), findsOneWidget);
  });
}
