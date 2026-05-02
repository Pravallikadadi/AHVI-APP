import 'package:flutter/material.dart';
import 'package:myapp/app_localizations.dart';
import 'package:myapp/theme/theme_tokens.dart';

enum _ContactSort { az, recent }

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  _ContactSort _sort = _ContactSort.az;

  Future<void> _openAddContactPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const _AddContactPage(),
      ),
    );
  }

  static final List<({String name, String number, String? image, DateTime added})>
  _allContacts = [
    (
      name: 'Ava Johnson',
      number: '+1 202 555 0140',
      image: 'https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?w=300&h=300&fit=crop',
      added: DateTime(2026, 2, 12),
    ),
    (
      name: 'Noah Carter',
      number: '+1 202 555 0112',
      image: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&h=300&fit=crop',
      added: DateTime(2026, 3, 10),
    ),
    (
      name: 'Mia Patel',
      number: '+1 202 555 0188',
      image: null,
      added: DateTime(2026, 1, 20),
    ),
    (
      name: 'Liam Brooks',
      number: '+1 202 555 0167',
      image: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&h=300&fit=crop',
      added: DateTime(2026, 3, 15),
    ),
    (
      name: 'Sofia Lee',
      number: '+1 202 555 0131',
      image: null,
      added: DateTime(2026, 2, 25),
    ),
    (
      name: 'Ethan Rivera',
      number: '+1 202 555 0172',
      image: 'https://images.unsplash.com/photo-1542206395-9feb3edaa68d?w=300&h=300&fit=crop',
      added: DateTime(2026, 3, 5),
    ),
  ];

  List<({String name, String number, String? image, DateTime added})> get _contacts {
    final q = _query.trim().toLowerCase();
    final filtered = _allContacts.where((c) {
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) || c.number.toLowerCase().contains(q);
    }).toList();

    switch (_sort) {
      case _ContactSort.az:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _ContactSort.recent:
        filtered.sort((a, b) => b.added.compareTo(a.added));
    }
    return filtered;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    final contacts = _contacts;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate.fixed([
              _buildSearch(t),
              const SizedBox(height: 12),
              _buildActions(t),
              const SizedBox(height: 14),
              _buildSort(t),
              const SizedBox(height: 12),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _buildContactCard(t, contacts[i]),
              childCount: contacts.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearch(AppThemeTokens t) {
    return Container(
      decoration: BoxDecoration(
        color: t.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.cardBorder),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        style: TextStyle(color: t.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: AppLocalizations.t(context, 'contacts_search_hint'),
          hintStyle: TextStyle(color: t.mutedText),
          prefixIcon: Icon(Icons.search_rounded, color: t.mutedText, size: 20),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        ),
      ),
    );
  }

  Widget _buildActions(AppThemeTokens t) {
    return Row(
      children: [
        Expanded(
          child: _ActionBtn(
            icon: Icons.person_add_alt_1_rounded,
            label: AppLocalizations.t(context, 'contacts_add'),
            onTap: _openAddContactPage,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionBtn(
            icon: Icons.import_contacts_rounded,
            label: AppLocalizations.t(context, 'contacts_import'),
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildSort(AppThemeTokens t) {
    final label = _sort == _ContactSort.az
        ? AppLocalizations.t(context, 'contacts_sort_az')
        : AppLocalizations.t(context, 'contacts_sort_recent');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          AppLocalizations.t(context, 'contacts'),
          style: TextStyle(
            color: t.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        PopupMenuButton<_ContactSort>(
          onSelected: (value) => setState(() => _sort = value),
          itemBuilder: (context) => [
            PopupMenuItem(value: _ContactSort.az, child: Text(AppLocalizations.t(context, 'contacts_sort_az'))),
            PopupMenuItem(value: _ContactSort.recent, child: Text(AppLocalizations.t(context, 'contacts_sort_recent'))),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: t.panel,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sort_rounded, size: 16, color: t.mutedText),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(color: t.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard(
    AppThemeTokens t,
    ({String name, String number, String? image, DateTime added}) contact,
  ) {
    final initials = contact.name
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((s) => s[0])
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: t.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.cardBorder),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                color: t.backgroundSecondary,
                child: contact.image == null
                    ? Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                    : Image.network(
                  contact.image!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            contact.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: t.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: t.accent.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddContactPage extends StatefulWidget {
  const _AddContactPage();

  @override
  State<_AddContactPage> createState() => _AddContactPageState();
}

class _AddContactPageState extends State<_AddContactPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _otherInfoCtrl = TextEditingController();

  DateTime? _birthday;
  _CountryCode _countryCode = const _CountryCode(flag: '🇺🇸', name: 'United States', code: '+1');
  bool _pickerOpen = false;
  String _pickerQuery = '';
  final TextEditingController _pickerSearchCtrl = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  static const List<_CountryCode> _countryCodes = [
    _CountryCode(flag: '🇺🇸', name: 'United States',   code: '+1'),
    _CountryCode(flag: '🇬🇧', name: 'United Kingdom',  code: '+44'),
    _CountryCode(flag: '🇮🇳', name: 'India',           code: '+91'),
    _CountryCode(flag: '🇦🇺', name: 'Australia',       code: '+61'),
    _CountryCode(flag: '🇨🇦', name: 'Canada',          code: '+1 CA'),
    _CountryCode(flag: '🇸🇬', name: 'Singapore',       code: '+65'),
    _CountryCode(flag: '🇯🇵', name: 'Japan',           code: '+81'),
    _CountryCode(flag: '🇨🇳', name: 'China',           code: '+86'),
    _CountryCode(flag: '🇩🇪', name: 'Germany',         code: '+49'),
    _CountryCode(flag: '🇫🇷', name: 'France',          code: '+33'),
    _CountryCode(flag: '🇮🇹', name: 'Italy',           code: '+39'),
    _CountryCode(flag: '🇪🇸', name: 'Spain',           code: '+34'),
    _CountryCode(flag: '🇵🇹', name: 'Portugal',        code: '+351'),
    _CountryCode(flag: '🇳🇱', name: 'Netherlands',     code: '+31'),
    _CountryCode(flag: '🇧🇪', name: 'Belgium',         code: '+32'),
    _CountryCode(flag: '🇨🇭', name: 'Switzerland',     code: '+41'),
    _CountryCode(flag: '🇦🇹', name: 'Austria',         code: '+43'),
    _CountryCode(flag: '🇸🇪', name: 'Sweden',          code: '+46'),
    _CountryCode(flag: '🇳🇴', name: 'Norway',          code: '+47'),
    _CountryCode(flag: '🇩🇰', name: 'Denmark',         code: '+45'),
    _CountryCode(flag: '🇫🇮', name: 'Finland',         code: '+358'),
    _CountryCode(flag: '🇵🇱', name: 'Poland',          code: '+48'),
    _CountryCode(flag: '🇷🇺', name: 'Russia',          code: '+7'),
    _CountryCode(flag: '🇹🇷', name: 'Turkey',          code: '+90'),
    _CountryCode(flag: '🇸🇦', name: 'Saudi Arabia',    code: '+966'),
    _CountryCode(flag: '🇦🇪', name: 'UAE',             code: '+971'),
    _CountryCode(flag: '🇮🇱', name: 'Israel',          code: '+972'),
    _CountryCode(flag: '🇰🇷', name: 'South Korea',     code: '+82'),
    _CountryCode(flag: '🇮🇩', name: 'Indonesia',       code: '+62'),
    _CountryCode(flag: '🇲🇾', name: 'Malaysia',        code: '+60'),
    _CountryCode(flag: '🇹🇭', name: 'Thailand',        code: '+66'),
    _CountryCode(flag: '🇵🇭', name: 'Philippines',     code: '+63'),
    _CountryCode(flag: '🇻🇳', name: 'Vietnam',         code: '+84'),
    _CountryCode(flag: '🇧🇷', name: 'Brazil',          code: '+55'),
    _CountryCode(flag: '🇲🇽', name: 'Mexico',          code: '+52'),
    _CountryCode(flag: '🇦🇷', name: 'Argentina',       code: '+54'),
    _CountryCode(flag: '🇨🇱', name: 'Chile',           code: '+56'),
    _CountryCode(flag: '🇨🇴', name: 'Colombia',        code: '+57'),
    _CountryCode(flag: '🇿🇦', name: 'South Africa',    code: '+27'),
    _CountryCode(flag: '🇳🇬', name: 'Nigeria',         code: '+234'),
    _CountryCode(flag: '🇰🇪', name: 'Kenya',           code: '+254'),
    _CountryCode(flag: '🇳🇿', name: 'New Zealand',     code: '+64'),
  ];

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _surnameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _otherInfoCtrl.dispose();
    _pickerSearchCtrl.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _togglePicker(AppThemeTokens t) {
    if (_pickerOpen) {
      _removeOverlay();
      setState(() {
        _pickerOpen = false;
        _pickerQuery = '';
        _pickerSearchCtrl.clear();
      });
    } else {
      setState(() => _pickerOpen = true);
      _overlayEntry = OverlayEntry(
        builder: (context) => _buildPickerOverlay(t),
      );
      Overlay.of(context).insert(_overlayEntry!);
    }
  }

  Widget _buildPickerOverlay(AppThemeTokens t) {
    return StatefulBuilder(
      builder: (ctx, setOverlayState) {
        return Stack(
          children: [
            // Transparent barrier to close on outside tap
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _removeOverlay();
                  setState(() {
                    _pickerOpen = false;
                    _pickerQuery = '';
                    _pickerSearchCtrl.clear();
                  });
                },
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 54),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: t.backgroundPrimary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: t.backgroundPrimary,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: t.cardBorder),
                          ),
                          child: TextField(
                            controller: _pickerSearchCtrl,
                            autofocus: true,
                            style: TextStyle(color: t.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: AppLocalizations.t(context, 'contacts_search_hint'),
                              hintStyle: TextStyle(color: t.mutedText),
                              prefixIcon: Icon(Icons.search_rounded, color: t.mutedText, size: 18),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onChanged: (v) {
                              setOverlayState(() => _pickerQuery = v);
                            },
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView(
                          padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                          shrinkWrap: true,
                          children: _countryCodes
                              .where((c) {
                                final q = _pickerQuery.toLowerCase();
                                return q.isEmpty ||
                                    c.name.toLowerCase().contains(q) ||
                                    c.code.contains(q);
                              })
                              .map((c) {
                                final isSelected = c == _countryCode;
                                return GestureDetector(
                                  onTap: () {
                                    _removeOverlay();
                                    setState(() {
                                      _countryCode = c;
                                      _pickerOpen = false;
                                      _pickerQuery = '';
                                      _pickerSearchCtrl.clear();
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? t.accent.primary.withValues(alpha: 0.14)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(c.flag, style: const TextStyle(fontSize: 18)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            c.name,
                                            style: TextStyle(
                                              color: t.textPrimary,
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          c.code,
                                          style: TextStyle(
                                            color: t.mutedText,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(width: 6),
                                          Icon(Icons.check_rounded, color: t.accent.primary, size: 16),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              })
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _birthday = picked);
    }
  }

  void _saveContact() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.t(context, 'contacts_saved_snackbar'))),
    );
    Navigator.of(context).pop();
  }

  String _birthdayText(BuildContext context) {
    final b = _birthday;
    if (b == null) return AppLocalizations.t(context, 'contacts_select_birthday');
    final month = b.month.toString().padLeft(2, '0');
    final day = b.day.toString().padLeft(2, '0');
    return '${b.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;

    return Scaffold(
      backgroundColor: t.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: t.backgroundPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: t.textPrimary),
        title: Text(
          AppLocalizations.t(context, 'contacts_create_contact'),
          style: TextStyle(
            color: t.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InputField(
                  controller: _firstNameCtrl,
                  label: 'contacts_first_name',
                  hint: 'contacts_first_name_hint',
                  keyboardType: TextInputType.name,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return AppLocalizations.t(context, 'contacts_first_name_required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _InputField(
                  controller: _surnameCtrl,
                  label: 'contacts_surname',
                  hint: 'contacts_surname_hint',
                  keyboardType: TextInputType.name,
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.t(context, 'contacts_phone_number'),
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CompositedTransformTarget(
                          link: _layerLink,
                          child: GestureDetector(
                            onTap: () => _togglePicker(t),
                            child: Container(
                              width: 120,
                              height: 50,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: t.panel,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _pickerOpen
                                      ? t.accent.primary
                                      : t.cardBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_countryCode.flag} ${_countryCode.code}',
                                    style: TextStyle(
                                      color: t.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  AnimatedRotation(
                                    turns: _pickerOpen ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(Icons.keyboard_arrow_down_rounded,
                                        size: 18, color: t.mutedText),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _InputField(
                            controller: _phoneCtrl,
                            label: '',
                            hint: 'contacts_phone_hint',
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return AppLocalizations.t(context, 'contacts_phone_required');
                              }
                              return null;
                            },
                            denseTop: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InputField(
                  controller: _emailCtrl,
                  label: 'contacts_email',
                  hint: 'contacts_email_hint',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.t(context, 'contacts_birthday'),
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickBirthday,
                  child: Ink(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: t.panel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: t.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cake_outlined,
                          color: t.mutedText,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _birthdayText(context),
                          style: TextStyle(
                            color: _birthday == null ? t.mutedText : t.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _InputField(
                  controller: _addressCtrl,
                  label: 'contacts_address',
                  hint: 'contacts_address_hint',
                  keyboardType: TextInputType.streetAddress,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _InputField(
                  controller: _otherInfoCtrl,
                  label: 'contacts_other_info',
                  hint: 'contacts_other_info_hint',
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveContact,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: t.accent.primary,
                      foregroundColor: t.tileText,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.t(context, 'contacts_save_contact'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
class _CountryCode {
  final String flag;
  final String name;
  final String code;

  const _CountryCode({
    required this.flag,
    required this.name,
    required this.code,
  });

  @override
  bool operator ==(Object other) =>
      other is _CountryCode && other.flag == flag && other.code == code;

  @override
  int get hashCode => Object.hash(flag, code);
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.denseTop = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool denseTop;

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    final localizedLabel = label.isNotEmpty ? AppLocalizations.t(context, label) : '';
    final localizedHint = hint.isNotEmpty ? AppLocalizations.t(context, hint) : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (localizedLabel.isNotEmpty) ...[
          Text(
            localizedLabel,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: denseTop ? 0 : 7),
        ],
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(color: t.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: localizedHint,
            hintStyle: TextStyle(color: t.mutedText),
            filled: true,
            fillColor: t.panel,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.accent.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
          ),
        ),
      ],
    );
  }
}