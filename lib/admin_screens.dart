// ignore_for_file: use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'common.dart';
import 'extras_admin.dart';

// =============================================================== home

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('অ্যাডমিন প্যানেল'),
        actions: [
          IconButton(
            tooltip: 'লগআউট',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              if (await confirmDialog(context, 'লগআউট', 'লগআউট করবেন?')) {
                fbAuth.signOut();
              }
            },
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.25,
        children: [
          const AdminTile(
              icon: Icons.campaign,
              label: 'ব্যানার / অফার',
              page: AdminBannersPage()),
          AdminTile(
              icon: Icons.group_add,
              label: 'রেফারেল কনফার্ম',
              page: const AdminReferralsPage(),
              countQuery:
                  db.collection('referrals').where('status', isEqualTo: 'pending')),
          AdminTile(
              icon: Icons.support_agent,
              label: 'কমপ্লেইন টিকেট',
              page: const AdminTicketsPage(),
              countQuery: db.collection('tickets').where('status',
                  whereIn: ['Processing', 'Technician Assigned'])),
          AdminTile(
              icon: Icons.swap_horiz,
              label: 'শিফট / প্যাকেজ আবেদন',
              page: const AdminRequestsPage(),
              countQuery:
                  db.collection('requests').where('status', isEqualTo: 'pending')),
          const AdminTile(
              icon: Icons.notifications_active,
              label: 'নোটিফিকেশন পাঠান',
              page: AdminNotifyPage()),
          const AdminTile(
              icon: Icons.emoji_events,
              label: 'লিডারবোর্ড ও গিফট',
              page: AdminLeaderboardPage()),
          AdminTile(
              icon: Icons.redeem,
              label: 'রিডিম রিকোয়েস্ট',
              page: const AdminRedeemsPage(),
              countQuery:
                  db.collection('redeems').where('status', isEqualTo: 'pending')),
          const AdminTile(
              icon: Icons.people, label: 'ইউজার লিস্ট', page: AdminUsersPage()),
          const AdminTile(
              icon: Icons.warning_amber,
              label: 'আউটেজ অ্যালার্ট',
              page: AdminOutagesPage()),
          const AdminTile(
              icon: Icons.apps,
              label: 'FTP / TV শর্টকাট',
              page: AdminShortcutsPage()),
          const AdminTile(
              icon: Icons.star_rate,
              label: 'টেকনিশিয়ান রেটিং',
              page: AdminRatingsPage()),
          const AdminTile(
              icon: Icons.poll, label: 'NPS সার্ভে', page: AdminNpsPage()),
          const AdminTile(
              icon: Icons.system_update,
              label: 'অ্যাপ আপডেট নোটিশ',
              page: AdminUpdatePage()),
          const AdminTile(
              icon: Icons.settings, label: 'সেটিংস', page: AdminSettingsPage()),
        ],
      ),
    );
  }
}

class AdminTile extends StatefulWidget {
  const AdminTile({
    super.key,
    required this.icon,
    required this.label,
    required this.page,
    this.countQuery,
  });
  final IconData icon;
  final String label;
  final Widget page;
  final Query<Json>? countQuery;

  @override
  State<AdminTile> createState() => _AdminTileState();
}

class _AdminTileState extends State<AdminTile> {
  late final Stream<int>? _count =
      widget.countQuery?.snapshots().map((s) => s.size);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
            context, MaterialPageRoute<void>(builder: (_) => widget.page)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<int>(
                stream: _count,
                builder: (context, s) => Badge(
                  isLabelVisible: (s.data ?? 0) > 0,
                  label: Text('${s.data ?? 0}'),
                  child: Icon(widget.icon,
                      size: 36, color: Theme.of(context).colorScheme.primary),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================ banners

class AdminBannersPage extends StatelessWidget {
  const AdminBannersPage({super.key});

  void _edit(BuildContext context, Snap? d) =>
      showSheet<void>(context, (c) => _BannerForm(d: d));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ব্যানার / অফার')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('নতুন ব্যানার'),
      ),
      body: QueryList(
        query: db.collection('banners'),
        sort: byNewest,
        empty: 'কোনো ব্যানার নেই।\nনিচের বাটন দিয়ে যোগ করুন।',
        builder: (context, docs) => ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [for (final d in docs) _tile(context, d)],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, Snap d) {
    final m = d.data();
    final color = kBannerColors[asInt(m['colorIndex']).abs() % kBannerColors.length];
    final exp = m['expiresAt'];
    final live = bannerLive(m);
    return Card(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(12)),
            child: Text(asStr(m['text']),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${live ? 'লাইভ' : 'বন্ধ / মেয়াদ শেষ'}  •  ${exp is Timestamp ? 'মেয়াদ: ${fmtDay(exp)}' : 'মেয়াদ নেই'}',
                    style: TextStyle(
                        fontSize: 12,
                        color: live ? Colors.green.shade700 : Colors.grey),
                  ),
                ),
                Switch(
                  value: m['active'] == true,
                  onChanged: (v) =>
                      guarded(context, () => d.reference.update({'active': v})),
                ),
                IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _edit(context, d)),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirmDialog(
                        context, 'ব্যানার মুছবেন?', 'এই ব্যানারটি মুছে যাবে।')) {
                      guarded(context, () => d.reference.delete());
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerForm extends StatefulWidget {
  const _BannerForm({this.d});
  final Snap? d;

  @override
  State<_BannerForm> createState() => _BannerFormState();
}

class _BannerFormState extends State<_BannerForm> {
  late final _text = TextEditingController(text: asStr(widget.d?.data()['text']));
  late int _color = asInt(widget.d?.data()['colorIndex']);
  late bool _active = widget.d == null ? true : widget.d!.data()['active'] == true;
  late DateTime? _exp = () {
    final e = widget.d?.data()['expiresAt'];
    return e is Timestamp ? e.toDate() : null;
  }();
  String? _err;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _exp ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (d != null) setState(() => _exp = d);
  }

  Future<void> _save() async {
    if (_text.text.trim().isEmpty) {
      setState(() => _err = 'ব্যানারের লেখা দিন');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final nav = Navigator.of(context);
    try {
      final data = <Object, Object?>{
        'text': _text.text.trim(),
        'colorIndex': _color,
        'active': _active,
        'expiresAt': _exp == null
            ? null
            : Timestamp.fromDate(DateTime(_exp!.year, _exp!.month, _exp!.day, 23, 59)),
      };
      if (widget.d == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await db.collection('banners').add(data.cast<String, dynamic>());
      } else {
        await widget.d!.reference.update(data);
      }
      nav.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = 'সমস্যা হয়েছে: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return formShell(
      title: widget.d == null ? 'নতুন ব্যানার' : 'ব্যানার এডিট',
      busy: _busy,
      err: _err,
      onSubmit: _save,
      label: 'সেভ করুন',
      children: [
        TextField(
          controller: _text,
          maxLines: 3,
          decoration: deco('ব্যানারে কী লেখা থাকবে?',
              hint: 'যেমন: ঈদ অফার! এই মাসে ২০ Mbps এ ১০০ টাকা ছাড়'),
        ),
        gap,
        Row(
          children: [
            for (var i = 0; i < kBannerColors.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _color = i),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: kBannerColors[i],
                    child: _color == i
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                ),
              ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('চালু (ইউজাররা দেখতে পাবে)'),
          value: _active,
          onChanged: (v) => setState(() => _active = v),
        ),
        Row(
          children: [
            Expanded(
              child: Text(_exp == null
                  ? 'মেয়াদ: নেই (নিজে বন্ধ না করা পর্যন্ত থাকবে)'
                  : 'মেয়াদ শেষ: ${_exp!.day}/${_exp!.month}/${_exp!.year}'),
            ),
            TextButton(onPressed: _pickDate, child: const Text('তারিখ বাছুন')),
            if (_exp != null)
              IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _exp = null)),
          ],
        ),
      ],
    );
  }
}

// ========================================================== referrals

class AdminReferralsPage extends StatefulWidget {
  const AdminReferralsPage({super.key});

  @override
  State<AdminReferralsPage> createState() => _AdminReferralsPageState();
}

class _AdminReferralsPageState extends State<AdminReferralsPage> {
  String _f = 'pending';

  Future<void> _confirm(BuildContext context, Snap d) async {
    final m = d.data();
    final pts = Cfg.v.referralPoints;
    final ok = await confirmDialog(
      context,
      'রেফারেল কনফার্ম',
      '${asStr(m['referrerName'])} কে $pts পয়েন্ট দেওয়া হবে।\n(নতুন গ্রাহক: ${asStr(m['referredName'])})\n\nনিশ্চিত করুন নতুন কানেকশন চালু হয়েছে ও প্রথম বিল পেমেন্ট হয়েছে।',
      ok: 'কনফার্ম',
    );
    if (!ok) return;
    final month = monthKey();
    await guarded(context, () async {
      await db.runTransaction((tx) async {
        final s = await tx.get(d.reference);
        final data = s.data();
        if (data == null || asStr(data['status']) != 'pending') return;
        final rUid = asStr(data['referrerUid']);
        tx.update(d.reference, {
          'status': 'confirmed',
          'month': month,
          'points': pts,
          'confirmedAt': FieldValue.serverTimestamp(),
        });
        tx.update(db.collection('users').doc(rUid),
            {'points': FieldValue.increment(pts)});
        tx.set(
          db.collection('leaderboard').doc('${month}_$rUid'),
          {
            'month': month,
            'uid': rUid,
            'name': asStr(data['referrerName']),
            'count': FieldValue.increment(1),
          },
          SetOptions(merge: true),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('রেফারেল কনফার্ম')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(value: 'pending', label: Text('অপেক্ষমাণ')),
                ButtonSegment<String>(value: 'confirmed', label: Text('কনফার্মড')),
                ButtonSegment<String>(value: 'rejected', label: Text('বাতিল')),
              ],
              selected: {_f},
              onSelectionChanged: (s) => setState(() => _f = s.first),
            ),
          ),
          Expanded(
            child: QueryList(
              query: db.collection('referrals'),
              sort: byNewest,
              filter: (d) => asStr(d.data()['status']) == _f,
              empty: 'কিছু নেই',
              builder: (context, docs) => ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i];
                  final m = d.data();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                    'নতুন গ্রাহক: ${asStr(m['referredName'])}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ),
                              StatusChip(asStr(m['status'])),
                            ],
                          ),
                          Text('ফোন: ${asStr(m['referredPhone'])}'),
                          Text('রেফার করেছেন: ${asStr(m['referrerName'])}'),
                          Text(fmtDate(m['createdAt']),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                          if (_f == 'pending')
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  IconButton(
                                      icon: const Icon(Icons.call),
                                      onPressed: () =>
                                          callPhone(asStr(m['referredPhone']))),
                                  const Spacer(),
                                  OutlinedButton(
                                    onPressed: () => guarded(
                                        context,
                                        () => d.reference
                                            .update({'status': 'rejected'})),
                                    child: const Text('বাতিল'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: () => _confirm(context, d),
                                    child: const Text('কনফার্ম'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================ tickets

class AdminTicketsPage extends StatefulWidget {
  const AdminTicketsPage({super.key});

  @override
  State<AdminTicketsPage> createState() => _AdminTicketsPageState();
}

class _AdminTicketsPageState extends State<AdminTicketsPage> {
  String _f = 'open';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('কমপ্লেইন টিকেট')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(value: 'open', label: Text('চলমান')),
                ButtonSegment<String>(value: 'done', label: Text('সমাধান')),
                ButtonSegment<String>(value: 'all', label: Text('সব')),
              ],
              selected: {_f},
              onSelectionChanged: (s) => setState(() => _f = s.first),
            ),
          ),
          Expanded(
            child: QueryList(
              query: db.collection('tickets'),
              sort: byNewest,
              filter: (d) {
                final st = asStr(d.data()['status']);
                if (_f == 'all') return true;
                return _f == 'done' ? st == 'Resolved' : st != 'Resolved';
              },
              empty: 'কোনো টিকেট নেই',
              builder: (context, docs) => ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: docs.length,
                itemBuilder: (context, i) => _AdminTicketCard(d: docs[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTicketCard extends StatelessWidget {
  const _AdminTicketCard({required this.d});
  final Snap d;

  Future<void> _assign(BuildContext context) async {
    final m = d.data();
    final r = await promptDialog(
      context,
      'টেকনিশিয়ান অ্যাসাইন',
      ['টেকনিশিয়ানের নাম', 'ফোন নম্বর'],
      initial: [asStr(m['technicianName']), asStr(m['technicianPhone'])],
      types: [TextInputType.name, TextInputType.phone],
    );
    if (r == null || r[0].isEmpty) return;
    await guarded(
      context,
      () => d.reference.update({
        'status': 'Technician Assigned',
        'technicianName': r[0],
        'technicianPhone': r[1],
        'assignedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = d.data();
    final status = asStr(m['status'], 'Processing');
    final phone = asStr(m['phone']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('#${asStr(m['ticketNo'])} — ${asStr(m['category'])}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                StatusChip(status),
              ],
            ),
            const SizedBox(height: 4),
            Text('${asStr(m['userName'])}  •  $phone'),
            Text('${asStr(m['address'])}  (${asStr(m['zone'])})'),
            if (asStr(m['note']).isNotEmpty)
              Text(asStr(m['note']), style: TextStyle(color: Colors.grey.shade700)),
            if (asStr(m['technicianName']).isNotEmpty)
              Text(
                  'টেকনিশিয়ান: ${asStr(m['technicianName'])} ${asStr(m['technicianPhone'])}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(fmtDate(m['createdAt']),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Wrap(
              spacing: 8,
              children: [
                IconButton(
                    icon: const Icon(Icons.call), onPressed: () => callPhone(phone)),
                if (status != 'Resolved')
                  OutlinedButton(
                    onPressed: () => _assign(context),
                    child: Text(status == 'Processing'
                        ? 'টেকনিশিয়ান দিন'
                        : 'টেকনিশিয়ান বদলান'),
                  ),
                if (status != 'Resolved')
                  FilledButton(
                    onPressed: () => guarded(
                      context,
                      () => d.reference.update({
                        'status': 'Resolved',
                        'resolvedAt': FieldValue.serverTimestamp(),
                      }),
                    ),
                    child: const Text('সমাধান হয়েছে'),
                  ),
                if (status == 'Resolved')
                  OutlinedButton(
                    onPressed: () => guarded(
                        context, () => d.reference.update({'status': 'Processing'})),
                    child: const Text('আবার খুলুন'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ========================================================== requests

class AdminRequestsPage extends StatefulWidget {
  const AdminRequestsPage({super.key});

  @override
  State<AdminRequestsPage> createState() => _AdminRequestsPageState();
}

class _AdminRequestsPageState extends State<AdminRequestsPage> {
  String _f = 'pending';

  Future<void> _approve(BuildContext context, Snap d) async {
    final m = d.data();
    final uid = asStr(m['uid']);
    if (m['type'] == 'shift') {
      final r = await promptDialog(
        context,
        'শিফট অনুমোদন',
        ['শিফট ফি (টাকা)', 'নোট (ঐচ্ছিক)'],
        initial: ['0', ''],
        types: [TextInputType.number, TextInputType.text],
        ok: 'অনুমোদন',
      );
      if (r == null) return;
      await guarded(context, () async {
        final b = db.batch();
        b.update(d.reference, {
          'status': 'approved',
          'fee': int.tryParse(r[0]) ?? 0,
          'adminNote': r[1],
          'decidedAt': FieldValue.serverTimestamp(),
        });
        b.update(db.collection('users').doc(uid),
            {'address': asStr(m['newAddress'])});
        await b.commit();
      });
    } else {
      final ok = await confirmDialog(
        context,
        'প্যাকেজ পরিবর্তন',
        '${asStr(m['userName'])} এর প্যাকেজ ${asStr(m['currentPackage'])} থেকে ${asStr(m['newPackage'])} করা হবে।',
        ok: 'অনুমোদন',
      );
      if (!ok) return;
      await guarded(context, () async {
        final b = db.batch();
        b.update(d.reference, {
          'status': 'approved',
          'decidedAt': FieldValue.serverTimestamp(),
        });
        b.update(db.collection('users').doc(uid),
            {'packageName': asStr(m['newPackage'])});
        await b.commit();
      });
    }
  }

  Future<void> _reject(BuildContext context, Snap d) async {
    final r = await promptDialog(context, 'আবেদন বাতিল', ['কারণ / নোট'], ok: 'বাতিল করুন');
    if (r == null) return;
    await guarded(
      context,
      () => d.reference.update({
        'status': 'rejected',
        'adminNote': r[0],
        'decidedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('শিফট / প্যাকেজ আবেদন')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(value: 'pending', label: Text('অপেক্ষমাণ')),
                ButtonSegment<String>(value: 'all', label: Text('সব')),
              ],
              selected: {_f},
              onSelectionChanged: (s) => setState(() => _f = s.first),
            ),
          ),
          Expanded(
            child: QueryList(
              query: db.collection('requests'),
              sort: byNewest,
              filter: (d) => _f == 'all' || asStr(d.data()['status']) == 'pending',
              empty: 'কোনো আবেদন নেই',
              builder: (context, docs) => ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i];
                  final m = d.data();
                  final isShift = m['type'] == 'shift';
                  final status = asStr(m['status'], 'pending');
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                    isShift ? 'লাইন শিফট' : 'প্যাকেজ পরিবর্তন',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ),
                              StatusChip(status),
                            ],
                          ),
                          Text('${asStr(m['userName'])}  •  ${asStr(m['phone'])}  (${asStr(m['zone'])})'),
                          if (isShift) ...[
                            Text('বর্তমান: ${asStr(m['currentAddress'])}'),
                            Text('নতুন: ${asStr(m['newAddress'])}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (asStr(m['mapLocation']).isNotEmpty)
                              Text('লোকেশন: ${asStr(m['mapLocation'])}'),
                            if (status == 'approved')
                              Text('ফি: $kTaka${asInt(m['fee'])}'),
                          ] else
                            Text(
                                '${asStr(m['currentPackage'])}  →  ${asStr(m['newPackage'])}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (asStr(m['adminNote']).isNotEmpty)
                            Text('নোট: ${asStr(m['adminNote'])}'),
                          Text(fmtDate(m['createdAt']),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                          if (status == 'pending')
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  IconButton(
                                      icon: const Icon(Icons.call),
                                      onPressed: () =>
                                          callPhone(asStr(m['phone']))),
                                  const Spacer(),
                                  OutlinedButton(
                                      onPressed: () => _reject(context, d),
                                      child: const Text('বাতিল')),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                      onPressed: () => _approve(context, d),
                                      child: const Text('অনুমোদন')),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ========================================================== notify

class AdminNotifyPage extends StatefulWidget {
  const AdminNotifyPage({super.key});

  @override
  State<AdminNotifyPage> createState() => _AdminNotifyPageState();
}

class _AdminNotifyPageState extends State<AdminNotifyPage> {
  static const _all = 'সব এলাকা';
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _target = _all;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _tpl(String t, String b) {
    _title.text = t;
    _body.text = b;
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      toast(context, 'টাইটেল ও মেসেজ দুটোই লিখুন');
      return;
    }
    setState(() => _busy = true);
    await guarded(context, () async {
      await db.collection('notifications').add({
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'target': _target == _all ? 'all' : _target,
        'pushed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      triggerPush();
      _title.clear();
      _body.clear();
      if (mounted) toast(context, 'নোটিফিকেশন পাঠানো হয়েছে');
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final targets = [_all, ...Cfg.v.zones];
    return Scaffold(
      appBar: AppBar(title: const Text('নোটিফিকেশন পাঠান')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('মেইনটেন্যান্স'),
                onPressed: () => _tpl('মেইনটেন্যান্স নোটিস',
                    'মেইনটেন্যান্সের কারণে ৩০ মিনিট সংযোগ বন্ধ থাকবে। অসুবিধার জন্য দুঃখিত।'),
              ),
              ActionChip(
                label: const Text('ফাইবার কাটা'),
                onPressed: () => _tpl('সংযোগে সমস্যা',
                    'ফাইবার লাইন কাটার কারণে আপনার এলাকায় ইন্টারনেট সমস্যা হচ্ছে। আমাদের টিম কাজ করছে।'),
              ),
              ActionChip(
                label: const Text('অফার'),
                onPressed: () =>
                    _tpl('নতুন অফার!', 'বিশেষ অফার চলছে। বিস্তারিত জানতে যোগাযোগ করুন।'),
              ),
            ],
          ),
          gap,
          TextField(controller: _title, decoration: deco('টাইটেল')),
          gap,
          TextField(controller: _body, maxLines: 3, decoration: deco('মেসেজ')),
          gap,
          pickField(
              label: 'কাদের কাছে যাবে',
              items: targets,
              value: _target,
              onChanged: (v) {
                if (v != null) _target = v;
              }),
          gap,
          FilledButton.icon(
            onPressed: _busy ? null : _send,
            icon: const Icon(Icons.send),
            label: Text(_busy ? 'পাঠানো হচ্ছে...' : 'পাঠান'),
          ),
          const SectionTitle('পাঠানো নোটিফিকেশন'),
          QueryList(
            query: db.collection('notifications'),
            sort: byNewest,
            empty: 'এখনো কিছু পাঠানো হয়নি',
            builder: (context, docs) => Column(
              children: [
                for (final d in docs.take(30))
                  Card(
                    child: ListTile(
                      title: Text(asStr(d.data()['title'])),
                      subtitle: Text(
                          '${asStr(d.data()['body'])}\n→ ${asStr(d.data()['target']) == 'all' ? _all : asStr(d.data()['target'])}  •  ${fmtDate(d.data()['createdAt'])}'),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (await confirmDialog(
                              context, 'মুছবেন?', 'এই নোটিফিকেশন মুছে যাবে।')) {
                            guarded(context, () => d.reference.delete());
                          }
                        },
                      ),
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

// ====================================================== leaderboard

class AdminLeaderboardPage extends StatefulWidget {
  const AdminLeaderboardPage({super.key});

  @override
  State<AdminLeaderboardPage> createState() => _AdminLeaderboardPageState();
}

class _AdminLeaderboardPageState extends State<AdminLeaderboardPage> {
  final _months = lastMonthKeys();
  late String _month = _months.first;
  final _gifts = List.generate(10, (_) => TextEditingController());
  bool _loading = true;
  bool _busy = false;
  bool _finalized = false;
  List<Map<String, dynamic>> _winners = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _gifts) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await db.collection('awards').doc(_month).get();
      final m = s.data() ?? <String, dynamic>{};
      final g = m['gifts'] is Map
          ? Map<String, dynamic>.from(m['gifts'] as Map)
          : <String, dynamic>{};
      for (var i = 0; i < 10; i++) {
        _gifts[i].text = asStr(g['${i + 1}']);
      }
      _finalized = m['status'] == 'finalized';
      _winners = m['winners'] is List
          ? (m['winners'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : <Map<String, dynamic>>[];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Map<String, dynamic> _giftMap() => {
        for (var i = 0; i < 10; i++) '${i + 1}': _gifts[i].text.trim(),
      };

  Future<void> _saveGifts() async {
    setState(() => _busy = true);
    await guarded(context, () async {
      await db.collection('awards').doc(_month).set({
        'month': _month,
        'gifts': _giftMap(),
        if (!_finalized) 'status': 'draft',
      }, SetOptions(merge: true));
      if (mounted) toast(context, 'গিফট লিস্ট সেভ হয়েছে');
    });
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _finalize() async {
    final ok = await confirmDialog(
      context,
      'Finalize & Award',
      '${monthLabel(_month)} মাসের Top 10 ফাইনাল হবে এবং বিজয়ীদের কাছে নোটিফিকেশন যাবে। এটা আর বদলানো যাবে না।',
      ok: 'ফাইনাল করুন',
    );
    if (!ok) return;
    setState(() => _busy = true);
    await guarded(context, () async {
      final lb = await db
          .collection('leaderboard')
          .where('month', isEqualTo: _month)
          .get();
      final rows = lb.docs.map((d) => d.data()).toList()
        ..sort((a, b) {
          final c = asInt(b['count']).compareTo(asInt(a['count']));
          return c != 0 ? c : asStr(a['name']).compareTo(asStr(b['name']));
        });
      final top = rows.take(10).toList();
      if (top.isEmpty) {
        if (mounted) toast(context, 'এই মাসে কোনো রেফারেল নেই');
        return;
      }
      final b = db.batch();
      final winners = <Map<String, dynamic>>[];
      for (var i = 0; i < top.length; i++) {
        final gift = _gifts[i].text.trim();
        final count = asInt(top[i]['count']);
        winners.add({
          'rank': i + 1,
          'uid': asStr(top[i]['uid']),
          'name': asStr(top[i]['name']),
          'count': count,
          'gift': gift,
        });
        b.set(db.collection('notifications').doc(), {
          'title': 'অভিনন্দন! আপনি ${i + 1} নম্বর স্থানে',
          'body':
              '${monthLabel(_month)} মাসে $count জনকে রেফার করে আপনি ${i + 1} নম্বর হয়েছেন।${gift.isEmpty ? '' : '\nআপনার গিফট: $gift'}',
          'target': 'uid:${asStr(top[i]['uid'])}',
          'pushed': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      b.set(db.collection('awards').doc(_month), {
        'month': _month,
        'gifts': _giftMap(),
        'status': 'finalized',
        'winners': winners,
        'finalizedAt': FieldValue.serverTimestamp(),
      });
      await b.commit();
      triggerPush();
      await _load();
      if (mounted) toast(context, 'ফাইনাল হয়েছে, বিজয়ীদের নোটিফিকেশন গেছে');
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('লিডারবোর্ড ও গিফট')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                pickField(
                  label: 'মাস',
                  items: _months,
                  value: _month,
                  onChanged: (v) {
                    if (v == null || v == _month) return;
                    setState(() {
                      _month = v;
                      _loading = true;
                    });
                    _load();
                  },
                ),
                gap,
                if (_finalized) ...[
                  Row(
                    children: [
                      const Expanded(
                        child: Text('এই মাসের ফলাফল ঘোষিত হয়েছে',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const StatusChip('done'),
                    ],
                  ),
                  for (final w in _winners)
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                          radius: 14, child: Text('${asInt(w['rank'])}')),
                      title: Text(asStr(w['name'])),
                      subtitle: Text(asStr(w['gift']).isEmpty
                          ? '(গিফট দেওয়া হয়নি)'
                          : '🎁 ${asStr(w['gift'])}'),
                      trailing: Text('${asInt(w['count'])} জন'),
                    ),
                ] else
                  QueryList(
                    key: ValueKey(_month),
                    query: db
                        .collection('leaderboard')
                        .where('month', isEqualTo: _month),
                    buildWhenEmpty: true,
                    builder: (context, docs) {
                      final rows = docs.map((d) => d.data()).toList()
                        ..sort((a, b) {
                          final c =
                              asInt(b['count']).compareTo(asInt(a['count']));
                          return c != 0
                              ? c
                              : asStr(a['name']).compareTo(asStr(b['name']));
                        });
                      return Column(
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                                'প্রতিটি র‍্যাঙ্কের পাশে গিফট লিখুন। ইউজাররা এগুলো লিডারবোর্ডে দেখতে পাবে।',
                                style: TextStyle(color: Colors.grey)),
                          ),
                          gap,
                          for (var i = 0; i < 10; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor:
                                        i < 3 ? Colors.amber : Colors.grey.shade300,
                                    child: Text('${i + 1}',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.black87)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          i < rows.length
                                              ? '${asStr(rows[i]['name'])} — ${asInt(rows[i]['count'])} জন'
                                              : 'এখনো কেউ নেই',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 4),
                                        TextField(
                                          controller: _gifts[i],
                                          decoration: deco('গিফট',
                                              hint: 'যেমন: ১ মাস ফ্রি স্পিড আপগ্রেড'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                if (!_finalized) ...[
                  gap,
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _saveGifts,
                    icon: const Icon(Icons.save),
                    label: const Text('গিফট লিস্ট সেভ'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _busy ? null : _finalize,
                    icon: const Icon(Icons.emoji_events),
                    label: const Text('Finalize & Award'),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
    );
  }
}

// =========================================================== redeems

class AdminRedeemsPage extends StatefulWidget {
  const AdminRedeemsPage({super.key});

  @override
  State<AdminRedeemsPage> createState() => _AdminRedeemsPageState();
}

class _AdminRedeemsPageState extends State<AdminRedeemsPage> {
  String _f = 'pending';

  Future<void> _refund(BuildContext context, Snap d) async {
    final ok = await confirmDialog(context, 'বাতিল করবেন?',
        'রিডিম বাতিল হবে এবং ইউজারের পয়েন্ট ফেরত যাবে।');
    if (!ok) return;
    await guarded(context, () async {
      await db.runTransaction((tx) async {
        final s = await tx.get(d.reference);
        final m = s.data();
        if (m == null || asStr(m['status']) != 'pending') return;
        tx.update(d.reference, {
          'status': 'rejected',
          'decidedAt': FieldValue.serverTimestamp(),
        });
        tx.update(db.collection('users').doc(asStr(m['uid'])),
            {'points': FieldValue.increment(asInt(m['points']))});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('রিডিম রিকোয়েস্ট')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(value: 'pending', label: Text('অপেক্ষমাণ')),
                ButtonSegment<String>(value: 'all', label: Text('সব')),
              ],
              selected: {_f},
              onSelectionChanged: (s) => setState(() => _f = s.first),
            ),
          ),
          Expanded(
            child: QueryList(
              query: db.collection('redeems'),
              sort: byNewest,
              filter: (d) => _f == 'all' || asStr(d.data()['status']) == 'pending',
              empty: 'কোনো রিকোয়েস্ট নেই',
              builder: (context, docs) => ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i];
                  final m = d.data();
                  final status = asStr(m['status'], 'pending');
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(asStr(m['userName']),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ),
                              StatusChip(status),
                            ],
                          ),
                          Text('${asStr(m['phone'])}'),
                          Text(
                              '${asInt(m['points'])} পয়েন্ট  →  $kTaka${asInt(m['taka'])} ছাড়',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          Text(fmtDate(m['createdAt']),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                          if (status == 'pending')
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  IconButton(
                                      icon: const Icon(Icons.call),
                                      onPressed: () =>
                                          callPhone(asStr(m['phone']))),
                                  const Spacer(),
                                  OutlinedButton(
                                      onPressed: () => _refund(context, d),
                                      child: const Text('বাতিল')),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: () => guarded(
                                      context,
                                      () => d.reference.update({
                                        'status': 'done',
                                        'decidedAt': FieldValue.serverTimestamp(),
                                      }),
                                    ),
                                    child: const Text('ছাড় দেওয়া হয়েছে'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================= users

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ইউজার লিস্ট')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: deco('নাম / ফোন / রেফারেল কোড দিয়ে খুঁজুন',
                  icon: Icons.search),
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: QueryList(
              query: db.collection('users'),
              sort: (a, b) =>
                  asStr(a.data()['name']).compareTo(asStr(b.data()['name'])),
              filter: (d) {
                if (_q.isEmpty) return true;
                final m = d.data();
                return [m['name'], m['phone'], m['referralCode'], m['email']]
                    .any((v) => asStr(v).toLowerCase().contains(_q));
              },
              empty: 'কোনো ইউজার পাওয়া যায়নি',
              builder: (context, docs) => ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i];
                  final m = d.data();
                  return ListTile(
                    title: Text(asStr(m['name'])),
                    subtitle: Text(
                        '${asStr(m['phone'])}  •  ${asStr(m['zone'])}  •  ${asStr(m['packageName'])}'),
                    trailing: Text('${asInt(m['points'])} pt',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () =>
                        showSheet<void>(context, (c) => _UserEditForm(d: d)),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserEditForm extends StatefulWidget {
  const _UserEditForm({required this.d});
  final Snap d;

  @override
  State<_UserEditForm> createState() => _UserEditFormState();
}

class _UserEditFormState extends State<_UserEditForm> {
  final _adj = TextEditingController();
  late final _due =
      TextEditingController(text: '${asInt(widget.d.data()['dueDay'])}');
  late bool _paid = asStr(widget.d.data()['paidMonth']) == monthKey();
  late String _zone = asStr(widget.d.data()['zone']);
  late String _pkg = asStr(widget.d.data()['packageName']);
  String? _err;
  bool _busy = false;

  @override
  void dispose() {
    _adj.dispose();
    _due.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final adj = int.tryParse(_adj.text.trim().replaceAll('+', '')) ?? 0;
    setState(() {
      _busy = true;
      _err = null;
    });
    final nav = Navigator.of(context);
    try {
      final data = <Object, Object?>{
        'zone': _zone,
        'packageName': _pkg,
        'dueDay': clampInt(int.tryParse(_due.text.trim()) ?? 0, 0, 28),
        'paidMonth': _paid ? monthKey() : '',
      };
      if (adj != 0) data['points'] = FieldValue.increment(adj);
      await widget.d.reference.update(data);
      nav.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = 'সমস্যা হয়েছে: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.d.data();
    final s = Cfg.v;
    return formShell(
      title: asStr(m['name']),
      busy: _busy,
      err: _err,
      onSubmit: _save,
      label: 'সেভ করুন',
      children: [
        infoRow(Icons.phone_outlined, 'মোবাইল', asStr(m['phone'])),
        infoRow(Icons.email_outlined, 'ইমেইল', asStr(m['email'])),
        infoRow(Icons.home_outlined, 'ঠিকানা', asStr(m['address'])),
        infoRow(Icons.card_giftcard, 'রেফারেল কোড', asStr(m['referralCode'])),
        infoRow(Icons.stars, 'বর্তমান পয়েন্ট', '${asInt(m['points'])}'),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => callPhone(asStr(m['phone'])),
            icon: const Icon(Icons.call),
            label: const Text('কল করুন'),
          ),
        ),
        gap,
        pickField(
            label: 'জোন',
            items: s.zones,
            value: _zone,
            onChanged: (v) {
              if (v != null) _zone = v;
            }),
        gap,
        pickField(
            label: 'প্যাকেজ',
            items: s.packages,
            value: _pkg,
            onChanged: (v) {
              if (v != null) _pkg = v;
            }),
        gap,
        TextField(
          controller: _adj,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: deco('পয়েন্ট যোগ / বিয়োগ',
              hint: 'যেমন: 50 অথবা -20 (খালি রাখলে বদলাবে না)'),
        ),
        gap,
        TextField(
          controller: _due,
          keyboardType: TextInputType.number,
          decoration: deco('এই ইউজারের বিলের তারিখ (১–২৮)',
              hint: '0 = সেটিংসের সাধারণ তারিখ'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('এই মাসের বিল পরিশোধিত'),
          subtitle: const Text('চালু থাকলে এই ইউজার বিল রিমাইন্ডার দেখবে না'),
          value: _paid,
          onChanged: (v) => setState(() => _paid = v),
        ),
      ],
    );
  }
}

// ========================================================== settings

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final _s = Cfg.v;
  late final _perTaka = TextEditingController(text: '${_s.pointsPerTaka}');
  late final _refPts = TextEditingController(text: '${_s.referralPoints}');
  late final _minRedeem = TextEditingController(text: '${_s.minRedeem}');
  late final _phone = TextEditingController(text: _s.supportPhone);
  late final _zones = TextEditingController(text: _s.zones.join('\n'));
  late final _pkgs = TextEditingController(text: _s.packages.join('\n'));
  late final _billDay = TextEditingController(text: '${_s.billDueDay}');
  late final _billMsg = TextEditingController(text: _s.billMessage);
  late final _testHost = TextEditingController(text: _s.testHost);
  late final _testPort = TextEditingController(text: '${_s.testPort}');
  late final _steps =
      TextEditingController(text: _s.troubleshootSteps.join('\n'));
  late final _npsQ = TextEditingController(text: _s.npsQuestion);
  late bool _npsOn = _s.npsEnabled;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _perTaka,
      _refPts,
      _minRedeem,
      _phone,
      _zones,
      _pkgs,
      _billDay,
      _billMsg,
      _testHost,
      _testPort,
      _steps,
      _npsQ
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _lines(TextEditingController c) => c.text
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _save() async {
    final perTaka = int.tryParse(_perTaka.text.trim()) ?? 10;
    final zones = _lines(_zones);
    final pkgs = _lines(_pkgs);
    if (perTaka < 1 || zones.isEmpty || pkgs.isEmpty) {
      toast(context,
          'পয়েন্ট রেট ১ বা তার বেশি দিন এবং জোন ও প্যাকেজ লিস্ট খালি রাখবেন না');
      return;
    }
    setState(() => _busy = true);
    await guarded(context, () async {
      await db.collection('settings').doc('main').set({
        'pointsPerTaka': perTaka,
        'referralPoints': int.tryParse(_refPts.text.trim()) ?? 50,
        'minRedeem': int.tryParse(_minRedeem.text.trim()) ?? 100,
        'supportPhone': _phone.text.trim(),
        'zones': zones,
        'packages': pkgs,
        'billDueDay': clampInt(int.tryParse(_billDay.text.trim()) ?? 0, 0, 28),
        'billMessage': _billMsg.text.trim(),
        'testHost': _testHost.text.trim(),
        'testPort': clampInt(int.tryParse(_testPort.text.trim()) ?? 80, 1, 65535),
        'troubleshootSteps': _lines(_steps),
        'npsEnabled': _npsOn,
        'npsQuestion': _npsQ.text.trim(),
      }, SetOptions(merge: true));
      if (mounted) toast(context, 'সেটিংস সেভ হয়েছে');
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('সেটিংস')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('পয়েন্ট ও রিওয়ার্ড'),
          TextField(
              controller: _perTaka,
              keyboardType: TextInputType.number,
              decoration: deco('কত পয়েন্টে ১ টাকা ছাড়?')),
          gap,
          TextField(
              controller: _refPts,
              keyboardType: TextInputType.number,
              decoration: deco('প্রতি সফল রেফারেলে কত পয়েন্ট?')),
          gap,
          TextField(
              controller: _minRedeem,
              keyboardType: TextInputType.number,
              decoration: deco('ন্যূনতম রিডিম পয়েন্ট')),
          gap,
          TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: deco('সাপোর্ট ফোন নম্বর')),
          const SectionTitle('বিল রিমাইন্ডার'),
          TextField(
              controller: _billDay,
              keyboardType: TextInputType.number,
              decoration: deco('প্রতি মাসের বিলের তারিখ (১–২৮)',
                  hint: '0 = রিমাইন্ডার বন্ধ')),
          gap,
          TextField(
              controller: _billMsg,
              maxLines: 2,
              decoration: deco('রিমাইন্ডারের মেসেজ')),
          const SectionTitle('Check My Line'),
          TextField(
              controller: _testHost,
              keyboardType: TextInputType.url,
              decoration: deco('টেস্ট সার্ভার (আপনার লোকাল সার্ভারের IP বা নাম)',
                  hint: 'খালি রাখলে শুধু ফোনের ইন্টারনেট টেস্ট হবে')),
          gap,
          TextField(
              controller: _testPort,
              keyboardType: TextInputType.number,
              decoration: deco('টেস্ট পোর্ট (সাধারণত 80)')),
          gap,
          TextField(
              controller: _steps,
              maxLines: 6,
              decoration:
                  deco('সমাধানের ধাপ (প্রতি লাইনে একটা)')),
          const SectionTitle('NPS সার্ভে'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('মাসে একবার NPS প্রশ্ন দেখাবে'),
            value: _npsOn,
            onChanged: (v) => setState(() => _npsOn = v),
          ),
          TextField(
              controller: _npsQ,
              maxLines: 2,
              decoration: deco('NPS প্রশ্ন')),
          const SectionTitle('জোন ও প্যাকেজ'),
          TextField(
              controller: _zones,
              maxLines: 5,
              decoration: deco('জোন / সাব-এরিয়া (প্রতি লাইনে একটা)')),
          gap,
          TextField(
              controller: _pkgs,
              maxLines: 5,
              decoration: deco('প্যাকেজ লিস্ট (প্রতি লাইনে একটা)')),
          const GithubTokenBox(),
          gap,
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'অপেক্ষা করুন...' : 'সেভ করুন'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
