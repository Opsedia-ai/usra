import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/sync/canonical_json.dart';
import 'package:usra/core/sync/envelope.dart';
import 'package:usra/core/sync/hlc.dart';
import 'package:usra/core/sync/merge.dart';

const family = '0f000000-0000-4000-8000-00000000000f';
const sync = 'e0000000-0000-4000-8000-000000000001';

GroupEntry g(Object? v, int ms, [int c = 0]) => GroupEntry(v, Hlc.at(ms, c));

void main() {
  group('hybrid logical clock', () {
    test('round-trips 16 hex digits, including the top bit', () {
      for (final hex in [
        '0000000000000000',
        '019300f8a1b20003',
        '7fffffffffffffff',
      ]) {
        expect(Hlc.parse(hex).toHex(), hex);
      }
      expect(() => Hlc.parse('019300F8A1B20003'), throwsFormatException);
      expect(() => Hlc.parse('19300f8a1b20003'), throwsFormatException);
      expect(
        () => Hlc.parse('8000000000000000'),
        throwsFormatException,
        reason: 'top bit set',
      );
    });

    test('ticks past the wall clock and every clock seen', () {
      var now = DateTime.utc(2026, 11, 13, 9);
      final clock = HlcClock(now: () => now);
      final a = clock.tick();
      final b = clock.tick();
      expect(b > a, isTrue);
      expect(b.millis, a.millis);
      clock.observe(Hlc.at(now.millisecondsSinceEpoch + 60000, 5));
      final c = clock.tick();
      expect(c, Hlc.at(now.millisecondsSinceEpoch + 60000, 6));
      now = now.add(const Duration(minutes: 5));
      expect(clock.tick(), Hlc.at(now.millisecondsSinceEpoch));
    });
  });

  group('canonical JSON', () {
    test('sorts keys and has no whitespace', () {
      expect(
        canonicalJson({
          'b': 1,
          'a': [true, null, 'x'],
          'c': 38.5,
        }),
        '{"a":[true,null,"x"],"b":1,"c":38.5}',
      );
      expect(canonicalJson(2.0), '2');
    });

    test('rejects duplicate keys, other spellings and deep nesting', () {
      List<int> b(String s) => utf8.encode(s);
      expect(parseCanonicalJson(b('{"a":1,"b":2}')), {'a': 1, 'b': 2});
      expect(
        () => parseCanonicalJson(b('{"a":1,"a":2}')),
        throwsFormatException,
      );
      expect(
        () => parseCanonicalJson(b('{"b":1,"a":2}')),
        throwsFormatException,
      );
      expect(() => parseCanonicalJson(b('{"a": 1}')), throwsFormatException);
      expect(() => parseCanonicalJson(b('{"a":1.0}')), throwsFormatException);
      expect(() => parseCanonicalJson([0xff, 0xfe]), throwsFormatException);
      expect(
        () => parseCanonicalJson(b('[[[[[[[[[1]]]]]]]]]')),
        throwsFormatException,
      );
      expect(parseCanonicalJson(b('[[[[[[[[1]]]]]]]]')), isA<List<dynamic>>());
    });
  });

  group('group merge', () {
    test('the later clock wins; equal clocks pick the larger value', () {
      expect(winner(g('a', 2), g('b', 1)).value, 'a');
      expect(winner(g('a', 1), g('b', 1)).value, 'b');
      expect(winner(g('b', 1), g('a', 1)).value, 'b');
    });

    test('a group is taken whole, never mixed', () {
      final local = {
        'dose': g({'amount': '500', 'unit': 'mg'}, 10),
      };
      final remote = {
        'dose': g({'amount': '5', 'unit': 'ml'}, 11),
      };
      expect(mergeGroups(local, remote).groups['dose']!.value, {
        'amount': '5',
        'unit': 'ml',
      });
    });

    test('two parents editing different groups both survive', () {
      final base = {'name': g('Sample syrup', 1), 'dose': g('5 ml', 1)};
      final a = {...base, 'name': g('Sample syrup 2', 5)};
      final b = {...base, 'dose': g('7.5 ml', 6)};
      final ab = mergeGroups(a, b).groups;
      final ba = mergeGroups(b, a).groups;
      expect(ab, ba);
      expect(ab['name']!.value, 'Sample syrup 2');
      expect(ab['dose']!.value, '7.5 ml');
    });

    test('a clinical group changed on both phones is flagged on both', () {
      final base = {'dose': Hlc.at(1)};
      final local = {'dose': g('5 ml', 5)};
      final remote = {'dose': g('7.5 ml', 6)};
      final lost = mergeGroups(
        local,
        remote,
        baseClocks: base,
        isClinical: (_) => true,
      );
      expect(lost.groups['dose']!.value, '7.5 ml');
      expect(lost.conflicts.single.lost.value, '5 ml');
      final won = mergeGroups(
        remote,
        local,
        baseClocks: base,
        isClinical: (_) => true,
      );
      expect(won.conflicts.single.kept.value, '7.5 ml');
      expect(
        won.conflicts.single.lost.value,
        '5 ml',
        reason: 'the phone whose value won sees it too',
      );
      expect(
        mergeGroups(local, remote, baseClocks: base).conflicts,
        isEmpty,
        reason: 'not clinical: merged silently',
      );
      expect(
        mergeGroups(
          local,
          remote,
          baseClocks: {'dose': Hlc.at(5)},
          isClinical: (_) => true,
        ).conflicts,
        isEmpty,
        reason: 'not changed here since the last sync: nothing to flag',
      );
    });

    test('a delete drops concurrent edits until a newer restore', () {
      final deleted = {deletedGroup: g(true, 5)};
      final edited = {'name': g('x', 6), deletedGroup: g(false, 1)};
      final merged = mergeGroups(edited, deleted, isClinical: (_) => true);
      expect(isDeleted(merged.groups), isTrue);
      expect(merged.conflicts, isEmpty);
      expect(tombstone(merged.groups).keys, [deletedGroup]);
      final restored = {'name': g('y', 7), deletedGroup: g(false, 7)};
      expect(mergeGroups(deleted, restored).groups['name']!.value, 'y');
    });

    test('commutative, associative and idempotent over random histories', () {
      final rnd = Random(42);
      for (var run = 0; run < 300; run++) {
        final versions = [
          for (var w = 0; w < 4; w++)
            {
              for (final name in ['a', 'b', 'c', deletedGroup])
                if (rnd.nextBool())
                  name: g(
                    name == deletedGroup ? rnd.nextBool() : rnd.nextInt(3),
                    rnd.nextInt(4),
                    rnd.nextInt(2),
                  ),
            },
        ];
        Groups fold(List<Groups> order) =>
            order.fold<Groups>({}, (acc, v) => mergeGroups(acc, v).groups);
        final expected = fold(versions);
        for (var p = 0; p < 6; p++) {
          final shuffled = [...versions, versions[rnd.nextInt(4)]]
            ..shuffle(rnd);
          expect(fold(shuffled), expected);
        }
      }
    });

    test('groups more than 10 minutes ahead are held', () {
      final now = DateTime.utc(2026, 11, 13, 9);
      final ms = now.millisecondsSinceEpoch;
      final split = splitFutureGroups({
        'ok': g(1, ms + const Duration(minutes: 9).inMilliseconds),
        'ahead': g(2, ms + const Duration(minutes: 11).inMilliseconds),
      }, now);
      expect(split.apply.keys, ['ok']);
      expect(split.held.keys, ['ahead']);
    });
  });

  group('record envelope', () {
    late SimpleKeyPair signer;
    late SimplePublicKey signerPublic;
    late SecretKey rk;
    final header = recordHeader(familyId: family, syncId: sync, keyVersion: 1);

    setUpAll(() async {
      signer = await Ed25519().newKeyPairFromSeed(List.filled(32, 7));
      signerPublic = await signer.extractPublicKey();
      rk = await deriveRecordKey(List.filled(32, 9), family);
    });

    RecordBody body([Map<String, GroupEntry>? groups]) => RecordBody(
      id: '01930000-0000-7000-8000-000000000001',
      type: 'medicine',
      by: 'da000000-0000-4000-8000-0000000000a1',
      logSeq: 3,
      logHash: 'aGVhZA',
      groups:
          groups ??
          {
            'name': g({'name': 'Sample syrup'}, 1000),
            deletedGroup: g(false, 999),
          },
    );

    Future<RecordBody> open(
      Uint8List h,
      List<int> stored, {
      SimplePublicKey? key,
    }) => openRecord(
      header: h,
      stored: stored,
      recordKey: rk,
      signerKey: (id) async => id == 'da000000-0000-4000-8000-0000000000a1'
          ? (key ?? signerPublic)
          : null,
    );

    test('header is 42 bytes', () {
      expect(header.length, 42);
      expect(header.sublist(0, 6), [0x55, 0x53, 0x52, 0x31, 0, 1]);
    });

    test('seals and opens, padded to a power of two + 40', () async {
      final small = await sealRecord(
        header: header,
        body: body({deletedGroup: g(true, 1)}),
        recordKey: rk,
        signingKey: signer,
      );
      // ids, the log head and the clock alone take about 200 bytes, so even
      // a tombstone lands in the 512-byte bucket (section 22's assumption).
      expect(small.length, 512 + 40);
      final stored = await sealRecord(
        header: header,
        body: body(),
        recordKey: rk,
        signingKey: signer,
      );
      expect(stored.length, 512 + 40);
      final opened = await open(header, stored);
      expect(opened.groups['name']!.value, {'name': 'Sample syrup'});
      expect(opened.hlc, Hlc.at(1000));
    });

    test(
      'compresses big bodies before encrypting, signature over the plain body',
      () async {
        final entries = {
          for (var i = 0; i < 40; i++)
            '01930000-0000-7000-8000-${i.toString().padLeft(12, '0')}': g({
              'status': 'taken',
              'at': '2026-11-13T08:00:00Z',
              'medicine': 'sample',
            }, 1000 + i),
        };
        final big = body(entries);
        final plainSize = canonicalJsonBytes(big.toJson()).length;
        expect(plainSize, greaterThan(4096));
        final stored = await sealRecord(
          header: header,
          body: big,
          recordKey: rk,
          signingKey: signer,
        );
        expect(
          stored.length - 40,
          lessThan(4096),
          reason: 'deflate moved it down a padding bucket',
        );
        expect((await open(header, stored)).groups.length, 40);
      },
    );

    test('a record moved to another sync id, family or epoch fails', () async {
      final stored = await sealRecord(
        header: header,
        body: body(),
        recordKey: rk,
        signingKey: signer,
      );
      for (final h in [
        recordHeader(
          familyId: family,
          syncId: 'e0000000-0000-4000-8000-000000000002',
          keyVersion: 1,
        ),
        recordHeader(
          familyId: '0f000000-0000-4000-8000-0000000000ff',
          syncId: sync,
          keyVersion: 1,
        ),
        recordHeader(familyId: family, syncId: sync, keyVersion: 2),
      ]) {
        await expectLater(open(h, stored), throwsA(isA<EnvelopeException>()));
      }
    });

    test('any flipped bit is rejected', () async {
      final stored = await sealRecord(
        header: header,
        body: body(),
        recordKey: rk,
        signingKey: signer,
      );
      for (final i in [0, 23, 24, 100, stored.length - 17, stored.length - 1]) {
        final copy = Uint8List.fromList(stored)..[i] ^= 1;
        await expectLater(
          open(header, copy),
          throwsA(isA<EnvelopeException>()),
        );
      }
    });

    test('an unknown signer or another device key is rejected', () async {
      final stored = await sealRecord(
        header: header,
        body: body(),
        recordKey: rk,
        signingKey: signer,
      );
      final other = await (await Ed25519().newKeyPairFromSeed(
        List.filled(32, 8),
      )).extractPublicKey();
      await expectLater(
        open(header, stored, key: other),
        throwsA(isA<EnvelopeException>()),
      );
      await expectLater(
        openRecord(
          header: header,
          stored: stored,
          recordKey: rk,
          signerKey: (_) async => null,
        ),
        throwsA(isA<EnvelopeException>()),
      );
    });

    test('wrong sizes are rejected before decrypting', () async {
      await expectLater(
        open(header, Uint8List(300 + 40)),
        throwsA(isA<EnvelopeException>()),
      );
      await expectLater(
        open(header, Uint8List(10)),
        throwsA(isA<EnvelopeException>()),
      );
    });

    test('a body whose clock is not its largest group clock is refused', () {
      final json = body().toJson()..['hlc'] = Hlc.at(5).toHex();
      expect(() => RecordBody.fromJson(json), throwsFormatException);
      final extra = body().toJson()..['x'] = 1;
      expect(() => RecordBody.fromJson(extra), throwsFormatException);
    });

    test('signatures with S at or above the group order are refused', () {
      final sig = List<int>.filled(64, 0);
      expect(isCanonicalEd25519S(sig), isTrue);
      sig[63] = 0x20; // 2^253 > L
      expect(isCanonicalEd25519S(sig), isFalse);
    });
  });
}
