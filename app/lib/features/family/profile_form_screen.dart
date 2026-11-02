import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';

const bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

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
  DateTime? _birthDate;
  String? _sex;
  String? _bloodType;
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
      }
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _allergies.dispose();
    _conditions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameMissing = true);
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final id = widget.profileId;
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
    if (mounted) context.go('/family/$savedId');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profileId == null ? l.familyNew : l.familyEdit),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextField(
                  key: const ValueKey('profile-name'),
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: '${l.familyNameLabel} *',
                    errorText: _nameMissing ? l.fieldRequired : null,
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  key: const ValueKey('profile-birthDate'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _birthDate ?? DateTime(1990),
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
                          : DateFormat.yMMMd(locale).format(_birthDate!),
                    ),
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
                DropdownButtonFormField<String>(
                  initialValue: _bloodType,
                  decoration: InputDecoration(labelText: l.profileBloodType),
                  items: [
                    for (final b in bloodTypes)
                      DropdownMenuItem(value: b, child: Text(b)),
                  ],
                  onChanged: (v) => setState(() => _bloodType = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _allergies,
                  decoration: InputDecoration(labelText: l.profileAllergies),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _conditions,
                  decoration: InputDecoration(labelText: l.profileConditions),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  key: const ValueKey('profile-save'),
                  onPressed: _saving ? null : _save,
                  child: Text(l.familySave),
                ),
              ],
            ),
    );
  }
}
