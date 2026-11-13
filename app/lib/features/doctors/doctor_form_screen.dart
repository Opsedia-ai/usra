import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/util/localized_numbers.dart';
import '../../l10n/app_localizations.dart';
import '../account/save_gate.dart';

/// Adds a doctor, or edits one when [doctorId] is given.
class DoctorFormScreen extends ConsumerStatefulWidget {
  const DoctorFormScreen({super.key, this.doctorId});

  final String? doctorId;

  @override
  ConsumerState<DoctorFormScreen> createState() => _DoctorFormScreenState();
}

class _DoctorFormScreenState extends ConsumerState<DoctorFormScreen> {
  final _name = TextEditingController();
  final _specialty = TextEditingController();
  final _phone = TextEditingController();
  final _clinic = TextEditingController();
  final _address = TextEditingController();
  final _fee = TextEditingController();
  final _notes = TextEditingController();
  bool _loaded = false;
  bool _nameMissing = false;
  bool _feeInvalid = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.doctorId == null) {
      _loaded = true;
    } else {
      _load(widget.doctorId!);
    }
  }

  Future<void> _load(String id) async {
    final d = await ref.read(databaseProvider).watchDoctor(id).first;
    if (!mounted) return;
    setState(() {
      if (d != null) {
        _name.text = d.name;
        _specialty.text = d.specialty ?? '';
        _phone.text = d.phone ?? '';
        _clinic.text = d.clinic ?? '';
        _address.text = d.address ?? '';
        _fee.text = d.feeMinor == null ? '' : formatMoneyInput(d.feeMinor!);
        _notes.text = d.notes ?? '';
      }
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _specialty,
      _phone,
      _clinic,
      _address,
      _fee,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final fee = parseMoneyMinor(_fee.text);
    final feeInvalid = _fee.text.trim().isNotEmpty && fee == null;
    final nameMissing = _name.text.trim().isEmpty;
    setState(() {
      _nameMissing = nameMissing;
      _feeInvalid = feeInvalid;
    });
    if (nameMissing || feeInvalid) return;

    setState(() => _saving = true);
    if (widget.doctorId == null && !await ref.read(saveGateProvider).allow()) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
    final String id;
    try {
      id = await ref
          .read(databaseProvider)
          .saveDoctor(
            id: widget.doctorId,
            name: _name.text,
            specialty: _specialty.text,
            phone: _phone.text,
            clinic: _clinic.text,
            address: _address.text,
            feeMinor: fee,
            notes: _notes.text,
          );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).saveFailed)),
      );
      return;
    }
    if (!mounted) return;
    // Back to where the form was opened from, so the way back to More stays.
    if (widget.doctorId != null && context.canPop()) {
      context.pop();
    } else if (context.canPop()) {
      context.pushReplacement('/doctors/$id');
    } else {
      context.go('/doctors/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget field(
      String key,
      TextEditingController c,
      String label, {
      TextInputType? keyboard,
      String? error,
      String? suffix,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        key: ValueKey('doctor-$key'),
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          suffixText: suffix,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.doctorId == null ? l.doctorNew : l.doctorEdit),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                field(
                  'name',
                  _name,
                  '${l.doctorName} *',
                  error: _nameMissing ? l.fieldRequired : null,
                ),
                field('specialty', _specialty, l.doctorSpecialty),
                field(
                  'phone',
                  _phone,
                  l.doctorPhone,
                  keyboard: TextInputType.phone,
                ),
                field('clinic', _clinic, l.doctorClinic),
                field('address', _address, l.doctorAddress),
                field(
                  'fee',
                  _fee,
                  l.doctorFee,
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  error: _feeInvalid ? l.fieldInvalid : null,
                  suffix: l.currencyEgp,
                ),
                field('notes', _notes, l.doctorNotes),
                const SizedBox(height: 12),
                FilledButton(
                  key: const ValueKey('doctor-save'),
                  onPressed: _saving ? null : _save,
                  child: Text(l.familySave),
                ),
              ],
            ),
    );
  }
}
