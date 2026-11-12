import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/preferences.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../account/save_gate.dart';
import '../medicines/medicines_providers.dart' show clockProvider;
import 'person_status.dart';
import '../children/growth.dart' show isUnderFive;
import '../doctors/contact_links.dart' show isCallablePhone;
import '../../core/util/date_picker.dart';

const bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

/// How a person is related to the one using the app, as saved.
const relationships = [
  'son',
  'daughter',
  'husband',
  'wife',
  'father',
  'mother',
  'brother',
  'sister',
  'grandfather',
  'grandmother',
  'other',
];

/// The sex a relationship implies ("بنتي" is a girl); null for "other".
String? sexOfRelationship(String? relationship) => switch (relationship) {
  'son' || 'husband' || 'father' || 'brother' || 'grandfather' => 'male',
  'daughter' || 'wife' || 'mother' || 'sister' || 'grandmother' => 'female',
  _ => null,
};

/// Where the birth-date picker opens for a new person: today for a son or
/// daughter (most are added as babies or young children), a usual year for
/// parents and grandparents, otherwise 1990. A guess only, to save taps.
DateTime birthDatePickerStart(String? relationship, DateTime today) =>
    switch (relationship) {
      'son' || 'daughter' => DateUtils.dateOnly(today),
      'father' || 'mother' => DateTime(1965),
      'grandfather' || 'grandmother' => DateTime(1945),
      _ => DateTime(1990),
    };

/// Adds a person, or edits one when [profileId] is given.
class ProfileFormScreen extends ConsumerStatefulWidget {
  const ProfileFormScreen({super.key, this.profileId});

  final String? profileId;

  @override
  ConsumerState<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends ConsumerState<ProfileFormScreen> {
  final _name = TextEditingController();
  final _allergies = TextEditingController();
  final _conditions = TextEditingController();
  final _emergencyPhone = TextEditingController();
  final _emergencyContact = TextEditingController();
  DateTime? _birthDate;
  String? _sex;
  String? _bloodType;
  String? _relationship;
  bool _phoneInvalid = false;
  bool _simpleMode = false;
  bool _loaded = false;
  bool _nameMissing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.profileId == null) {
      _loaded = true;
    } else {
      _load(widget.profileId!);
    }
  }

  Future<void> _load(String id) async {
    final p = await ref.read(databaseProvider).watchProfile(id).first;
    if (!mounted) return;
    setState(() {
      if (p != null) {
        _name.text = p.displayName;
        _allergies.text = p.allergies ?? '';
        _conditions.text = p.conditions ?? '';
        _birthDate = p.birthDate;
        _sex = p.sex;
        _bloodType = p.bloodType;
        _simpleMode = p.simpleMode;
        _relationship = p.relationship;
        _emergencyPhone.text = p.emergencyPhone ?? '';
        _emergencyContact.text = p.emergencyContactName ?? '';
      }
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _allergies.dispose();
    _conditions.dispose();
    _emergencyPhone.dispose();
    _emergencyContact.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final phone = _emergencyPhone.text.trim();
    // A number that can't be called is worse than none on an emergency card.
    final phoneInvalid = phone.isNotEmpty && !isCallablePhone(phone);
    setState(() {
      _nameMissing = _name.text.trim().isEmpty;
      _phoneInvalid = phoneInvalid;
    });
    if (_nameMissing || phoneInvalid) return;
    setState(() => _saving = true);
    final id = widget.profileId;
    if (id == null && !await ref.read(saveGateProvider).allow()) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
    final db = ref.read(databaseProvider);
    final String savedId;
    try {
      if (id == null) {
        savedId = await db.addProfile(
          _name.text,
          birthDate: _birthDate,
          sex: _sex,
          bloodType: _bloodType,
          allergies: _allergies.text,
          conditions: _conditions.text,
          simpleMode: _simpleMode,
          relationship: _relationship,
          emergencyPhone: phone,
          emergencyContactName: _emergencyContact.text,
        );
      } else {
        await db.updateProfile(
          id,
          displayName: _name.text,
          birthDate: _birthDate,
          sex: _sex,
          bloodType: _bloodType,
          allergies: _allergies.text,
          conditions: _conditions.text,
          simpleMode: _simpleMode,
          relationship: Value(_relationship),
          emergencyPhone: Value(phone),
          emergencyContactName: Value(_emergencyContact.text),
        );
        savedId = id;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).saveFailed)),
      );
      return;
    }
    if (mounted) {
      context.go(
        pathAfterProfileSave(
          savedId,
          isNew: id == null,
          birthDate: _birthDate,
          today: DateTime.now(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    // Related to whom? Not asked about the person using the app.
    final isMe =
        widget.profileId != null &&
        widget.profileId == ref.watch(meProfileIdProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profileId == null ? l.familyNew : l.familyEdit),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (!isMe) ...[
                  Text(
                    l.profileRelationship,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in relationships)
                        ChoiceChip(
                          key: ValueKey('profile-relationship-$r'),
                          label: Text(l.relationshipMine(r)),
                          selected: _relationship == r,
                          // "بنتي" selects أنثى, "ابني" ذكر; still
                          // changeable below.
                          onSelected: (on) => setState(() {
                            _relationship = on ? r : null;
                            if (sexOfRelationship(_relationship)
                                case final sex?) {
                              _sex = sex;
                            }
                          }),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('profile-name'),
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: '${l.familyNameLabel} *',
                    errorText: _nameMissing ? l.fieldRequired : null,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l.profileSex,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  emptySelectionAllowed: true,
                  segments: [
                    ButtonSegment(value: 'female', label: Text(l.sexFemale)),
                    ButtonSegment(value: 'male', label: Text(l.sexMale)),
                  ],
                  selected: {?_sex},
                  onSelectionChanged: (s) =>
                      setState(() => _sex = s.isEmpty ? null : s.first),
                ),
                const SizedBox(height: 16),
                InkWell(
                  key: const ValueKey('profile-birthDate'),
                  onTap: () async {
                    final picked = await pickDate(
                      context,
                      initialDate:
                          _birthDate ??
                          birthDatePickerStart(_relationship, DateTime.now()),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _birthDate = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: l.profileBirthDate),
                    child: Text(
                      _birthDate == null
                          ? l.pickDate
                          : [
                              DateFormat.yMMMd(locale).format(_birthDate!),
                              ?ageLabel(
                                l,
                                _birthDate,
                                ref.read(clockProvider)(),
                              ),
                            ].join(' · '),
                      key: const ValueKey('profile-birthDate-text'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('profile-emergency-phone'),
                  controller: _emergencyPhone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l.profileEmergencyPhone,
                    helperText: l.profileEmergencyPhoneHint,
                    helperMaxLines: 2,
                    errorText: _phoneInvalid ? l.profileEmergencyInvalid : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('profile-emergency-name'),
                  controller: _emergencyContact,
                  decoration: InputDecoration(
                    labelText: l.profileEmergencyName,
                    helperText: l.profileEmergencyNameHint,
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 8),
                // A new person starts short. Details are on show when
                // changing what's there, so nothing saved is ever tucked away.
                Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: const ValueKey('profile-more'),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    maintainState: true,
                    initiallyExpanded: widget.profileId != null,
                    title: Text(l.profileMoreDetails),
                    children: [
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _bloodType,
                        decoration: InputDecoration(
                          labelText: l.profileBloodType,
                        ),
                        items: [
                          for (final b in bloodTypes)
                            DropdownMenuItem(value: b, child: Text(b)),
                        ],
                        onChanged: (v) => setState(() => _bloodType = v),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _allergies,
                        decoration: InputDecoration(
                          labelText: l.profileAllergies,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _conditions,
                        decoration: InputDecoration(
                          labelText: l.profileConditions,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        key: const ValueKey('profile-simple-mode'),
                        contentPadding: EdgeInsets.zero,
                        value: _simpleMode,
                        onChanged: (v) => setState(() => _simpleMode = v),
                        title: Text(l.profileSimpleMode),
                        subtitle: Text(l.profileSimpleModeHint),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const ValueKey('profile-save'),
                  onPressed: _saving ? null : _save,
                  child: ListenableBuilder(
                    listenable: _name,
                    builder: (_, _) => Text(
                      widget.profileId != null || _name.text.trim().isEmpty
                          ? l.familySave
                          : l.profileSaveNamed(_name.text.trim()),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Where saving a profile leads: a new child under five goes to the vaccine
/// setup, to tick the doses they already had; everyone else to their page.
String pathAfterProfileSave(
  String id, {
  required bool isNew,
  required DateTime? birthDate,
  required DateTime today,
}) => isNew && isUnderFive(birthDate, today)
    ? '/family/$id/vaccines/setup?first=1'
    : '/family/$id';
