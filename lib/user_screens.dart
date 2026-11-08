// ignore_for_file: use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'common.dart';
import 'extras_user.dart';

// ======================================================== root & shell

class UserRoot extends StatefulWidget {
  const UserRoot({super.key, required this.user});
  final User user;

  @override
  State<UserRoot> createState() => _UserRootState();
}

class _UserRootState extends State<UserRoot> {
  late final Stream<DocumentSnapshot<Json>> _s =
      db.collection('users').doc(widget.user.uid).snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Json>>(
      stream: _s,
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('অ্যাকাউন্ট প্রস্তুত হচ্ছে...'),
                  TextButton(
                    onPressed: () => fbAuth.signOut(),
                    child: const Text('লগআউট'),
                  ),
                ],
              ),
            ),
          );
        }
        return UserShell(me: AppUser.fromDoc(snap.data!));
      },
    );
  }
}

class UserShell extends StatefulWidget {
  const UserShell({super.key, required this.me});
  final AppUser me;

  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  int _tab = 0;
  late Stream<QuerySnapshot<Json>> _notifs =
      notifQuery(widget.me.uid, widget.me.zone).snapshots();

  @override
  void didUpdateWidget(covariant UserShell old) {
    super.didUpdateWidget(old);
    if (old.me.zone != widget.me.zone) {
      _notifs = notifQuery(widget.me.uid, widget.me.zone).snapshots();
    }
  }

  void _markSeen() {
    db
        .collection('users')
        .doc(widget.me.uid)
        .update({'notifSeenAt': FieldValue.serverTimestamp()}).catchError((_) {});
  }

  void _go(int i) {
    final prev = _tab;
    setState(() => _tab = i);
    if (prev == 3 || i == 3) _markSeen();
  }

  int _unread(QuerySnapshot<Json>? q) {
    if (q == null || _tab == 3) return 0;
    final seen = widget.me.notifSeenAt;
    return q.docs.where((d) {
      final t = d.data()['createdAt'];
      if (t is! Timestamp) return true;
      return seen == null || t.compareTo(seen) > 0;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: [
            HomeTab(me: me, goTab: _go),
            RewardsTab(me: me),
            ServiceTab(me: me),
            AlertsTab(me: me),
            ProfileTab(me: me),
          ],
        ),
      ),
      bottomNavigationBar: StreamBuilder<QuerySnapshot<Json>>(
        stream: _notifs,
        builder: (context, s) {
          final n = _unread(s.data);
          return NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: _go,
            destinations: [
              const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'হোম'),
              const NavigationDestination(
                  icon: Icon(Icons.emoji_events_outlined),
                  selectedIcon: Icon(Icons.emoji_events),
                  label: 'রিওয়ার্ড'),
              const NavigationDestination(
                  icon: Icon(Icons.support_agent_outlined),
                  selectedIcon: Icon(Icons.support_agent),
                  label: 'সার্ভিস'),
              NavigationDestination(
                  icon: Badge(
                      isLabelVisible: n > 0,
                      label: Text('$n'),
                      child: const Icon(Icons.notifications_outlined)),
                  selectedIcon: const Icon(Icons.notifications),
                  label: 'নোটিফিকেশন'),
              const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'প্রোফাইল'),
            ],
          );
        },
      ),
    );
  }
}

// ================================================================ home

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.me, required this.goTab});
  final AppUser me;
  final void Function(int) goTab;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('স্বাগতম, ${me.name}',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('${me.packageName}  •  ${me.zone}',
            style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 12),
        NetStatusCard(me: me),
        OutageBanners(zone: me.zone),
        BillReminderCard(me: me),
        const BannerCarousel(),
        const SizedBox(height: 16),
        const ShortcutsGrid(),
        WalletCard(me: me),
        const SizedBox(height: 16),
        ReferralCard(me: me),
        const SizedBox(height: 16),
        Row(
          children: [
            _QuickAction(
                icon: Icons.support_agent,
                label: 'কমপ্লেইন',
                onTap: () => goTab(2)),
            const SizedBox(width: 8),
            _QuickAction(
                icon: Icons.swap_horiz,
                label: 'শিফট / প্যাকেজ',
                onTap: () => goTab(2)),
            const SizedBox(width: 8),
            _QuickAction(
                icon: Icons.emoji_events,
                label: 'Top 10',
                onTap: () => goTab(1)),
          ],
        ),
        const SizedBox(height: 16),
        NpsCard(me: me),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _ctrl = PageController(viewportFraction: 0.92);
  late final Stream<QuerySnapshot<Json>> _s =
      db.collection('banners').snapshots();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Json>>(
      stream: _s,
      builder: (context, snap) {
        final docs = (snap.data?.docs ?? <Snap>[])
            .where((d) => bannerLive(d.data()))
            .toList()
          ..sort(byNewest);
        if (docs.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 120,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final m = docs[i].data();
              final color =
                  kBannerColors[asInt(m['colorIndex']).abs() % kBannerColors.length];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(16)),
                child: Text(
                  asStr(m['text']),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class WalletCard extends StatelessWidget {
  const WalletCard({super.key, required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: Cfg.notifier,
      builder: (context, s, _) {
        final taka = me.points ~/ s.pointsPerTaka;
        return Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined),
                    SizedBox(width: 8),
                    Text('ডিজিটাল ওয়ালেট',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${me.points} পয়েন্ট',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(
                    '≈ $taka টাকা বিল ছাড় (${s.pointsPerTaka} পয়েন্ট = ১ টাকা)'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => showSheet<void>(
                      context, (ctx) => RedeemForm(me: me)),
                  icon: const Icon(Icons.redeem),
                  label: const Text('রিডিম করুন'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ReferralCard extends StatelessWidget {
  const ReferralCard({super.key, required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('আপনার রেফারেল কোড',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    me.referralCode,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4),
                  ),
                ),
                IconButton(
                  tooltip: 'কোড কপি',
                  icon: const Icon(Icons.copy),
                  onPressed: () => copyText(context, me.referralCode),
                ),
                IconButton(
                  tooltip: 'মেসেজ কপি',
                  icon: const Icon(Icons.share),
                  onPressed: () => copyText(
                    context,
                    '$kAppName ইন্টারনেট কানেকশন নিন! সাইন আপের সময় আমার রেফারেল কোড ব্যবহার করুন: ${me.referralCode}',
                    'শেয়ার করার মেসেজ কপি হয়েছে',
                  ),
                ),
              ],
            ),
            ValueListenableBuilder<AppSettings>(
              valueListenable: Cfg.notifier,
              builder: (context, s, _) => Text(
                'বন্ধু বা পরিচিত কেউ নতুন কানেকশন নিয়ে প্রথম বিল দিলে আপনি ${s.referralPoints} পয়েন্ট পাবেন।',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RedeemForm extends StatefulWidget {
  const RedeemForm({super.key, required this.me});
  final AppUser me;

  @override
  State<RedeemForm> createState() => _RedeemFormState();
}

class _RedeemFormState extends State<RedeemForm> {
  final _pts = TextEditingController();
  String? _err;
  bool _busy = false;

  @override
  void dispose() {
    _pts.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final s = Cfg.v;
    final p = int.tryParse(_pts.text.trim()) ?? 0;
    final taka = p ~/ s.pointsPerTaka;
    final used = taka * s.pointsPerTaka;
    if (p < s.minRedeem || taka < 1) {
      setState(() => _err = 'ন্যূনতম ${s.minRedeem} পয়েন্ট রিডিম করা যাবে');
      return;
    }
    if (p > widget.me.points) {
      setState(() => _err = 'আপনার পয়েন্ট যথেষ্ট নয়');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final nav = Navigator.of(context);
    final msg = ScaffoldMessenger.of(context);
    try {
      final b = db.batch();
      b.update(db.collection('users').doc(widget.me.uid),
          {'points': FieldValue.increment(-used)});
      b.set(db.collection('redeems').doc(), {
        'uid': widget.me.uid,
        'userName': widget.me.name,
        'phone': widget.me.phone,
        'points': used,
        'taka': taka,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await b.commit();
      nav.pop();
      msg.showSnackBar(SnackBar(
          content: Text(
              '$used পয়েন্ট ($taka টাকা ছাড়) রিডিমের আবেদন জমা হয়েছে। পরবর্তী বিলে ছাড় পাবেন।')));
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
    final s = Cfg.v;
    return formShell(
      title: 'পয়েন্ট রিডিম',
      busy: _busy,
      err: _err,
      onSubmit: _go,
      label: 'রিডিম করুন',
      children: [
        Text(
            'আপনার পয়েন্ট: ${widget.me.points}\n${s.pointsPerTaka} পয়েন্ট = ১ টাকা ছাড় • ন্যূনতম ${s.minRedeem} পয়েন্ট'),
        gap,
        TextField(
          controller: _pts,
          keyboardType: TextInputType.number,
          decoration: deco('কত পয়েন্ট রিডিম করবেন?'),
        ),
      ],
    );
  }
}

// ============================================================== rewards

class RewardsTab extends StatelessWidget {
  const RewardsTab({super.key, required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        WalletCard(me: me),
        const SizedBox(height: 8),
        LeaderboardCard(me: me),
        const LastWinnersCard(),
        const SectionTitle('আমার রেফারেল'),
        QueryList(
          query: db.collection('referrals').where('referrerUid', isEqualTo: me.uid),
          sort: byNewest,
          empty: 'এখনো কেউ আপনার কোড ব্যবহার করেনি',
          builder: (c, docs) => Column(
            children: [
              for (final d in docs)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.person_add_alt),
                  title: Text(asStr(d.data()['referredName'])),
                  subtitle: Text(d.data()['status'] == 'confirmed'
                      ? '+${asInt(d.data()['points'])} পয়েন্ট পেয়েছেন'
                      : fmtDate(d.data()['createdAt'])),
                  trailing: StatusChip(asStr(d.data()['status'])),
                ),
            ],
          ),
        ),
        const SectionTitle('রিডিম হিস্টরি'),
        QueryList(
          query: db.collection('redeems').where('uid', isEqualTo: me.uid),
          sort: byNewest,
          empty: 'এখনো কোনো রিডিম করেননি',
          builder: (c, docs) => Column(
            children: [
              for (final d in docs.take(10))
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.redeem),
                  title: Text(
                      '${asInt(d.data()['points'])} পয়েন্ট → $kTaka${asInt(d.data()['taka'])} ছাড়'),
                  subtitle: Text(fmtDate(d.data()['createdAt'])),
                  trailing: StatusChip(asStr(d.data()['status'])),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class LeaderboardCard extends StatefulWidget {
  const LeaderboardCard({super.key, required this.me});
  final AppUser me;

  @override
  State<LeaderboardCard> createState() => _LeaderboardCardState();
}

class _LeaderboardCardState extends State<LeaderboardCard> {
  final String _month = monthKey();
  late final Stream<QuerySnapshot<Json>> _lb =
      db.collection('leaderboard').where('month', isEqualTo: _month).snapshots();
  late final Stream<DocumentSnapshot<Json>> _aw =
      db.collection('awards').doc(_month).snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Json>>(
      stream: _aw,
      builder: (context, awSnap) {
        final aw = awSnap.data?.data() ?? <String, dynamic>{};
        final gifts = aw['gifts'] is Map
            ? Map<String, dynamic>.from(aw['gifts'] as Map)
            : <String, dynamic>{};
        final finalized = aw['status'] == 'finalized';
        return StreamBuilder<QuerySnapshot<Json>>(
          stream: _lb,
          builder: (context, lbSnap) {
            final rows = (lbSnap.data?.docs ?? <Snap>[])
                .map((d) => d.data())
                .toList()
              ..sort((a, b) {
                final c = asInt(b['count']).compareTo(asInt(a['count']));
                return c != 0 ? c : asStr(a['name']).compareTo(asStr(b['name']));
              });
            final myIdx = rows.indexWhere((r) => r['uid'] == widget.me.uid);
            return Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Top 10 — ${monthLabel(_month)}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          if (finalized) const StatusChip('done'),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(
                        myIdx >= 0
                            ? 'আপনার অবস্থান: ${myIdx + 1} নম্বর • ${asInt(rows[myIdx]['count'])} জন রেফার'
                            : 'এই মাসে আপনি এখনো কাউকে রেফার করেননি',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ),
                    for (var i = 0; i < 10; i++) _row(i, rows, gifts),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _row(int i, List<Map<String, dynamic>> rows, Map<String, dynamic> gifts) {
    final r = i < rows.length ? rows[i] : null;
    final gift = asStr(gifts['${i + 1}']);
    final mine = r != null && r['uid'] == widget.me.uid;
    return ListTile(
      dense: true,
      tileColor: mine ? Colors.amber.shade50 : null,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: i < 3 ? Colors.amber : Colors.grey.shade300,
        child: Text('${i + 1}',
            style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ),
      title: Text(r == null ? '—' : asStr(r['name'])),
      subtitle: gift.isEmpty ? null : Text('🎁 $gift'),
      trailing: r == null
          ? null
          : Text('${asInt(r['count'])} জন',
              style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class LastWinnersCard extends StatefulWidget {
  const LastWinnersCard({super.key});

  @override
  State<LastWinnersCard> createState() => _LastWinnersCardState();
}

class _LastWinnersCardState extends State<LastWinnersCard> {
  final String _month = prevMonthKey();
  late final Stream<DocumentSnapshot<Json>> _aw =
      db.collection('awards').doc(_month).snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Json>>(
      stream: _aw,
      builder: (context, snap) {
        final m = snap.data?.data();
        if (m == null || m['status'] != 'finalized' || m['winners'] is! List) {
          return const SizedBox.shrink();
        }
        final winners = (m['winners'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('গত মাসের বিজয়ী — ${monthLabel(_month)}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                for (final w in winners)
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                        radius: 14, child: Text('${asInt(w['rank'])}')),
                    title: Text(asStr(w['name'])),
                    subtitle: asStr(w['gift']).isEmpty
                        ? null
                        : Text('🎁 ${asStr(w['gift'])}'),
                    trailing: Text('${asInt(w['count'])} জন'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================== service

class ServiceTab extends StatelessWidget {
  const ServiceTab({super.key, required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                _QuickAction(
                    icon: Icons.report_problem_outlined,
                    label: 'নতুন কমপ্লেইন',
                    onTap: () => showSheet<void>(
                        context, (c) => ComplaintForm(me: me))),
                const SizedBox(width: 8),
                _QuickAction(
                    icon: Icons.local_shipping_outlined,
                    label: 'লাইন শিফট',
                    onTap: () =>
                        showSheet<void>(context, (c) => ShiftForm(me: me))),
                const SizedBox(width: 8),
                _QuickAction(
                    icon: Icons.speed,
                    label: 'প্যাকেজ পরিবর্তন',
                    onTap: () =>
                        showSheet<void>(context, (c) => PackageForm(me: me))),
              ],
            ),
          ),
          const TabBar(tabs: [
            Tab(text: 'আমার টিকেট'),
            Tab(text: 'শিফট / প্যাকেজ আবেদন'),
          ]),
          Expanded(
            child: TabBarView(
              children: [
                QueryList(
                  query: db.collection('tickets').where('uid', isEqualTo: me.uid),
                  sort: byNewest,
                  empty: 'কোনো কমপ্লেইন নেই',
                  builder: (c, docs) => ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    itemBuilder: (c, i) => _TicketCard(d: docs[i]),
                  ),
                ),
                QueryList(
                  query:
                      db.collection('requests').where('uid', isEqualTo: me.uid),
                  sort: byNewest,
                  empty: 'কোনো আবেদন নেই',
                  builder: (c, docs) => ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    itemBuilder: (c, i) => _RequestCard(m: docs[i].data()),
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

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.d});
  final Snap d;
  Json get m => d.data();

  @override
  Widget build(BuildContext context) {
    final status = asStr(m['status'], 'Processing');
    final tech = asStr(m['technicianName']);
    final techPhone = asStr(m['technicianPhone']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('#${asStr(m['ticketNo'])}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                StatusChip(status),
              ],
            ),
            const SizedBox(height: 6),
            Text(asStr(m['category'])),
            if (asStr(m['note']).isNotEmpty)
              Text(asStr(m['note']),
                  style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 10),
            TicketSteps(status),
            TicketRatingBox(d: d),
            if (status == 'Technician Assigned' && tech.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.engineering, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text('$tech  $techPhone')),
                    if (techPhone.isNotEmpty)
                      IconButton(
                          icon: const Icon(Icons.call, color: Colors.green),
                          onPressed: () => callPhone(techPhone)),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(fmtDate(m['createdAt']),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class TicketSteps extends StatelessWidget {
  const TicketSteps(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final idx = status == 'Resolved'
        ? 2
        : status == 'Technician Assigned'
            ? 1
            : 0;
    const labels = ['প্রসেসিং', 'টেকনিশিয়ান', 'সমাধান'];
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0)
            Expanded(
              child: Divider(
                  thickness: 2,
                  color: i <= idx ? Colors.green : Colors.grey.shade300),
            ),
          Column(
            children: [
              Icon(
                i <= idx ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: i <= idx ? Colors.green : Colors.grey,
              ),
              Text(labels[i], style: const TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.m});
  final Json m;

  @override
  Widget build(BuildContext context) {
    final isShift = m['type'] == 'shift';
    final status = asStr(m['status'], 'pending');
    final fee = asInt(m['fee']);
    final note = asStr(m['adminNote']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isShift ? Icons.local_shipping_outlined : Icons.speed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(isShift ? 'লাইন শিফট' : 'প্যাকেজ পরিবর্তন',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                StatusChip(status),
              ],
            ),
            const SizedBox(height: 6),
            if (isShift) ...[
              Text('নতুন ঠিকানা: ${asStr(m['newAddress'])}'),
              if (asStr(m['mapLocation']).isNotEmpty)
                Text('লোকেশন: ${asStr(m['mapLocation'])}'),
              if (status == 'approved' && fee > 0)
                Text('শিফট ফি: $kTaka$fee',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
            ] else
              Text('${asStr(m['currentPackage'])}  →  ${asStr(m['newPackage'])}'),
            if (note.isNotEmpty) Text('অ্যাডমিন নোট: $note'),
            const SizedBox(height: 4),
            Text(fmtDate(m['createdAt']),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class ComplaintForm extends StatefulWidget {
  const ComplaintForm({super.key, required this.me});
  final AppUser me;

  @override
  State<ComplaintForm> createState() => _ComplaintFormState();
}

class _ComplaintFormState extends State<ComplaintForm> {
  static const _cats = ['নেট বন্ধ', 'স্পিড কম', 'ক্যাবল কাটা', 'অন্যান্য'];
  String? _cat;
  final _note = TextEditingController();
  String? _err;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_cat == null) {
      setState(() => _err = 'সমস্যার ধরন বেছে নিন');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final nav = Navigator.of(context);
    final msg = ScaffoldMessenger.of(context);
    final no = 'TC-${(DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0')}';
    try {
      final me = widget.me;
      await db.collection('tickets').add({
        'uid': me.uid,
        'userName': me.name,
        'phone': me.phone,
        'address': me.address,
        'zone': me.zone,
        'category': _cat,
        'note': _note.text.trim(),
        'status': 'Processing',
        'ticketNo': no,
        'technicianName': '',
        'technicianPhone': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      nav.pop();
      msg.showSnackBar(SnackBar(content: Text('কমপ্লেইন জমা হয়েছে। টিকেট নম্বর: $no')));
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
      title: 'নতুন কমপ্লেইন',
      busy: _busy,
      err: _err,
      onSubmit: _go,
      children: [
        choiceWrap(_cats, _cat, (v) => setState(() => _cat = v)),
        gap,
        TextField(
          controller: _note,
          maxLines: 3,
          decoration: deco('বিস্তারিত (ঐচ্ছিক)'),
        ),
      ],
    );
  }
}

class ShiftForm extends StatefulWidget {
  const ShiftForm({super.key, required this.me});
  final AppUser me;

  @override
  State<ShiftForm> createState() => _ShiftFormState();
}

class _ShiftFormState extends State<ShiftForm> {
  final _addr = TextEditingController();
  final _map = TextEditingController();
  String? _err;
  bool _busy = false;

  @override
  void dispose() {
    _addr.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_addr.text.trim().isEmpty) {
      setState(() => _err = 'নতুন ঠিকানা লিখুন');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final nav = Navigator.of(context);
    final msg = ScaffoldMessenger.of(context);
    try {
      final me = widget.me;
      await db.collection('requests').add({
        'type': 'shift',
        'uid': me.uid,
        'userName': me.name,
        'phone': me.phone,
        'zone': me.zone,
        'currentAddress': me.address,
        'newAddress': _addr.text.trim(),
        'mapLocation': _map.text.trim(),
        'currentPackage': me.packageName,
        'newPackage': '',
        'status': 'pending',
        'fee': 0,
        'adminNote': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      nav.pop();
      msg.showSnackBar(const SnackBar(
          content: Text('শিফটের আবেদন জমা হয়েছে। ফি জানিয়ে দেওয়া হবে।')));
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
      title: 'কানেকশন শিফট',
      busy: _busy,
      err: _err,
      onSubmit: _go,
      children: [
        TextField(
            controller: _addr,
            maxLines: 2,
            decoration: deco('নতুন ঠিকানা')),
        gap,
        TextField(
            controller: _map,
            decoration: deco('ম্যাপ লোকেশন / ল্যান্ডমার্ক',
                hint: 'গুগল ম্যাপ লিংক বা চেনার মতো জায়গা')),
      ],
    );
  }
}

class PackageForm extends StatefulWidget {
  const PackageForm({super.key, required this.me});
  final AppUser me;

  @override
  State<PackageForm> createState() => _PackageFormState();
}

class _PackageFormState extends State<PackageForm> {
  String? _pkg;
  String? _err;
  bool _busy = false;

  Future<void> _go() async {
    if (_pkg == null) {
      setState(() => _err = 'নতুন প্যাকেজ বেছে নিন');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final nav = Navigator.of(context);
    final msg = ScaffoldMessenger.of(context);
    try {
      final me = widget.me;
      await db.collection('requests').add({
        'type': 'package',
        'uid': me.uid,
        'userName': me.name,
        'phone': me.phone,
        'zone': me.zone,
        'currentAddress': me.address,
        'newAddress': '',
        'mapLocation': '',
        'currentPackage': me.packageName,
        'newPackage': _pkg,
        'status': 'pending',
        'fee': 0,
        'adminNote': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      nav.pop();
      msg.showSnackBar(const SnackBar(
          content: Text('প্যাকেজ পরিবর্তনের আবেদন জমা হয়েছে।')));
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
    final items =
        Cfg.v.packages.where((p) => p != widget.me.packageName).toList();
    return formShell(
      title: 'প্যাকেজ পরিবর্তন',
      busy: _busy,
      err: _err,
      onSubmit: _go,
      children: [
        Text('বর্তমান প্যাকেজ: ${widget.me.packageName}'),
        gap,
        pickField(
            label: 'নতুন প্যাকেজ',
            items: items,
            value: _pkg,
            onChanged: (v) => _pkg = v),
      ],
    );
  }
}

// ============================================================== alerts

class AlertsTab extends StatelessWidget {
  const AlertsTab({super.key, required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('নোটিফিকেশন',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: QueryList(
            key: ValueKey(me.zone),
            query: notifQuery(me.uid, me.zone),
            sort: byNewest,
            empty: 'কোনো নোটিফিকেশন নেই',
            builder: (c, docs) => ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (c, i) {
                final m = docs[i].data();
                final personal = asStr(m['target']).startsWith('uid:');
                return Card(
                  child: ListTile(
                    leading: Icon(
                        personal ? Icons.emoji_events : Icons.campaign,
                        color: personal ? Colors.amber.shade800 : null),
                    title: Text(asStr(m['title'])),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(asStr(m['body'])),
                        const SizedBox(height: 4),
                        Text(fmtDate(m['createdAt']),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================= profile

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    final support = Cfg.v.supportPhone;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: CircleAvatar(
            radius: 36,
            child: Text(me.name.isEmpty ? '?' : me.name.characters.first,
                style: const TextStyle(fontSize: 28)),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(me.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        infoRow(Icons.phone_outlined, 'মোবাইল', me.phone),
        infoRow(Icons.email_outlined, 'ইমেইল', me.email),
        infoRow(Icons.home_outlined, 'ঠিকানা', me.address),
        infoRow(Icons.map_outlined, 'জোন', me.zone),
        infoRow(Icons.speed, 'প্যাকেজ', me.packageName),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () =>
              showSheet<void>(context, (c) => EditProfileForm(me: me)),
          icon: const Icon(Icons.edit),
          label: const Text('প্রোফাইল এডিট'),
        ),
        if (support.isNotEmpty) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => callPhone(support),
            icon: const Icon(Icons.call),
            label: Text('সাপোর্টে কল করুন ($support)'),
          ),
        ],
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: () async {
            if (await confirmDialog(context, 'লগআউট', 'লগআউট করতে চান?')) {
              fbAuth.signOut();
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('লগআউট'),
        ),
      ],
    );
  }
}

class EditProfileForm extends StatefulWidget {
  const EditProfileForm({super.key, required this.me});
  final AppUser me;

  @override
  State<EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends State<EditProfileForm> {
  late final _name = TextEditingController(text: widget.me.name);
  late final _phone = TextEditingController(text: widget.me.phone);
  late final _addr = TextEditingController(text: widget.me.address);
  late String _zone = widget.me.zone;
  String? _err;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _addr.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final phone = normalizePhone(_phone.text);
    if (_name.text.trim().isEmpty) {
      setState(() => _err = 'নাম লিখুন');
      return;
    }
    if (!validPhone(phone)) {
      setState(() => _err = 'সঠিক মোবাইল নম্বর দিন');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final nav = Navigator.of(context);
    try {
      await db.collection('users').doc(widget.me.uid).update({
        'name': _name.text.trim(),
        'phone': phone,
        'address': _addr.text.trim(),
        'zone': _zone,
      });
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
      title: 'প্রোফাইল এডিট',
      busy: _busy,
      err: _err,
      onSubmit: _go,
      label: 'সেভ করুন',
      children: [
        TextField(controller: _name, decoration: deco('নাম')),
        gap,
        TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: deco('মোবাইল')),
        gap,
        TextField(controller: _addr, maxLines: 2, decoration: deco('ঠিকানা')),
        gap,
        pickField(
            label: 'জোন',
            items: Cfg.v.zones,
            value: _zone,
            onChanged: (v) {
              if (v != null) _zone = v;
            }),
      ],
    );
  }
}
