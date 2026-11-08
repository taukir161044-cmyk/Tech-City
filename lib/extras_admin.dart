// ignore_for_file: use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'common.dart';

const String kOutageTemplate =
    'আপনার এলাকার অপটিক্যাল ফাইবার মেরামত হচ্ছে। আনুমানিক ১ ঘণ্টার মধ্যে লাইন ঠিক হবে।';

// ============================================================== outages

class AdminOutagesPage extends StatelessWidget {
  const AdminOutagesPage({super.key});

  void _edit(BuildContext context, Snap? d) =>
      showSheet<void>(context, (c) => _OutageForm(d: d));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('আউটেজ / মেইনটেন্যান্স অ্যালার্ট')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('নতুন অ্যালার্ট'),
      ),
      body: QueryList(
        query: db.collection('outages'),
        sort: byNewest,
        empty: 'কোনো অ্যালার্ট নেই।\nফাইবার কাটলে নিচের বাটন দিয়ে যোগ করুন।',
        builder: (context, docs) => ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [for (final d in docs) _tile(context, d)],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, Snap d) {
    final m = d.data();
    final zone = asStr(m['zone'], 'all');
    final active = m['active'] == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: active ? Colors.red.shade700 : Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(zone == 'all' ? kAllLabel : zone,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Text(active ? 'চলছে' : 'সমাধান',
                    style: TextStyle(
                        color: active ? Colors.red.shade700 : Colors.green.shade700,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 6),
            Text(asStr(m['message'])),
            Text(fmtDate(m['createdAt']),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Row(
              children: [
                Switch(
                  value: active,
                  onChanged: (v) =>
                      guarded(context, () => d.reference.update({'active': v})),
                ),
                const Text('ইউজারদের দেখাচ্ছে'),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _edit(context, d)),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirmDialog(
                        context, 'মুছবেন?', 'এই অ্যালার্ট মুছে যাবে।')) {
                      guarded(context, () => d.reference.delete());
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OutageForm extends StatefulWidget {
  const _OutageForm({this.d});
  final Snap? d;

  @override
  State<_OutageForm> createState() => _OutageFormState();
}

class _OutageFormState extends State<_OutageForm> {
  late final _msg = TextEditingController(
      text: widget.d == null ? kOutageTemplate : asStr(widget.d!.data()['message']));
  late String _zone = widget.d == null
      ? kAllLabel
      : (asStr(widget.d!.data()['zone'], 'all') == 'all'
          ? kAllLabel
          : asStr(widget.d!.data()['zone']));
  late bool _active = widget.d == null ? true : widget.d!.data()['active'] == true;
  bool _notify = true;
  String? _err;
  bool _busy = false;

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_msg.text.trim().isEmpty) {
      setState(() => _err = 'মেসেজ লিখুন');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final nav = Navigator.of(context);
    try {
      final target = _zone == kAllLabel ? 'all' : _zone;
      final data = <String, dynamic>{
        'zone': target,
        'message': _msg.text.trim(),
        'active': _active,
      };
      if (widget.d == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await db.collection('outages').add(data);
        if (_notify && _active) {
          await db.collection('notifications').add({
            'title': 'নেটওয়ার্ক সমস্যা',
            'body': _msg.text.trim(),
            'target': target,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
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
    final items = <String>[kAllLabel, ...Cfg.v.zones];
    if (!items.contains(_zone)) items.add(_zone);
    return formShell(
      title: widget.d == null ? 'নতুন আউটেজ অ্যালার্ট' : 'অ্যালার্ট এডিট',
      busy: _busy,
      err: _err,
      onSubmit: _save,
      label: 'সেভ করুন',
      children: [
        pickField(
            label: 'কোন এলাকায়',
            items: items,
            value: _zone,
            onChanged: (v) {
              if (v != null) _zone = v;
            }),
        gap,
        TextField(
          controller: _msg,
          maxLines: 3,
          decoration: deco('ইউজারদের হোম স্ক্রিনে কী লেখা দেখাবে?'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('চালু (ইউজাররা দেখতে পাবে)'),
          value: _active,
          onChanged: (v) => setState(() => _active = v),
        ),
        if (widget.d == null)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('নোটিফিকেশন ট্যাবেও পাঠান'),
            value: _notify,
            onChanged: (v) => setState(() => _notify = v ?? false),
          ),
      ],
    );
  }
}

// ============================================================ shortcuts

class AdminShortcutsPage extends StatelessWidget {
  const AdminShortcutsPage({super.key});

  void _edit(BuildContext context, Snap? d) =>
      showSheet<void>(context, (c) => _ShortcutForm(d: d));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FTP / TV শর্টকাট')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('নতুন শর্টকাট'),
      ),
      body: QueryList(
        query: db.collection('shortcuts'),
        sort: (a, b) {
          final c = asInt(a.data()['order']).compareTo(asInt(b.data()['order']));
          return c != 0
              ? c
              : asStr(a.data()['title']).compareTo(asStr(b.data()['title']));
        },
        empty: 'কোনো শর্টকাট নেই।\nFTP, Live TV, BDIX লিংক যোগ করুন।',
        builder: (context, docs) => ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            for (final d in docs)
              Card(
                child: ListTile(
                  leading: Icon(kShortcutIcons[
                      asInt(d.data()['iconIndex']).abs() % kShortcutIcons.length]),
                  title: Text(asStr(d.data()['title'])),
                  subtitle: Text(
                      '${asStr(d.data()['url'])}\nক্রম: ${asInt(d.data()['order'])}'),
                  isThreeLine: true,
                  onTap: () => _edit(context, d),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: d.data()['active'] == true,
                        onChanged: (v) => guarded(
                            context, () => d.reference.update({'active': v})),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (await confirmDialog(
                              context, 'মুছবেন?', 'এই শর্টকাট মুছে যাবে।')) {
                            guarded(context, () => d.reference.delete());
                          }
                        },
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

class _ShortcutForm extends StatefulWidget {
  const _ShortcutForm({this.d});
  final Snap? d;

  @override
  State<_ShortcutForm> createState() => _ShortcutFormState();
}

class _ShortcutFormState extends State<_ShortcutForm> {
  late final _title = TextEditingController(text: asStr(widget.d?.data()['title']));
  late final _url = TextEditingController(text: asStr(widget.d?.data()['url']));
  late final _order =
      TextEditingController(text: '${asInt(widget.d?.data()['order'])}');
  late int _icon = asInt(widget.d?.data()['iconIndex']).abs() % kShortcutIcons.length;
  late bool _active = widget.d == null ? true : widget.d!.data()['active'] == true;
  String? _err;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _url.text.trim().isEmpty) {
      setState(() => _err = 'নাম ও লিংক দুটোই দিন');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final nav = Navigator.of(context);
    try {
      final data = <String, dynamic>{
        'title': _title.text.trim(),
        'url': _url.text.trim(),
        'order': int.tryParse(_order.text.trim()) ?? 0,
        'iconIndex': _icon,
        'active': _active,
      };
      if (widget.d == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await db.collection('shortcuts').add(data);
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
      title: widget.d == null ? 'নতুন শর্টকাট' : 'শর্টকাট এডিট',
      busy: _busy,
      err: _err,
      onSubmit: _save,
      label: 'সেভ করুন',
      children: [
        TextField(
            controller: _title,
            decoration: deco('বাটনের নাম', hint: 'যেমন: Movie FTP, Live TV')),
        gap,
        TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: deco('লিংক', hint: 'http://172.16.0.5 বা ftp://...')),
        gap,
        TextField(
            controller: _order,
            keyboardType: TextInputType.number,
            decoration: deco('ক্রম (ছোট সংখ্যা আগে দেখাবে)')),
        gap,
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < kShortcutIcons.length; i++)
              GestureDetector(
                onTap: () => setState(() => _icon = i),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: _icon == i
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade300,
                  child: Icon(kShortcutIcons[i],
                      color: _icon == i ? Colors.white : Colors.black87),
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
      ],
    );
  }
}

// ============================================================== ratings

double _avg(List<int> l) => l.reduce((a, b) => a + b) / l.length;

class AdminRatingsPage extends StatelessWidget {
  const AdminRatingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('টেকনিশিয়ান রেটিং')),
      body: QueryList(
        query: db.collection('tickets'),
        sort: byNewest,
        filter: (d) => d.data()['rating'] is num,
        empty: 'এখনো কোনো রেটিং আসেনি',
        builder: (context, docs) {
          final per = <String, List<int>>{};
          var sum = 0;
          for (final d in docs) {
            final r = asInt(d.data()['rating']);
            sum += r;
            final t = asStr(d.data()['technicianName']).trim();
            per.putIfAbsent(t.isEmpty ? 'অজানা' : t, () => <int>[]).add(r);
          }
          final overall = sum / docs.length;
          final techs = per.entries.toList()
            ..sort((a, b) => _avg(b.value).compareTo(_avg(a.value)));
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(overall.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 40, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          starRow(overall, size: 22),
                          Text('মোট ${docs.length} টি রেটিং'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SectionTitle('টেকনিশিয়ান অনুযায়ী'),
              for (final e in techs)
                Card(
                  child: ListTile(
                    title: Text(e.key),
                    subtitle: Text('${e.value.length} টি রেটিং'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_avg(e.value).toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        starRow(_avg(e.value), size: 14),
                      ],
                    ),
                  ),
                ),
              const SectionTitle('সাম্প্রতিক ফিডব্যাক'),
              for (final d in docs.take(30))
                Card(
                  child: ListTile(
                    title: Text(
                        '${asStr(d.data()['userName'])}  •  #${asStr(d.data()['ticketNo'])}'),
                    subtitle: Text(
                        '${asStr(d.data()['feedback']).isEmpty ? '(মন্তব্য নেই)' : asStr(d.data()['feedback'])}\nটেকনিশিয়ান: ${asStr(d.data()['technicianName'], '—')}'),
                    isThreeLine: true,
                    trailing: starRow(asInt(d.data()['rating']), size: 16),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ================================================================ NPS

Widget _stat(String label, int n, Color c) => Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text('$n',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: c)),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );

class AdminNpsPage extends StatefulWidget {
  const AdminNpsPage({super.key});

  @override
  State<AdminNpsPage> createState() => _AdminNpsPageState();
}

class _AdminNpsPageState extends State<AdminNpsPage> {
  final _months = lastMonthKeys();
  late String _month = _months.first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NPS সার্ভে')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: pickField(
              label: 'মাস',
              items: _months,
              value: _month,
              onChanged: (v) {
                if (v != null && v != _month) setState(() => _month = v);
              },
            ),
          ),
          Expanded(
            child: QueryList(
              key: ValueKey(_month),
              query: db.collection('nps').where('month', isEqualTo: _month),
              sort: byNewest,
              empty: 'এই মাসে কেউ উত্তর দেয়নি',
              builder: (context, docs) {
                final scores = docs.map((d) => asInt(d.data()['score'])).toList();
                final total = scores.length;
                final promoters = scores.where((s) => s >= 9).length;
                final detractors = scores.where((s) => s <= 6).length;
                final passives = total - promoters - detractors;
                final nps = ((promoters - detractors) * 100 / total).round();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Text('$nps',
                                style: const TextStyle(
                                    fontSize: 44, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                  'NPS স্কোর\nমোট $total জন উত্তর দিয়েছে\n(−১০০ থেকে +১০০ এর মধ্যে)'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _stat('Promoter\n৯–১০', promoters, Colors.green.shade700),
                        _stat('Passive\n৭–৮', passives, Colors.orange.shade800),
                        _stat('Detractor\n০–৬', detractors, Colors.red.shade700),
                      ],
                    ),
                    const SectionTitle('মতামত'),
                    for (final d in docs)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(
                              child: Text('${asInt(d.data()['score'])}')),
                          title: Text(asStr(d.data()['userName'])),
                          subtitle: Text(asStr(d.data()['comment']).isEmpty
                              ? '(মন্তব্য নেই)'
                              : asStr(d.data()['comment'])),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================ app update

class AdminUpdatePage extends StatefulWidget {
  const AdminUpdatePage({super.key});

  @override
  State<AdminUpdatePage> createState() => _AdminUpdatePageState();
}

class _AdminUpdatePageState extends State<AdminUpdatePage> {
  final _build = TextEditingController();
  final _msg = TextEditingController();
  final _url = TextEditingController(text: kDefaultApkUrl);
  bool _force = false;
  bool _notify = true;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _build.dispose();
    _msg.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await db.collection('settings').doc('app').get();
      final m = s.data();
      if (m != null) {
        _build.text = '${asInt(m['latestBuild'])}';
        _msg.text = asStr(m['message']);
        final u = asStr(m['url']).trim();
        if (u.isNotEmpty) _url.text = u;
        _force = m['force'] == true;
      }
    } catch (_) {}
    if (_build.text.isEmpty || _build.text == '0') {
      _build.text = kBuildNumber > 0 ? '$kBuildNumber' : '';
    }
    if (_msg.text.isEmpty) {
      _msg.text = 'অ্যাপের নতুন ভার্সন এসেছে। আপডেট করে নিন।';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _publish() async {
    final b = int.tryParse(_build.text.trim()) ?? 0;
    if (b < 1) {
      toast(context, 'বিল্ড নম্বর দিন');
      return;
    }
    setState(() => _busy = true);
    await guarded(context, () async {
      await db.collection('settings').doc('app').set({
        'latestBuild': b,
        'message': _msg.text.trim(),
        'url': _url.text.trim(),
        'force': _force,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (_notify) {
        await db.collection('notifications').add({
          'title': 'নতুন অ্যাপ আপডেট',
          'body': _msg.text.trim(),
          'target': 'all',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (mounted) toast(context, 'আপডেট নোটিশ পাবলিশ হয়েছে');
    });
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    await guarded(context, () async {
      await db.collection('settings').doc('app').set({
        'latestBuild': 0,
        'force': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _force = false;
      _build.text = '0';
      if (mounted) toast(context, 'আপডেট নোটিশ বন্ধ করা হয়েছে');
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('অ্যাপ আপডেট নোটিশ')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                        'এই ফোনের অ্যাপের বিল্ড নম্বর: ${kBuildNumber == 0 ? 'অজানা' : kBuildNumber}\n\n'
                        'নিয়ম: GitHub এ নতুন বিল্ড শেষ হলে সেই APK নিজের ফোনে ইনস্টল করুন, তারপর এই পেজ খুলুন। বিল্ড নম্বর নিজে থেকে বসে যাবে, শুধু পাবলিশ চাপুন। '
                        'যাদের অ্যাপের বিল্ড নম্বর এর চেয়ে ছোট, তারা আপডেট কার্ড দেখবে।'),
                  ),
                ),
                gap,
                TextField(
                  controller: _build,
                  keyboardType: TextInputType.number,
                  decoration: deco('সর্বশেষ বিল্ড নম্বর'),
                ),
                gap,
                TextField(
                  controller: _msg,
                  maxLines: 3,
                  decoration: deco('ইউজারদের মেসেজ (কী নতুন হলো)'),
                ),
                gap,
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  decoration: deco('APK ডাউনলোড লিংক'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('বাধ্যতামূলক আপডেট'),
                  subtitle: const Text('চালু করলে পুরনো অ্যাপ আপডেট ছাড়া চলবে না'),
                  value: _force,
                  onChanged: (v) => setState(() => _force = v),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('নোটিফিকেশন ট্যাবেও পাঠান'),
                  value: _notify,
                  onChanged: (v) => setState(() => _notify = v ?? false),
                ),
                gap,
                FilledButton.icon(
                  onPressed: _busy ? null : _publish,
                  icon: const Icon(Icons.system_update),
                  label: const Text('আপডেট নোটিশ পাবলিশ করুন'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy ? null : _clear,
                  child: const Text('নোটিশ বন্ধ করুন'),
                ),
              ],
            ),
    );
  }
}
