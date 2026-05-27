import 'package:flutter/material.dart';
import 'package:myapp/contacts/contact_form_page.dart';
import 'package:myapp/models/ahvi_contact.dart';
import 'package:myapp/services/contact_service.dart';

class ContactDetailPage extends StatefulWidget {
  const ContactDetailPage({super.key, required this.contact});

  final AhviContact contact;

  @override
  State<ContactDetailPage> createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends State<ContactDetailPage> {
  final ContactService _service = ContactService();
  late AhviContact _contact;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _contact = widget.contact;
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ContactFormPage(contact: _contact)),
    );
    if (changed == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _toggleFavorite() async {
    setState(() => _busy = true);
    try {
      final updated = await _service.updateContact(_contact.id, {
        'isFavorite': !_contact.isFavorite,
      });
      if (!mounted) return;
      setState(() {
        _contact = updated;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update contact: $e')),
      );
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete contact?'),
        content: Text('Remove ${_contact.fullName} from AHVI contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      await _service.deleteContact(_contact.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete contact: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _contact.avatarUrl.trim();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _busy ? null : () => Navigator.pop(context, true),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _busy ? null : _toggleFavorite,
                  icon: Icon(
                    _contact.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: _contact.isFavorite
                        ? const Color(0xFFFFB800)
                        : const Color(0xFF7D8797),
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : _edit,
                  icon: const Icon(Icons.edit_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: CircleAvatar(
                radius: 54,
                backgroundColor: const Color(0xFFE7ECFF),
                backgroundImage:
                    imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                child: imageUrl.isEmpty
                    ? Text(
                        _contact.initials,
                        style: const TextStyle(
                          color: Color(0xFF5D6CFF),
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _contact.fullName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            if (_contact.relationship.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _contact.relationship,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF697386),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 24),
            _InfoCard(
              children: [
                _InfoRow(
                  icon: Icons.phone_rounded,
                  label: 'Phone',
                  value: _contact.phoneNumber,
                ),
                if (_contact.notes.trim().isNotEmpty)
                  _InfoRow(
                    icon: Icons.notes_rounded,
                    label: 'Notes',
                    value: _contact.notes,
                  ),
                if (_contact.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _contact.tags
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              backgroundColor: const Color(0xFFEFF3FF),
                              side: BorderSide.none,
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete contact'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD73A49),
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFC9D3EA)),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF6B7BFF)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF697386),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
