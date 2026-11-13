import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/modules/feature_module.dart';
import 'package:usra/core/routing/app_router.dart';

ModuleTab _tab(String path, {List<String> alsoFor = const []}) => ModuleTab(
  path: path,
  icon: const IconData(0),
  label: (_) => path,
  alsoFor: alsoFor,
);

/// Which bottom tab is lit (QA L4).
void main() {
  final home = _tab('/home', alsoFor: ['/family']);
  final medicines = _tab('/medicines');
  final records = _tab('/records');
  final more = _tab('/settings', alsoFor: ['/doctors', '/money']);
  final regular = [home, medicines, records, more];

  test('a tab\'s own path lights it', () {
    expect(selectedTab(regular, regular, '/records', '/home'), 2);
    expect(selectedTab(regular, regular, '/medicines/abc', null), 1);
  });

  test('a shared page stays with the tab it was opened from', () {
    // A record opened from Records, a sick list opened from Medicines.
    expect(selectedTab(regular, regular, '/family/p/record/r', '/records'), 2);
    expect(
      selectedTab(regular, regular, '/family/p/sick-days', '/medicines'),
      1,
    );
    // Opened from Home, or with nothing remembered: Home, which owns it.
    expect(selectedTab(regular, regular, '/family/p', '/home'), 0);
    expect(selectedTab(regular, regular, '/family/p', null), 0);
    // Doctors belongs to More in the regular bar, even beside Simple Mode's
    // Call tab.
    final all = [...regular, _tab('/doctors')];
    expect(selectedTab(regular, all, '/doctors', '/settings'), 3);
    expect(selectedTab(regular, all, '/doctors', null), 3);
  });

  test('in Simple Mode, More lights no tab', () {
    final family = _tab('/family');
    final call = _tab('/doctors');
    final simple = [home, family, call];
    final all = [...regular, ...simple];
    expect(selectedTab(simple, all, '/settings', '/home'), -1);
    expect(selectedTab(simple, all, '/family/p', '/home'), 1);
  });
}
