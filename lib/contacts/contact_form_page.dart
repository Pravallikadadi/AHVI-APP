import 'package:flutter/material.dart';
import 'package:myapp/models/ahvi_contact.dart';
import 'package:myapp/services/contact_service.dart';

class ContactFormPage extends StatefulWidget {
  const ContactFormPage({super.key, this.contact});

  final AhviContact? contact;

  @override
  State<ContactFormPage> createState() => _ContactFormPageState();
}

class _ContactFormPageState extends State<ContactFormPage> {
  final _formKey = GlobalKey<FormState>();
  final ContactService _service = ContactService();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _relationshipCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _tagsCtrl;
  late final TextEditingController _avatarCtrl;
  bool _favorite = false;
  bool _saving = false;

  bool get _editing => widget.contact != null;

  @override
  void initState() {
    super.initState();
    final contact = widget.contact;
    _firstNameCtrl = TextEditingController(text: contact?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: contact?.lastName ?? '');
    _phoneCtrl = TextEditingController(text: contact?.phoneNumber ?? '');
    _displayNameCtrl = TextEditingController(text: contact?.displayName ?? '');
    _relationshipCtrl =
        TextEditingController(text: contact?.relationship ?? '');
    _notesCtrl = TextEditingController(text: contact?.notes ?? '');
    _tagsCtrl = TextEditingController(text: contact?.tags.join(', ') ?? '');
    _avatarCtrl = TextEditingController(text: contact?.avatarUrl ?? '');
    _favorite = contact?.isFavorite ?? false;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _displayNameCtrl.dispose();
    _relationshipCtrl.dispose();
    _notesCtrl.dispose();
    _tagsCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  List<String> _tags() => _tagsCtrl.text
      .split(',')
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final input = AhviContactInput(
      firstName: _firstNameCtrl.text,
      lastName: _lastNameCtrl.text,
      phoneNumber: _phoneCtrl.text,
      displayName: _displayNameCtrl.text,
      relationship: _relationshipCtrl.text,
      notes: _notesCtrl.text,
      tags: _tags(),
      isFavorite: _favorite,
      avatarUrl: _avatarCtrl.text,
    );
    try {
      if (_editing) {
        await _service.updateContact(widget.contact!.id, input.toJson());
      } else {
        await _service.createContact(input);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save contact: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  Expanded(
                    child: Text(
                      _editing ? 'Edit Contact' : 'New Contact',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
                  children: [
                    _Field(
                      controller: _firstNameCtrl,
                      label: 'First name',
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? 'Required' : null,
                    ),
                    _Field(controller: _lastNameCtrl, label: 'Last name'),
                    _Field(
                      controller: _phoneCtrl,
                      label: 'Phone number',
                      keyboardType: TextInputType.phone,
                      validator: (value) =>
                          (value ?? '').trim().length < 3 ? 'Required' : null,
                    ),
                    _Field(
                        controller: _displayNameCtrl, label: 'Display name'),
                    _Field(
                        controller: _relationshipCtrl,
                        label: 'Relationship'),
                    _Field(
                      controller: _tagsCtrl,
                      label: 'Tags',
                      hint: 'family, work, travel',
                    ),
                    _Field(
                      controller: _avatarCtrl,
                      label: 'Avatar URL',
                      keyboardType: TextInputType.url,
                    ),
                    _Field(
                      controller: _notesCtrl,
                      label: 'Notes',
                      maxLines: 4,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Favorite',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      value: _favorite,
                      onChanged: (value) => setState(() => _favorite = value),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        backgroundColor: const Color(0xFF6578F8),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_editing ? 'Save changes' : 'Add contact'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFC9D3EA)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFC9D3EA)),
          ),
        ),
      ),
    );
  }
}
