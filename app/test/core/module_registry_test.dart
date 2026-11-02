import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/modules/feature_module.dart';
import 'package:usra/core/modules/module_registry.dart';
import 'package:usra/core/records/record_type.dart';
import 'package:usra/modules.dart';

class _FakeModule extends FeatureModule {
  const _FakeModule(
    this.id, {
    this.order = 50,
    this.types = const [],
    this.requires = Entitlement.free,
  });

  @override
  final String id;
  final int order;
  final List<RecordTypeDefinition> types;
  @override
  final Entitlement requires;

  @override
  List<ModuleTab> get tabs => [
    ModuleTab(path: '/$id', icon: Icons.circle, label: (_) => id, order: order),
  ];

  @override
  List<RecordTypeDefinition> get recordTypes => types;
}

void main() {
  test('the app modules register without conflicts', () {
    final registry = ModuleRegistry(appModules);
    expect(registry.tabs.first.path, '/home');
    expect(registry.recordTypes['visit'], isNotNull);
    expect(registry.recordTypes['surgery'], isNotNull);
  });

  test('duplicate module ids are rejected', () {
    expect(
      () => ModuleRegistry(const [_FakeModule('a'), _FakeModule('a')]),
      throwsArgumentError,
    );
  });

  test('duplicate record types are rejected', () {
    const type = RecordTypeDefinition(key: 'x', icon: Icons.circle);
    expect(
      () => ModuleRegistry(const [
        _FakeModule('a', types: [type]),
        _FakeModule('b', types: [type]),
      ]),
      throwsArgumentError,
    );
  });

  test('tabs are ordered by their order value', () {
    final registry = ModuleRegistry(const [
      _FakeModule('late', order: 90),
      _FakeModule('early', order: 1),
    ]);
    expect(registry.tabs.map((t) => t.path), ['/early', '/late']);
  });

  test('paid modules only show with the right entitlement', () {
    final registry = ModuleRegistry(const [
      _FakeModule('free'),
      _FakeModule('ai', requires: Entitlement.aiCredits),
    ]);
    expect(registry.availableWith({}).map((m) => m.id), ['free']);
    expect(registry.availableWith({Entitlement.aiCredits}).map((m) => m.id), [
      'free',
      'ai',
    ]);
  });

  group('record type validation', () {
    const visit = RecordTypeDefinition(
      key: 'visit',
      icon: Icons.circle,
      fields: [
        FieldSpec(key: 'doctorName', kind: FieldKind.text, required: true),
        FieldSpec(key: 'fee', kind: FieldKind.money),
        FieldSpec(key: 'kind', kind: FieldKind.choice, choices: ['a', 'b']),
      ],
    );

    test('accepts valid data', () {
      expect(
        visit.validate({'doctorName': 'Dr Hany', 'fee': 600, 'kind': 'a'}),
        isEmpty,
      );
    });

    test('reports missing required and wrong kinds', () {
      expect(
        visit.validate({'doctorName': '  ', 'fee': 'six hundred', 'kind': 'z'}),
        ['doctorName', 'fee', 'kind'],
      );
    });
  });
}
