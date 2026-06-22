import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:myapp/contacts/contact_detail_page.dart';
import 'package:myapp/contacts/contact_form_page.dart';
import 'package:myapp/models/ahvi_contact.dart';
import 'package:myapp/services/contact_service.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ContactService _service = ContactService();
  final TextEditingController _searchCtrl = TextEditingController();
  List<AhviContact> _contacts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final contacts = await _service.listContacts();
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<AhviContact> get _visibleContacts {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? List<AhviContact>.from(_contacts)
        : _contacts.where((contact) {
            final haystack = [
              contact.fullName,
              contact.phoneNumber,
              contact.relationship,
              contact.tags.join(' '),
            ].join(' ').toLowerCase();
            return haystack.contains(query);
          }).toList();
    filtered.sort(
      (a, b) {
        final favorite = (b.isFavorite ? 1 : 0) - (a.isFavorite ? 1 : 0);
        if (favorite != 0) return favorite;
        return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      },
    );
    return filtered;
  }

  String _normalizePhone(String value) =>
      value.replaceAll(RegExp(r'[^\d]'), '');

  Future<void> _importFromPhone() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Contacts permission denied')),
        );
        return;
      }
      final picked = await FlutterContacts.openExternalPick();
      if (picked == null) return;
      final phoneContact = await FlutterContacts.getContact(picked.id);
      if (phoneContact == null) return;

      final rawPhone = phoneContact.phones.isNotEmpty
          ? phoneContact.phones.first.number.trim()
          : '';
      if (rawPhone.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Selected contact has no phone number'),
          ),
        );
        return;
      }

      final normalizedNew = _normalizePhone(rawPhone);
      final duplicate = normalizedNew.isNotEmpty &&
          _contacts.any(
            (c) => _normalizePhone(c.phoneNumber) == normalizedNew,
          );
      if (duplicate) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Contact already exists')),
        );
        return;
      }

      final displayName = phoneContact.displayName.trim();
      final firstName = phoneContact.name.first.trim().isNotEmpty
          ? phoneContact.name.first.trim()
          : (displayName.isNotEmpty ? displayName : rawPhone);

      await _service.createContact(
        AhviContactInput(
          firstName: firstName,
          lastName: phoneContact.name.last.trim(),
          phoneNumber: rawPhone,
          displayName: displayName,
          tags: [
            'source:phonebook',
            'sourceId:${phoneContact.id}',
          ],
        ),
      );
      if (!mounted) return;
      await _loadContacts();
      messenger.showSnackBar(
        const SnackBar(content: Text('Contact imported')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not import contact: $e')),
      );
    }
  }

  Future<void> _openAdd() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ContactFormPage()),
    );
    if (changed == true) _loadContacts();
  }

  Future<void> _openDetail(AhviContact contact) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ContactDetailPage(contact: contact)),
    );
    if (changed == true) _loadContacts();
  }

  Future<void> _toggleFavorite(AhviContact contact) async {
    setState(() {
      _contacts = _contacts
          .map(
            (item) => item.id == contact.id
                ? AhviContact(
                    id: item.id,
                    firstName: item.firstName,
                    lastName: item.lastName,
                    phoneNumber: item.phoneNumber,
                    displayName: item.displayName,
                    relationship: item.relationship,
                    notes: item.notes,
                    tags: item.tags,
                    isFavorite: !item.isFavorite,
                    avatarUrl: item.avatarUrl,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt,
                  )
                : item,
          )
          .toList();
    });
    try {
      await _service.updateContact(contact.id, {
        'isFavorite': !contact.isFavorite,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update favorite: $e')),
      );
      _loadContacts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _visibleContacts;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAdd,
        backgroundColor: const Color(0xFF6B7BFF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Contacts',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF121620),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _importFromPhone,
                    icon: const Icon(Icons.contact_phone_rounded),
                    tooltip: 'Import from phone',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search contacts',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFFC9D3EA)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFFC9D3EA)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadContacts,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _ErrorState(message: _error!, onRetry: _loadContacts)
                        : contacts.isEmpty
                            ? _EmptyState(onImport: _importFromPhone)
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 4, 24, 110),
                                itemCount: contacts.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final contact = contacts[index];
                                  return _ContactTile(
                                    contact: contact,
                                    onTap: () => _openDetail(contact),
                                    onFavorite: () => _toggleFavorite(contact),
                                  );
                                },
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.onTap,
    required this.onFavorite,
  });

  final AhviContact contact;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _ContactAvatar(contact: contact),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        contact.maskedPhoneNumber,
                        if (contact.relationship.trim().isNotEmpty)
                          contact.relationship,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF697386),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onFavorite,
                icon: Icon(
                  contact.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: contact.isFavorite
                      ? const Color(0xFFFFB800)
                      : const Color(0xFF8B94A7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactAvatar extends StatelessWidget {
  const _ContactAvatar({required this.contact});

  final AhviContact contact;

  @override
  Widget build(BuildContext context) {
    final imageUrl = contact.avatarUrl.trim();
    return CircleAvatar(
      radius: 28,
      backgroundColor: const Color(0xFFE7ECFF),
      backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
      child: imageUrl.isEmpty
          ? Text(
              contact.initials,
              style: const TextStyle(
                color: Color(0xFF5D6CFF),
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 120),
      children: [
        const Icon(Icons.contacts_rounded, size: 52, color: Color(0xFF7F8CFF)),
        const SizedBox(height: 18),
        const Text(
          'No contacts yet',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Add people you plan with, travel with, or need AHVI to remember.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF697386), fontSize: 16),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.contact_phone_rounded),
            label: const Text('Import from phone'),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 120),
      children: [
        const Icon(Icons.warning_amber_rounded,
            size: 52, color: Color(0xFFFFA726)),
        const SizedBox(height: 18),
        const Text(
          'Could not load contacts',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF697386)),
        ),
        const SizedBox(height: 18),
        Center(
          child: FilledButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
