import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zabi/service/mobile_auth_service.dart';
import 'package:zabi/view/screens/account/cloud_sync_status_card.dart';

enum _AccountForm { login, register, forgot, reset }

class AccountSettingsCard extends StatelessWidget {
  const AccountSettingsCard({super.key});
  @override
  Widget build(BuildContext context) => Obx(() {
    final user = MobileAuthService.instance.user.value;
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.account_circle_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text('auth_account_title'.tr),
        subtitle: Text(user == null ? 'auth_account_hint'.tr : user.email),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Get.to(() => const AccountScreen()),
      ),
    );
  });
}

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, this.service});
  final MobileAuthService? service;
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final MobileAuthService _auth =
      widget.service ?? MobileAuthService.instance;
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();
  _AccountForm _mode = _AccountForm.login;
  bool _loading = true, _busy = false, _obscure = true;
  String? _message;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _message = null;
      });
    }
    try {
      await _auth.initialize();
      await _auth.loadConfiguration();
      if (_auth.initializationError.value != null) {
        throw MobileAuthException(_auth.initializationError.value!);
      }
    } on MobileAuthException catch (error) {
      if (mounted) {
        setState(() {
          _message = error.messageKey.tr;
          _error = true;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      await action();
      if (mounted && success != null) setState(() => _message = success.tr);
    } on MobileAuthException catch (error) {
      if (mounted && error.messageKey != 'auth_cancelled') {
        setState(() {
          _error = true;
          _message = error.messageKey.tr;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _message = 'auth_service_unavailable'.tr;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changeMode(_AccountForm mode) {
    _password.clear();
    _confirm.clear();
    _code.clear();
    setState(() {
      _mode = mode;
      _message = null;
      _error = false;
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await _run(() async {
      switch (_mode) {
        case _AccountForm.login:
          await _auth.login(email: _email.text, password: _password.text);
          _password.clear();
        case _AccountForm.register:
          await _auth.register(
            name: _name.text,
            email: _email.text,
            password: _password.text,
          );
          _password.clear();
          _confirm.clear();
        case _AccountForm.forgot:
          await _auth.forgotPassword(_email.text);
          if (mounted) {
            setState(() {
              _mode = _AccountForm.reset;
              _message = 'auth_reset_sent'.tr;
            });
          }
        case _AccountForm.reset:
          await _auth.resetPassword(
            email: _email.text,
            code: _code.text,
            password: _password.text,
          );
          _password.clear();
          _confirm.clear();
          _code.clear();
          if (mounted) {
            setState(() {
              _mode = _AccountForm.login;
              _message = 'auth_password_changed'.tr;
            });
          }
      }
    });
  }

  Future<void> _delete(MobileUser user) async {
    var password = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('auth_delete_title'.tr),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('auth_delete_description'.tr),
              if (user.hasPassword) ...[
                const SizedBox(height: 16),
                TextField(
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(labelText: 'auth_password'.tr),
                  onChanged: (value) => password = value,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('auth_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text('auth_delete_confirm'.tr),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && _auth.user.value?.id == user.id) {
      await _run(
        () => _auth.deleteAccount(password: user.hasPassword ? password : null),
        success: 'auth_account_deleted',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in [_email, _name, _password, _confirm, _code]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        'auth_account_title'.tr,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Obx(
            () => ListView(
              key: ValueKey(_auth.user.value?.id ?? 'signed_out'),
              padding: const EdgeInsets.all(20),
              children: [
                if (_loading || _busy) const LinearProgressIndicator(),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _message!,
                        style: TextStyle(
                          color: _error
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                if (!_loading) ...[
                  if (_auth.user.value != null)
                    _profile(_auth.user.value!)
                  else if (!_auth.configuration.value.available) ...[
                    Text('auth_unavailable_hint'.tr),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _load,
                      child: Text('auth_retry'.tr),
                    ),
                  ] else
                    _credentials(),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _profile(MobileUser user) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 20),
      Icon(
        Icons.account_circle_outlined,
        size: 56,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(height: 12),
      Text(
        user.name,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 6),
      Text(user.email, textAlign: TextAlign.center),
      const SizedBox(height: 20),
      if (!user.emailVerified && _auth.configuration.value.verification)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'auth_verify_title'.tr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('auth_verify_hint'.tr),
                const SizedBox(height: 16),
                _codeField(),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          await _auth.verifyEmail(_code.text);
                          _code.clear();
                        }, success: 'auth_email_verified'),
                  child: Text('auth_verify_action'.tr),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          _auth.resendVerification,
                          success: 'auth_verification_sent',
                        ),
                  child: Text('auth_resend_code'.tr),
                ),
              ],
            ),
          ),
        )
      else if (user.emailVerified)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.verified_outlined),
          title: Text('auth_email_verified'.tr),
        ),
      if (!user.emailVerified && !_auth.configuration.value.verification)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text('auth_verification_unavailable'.tr),
        ),
      if (widget.service == null) const CloudSyncStatusCard(),
      if (user.emailVerified &&
          _auth.configuration.value.google &&
          !user.providers.contains('google'))
        OutlinedButton(
          onPressed: _busy
              ? null
              : () => _run(
                  () => _auth.signInWithGoogle(link: true),
                  success: 'auth_provider_linked',
                ),
          child: Text('auth_link_google'.tr),
        ),
      if (user.emailVerified &&
          _auth.configuration.value.apple &&
          !user.providers.contains('apple'))
        OutlinedButton(
          onPressed: _busy
              ? null
              : () => _run(
                  () => _auth.signInWithApple(link: true),
                  success: 'auth_provider_linked',
                ),
          child: Text('auth_link_apple'.tr),
        ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: _busy ? null : () => _run(_auth.refreshUser),
        icon: const Icon(Icons.refresh),
        label: Text('auth_refresh'.tr),
      ),
      OutlinedButton(
        onPressed: _busy ? null : () => _run(_auth.logout),
        child: Text('auth_logout'.tr),
      ),
      const SizedBox(height: 16),
      TextButton(
        onPressed: _busy ? null : () => _delete(user),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        child: Text('auth_delete_title'.tr),
      ),
    ],
  );

  Widget _credentials() {
    final config = _auth.configuration.value;
    final passwordNeeded = _mode != _AccountForm.forgot;
    final newPassword =
        _mode == _AccountForm.register || _mode == _AccountForm.reset;
    final title = switch (_mode) {
      _AccountForm.login => 'auth_login',
      _AccountForm.register => 'auth_register',
      _AccountForm.forgot => 'auth_forgot_password',
      _AccountForm.reset => 'auth_reset_password',
    };
    return AutofillGroup(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Text(title.tr, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('auth_account_hint'.tr),
            const SizedBox(height: 24),
            if ((_mode == _AccountForm.login ||
                    _mode == _AccountForm.register) &&
                (config.google || config.apple)) ...[
              if (config.google)
                OutlinedButton(
                  onPressed: _busy ? null : () => _run(_auth.signInWithGoogle),
                  child: Text('auth_google'.tr),
                ),
              if (config.apple)
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _run(_auth.signInWithApple),
                  icon: const Icon(Icons.apple),
                  label: Text('auth_apple'.tr),
                ),
              const SizedBox(height: 16),
            ],
            if (config.email) ...[
              if (_mode == _AccountForm.register) ...[
                TextFormField(
                  key: const ValueKey('auth_name'),
                  controller: _name,
                  enabled: !_busy,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(
                    labelText: 'auth_name'.tr,
                    counterText: '',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'auth_invalid_name'.tr
                      : null,
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                key: const ValueKey('auth_email'),
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: 'auth_email'.tr),
                validator: (value) => MobileAuthService.validEmail(value ?? '')
                    ? null
                    : 'auth_invalid_email'.tr,
              ),
              const SizedBox(height: 16),
              if (_mode == _AccountForm.reset) ...[
                _codeField(),
                const SizedBox(height: 16),
              ],
              if (passwordNeeded) ...[
                TextFormField(
                  key: const ValueKey('auth_password'),
                  controller: _password,
                  enabled: !_busy,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: [
                    newPassword
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    labelText: 'auth_password'.tr,
                    suffixIcon: IconButton(
                      tooltip:
                          (_obscure
                                  ? 'auth_show_password'
                                  : 'auth_hide_password')
                              .tr,
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => newPassword
                      ? MobileAuthService.passwordError(value ?? '')?.tr
                      : value?.isNotEmpty == true
                      ? null
                      : 'auth_invalid_credentials'.tr,
                ),
                if (newPassword) ...[
                  const SizedBox(height: 8),
                  Text(
                    'auth_password_requirements'.tr,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('auth_confirm'),
                    controller: _confirm,
                    enabled: !_busy,
                    obscureText: _obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'auth_confirm_password'.tr,
                    ),
                    validator: (value) => value == _password.text
                        ? null
                        : 'auth_password_mismatch'.tr,
                  ),
                ],
                const SizedBox(height: 20),
              ],
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    (_mode == _AccountForm.forgot ? 'auth_send_code' : title)
                        .tr,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              if (_mode == _AccountForm.login) ...[
                if (config.passwordReset)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _changeMode(_AccountForm.forgot),
                    child: Text('auth_forgot_password'.tr),
                  ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _changeMode(_AccountForm.register),
                  child: Text('auth_create_account'.tr),
                ),
              ] else
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _changeMode(_AccountForm.login),
                  child: Text('auth_back_login'.tr),
                ),
              if (_mode == _AccountForm.forgot)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _changeMode(_AccountForm.reset),
                  child: Text('auth_have_code'.tr),
                ),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text('auth_continue_guest'.tr),
            ),
          ],
        ),
      ),
    );
  }

  Widget _codeField() => TextFormField(
    key: const ValueKey('auth_code'),
    controller: _code,
    enabled: !_busy,
    keyboardType: TextInputType.number,
    autofillHints: const [AutofillHints.oneTimeCode],
    maxLength: 6,
    decoration: InputDecoration(
      labelText: 'auth_email_code'.tr,
      counterText: '',
    ),
    validator: (value) => MobileAuthService.validCode(value ?? '')
        ? null
        : 'auth_invalid_code'.tr,
  );
}
