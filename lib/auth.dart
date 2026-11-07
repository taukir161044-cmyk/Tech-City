// ignore_for_file: use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _addr = TextEditingController();
  final _ref = TextEditingController();
  String? _zone;
  String? _pkg;
  bool _signup = false;
  bool _hide = true;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    for (final c in [_email, _pass, _name, _phone, _addr, _ref]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fail(String m) {
    if (mounted) setState(() => _err = m);
  }

  Future<void> _submit() async {
    final email = _email.text.trim().toLowerCase();
    final pass = _pass.text;
    if (!email.contains('@') || !email.contains('.')) {
      _fail('সঠিক ইমেইল দিন');
      return;
    }
    if (pass.length < 6) {
      _fail('পাসওয়ার্ড কমপক্ষে ৬ অক্ষরের দিন');
      return;
    }
    var name = '', phone = '', addr = '', refCode = '';
    if (_signup) {
      name = _name.text.trim();
      phone = normalizePhone(_phone.text);
      addr = _addr.text.trim();
      refCode = _ref.text.trim().toUpperCase();
      if (name.isEmpty) {
        _fail('নাম লিখুন');
        return;
      }
      if (!validPhone(phone)) {
        _fail('সঠিক মোবাইল নম্বর দিন (01XXXXXXXXX)');
        return;
      }
      if (_zone == null) {
        _fail('জোন / এলাকা বেছে নিন');
        return;
      }
      if (_pkg == null) {
        _fail('বর্তমান প্যাকেজ বেছে নিন');
        return;
      }
      if (addr.isEmpty) {
        _fail('ঠিকানা লিখুন');
        return;
      }
    }

    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      if (!_signup) {
        await fbAuth.signInWithEmailAndPassword(email: email, password: pass);
      } else {
        var refUid = '', refName = '';
        if (refCode.isNotEmpty) {
          final d = await db.collection('referralCodes').doc(refCode).get();
          if (!d.exists) {
            _fail('রেফারেল কোডটি সঠিক নয়');
            return;
          }
          refUid = asStr(d.data()?['uid']);
          refName = asStr(d.data()?['name']);
        }
        final cred = await fbAuth.createUserWithEmailAndPassword(
            email: email, password: pass);
        final u = cred.user!;
        if (!isAdminUser(u)) {
          try {
            await _createProfile(
                u, email, name, phone, addr, _zone!, _pkg!, refUid, refName);
          } catch (e) {
            try {
              await u.delete();
            } catch (_) {}
            toastGlobal('অ্যাকাউন্ট তৈরি হয়নি, আবার চেষ্টা করুন: $e');
            rethrow;
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      _fail(authError(e.code));
    } catch (e) {
      _fail('সমস্যা হয়েছে: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createProfile(User u, String email, String name, String phone,
      String addr, String zone, String pkg, String refUid, String refName) async {
    var code = '';
    for (var i = 0; i < 10 && code.isEmpty; i++) {
      final c = genCode();
      final ex = await db.collection('referralCodes').doc(c).get();
      if (!ex.exists) code = c;
    }
    if (code.isEmpty) code = genCode(8);

    final b = db.batch();
    b.set(db.collection('users').doc(u.uid), {
      'name': name,
      'phone': phone,
      'email': email,
      'address': addr,
      'zone': zone,
      'packageName': pkg,
      'referralCode': code,
      'referredBy': refUid,
      'points': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    b.set(db.collection('referralCodes').doc(code), {
      'uid': u.uid,
      'name': name,
    });
    if (refUid.isNotEmpty && refUid != u.uid) {
      b.set(db.collection('referrals').doc(u.uid), {
        'referrerUid': refUid,
        'referrerName': refName,
        'referredUid': u.uid,
        'referredName': name,
        'referredPhone': phone,
        'status': 'pending',
        'month': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await b.commit();
  }

  Future<void> _reset() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      _fail('আগে ইমেইল ঘরে ইমেইল লিখুন');
      return;
    }
    try {
      await fbAuth.sendPasswordResetEmail(email: email);
      if (mounted) toast(context, 'পাসওয়ার্ড রিসেট লিংক ইমেইলে পাঠানো হয়েছে');
    } on FirebaseAuthException catch (e) {
      _fail(authError(e.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ValueListenableBuilder<AppSettings>(
                valueListenable: Cfg.notifier,
                builder: (context, s, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.wifi,
                        size: 64, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 8),
                    Text(kAppName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text(_signup ? 'নতুন অ্যাকাউন্ট খুলুন' : 'লগইন করুন',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 24),
                    if (_signup) ...[
                      TextField(
                          controller: _name,
                          decoration: deco('আপনার নাম', icon: Icons.person_outline)),
                      gap,
                      TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: deco('মোবাইল নম্বর',
                              hint: '01XXXXXXXXX', icon: Icons.phone_outlined)),
                      gap,
                      pickField(
                          label: 'জোন / এলাকা',
                          items: s.zones,
                          value: _zone,
                          onChanged: (v) => _zone = v),
                      gap,
                      pickField(
                          label: 'বর্তমান প্যাকেজ',
                          items: s.packages,
                          value: _pkg,
                          onChanged: (v) => _pkg = v),
                      gap,
                      TextField(
                          controller: _addr,
                          maxLines: 2,
                          decoration:
                              deco('ঠিকানা', icon: Icons.home_outlined)),
                      gap,
                    ],
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: deco('ইমেইল', icon: Icons.email_outlined),
                    ),
                    gap,
                    TextField(
                      controller: _pass,
                      obscureText: _hide,
                      decoration: InputDecoration(
                        labelText: 'পাসওয়ার্ড',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _hide ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                    ),
                    if (_signup) ...[
                      gap,
                      TextField(
                        controller: _ref,
                        textCapitalization: TextCapitalization.characters,
                        decoration: deco('রেফারেল কোড (থাকলে)',
                            icon: Icons.card_giftcard),
                      ),
                    ],
                    if (_err != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_err!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(_busy
                            ? 'অপেক্ষা করুন...'
                            : (_signup ? 'অ্যাকাউন্ট খুলুন' : 'লগইন')),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _signup = !_signup;
                                _err = null;
                              }),
                      child: Text(_signup
                          ? 'আগে থেকেই অ্যাকাউন্ট আছে? লগইন করুন'
                          : 'নতুন অ্যাকাউন্ট খুলুন'),
                    ),
                    if (!_signup)
                      TextButton(
                        onPressed: _busy ? null : _reset,
                        child: const Text('পাসওয়ার্ড ভুলে গেছেন?'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
