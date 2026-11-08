// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:io' show InternetAddress, Socket;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'common.dart';
import 'user_screens.dart' show ComplaintForm;

Future<bool> hasInternet() async {
  try {
    final r = await InternetAddress.lookup('google.com')
        .timeout(const Duration(seconds: 4));
    return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

// ======================================================= network status

class NetStatusCard extends StatefulWidget {
  const NetStatusCard({super.key, required this.me});
  final AppUser me;

  @override
  State<NetStatusCard> createState() => _NetStatusCardState();
}

class _NetStatusCardState extends State<NetStatusCard> {
  bool? _online;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final r = await hasInternet();
    if (mounted && r != _online) setState(() => _online = r);
  }

  @override
  Widget build(BuildContext context) {
    final on = _online;
    final color = on == null
        ? Colors.grey
        : (on ? Colors.green.shade700 : Colors.red.shade700);
    final label = on == null
        ? 'সংযোগ যাচাই হচ্ছে...'
        : (on ? 'ইন্টারনেট চালু (Online)' : 'ইন্টারনেট বন্ধ (Offline)');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              Icon(on == false ? Icons.wifi_off : Icons.wifi, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              ),
              FilledButton.tonal(
                onPressed: () => showSheet<void>(context,
                    (c) => LineCheckSheet(me: widget.me, parent: context)),
                child: const Text('Check My Line'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LineCheckSheet extends StatefulWidget {
  const LineCheckSheet({super.key, required this.me, required this.parent});
  final AppUser me;
  final BuildContext parent;

  @override
  State<LineCheckSheet> createState() => _LineCheckSheetState();
}

class _LineCheckSheetState extends State<LineCheckSheet> {
  bool _running = true;
  bool _net = false;
  bool? _local;
  int _ms = 0;
  String _outage = '';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _local = null;
      _outage = '';
    });
    final net = await hasInternet();
    bool? local;
    var ms = 0;
    final s = Cfg.v;
    if (s.testHost.isNotEmpty) {
      final sw = Stopwatch()..start();
      try {
        final sock = await Socket.connect(s.testHost, s.testPort,
            timeout: const Duration(seconds: 4));
        ms = sw.elapsedMilliseconds;
        sock.destroy();
        local = true;
      } catch (_) {
        local = false;
      }
    }
    var outage = '';
    try {
      final q = await db
          .collection('outages')
          .where('active', isEqualTo: true)
          .get()
          .timeout(const Duration(seconds: 5));
      for (final d in q.docs) {
        final z = asStr(d.data()['zone'], 'all');
        if (z == 'all' || z == widget.me.zone) {
          outage = asStr(d.data()['message']);
          break;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _net = net;
      _local = local;
      _ms = ms;
      _outage = outage;
      _running = false;
    });
  }

  Widget _row(String label, bool ok,
      [String okText = 'ঠিক আছে', String badText = 'সমস্যা']) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(ok ? Icons.check_circle : Icons.cancel,
          color: ok ? Colors.green : Colors.red),
      title: Text(label),
      trailing: Text(
        ok ? okText : badText,
        style: TextStyle(
            color: ok ? Colors.green.shade700 : Colors.red.shade700,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_running) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('আপনার লাইন পরীক্ষা করা হচ্ছে...'),
          ],
        ),
      );
    }
    final slow = _local == true && _ms > 400;
    final problem = !_net || _local == false || slow;
    final outage = _outage.isNotEmpty;
    final steps = Cfg.v.troubleshootSteps;
    final support = Cfg.v.supportPhone;

    String verdict;
    Color color;
    IconData icon;
    if (outage) {
      verdict =
          'আপনার এলাকায় সার্ভিস সমস্যা চলছে। আমাদের টিম কাজ করছে, আলাদা কমপ্লেইন না করলেও চলবে।\n$_outage';
      color = Colors.red.shade700;
      icon = Icons.warning_amber_rounded;
    } else if (!_net) {
      verdict =
          'এই ফোনে ইন্টারনেট পাওয়া যাচ্ছে না। Wi-Fi এ যুক্ত থাকলে লাইন বা রাউটারে সমস্যা হতে পারে। নিচের ধাপগুলো চেষ্টা করুন।';
      color = Colors.orange.shade800;
      icon = Icons.wifi_off;
    } else if (_local == false) {
      verdict =
          'ইন্টারনেট আছে, কিন্তু Tech City সার্ভারে পৌঁছানো যাচ্ছে না। নিচের ধাপগুলো চেষ্টা করুন।';
      color = Colors.orange.shade800;
      icon = Icons.error_outline;
    } else if (slow) {
      verdict =
          'সংযোগ আছে, কিন্তু সার্ভারে সাড়া পেতে বেশি সময় লাগছে (${_ms}ms)। নিচের ধাপগুলো চেষ্টা করুন।';
      color = Colors.orange.shade800;
      icon = Icons.speed;
    } else {
      verdict = _local == true
          ? 'আপনার লাইন ঠিক আছে। (সার্ভার সাড়া: ${_ms}ms)'
          : 'আপনার ইন্টারনেট ঠিক আছে।';
      color = Colors.green.shade700;
      icon = Icons.check_circle;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Check My Line',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(verdict,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _row('ফোনের ইন্টারনেট', _net),
        if (_local != null)
          _row('Tech City সার্ভার', _local == true,
              _local == true ? '${_ms}ms' : 'ঠিক আছে', 'সাড়া নেই'),
        _row('আপনার এলাকায় আউটেজ', !outage, 'নেই', 'আছে'),
        if (problem && !outage) ...[
          const SizedBox(height: 8),
          const Text('সমাধানের ধাপ',
              style: TextStyle(fontWeight: FontWeight.bold)),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${i + 1}. ${steps[i]}'),
            ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _run,
                child: const Text('আবার টেস্ট'),
              ),
            ),
            if (problem && !outage) ...[
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final parent = widget.parent;
                    Navigator.pop(context);
                    showSheet<void>(
                        parent, (c) => ComplaintForm(me: widget.me));
                  },
                  child: const Text('কমপ্লেইন করুন'),
                ),
              ),
            ],
          ],
        ),
        if (problem && support.isNotEmpty)
          TextButton.icon(
            onPressed: () => callPhone(support),
            icon: const Icon(Icons.call),
            label: Text('সাপোর্টে কল করুন ($support)'),
          ),
      ],
    );
  }
}

// ============================================================== outage

class OutageBanners extends StatefulWidget {
  const OutageBanners({super.key, required this.zone});
  final String zone;

  @override
  State<OutageBanners> createState() => _OutageBannersState();
}

class _OutageBannersState extends State<OutageBanners> {
  late final Stream<QuerySnapshot<Json>> _s =
      db.collection('outages').where('active', isEqualTo: true).snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Json>>(
      stream: _s,
      builder: (context, snap) {
        final docs = (snap.data?.docs ?? <Snap>[]).where((d) {
          final z = asStr(d.data()['zone'], 'all');
          return z == 'all' || z == widget.zone;
        }).toList()
          ..sort(byNewest);
        if (docs.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            for (final d in docs)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        asStr(d.data()['message']),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ========================================================= bill reminder

class BillReminderCard extends StatelessWidget {
  const BillReminderCard({super.key, required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: Cfg.notifier,
      builder: (context, s, _) {
        final day = me.dueDay > 0 ? me.dueDay : s.billDueDay;
        final due = nextDueDate(day);
        if (due == null) return const SizedBox.shrink();
        final n = DateTime.now();
        final days = due.difference(DateTime(n.year, n.month, n.day)).inDays;
        if (days > 3 || me.paidMonth == monthKey(due)) {
          return const SizedBox.shrink();
        }
        final head =
            days == 0 ? 'আজ বিল পরিশোধের শেষ দিন' : 'বিল পরিশোধের আর $days দিন বাকি';
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.receipt_long, color: Colors.amber.shade900),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(head,
                        style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('শেষ তারিখ: ${due.day}/${due.month}/${due.year}',
                        style: const TextStyle(color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text(s.billMessage,
                        style: const TextStyle(color: Colors.black87)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =========================================================== shortcuts

class ShortcutsGrid extends StatefulWidget {
  const ShortcutsGrid({super.key});

  @override
  State<ShortcutsGrid> createState() => _ShortcutsGridState();
}

class _ShortcutsGridState extends State<ShortcutsGrid> {
  late final Stream<QuerySnapshot<Json>> _s =
      db.collection('shortcuts').where('active', isEqualTo: true).snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Json>>(
      stream: _s,
      builder: (context, snap) {
        final docs = (snap.data?.docs ?? <Snap>[]).toList()
          ..sort((a, b) {
            final c = asInt(a.data()['order']).compareTo(asInt(b.data()['order']));
            return c != 0
                ? c
                : asStr(a.data()['title']).compareTo(asStr(b.data()['title']));
          });
        if (docs.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: LayoutBuilder(
            builder: (context, box) {
              final w = (box.maxWidth - 16) / 3;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in docs)
                    SizedBox(
                      width: w,
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => launchLink(context, asStr(d.data()['url'])),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  kShortcutIcons[asInt(d.data()['iconIndex']).abs() %
                                      kShortcutIcons.length],
                                  size: 28,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  asStr(d.data()['title']),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ================================================================ NPS

class NpsCard extends StatefulWidget {
  const NpsCard({super.key, required this.me});
  final AppUser me;

  @override
  State<NpsCard> createState() => _NpsCardState();
}

class _NpsCardState extends State<NpsCard> {
  late final String _month = monthKey();
  late final Stream<DocumentSnapshot<Json>> _s =
      db.collection('nps').doc('${_month}_${widget.me.uid}').snapshots();
  final _note = TextEditingController();
  int? _score;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_score == null) return;
    setState(() => _busy = true);
    try {
      await db.collection('nps').doc('${_month}_${widget.me.uid}').set({
        'month': _month,
        'uid': widget.me.uid,
        'userName': widget.me.name,
        'phone': widget.me.phone,
        'score': _score,
        'comment': _note.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) toast(context, 'আপনার মতামতের জন্য ধন্যবাদ!');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, 'সমস্যা হয়েছে: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: Cfg.notifier,
      builder: (context, s, _) {
        if (!s.npsEnabled) return const SizedBox.shrink();
        return StreamBuilder<DocumentSnapshot<Json>>(
          stream: _s,
          builder: (context, snap) {
            if (!snap.hasData || snap.data!.exists) {
              return const SizedBox.shrink();
            }
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.npsQuestion,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('০ = মোটেই না, ১০ = অবশ্যই করব',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i <= 10; i++)
                          ChoiceChip(
                            label: Text('$i'),
                            selected: _score == i,
                            onSelected: (_) => setState(() => _score = i),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _note,
                      decoration: deco('মন্তব্য (ঐচ্ছিক)'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: (_score == null || _busy) ? null : _submit,
                      child: Text(_busy ? 'অপেক্ষা করুন...' : 'জমা দিন'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================== rating

class TicketRatingBox extends StatelessWidget {
  const TicketRatingBox({super.key, required this.d});
  final Snap d;

  @override
  Widget build(BuildContext context) {
    final m = d.data();
    if (asStr(m['status']) != 'Resolved') return const SizedBox.shrink();
    final r = m['rating'];
    if (r is num) {
      final fb = asStr(m['feedback']);
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('আপনার রেটিং: '),
                starRow(r),
              ],
            ),
            if (fb.isNotEmpty)
              Text(fb, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FilledButton.tonalIcon(
        onPressed: () => showSheet<void>(context, (c) => RatingForm(d: d)),
        icon: const Icon(Icons.star_outline),
        label: const Text('টেকনিশিয়ানকে রেটিং দিন'),
      ),
    );
  }
}

class RatingForm extends StatefulWidget {
  const RatingForm({super.key, required this.d});
  final Snap d;

  @override
  State<RatingForm> createState() => _RatingFormState();
}

class _RatingFormState extends State<RatingForm> {
  final _note = TextEditingController();
  int _stars = 0;
  String? _err;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_stars == 0) {
      setState(() => _err = 'স্টার বেছে নিন');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final nav = Navigator.of(context);
    final msg = ScaffoldMessenger.of(context);
    try {
      await widget.d.reference.update({
        'rating': _stars,
        'feedback': _note.text.trim(),
        'ratedAt': FieldValue.serverTimestamp(),
      });
      nav.pop();
      msg.showSnackBar(const SnackBar(content: Text('রেটিং দেওয়ার জন্য ধন্যবাদ!')));
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
      title: 'টেকনিশিয়ানকে রেটিং দিন',
      busy: _busy,
      err: _err,
      onSubmit: _go,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                iconSize: 36,
                icon: Icon(i <= _stars ? Icons.star : Icons.star_border,
                    color: Colors.amber.shade700),
                onPressed: () => setState(() => _stars = i),
              ),
          ],
        ),
        TextField(
          controller: _note,
          maxLines: 3,
          decoration: deco('টেকনিশিয়ান কি সময়মতো এসেছিল? মন্তব্য (ঐচ্ছিক)'),
        ),
      ],
    );
  }
}

// =========================================================== app update

class UpdateInfo {
  const UpdateInfo(this.build, this.message, this.url, this.force);
  final int build;
  final String message, url;
  final bool force;

  bool get outdated => build > kBuildNumber;

  factory UpdateInfo.from(Json? m) {
    final u = asStr(m?['url']).trim();
    return UpdateInfo(
      asInt(m?['latestBuild']),
      asStr(m?['message']),
      u.isEmpty ? kDefaultApkUrl : u,
      m?['force'] == true,
    );
  }
}

/// অ্যাডমিন "বাধ্যতামূলক আপডেট" দিলে পুরনো অ্যাপ ব্লক হয়ে যায়
class UpdateGuard extends StatefulWidget {
  const UpdateGuard({super.key, required this.child});
  final Widget child;

  @override
  State<UpdateGuard> createState() => _UpdateGuardState();
}

class _UpdateGuardState extends State<UpdateGuard> {
  late final Stream<DocumentSnapshot<Json>> _s =
      db.collection('settings').doc('app').snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Json>>(
      stream: _s,
      builder: (context, snap) {
        final info = UpdateInfo.from(snap.data?.data());
        if (info.outdated && info.force) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.system_update,
                          size: 72, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 16),
                      const Text('অ্যাপ আপডেট করতে হবে',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                          info.message.isEmpty
                              ? 'চালিয়ে যেতে নতুন ভার্সন ডাউনলোড করে ইনস্টল করুন।'
                              : info.message,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => launchLink(context, info.url),
                        icon: const Icon(Icons.download),
                        label: const Text('নতুন ভার্সন ডাউনলোড'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return widget.child;
      },
    );
  }
}

class UpdateCard extends StatefulWidget {
  const UpdateCard({super.key});

  @override
  State<UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<UpdateCard> {
  late final Stream<DocumentSnapshot<Json>> _s =
      db.collection('settings').doc('app').snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Json>>(
      stream: _s,
      builder: (context, snap) {
        final info = UpdateInfo.from(snap.data?.data());
        if (!info.outdated) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.system_update, color: Colors.blue.shade800),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('নতুন আপডেট এসেছে',
                        style: TextStyle(
                            color: Colors.black87, fontWeight: FontWeight.bold)),
                    if (info.message.isNotEmpty)
                      Text(info.message,
                          style: const TextStyle(color: Colors.black87)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => launchLink(context, info.url),
                child: const Text('আপডেট'),
              ),
            ],
          ),
        );
      },
    );
  }
}
