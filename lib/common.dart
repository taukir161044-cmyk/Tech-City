// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const String kAppName = 'Tech City';

/// GitHub Actions বিল্ডের সময় --dart-define=BUILD_NUMBER দিয়ে বসে (রান নম্বর)
const int kBuildNumber = int.fromEnvironment('BUILD_NUMBER', defaultValue: 0);

/// প্রতি বিল্ডে GitHub Releases এ এই লিংকে সর্বশেষ APK থাকে
const String kDefaultApkUrl =
    'https://github.com/taukir161044-cmyk/Tech-City/releases/latest/download/tech-city.apk';

/// এই ইমেইল দিয়ে লগইন করলেই অ্যাডমিন প্যানেল খুলবে।
/// firestore.rules ফাইলেও একই ইমেইল আছে — বদলাতে হলে দুই জায়গাতেই বদলান।
const String kAdminEmail = 'fahadtaukir4@gmail.com';

typedef Json = Map<String, dynamic>;
typedef Snap = QueryDocumentSnapshot<Json>;

FirebaseFirestore get db => FirebaseFirestore.instance;
FirebaseAuth get fbAuth => FirebaseAuth.instance;

final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

bool isAdminUser(User? u) =>
    (u?.email ?? '').trim().toLowerCase() == kAdminEmail;

const List<Color> kBannerColors = [
  Color(0xFF1565C0),
  Color(0xFF2E7D32),
  Color(0xFFC62828),
  Color(0xFF6A1B9A),
  Color(0xFFEF6C00),
];

const gap = SizedBox(height: 12);
const String kTaka = '৳';

// ---------------------------------------------------------------- helpers

int asInt(dynamic v, [int d = 0]) => v is num ? v.toInt() : d;

String asStr(dynamic v, [String d = '']) => v == null ? d : v.toString();

List<String> asStrList(dynamic v, List<String> d) {
  if (v is List) {
    final l =
        v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    return l.isEmpty ? d : l;
  }
  return d;
}

String fmtDate(dynamic ts) {
  if (ts is! Timestamp) return '';
  final d = ts.toDate().toLocal();
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(d.day)}/${p(d.month)}/${d.year}  ${p(d.hour)}:${p(d.minute)}';
}

String fmtDay(Timestamp ts) {
  final d = ts.toDate().toLocal();
  return '${d.day}/${d.month}/${d.year}';
}

String monthKey([DateTime? d]) {
  final t = d ?? DateTime.now();
  return '${t.year}-${t.month.toString().padLeft(2, '0')}';
}

String prevMonthKey() {
  final n = DateTime.now();
  return monthKey(DateTime(n.year, n.month - 1, 1));
}

List<String> lastMonthKeys([int n = 6]) {
  final now = DateTime.now();
  return [for (var i = 0; i < n; i++) monthKey(DateTime(now.year, now.month - i, 1))];
}

const _bnMonths = [
  'জানুয়ারি',
  'ফেব্রুয়ারি',
  'মার্চ',
  'এপ্রিল',
  'মে',
  'জুন',
  'জুলাই',
  'আগস্ট',
  'সেপ্টেম্বর',
  'অক্টোবর',
  'নভেম্বর',
  'ডিসেম্বর',
];

String monthLabel(String key) {
  final p = key.split('-');
  if (p.length != 2) return key;
  final m = int.tryParse(p[1]) ?? 1;
  return '${_bnMonths[(m - 1).clamp(0, 11)]} ${p[0]}';
}

String genCode([int len = 6]) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = Random.secure();
  return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
}

String normalizePhone(String s) {
  var d = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('88') && d.length == 13) d = d.substring(2);
  return d;
}

bool validPhone(String d) => RegExp(r'^01[0-9]{9}$').hasMatch(d);

String authError(String code) {
  switch (code) {
    case 'invalid-email':
      return 'ইমেইল ঠিকানা সঠিক নয়';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'ইমেইল বা পাসওয়ার্ড ভুল';
    case 'email-already-in-use':
      return 'এই ইমেইল দিয়ে আগেই অ্যাকাউন্ট খোলা হয়েছে';
    case 'weak-password':
      return 'পাসওয়ার্ড দুর্বল — কমপক্ষে ৬ অক্ষর দিন';
    case 'network-request-failed':
      return 'ইন্টারনেট সংযোগ নেই';
    case 'too-many-requests':
      return 'অনেকবার চেষ্টা হয়েছে, কিছুক্ষণ পরে আবার চেষ্টা করুন';
    default:
      return 'সমস্যা হয়েছে ($code)';
  }
}

// ----------------------------------------------------------- status labels

String statusLabel(String s) {
  switch (s) {
    case 'pending':
      return 'অপেক্ষমাণ';
    case 'approved':
      return 'অনুমোদিত';
    case 'confirmed':
      return 'কনফার্মড';
    case 'done':
      return 'সম্পন্ন';
    case 'rejected':
      return 'বাতিল';
    case 'Processing':
      return 'প্রসেসিং';
    case 'Technician Assigned':
      return 'টেকনিশিয়ান অ্যাসাইনড';
    case 'Resolved':
      return 'সমাধান হয়েছে';
    default:
      return s;
  }
}

Color statusColor(String s) {
  switch (s) {
    case 'approved':
    case 'confirmed':
    case 'done':
    case 'Resolved':
      return Colors.green.shade700;
    case 'rejected':
      return Colors.red.shade700;
    case 'Technician Assigned':
      return Colors.blue.shade700;
    default:
      return Colors.orange.shade800;
  }
}

// --------------------------------------------------------------- settings

class AppSettings {
  const AppSettings({
    required this.pointsPerTaka,
    required this.referralPoints,
    required this.minRedeem,
    required this.zones,
    required this.packages,
    required this.supportPhone,
    required this.billDueDay,
    required this.billMessage,
    required this.testHost,
    required this.testPort,
    required this.troubleshootSteps,
    required this.npsEnabled,
    required this.npsQuestion,
  });

  final int pointsPerTaka;
  final int referralPoints;
  final int minRedeem;
  final List<String> zones;
  final List<String> packages;
  final String supportPhone;
  final int billDueDay;
  final String billMessage;
  final String testHost;
  final int testPort;
  final List<String> troubleshootSteps;
  final bool npsEnabled;
  final String npsQuestion;

  static const defaults = AppSettings(
    pointsPerTaka: 10,
    referralPoints: 50,
    minRedeem: 100,
    zones: ['Zone A', 'Zone B', 'Zone C'],
    packages: ['5 Mbps', '10 Mbps', '20 Mbps', '30 Mbps'],
    supportPhone: '',
    billDueDay: 0,
    billMessage:
        'আপনার এই মাসের বিল পরিশোধের সময় এসে গেছে। বিকাশ বা নগদ দিয়ে পে করে দিন।',
    testHost: '',
    testPort: 80,
    troubleshootSteps: [
      'রাউটারের পাওয়ার ক্যাবল খুলে ৩০ সেকেন্ড অপেক্ষা করুন, তারপর আবার লাগান।',
      'রাউটারের WAN / ইন্টারনেট পোর্টের ক্যাবল ঠিকমতো লাগানো আছে কিনা দেখুন।',
      'ক্যাবল বাঁকা, কাটা বা ঢিলা কিনা দেখুন।',
      'রাউটারের PON / LOS লাইট লাল জ্বললে সরাসরি আমাদের জানান।',
      'কিছুক্ষণ পরেও ঠিক না হলে কমপ্লেইন করুন।',
    ],
    npsEnabled: true,
    npsQuestion:
        'আপনি Tech City ইন্টারনেট সার্ভিস অন্যদের কাছে কতটা সুপারিশ করবেন?',
  );

  factory AppSettings.fromMap(Json? m) {
    const d = AppSettings.defaults;
    if (m == null) return d;
    final msg = asStr(m['billMessage']).trim();
    final q = asStr(m['npsQuestion']).trim();
    return AppSettings(
      pointsPerTaka: max(1, asInt(m['pointsPerTaka'], d.pointsPerTaka)),
      referralPoints: max(0, asInt(m['referralPoints'], d.referralPoints)),
      minRedeem: max(1, asInt(m['minRedeem'], d.minRedeem)),
      zones: asStrList(m['zones'], d.zones),
      packages: asStrList(m['packages'], d.packages),
      supportPhone: asStr(m['supportPhone']),
      billDueDay: min(28, max(0, asInt(m['billDueDay'], 0))),
      billMessage: msg.isEmpty ? d.billMessage : msg,
      testHost: asStr(m['testHost']).trim(),
      testPort: min(65535, max(1, asInt(m['testPort'], 80))),
      troubleshootSteps: asStrList(m['troubleshootSteps'], d.troubleshootSteps),
      npsEnabled: m['npsEnabled'] != false,
      npsQuestion: q.isEmpty ? d.npsQuestion : q,
    );
  }
}

class Cfg {
  static final ValueNotifier<AppSettings> notifier =
      ValueNotifier<AppSettings>(AppSettings.defaults);
  static StreamSubscription<DocumentSnapshot<Json>>? _sub;

  static AppSettings get v => notifier.value;

  static void start() {
    _sub ??= db.collection('settings').doc('main').snapshots().listen(
      (s) {
        notifier.value = AppSettings.fromMap(s.data());
      },
      onError: (_) {},
    );
  }
}

// -------------------------------------------------------------- user model

class AppUser {
  AppUser({
    required this.uid,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.zone,
    required this.packageName,
    required this.referralCode,
    required this.points,
    required this.notifSeenAt,
    required this.dueDay,
    required this.paidMonth,
  });

  final String uid, name, phone, email, address, zone, packageName, referralCode;
  final int points, dueDay;
  final String paidMonth;
  final Timestamp? notifSeenAt;

  factory AppUser.fromDoc(DocumentSnapshot<Json> d) {
    final m = d.data() ?? <String, dynamic>{};
    final seen = m['notifSeenAt'];
    return AppUser(
      uid: d.id,
      name: asStr(m['name']),
      phone: asStr(m['phone']),
      email: asStr(m['email']),
      address: asStr(m['address']),
      zone: asStr(m['zone']),
      packageName: asStr(m['packageName']),
      referralCode: asStr(m['referralCode']),
      points: asInt(m['points']),
      notifSeenAt: seen is Timestamp ? seen : null,
      dueDay: asInt(m['dueDay']),
      paidMonth: asStr(m['paidMonth']),
    );
  }
}

Query<Json> notifQuery(String uid, String zone) => db
    .collection('notifications')
    .where('target', whereIn: ['all', zone, 'uid:$uid']);

// ---------------------------------------------------------- sort / filter

int _ms(dynamic t) =>
    t is Timestamp ? t.millisecondsSinceEpoch : DateTime.now().millisecondsSinceEpoch;

int byNewest(Snap a, Snap b) =>
    _ms(b.data()['createdAt']).compareTo(_ms(a.data()['createdAt']));

bool bannerLive(Json m) {
  if (m['active'] != true) return false;
  final e = m['expiresAt'];
  return e is! Timestamp || e.toDate().isAfter(DateTime.now());
}

// ----------------------------------------------------------------- UI bits

void toast(BuildContext c, String msg) {
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));
}

void toastGlobal(String msg) {
  messengerKey.currentState?.showSnackBar(SnackBar(content: Text(msg)));
}

Future<void> guarded(BuildContext c, Future<void> Function() f) async {
  try {
    await f();
  } catch (e) {
    if (c.mounted) toast(c, 'সমস্যা হয়েছে: $e');
  }
}

Future<void> copyText(BuildContext c, String text,
    [String msg = 'কপি হয়েছে']) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (c.mounted) toast(c, msg);
}

Future<void> callPhone(String p) async {
  if (p.trim().isEmpty) return;
  try {
    await launchUrl(Uri(scheme: 'tel', path: p.trim()));
  } catch (_) {}
}

Future<bool> confirmDialog(BuildContext c, String title, String msg,
    {String ok = 'হ্যাঁ'}) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(msg),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('না')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
      ],
    ),
  );
  return r == true;
}

Future<List<String>?> promptDialog(
  BuildContext c,
  String title,
  List<String> labels, {
  List<String>? initial,
  List<TextInputType>? types,
  String ok = 'সেভ',
}) {
  final ctrls = [
    for (var i = 0; i < labels.length; i++)
      TextEditingController(
          text: initial != null && i < initial.length ? initial[i] : '')
  ];
  return showDialog<List<String>>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < labels.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: ctrls[i],
                  keyboardType: types != null && i < types.length
                      ? types[i]
                      : TextInputType.text,
                  decoration: deco(labels[i]),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
        FilledButton(
          onPressed: () =>
              Navigator.pop(ctx, ctrls.map((e) => e.text.trim()).toList()),
          child: Text(ok),
        ),
      ],
    ),
  );
}

InputDecoration deco(String label, {String? hint, IconData? icon}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      border: const OutlineInputBorder(),
    );

Future<T?> showSheet<T>(BuildContext c, Widget Function(BuildContext) builder) {
  return showModalBottomSheet<T>(
    context: c,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
      child: SingleChildScrollView(child: builder(ctx)),
    ),
  );
}

Widget formShell({
  required String title,
  required List<Widget> children,
  required bool busy,
  required VoidCallback onSubmit,
  String? err,
  String label = 'জমা দিন',
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      gap,
      ...children,
      if (err != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(err, style: const TextStyle(color: Colors.red)),
        ),
      gap,
      FilledButton(
        onPressed: busy ? null : onSubmit,
        child: Text(busy ? 'অপেক্ষা করুন...' : label),
      ),
    ],
  );
}

Widget pickField({
  required String label,
  required List<String> items,
  required String? value,
  required ValueChanged<String?> onChanged,
}) {
  return DropdownMenu<String>(
    key: ValueKey('$label|${items.join(',')}'),
    expandedInsets: EdgeInsets.zero,
    label: Text(label),
    initialSelection: items.contains(value) ? value : null,
    requestFocusOnTap: false,
    dropdownMenuEntries: [
      for (final i in items) DropdownMenuEntry<String>(value: i, label: i)
    ],
    onSelected: onChanged,
  );
}

Widget choiceWrap(List<String> items, String? value, ValueChanged<String> onPick) {
  return Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final i in items)
        ChoiceChip(
            label: Text(i), selected: value == i, onSelected: (_) => onPick(i))
    ],
  );
}

Widget infoRow(IconData icon, String label, String value) => ListTile(
      dense: true,
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value.isEmpty ? '—' : value,
          style: const TextStyle(fontSize: 15)),
    );

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusLabel(status),
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Firestore query থেকে লাইভ লিস্ট। sort/filter ক্লায়েন্ট সাইডে করা হয়
/// যাতে আলাদা index বানাতে না হয়।
class QueryList extends StatefulWidget {
  const QueryList({
    super.key,
    required this.query,
    required this.builder,
    this.empty = 'কিছু পাওয়া যায়নি',
    this.sort,
    this.filter,
    this.buildWhenEmpty = false,
  });

  final Query<Json> query;
  final Widget Function(BuildContext context, List<Snap> docs) builder;
  final String empty;
  final int Function(Snap a, Snap b)? sort;
  final bool Function(Snap d)? filter;
  final bool buildWhenEmpty;

  @override
  State<QueryList> createState() => _QueryListState();
}

class _QueryListState extends State<QueryList> {
  late final Stream<QuerySnapshot<Json>> _stream = widget.query.snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Json>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text('ডেটা লোড করা যায়নি।\n${snap.error}',
                  textAlign: TextAlign.center),
            ),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        var docs = snap.data!.docs.toList();
        if (widget.filter != null) docs = docs.where(widget.filter!).toList();
        if (widget.sort != null) docs.sort(widget.sort!);
        if (docs.isEmpty && !widget.buildWhenEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(widget.empty,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
            ),
          );
        }
        return widget.builder(context, docs);
      },
    );
  }
}

// ------------------------------------------------------ extras (v2 features)

const String kAllLabel = 'সব এলাকা';

const List<IconData> kShortcutIcons = [
  Icons.movie,
  Icons.live_tv,
  Icons.folder_open,
  Icons.download,
  Icons.sports_esports,
  Icons.public,
  Icons.music_note,
  Icons.link,
];

int clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

/// পরবর্তী বিলের তারিখ। dueDay (১–২৮) না থাকলে null।
DateTime? nextDueDate(int dueDay, [DateTime? now]) {
  if (dueDay < 1) return null;
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  var d = DateTime(n.year, n.month, dueDay);
  if (d.isBefore(today)) d = DateTime(n.year, n.month + 1, dueDay);
  return d;
}

Future<void> launchLink(BuildContext c, String url) async {
  var u = url.trim();
  if (u.isEmpty) return;
  if (!u.contains('://')) u = 'http://$u';
  try {
    final ok = await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
    if (!ok && c.mounted) toast(c, 'লিংক খোলা যায়নি');
  } catch (_) {
    if (c.mounted) toast(c, 'লিংক খোলা যায়নি');
  }
}

Widget starRow(num n, {double size = 18}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(i <= n.round() ? Icons.star : Icons.star_border,
              size: size, color: Colors.amber.shade700),
      ],
    );
