import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth.dart';
import 'store.dart';
import 'widgets.dart';

/// Normalize only when submitting, preserving Arabic keyboard composition.
String normalizeSaudiMobile(String value) {
  var phone = String.fromCharCodes(
    value.runes.map((rune) {
      if (rune >= 0x0660 && rune <= 0x0669) return rune - 0x0660 + 0x30;
      if (rune >= 0x06f0 && rune <= 0x06f9) return rune - 0x06f0 + 0x30;
      return rune;
    }),
  ).replaceAll(RegExp(r'[\s()\-]'), '');
  if (phone.startsWith('00966')) phone = '+966${phone.substring(5)}';
  if (RegExp(r'^05[0-9]{8}$').hasMatch(phone)) {
    phone = '+966${phone.substring(1)}';
  } else if (RegExp(r'^5[0-9]{8}$').hasMatch(phone)) {
    phone = '+966$phone';
  } else if (RegExp(r'^9665[0-9]{8}$').hasMatch(phone)) {
    phone = '+$phone';
  }
  return phone;
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.store, required this.auth});
  final TrustStore store;
  final AuthController auth;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _loginForm = GlobalKey<FormState>();
  final _registerForm = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _loginPassword = TextEditingController();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _registering = false;
  bool _hideLoginPassword = true;
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  bool _terms = false;
  String _role = 'customer';
  TrustStore get s => widget.store;
  AuthController get auth => widget.auth;

  @override
  void dispose() {
    for (final controller in [
      _login,
      _loginPassword,
      _fullName,
      _username,
      _email,
      _phone,
      _city,
      _password,
      _confirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggle() {
    FocusScope.of(context).unfocus();
    auth.clearError();
    setState(() => _registering = !_registering);
  }

  Future<void> _submitLogin() async {
    if (auth.busy || !(_loginForm.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final success = await auth.login(_login.text.trim(), _loginPassword.text);
    if (success) TextInput.finishAutofillContext();
  }

  Future<void> _submitRegistration() async {
    if (auth.busy || !(_registerForm.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final success = await auth.register({
      'fullName': _fullName.text.trim(),
      'username': _username.text.trim(),
      'email': _email.text.trim(),
      'phone': normalizeSaudiMobile(_phone.text),
      'city': _city.text.trim(),
      'role': _role,
      'password': _password.text,
      'termsAccepted': _terms,
    });
    if (success) TextInput.finishAutofillContext();
  }

  String? _required(String? value) => (value?.trim().isEmpty ?? true)
      ? s.t('هذا الحقل مطلوب', 'This field is required')
      : null;

  String? _validatePassword(String? value) =>
      value == null || value.length < 10 || value.length > 128
      ? s.t('استخدم من ١٠ إلى ١٢٨ حرفًا', 'Use 10 to 128 characters')
      : null;

  InputDecoration _decoration(String label, IconData icon, {String? hint}) =>
      InputDecoration(labelText: label, prefixIcon: Icon(icon), hintText: hint);

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool hidden,
    required VoidCallback onVisibility,
    required String fieldKey,
    required String? Function(String?) validator,
    bool last = false,
    bool current = false,
    VoidCallback? onSubmit,
  }) => TextFormField(
    key: ValueKey(fieldKey),
    controller: controller,
    enabled: !auth.busy,
    obscureText: hidden,
    autocorrect: false,
    enableSuggestions: false,
    keyboardType: TextInputType.visiblePassword,
    autofillHints: [
      current ? AutofillHints.password : AutofillHints.newPassword,
    ],
    textInputAction: last ? TextInputAction.done : TextInputAction.next,
    onFieldSubmitted: last ? (_) => onSubmit?.call() : null,
    decoration: _decoration(label, Icons.lock_outline).copyWith(
      suffixIcon: IconButton(
        onPressed: onVisibility,
        tooltip: hidden
            ? s.t('إظهار كلمة المرور', 'Show password')
            : s.t('إخفاء كلمة المرور', 'Hide password'),
        icon: Icon(
          hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
    validator: validator,
  );

  void _showTerms() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(s.t('الشروط والخصوصية', 'Terms and privacy')),
      content: SingleChildScrollView(
        child: Text(
          s.t(
            'هذه نسخة مشروع جامعي من ثقة تعمل دون إنترنت. تُحفظ الحسابات والطلبات على هذا الجهاز فقط، ويستطيع مدير المشروع الاطلاع على بيانات التسجيل وإيقاف الحسابات المحلية.\n\n'
                'استخدم بيانات تخصك، ولا تشارك بيانات حساسة أو وثائق رسمية في هذه النسخة. البريد والجوال غير موثقين، وإنشاء حساب مقدم خدمة لا يمثل اعتمادًا أو توثيقًا. لا تتوفر دفعات حقيقية أو خدمة حكومية فعلية.\n\n'
                'بإنشاء الحساب توافق على استخدام هذه النسخة للتجربة واحترام خصوصية الآخرين.',
            'This is an offline university project. Accounts and requests are stored only on this device. The project administrator can view registration details and suspend local accounts.\n\n'
                'Use your own details and avoid sensitive information or official documents in this version. Email and phone are not verified. A provider account does not indicate certification or approval. Real payments and government services are unavailable.\n\n'
                'By creating an account, you agree to use this version for testing and respect others’ privacy.',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.t('فهمت', 'Got it')),
        ),
      ],
    ),
  );

  Widget _loginFields() => Form(
    key: _loginForm,
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const ValueKey('loginIdentifier'),
            controller: _login,
            enabled: !auth.busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.username],
            decoration: _decoration(
              s.t('اسم المستخدم أو البريد الإلكتروني', 'Username or email'),
              Icons.person_outline,
            ),
            validator: _required,
          ),
          const SizedBox(height: 18),
          _passwordField(
            controller: _loginPassword,
            label: s.t('كلمة المرور', 'Password'),
            hidden: _hideLoginPassword,
            onVisibility: () =>
                setState(() => _hideLoginPassword = !_hideLoginPassword),
            fieldKey: 'loginPassword',
            validator: (value) => value == null || value.isEmpty
                ? s.t('أدخل كلمة المرور', 'Enter your password')
                : null,
            current: true,
            last: true,
            onSubmit: _submitLogin,
          ),
          const SizedBox(height: 24),
          _submitButton(
            s.t('تسجيل الدخول', 'Sign in'),
            _submitLogin,
            'loginSubmit',
          ),
        ],
      ),
    ),
  );

  Widget _registrationFields() => Form(
    key: _registerForm,
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const ValueKey('registerFullName'),
            controller: _fullName,
            enabled: !auth.busy,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.name,
            autofillHints: const [AutofillHints.name],
            decoration: _decoration(
              s.t('الاسم الكامل', 'Full name'),
              Icons.person_outline,
            ),
            validator: (value) {
              if (_required(value) != null) return _required(value);
              return value!.trim().length < 3 || value.trim().length > 100
                  ? s.t(
                      'أدخل اسمًا من ٣ إلى ١٠٠ حرف',
                      'Enter 3 to 100 characters',
                    )
                  : null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('registerUsername'),
            controller: _username,
            enabled: !auth.busy,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.newUsername],
            decoration:
                _decoration(
                  s.t('اسم المستخدم', 'Username'),
                  Icons.alternate_email,
                ).copyWith(
                  helperText: s.t(
                    '٣–٣٠ حرفًا إنجليزيًا أو رقمًا أو _ أو .',
                    '3–30 English letters, numbers, _ or .',
                  ),
                  helperMaxLines: 2,
                ),
            validator: (value) =>
                RegExp(r'^[a-zA-Z0-9_.]{3,30}$').hasMatch(value?.trim() ?? '')
                ? null
                : s.t(
                    'أدخل اسم مستخدم مطابقًا للشروط',
                    'Enter a valid username',
                  ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('registerEmail'),
            controller: _email,
            enabled: !auth.busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            decoration: _decoration(
              s.t('البريد الإلكتروني', 'Email'),
              Icons.mail_outline,
            ),
            validator: (value) =>
                RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(value?.trim() ?? '') &&
                    (value?.trim().length ?? 0) <= 254
                ? null
                : s.t(
                    'أدخل بريدًا إلكترونيًا صحيحًا',
                    'Enter a valid email address',
                  ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('registerPhone'),
            controller: _phone,
            enabled: !auth.busy,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: _decoration(
              s.t('رقم الجوال السعودي', 'Saudi mobile number'),
              Icons.phone_outlined,
              hint: '05XXXXXXXX',
            ),
            validator: (value) =>
                RegExp(r'^\+9665[0-9]{8}$')
                    .hasMatch(normalizeSaudiMobile(value ?? ''))
                ? null
                : s.t(
                    'أدخل رقم جوال صحيحًا يبدأ بـ 05 أو +9665',
                    'Enter a valid number starting with 05 or +9665',
                  ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('registerCity'),
            controller: _city,
            enabled: !auth.busy,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.addressCity],
            decoration: _decoration(
              s.t('المدينة', 'City'),
              Icons.location_on_outlined,
            ),
            validator: (value) =>
                (value?.trim().length ?? 0) >= 2 &&
                    (value?.trim().length ?? 0) <= 80
                ? null
                : s.t(
                    'أدخل اسم المدينة من حرفين إلى ٨٠ حرفًا',
                    'Enter a city from 2 to 80 characters',
                  ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const ValueKey('registerRole'),
            initialValue: _role,
            decoration: _decoration(
              s.t('نوع الحساب', 'Account type'),
              Icons.badge_outlined,
            ),
            items: [
              DropdownMenuItem(
                value: 'customer',
                child: Text(
                  s.t('عميل • أطلب خدمة', 'Customer • Request a service'),
                ),
              ),
              DropdownMenuItem(
                value: 'provider',
                child: Text(
                  s.t('مقدم خدمة • أقدم عروضًا', 'Provider • Submit offers'),
                ),
              ),
            ],
            isExpanded: true,
            onChanged: auth.busy
                ? null
                : (value) => setState(() => _role = value!),
          ),
          const SizedBox(height: 16),
          _passwordField(
            controller: _password,
            label: s.t(
              'كلمة المرور (١٠ أحرف على الأقل)',
              'Password (at least 10 characters)',
            ),
            hidden: _hidePassword,
            onVisibility: () => setState(() => _hidePassword = !_hidePassword),
            fieldKey: 'registerPassword',
            validator: _validatePassword,
          ),
          const SizedBox(height: 16),
          _passwordField(
            controller: _confirmation,
            label: s.t('تأكيد كلمة المرور', 'Confirm password'),
            hidden: _hideConfirmation,
            onVisibility: () =>
                setState(() => _hideConfirmation = !_hideConfirmation),
            fieldKey: 'registerConfirmation',
            validator: (value) =>
                value != _password.text || (value?.isEmpty ?? true)
                ? s.t('كلمتا المرور غير متطابقتين', 'Passwords do not match')
                : null,
            last: true,
            onSubmit: _submitRegistration,
          ),
          const SizedBox(height: 18),
          FormField<bool>(
            key: const ValueKey('registerTerms'),
            initialValue: _terms,
            validator: (_) => _terms
                ? null
                : s.t(
                    'يلزم الموافقة على الشروط والخصوصية',
                    'Accept the terms and privacy notice',
                  ),
            builder: (state) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _terms,
                  onChanged: auth.busy
                      ? null
                      : (value) {
                          setState(() => _terms = value ?? false);
                          state.didChange(_terms);
                        },
                  title: Text(
                    s.t(
                      'أوافق على الشروط والخصوصية',
                      'I accept the terms and privacy notice',
                    ),
                  ),
                ),
                if (state.hasError)
                  Text(
                    state.errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: _showTerms,
              child: Text(
                s.t('قراءة الشروط والخصوصية', 'Read terms and privacy'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            s.t(
              'يُحفظ حسابك على هذا الجهاز فقط. لا يُرسل رمز تحقق للجوال أو البريد في النسخة الجامعية.',
              'Your account is stored only on this device. This university version does not send email or SMS verification codes.',
            ),
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          _submitButton(
            s.t('إنشاء الحساب', 'Create account'),
            _submitRegistration,
            'registerSubmit',
          ),
        ],
      ),
    ),
  );

  Widget _submitButton(String label, VoidCallback action, String key) =>
      FilledButton(
        key: ValueKey(key),
        onPressed: auth.busy ? null : action,
        child: auth.busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([auth, s]),
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: auth.busy
                ? null
                : () {
                    s.english = !s.english;
                    s.save();
                  },
            icon: const Icon(Icons.language, size: 18),
            label: Text(s.english ? 'العربية' : 'English'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: CircleAvatar(
                      radius: 34,
                      backgroundColor: pale,
                      child: Icon(
                        Icons.verified_user_rounded,
                        color: green,
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.t('ثقة', 'TRUST'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontSize: 32),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.t('خدماتك تبدأ بحسابك', 'Your services start here'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: muted),
                  ),
                  const SizedBox(height: 26),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _registering
                              ? s.t('إنشاء حساب جديد', 'Create a new account')
                              : s.t('أهلًا بعودتك', 'Welcome back'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _registering
                              ? s.t(
                                  'عبّئ جميع البيانات التالية لبدء استخدام ثقة.',
                                  'Complete all fields below to start using Trust.',
                                )
                              : s.t(
                                  'سجّل دخولك للوصول إلى حسابك وخدماتك.',
                                  'Sign in to access your account and services.',
                                ),
                          style: const TextStyle(color: muted, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        if (auth.errorCode != null) ...[
                          AuthErrorNotice(
                            authErrorText(auth.errorCode!, s.english),
                          ),
                          const SizedBox(height: 18),
                        ],
                        if (_registering)
                          _registrationFields()
                        else
                          _loginFields(),
                        const SizedBox(height: 14),
                        TextButton(
                          key: const ValueKey('toggleAuthMode'),
                          onPressed: auth.busy ? null : _toggle,
                          child: Text(
                            _registering
                                ? s.t(
                                    'لديك حساب؟ تسجيل الدخول',
                                    'Already have an account? Sign in',
                                  )
                                : s.t(
                                    'ليس لديك حساب؟ إنشاء حساب جديد',
                                    'No account? Create a new account',
                                  ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
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

class AuthErrorNotice extends StatelessWidget {
  const AuthErrorNotice(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({
    super.key,
    required this.store,
    required this.auth,
  });
  final TrustStore store;
  final AuthController auth;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _hidden = [true, true, true];
  TrustStore get s => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.auth.clearError();
    });
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.auth.busy || !(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final success = await widget.auth.changePassword(_current.text, _next.text);
    if (!mounted || !success) return;
    TextInput.finishAutofillContext();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.t('تم تغيير كلمة المرور بنجاح', 'Password changed successfully'),
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  Widget _field(
    int index,
    TextEditingController controller,
    String label,
    String? Function(String?) validator,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      key: ValueKey('changePassword$index'),
      controller: controller,
      enabled: !widget.auth.busy,
      obscureText: _hidden[index],
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: index == 2 ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: index == 2 ? (_) => _submit() : null,
      autofillHints: [
        index == 0 ? AutofillHints.password : AutofillHints.newPassword,
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _hidden[index]
              ? s.t('إظهار كلمة المرور', 'Show password')
              : s.t('إخفاء كلمة المرور', 'Hide password'),
          onPressed: () => setState(() => _hidden[index] = !_hidden[index]),
          icon: Icon(
            _hidden[index]
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
      validator: validator,
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.auth, s]),
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(s.t('تغيير كلمة المرور', 'Change password'))),
      body: SafeArea(
        top: false,
        child: PageBody(
          children: [
            const SizedBox(height: 12),
            Panel(
              child: Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        s.t(
                          'اختر كلمة مرور جديدة خاصة بك.',
                          'Choose a new password that is unique to you.',
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.t(
                          'ستُحدّث كلمة المرور للحساب المحلي على هذا الجهاز.',
                          'This changes the password for your local account on this device.',
                        ),
                        style: const TextStyle(color: muted, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      if (widget.auth.errorCode != null) ...[
                        AuthErrorNotice(
                          authErrorText(widget.auth.errorCode!, s.english),
                        ),
                        const SizedBox(height: 18),
                      ],
                      _field(
                        0,
                        _current,
                        s.t('كلمة المرور الحالية', 'Current password'),
                        (value) => value == null || value.isEmpty
                            ? s.t(
                                'أدخل كلمة المرور الحالية',
                                'Enter your current password',
                              )
                            : null,
                      ),
                      _field(
                        1,
                        _next,
                        s.t('كلمة المرور الجديدة', 'New password'),
                        (value) {
                          if (value == null ||
                              value.length < 10 ||
                              value.length > 128) {
                            return s.t(
                              'استخدم من ١٠ إلى ١٢٨ حرفًا',
                              'Use 10 to 128 characters',
                            );
                          }
                          if (value == _current.text) {
                            return s.t(
                              'اختر كلمة مرور مختلفة عن الحالية',
                              'Choose a different password',
                            );
                          }
                          return null;
                        },
                      ),
                      _field(
                        2,
                        _confirm,
                        s.t(
                          'تأكيد كلمة المرور الجديدة',
                          'Confirm new password',
                        ),
                        (value) =>
                            value != _next.text || (value?.isEmpty ?? true)
                            ? s.t(
                                'كلمتا المرور غير متطابقتين',
                                'Passwords do not match',
                              )
                            : null,
                      ),
                      FilledButton(
                        key: const ValueKey('changePasswordSubmit'),
                        onPressed: widget.auth.busy ? null : _submit,
                        child: widget.auth.busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(s.t('حفظ كلمة المرور', 'Save password')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
