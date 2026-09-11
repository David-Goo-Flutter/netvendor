import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:netvendor/features/lookup/domain/entities/lookup_result.dart';
import 'package:netvendor/features/lookup/domain/entities/lookup_status.dart';
import 'package:netvendor/features/lookup/domain/exceptions/lookup_exceptions.dart';
import 'package:netvendor/features/lookup/domain/repositories/lookup_repository.dart';
import 'package:netvendor/features/lookup/presentation/providers/lookup_controller_provider.dart';
import 'package:netvendor/features/lookup/presentation/providers/lookup_repository_provider.dart';
import 'package:netvendor/features/lookup/presentation/providers/recent_lookups_provider.dart';

class _MockLookupRepository extends Mock implements LookupRepository {}

LookupResult _result({LookupStatus status = LookupStatus.found}) => LookupResult(
      id: 1,
      ipAddress: '192.168.1.1',
      macAddress: 'aa:bb:cc:dd:ee:ff',
      vendor: status == LookupStatus.found ? 'Arcadyan Corporation' : null,
      status: status,
      createdAt: DateTime.utc(2026, 1, 1),
      cached: false,
    );

void main() {
  late _MockLookupRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _MockLookupRepository();
    // fetchRecentLookups is invalidated after a successful lookup; give it a
    // default so tests that don't care about the history list don't need to stub it.
    when(() => repository.fetchRecentLookups()).thenAnswer((_) async => []);

    container = ProviderContainer(
      overrides: [lookupRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  test('starts with no result (AsyncData(null))', () async {
    final initial = await container.read(lookupControllerProvider.future);
    expect(initial, isNull);
  });

  test('lookup() sets AsyncLoading then AsyncData on success', () async {
    when(() => repository.lookup('192.168.1.1')).thenAnswer((_) async => _result());

    // Let the initial `build()` settle to AsyncData(null) before watching for
    // the transitions `lookup()` itself causes.
    await container.read(lookupControllerProvider.future);

    final states = <AsyncValue<LookupResult?>>[];
    container.listen(lookupControllerProvider, (_, next) => states.add(next));

    await container.read(lookupControllerProvider.notifier).lookup('192.168.1.1');

    expect(states.map((s) => s.isLoading), [true, false]);
    expect(container.read(lookupControllerProvider).value?.vendor, 'Arcadyan Corporation');
  });

  test('lookup() sets AsyncError on failure, without touching history', () async {
    when(() => repository.lookup('bad')).thenThrow(ArpEntryNotFoundException('bad'));

    await container.read(lookupControllerProvider.notifier).lookup('bad');

    expect(container.read(lookupControllerProvider).hasError, isTrue);
    expect(container.read(lookupControllerProvider).error, isA<ArpEntryNotFoundException>());
  });

  test('a successful lookup invalidates the recent lookups list', () async {
    when(() => repository.lookup('192.168.1.1')).thenAnswer((_) async => _result());

    // Keep the provider alive with a listener, the way `RecentLookupsList`'s
    // `ref.watch` would -- a bare `.future` read has no subscriber left to
    // notify once `invalidate` fires, so it wouldn't recompute on its own.
    container.listen(recentLookupsProvider, (previous, next) {});
    await container.read(recentLookupsProvider.future);

    await container.read(lookupControllerProvider.notifier).lookup('192.168.1.1');
    await container.read(recentLookupsProvider.future);

    verify(() => repository.fetchRecentLookups()).called(2);
  });
}
