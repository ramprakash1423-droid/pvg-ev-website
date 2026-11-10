import 'package:flutter/material.dart';
import 'api.dart';
import 'ui.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.api});
  final PvgApi api;
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      phone = TextEditingController(),
      code = TextEditingController();
  Map<String, dynamic>? challenge;
  bool busy = false, sms = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      challenge = await widget.api.sendOtp(
        phone.text.trim(),
        name.text.trim(),
        sms: sms || !widget.api.isPreview,
      );
    } catch (e) {
      error = errorText(e);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> verify() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.verifyOtp(challenge!['challenge_id'], code.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      error = errorText(e);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> demo() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final c = await widget.api.sendOtp('9000000001', 'PVG demo customer');
      await widget.api.verifyOtp(c['challenge_id'], c['preview_code']);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      error = errorText(e);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Welcome to PVG EV')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 16),
        const Align(
          alignment: Alignment.centerLeft,
          child: CircleAvatar(
            radius: 24,
            backgroundColor: lime,
            child: Icon(Icons.bolt_rounded, color: forest, size: 30),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          challenge == null ? 'Power your day.' : 'Check your messages.',
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          challenge == null
              ? 'Your phone number keeps your visits and invoices together.'
              : 'Enter the six-digit code for +91 ${phone.text}.',
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 16),
        Form(
          key: form,
          child: Column(
            children: challenge == null
                ? [
                    TextFormField(
                      controller: name,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(labelText: 'Your name'),
                      validator: (v) =>
                          v!.trim().length < 2 ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      autofillHints: const [
                        AutofillHints.telephoneNumberNational,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        prefixText: '+91 ',
                      ),
                      validator: (v) =>
                          !RegExp(r'^[6-9]\d{9}$').hasMatch(v!.trim())
                          ? 'Enter a valid 10-digit mobile number'
                          : null,
                    ),
                    if (widget.api.isPreview &&
                        widget.api.config?['integrations']?['sms_available'] ==
                            true)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: sms,
                        onChanged: busy
                            ? null
                            : (v) => setState(() => sms = v!),
                        title: const Text(
                          'Send a real test SMS',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: const Text(
                          'Use your own number. Temporary Clickacook sender until PVG registration.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    PrimaryButton(
                      sms || !widget.api.isPreview
                          ? 'Send verification SMS'
                          : 'Get preview code',
                      busy: busy,
                      onPressed: send,
                    ),
                  ]
                : [
                    TextFormField(
                      controller: code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      decoration: const InputDecoration(
                        labelText: 'Verification code',
                      ),
                    ),
                    if (challenge!['preview_code'] != null)
                      Notice(
                        'Preview code: ${challenge!['preview_code']} · no SMS sent',
                      ),
                    PrimaryButton(
                      'Verify & continue',
                      busy: busy,
                      onPressed: verify,
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() => challenge = null),
                      child: const Text('Change number / request another code'),
                    ),
                  ],
          ),
        ),
        if (error != null) Notice(error!, error: true),
        const SizedBox(height: 25),
        if (challenge == null && widget.api.isPreview) ...[
          const Divider(),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: busy ? null : demo,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Explore with sample customer'),
            ),
          ),
        ],
        Notice(
          widget.api.isPreview
              ? 'This is a local pilot. Sample accounts and preview codes are disabled in a production build.'
              : 'We’ll send a one-time verification code to your mobile. Never share your code with anyone.',
        ),
      ],
    ),
  );
}
