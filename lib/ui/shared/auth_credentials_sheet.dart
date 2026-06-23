import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/kubely_colors.dart';
import '../../core/theme/kubely_typography.dart';
import '../../core/theme/kubely_radii.dart';
import '../../data/services/aws_auth.dart';

class AwsCredentialsSheet extends StatefulWidget {
  const AwsCredentialsSheet({super.key});

  static Future<AwsCredentials?> show(BuildContext context) {
    return showModalBottomSheet<AwsCredentials>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const AwsCredentialsSheet(),
    );
  }

  @override
  State<AwsCredentialsSheet> createState() => _AwsCredentialsSheetState();
}

class _AwsCredentialsSheetState extends State<AwsCredentialsSheet> {
  final _accessKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _sessionTokenController = TextEditingController();
  bool _showSecret = false;

  @override
  void dispose() {
    _accessKeyController.dispose();
    _secretKeyController.dispose();
    _sessionTokenController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _accessKeyController.text.trim().isNotEmpty &&
      _secretKeyController.text.trim().isNotEmpty;

  void _submit() {
    if (!_isValid) return;
    Navigator.of(context).pop(AwsCredentials(
      accessKeyId: _accessKeyController.text.trim(),
      secretAccessKey: _secretKeyController.text.trim(),
      sessionToken: _sessionTokenController.text.trim().isEmpty
          ? null
          : _sessionTokenController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: KubelyColors.sheetBackground,
          borderRadius: KubelyRadii.sheet,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: bottomPadding + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: KubelyColors.textFaint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: KubelyColors.providerEks.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(LucideIcons.key,
                        size: 20, color: KubelyColors.providerEks),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AWS Credentials',
                          style: KubelyTypography.appBarTitle),
                      const SizedBox(height: 2),
                      Text('Required for EKS cluster access',
                          style: KubelyTypography.caption
                              .copyWith(color: KubelyColors.textDim)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Access Key
              Text('Access Key ID',
                  style: KubelyTypography.eyebrow
                      .copyWith(fontSize: 10, letterSpacing: 0.9)),
              const SizedBox(height: 6),
              _CredentialField(
                controller: _accessKeyController,
                hint: 'AKIAIOSFODNN7EXAMPLE',
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 14),

              // Secret Key
              Row(
                children: [
                  Text('Secret Access Key',
                      style: KubelyTypography.eyebrow
                          .copyWith(fontSize: 10, letterSpacing: 0.9)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showSecret = !_showSecret),
                    child: Icon(
                      _showSecret ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 14,
                      color: KubelyColors.textDim,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _CredentialField(
                controller: _secretKeyController,
                hint: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
                obscure: !_showSecret,
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 14),

              // Session Token (optional)
              Text('Session Token (optional)',
                  style: KubelyTypography.eyebrow
                      .copyWith(fontSize: 10, letterSpacing: 0.9)),
              const SizedBox(height: 6),
              _CredentialField(
                controller: _sessionTokenController,
                hint: 'For temporary credentials (STS)',
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 12),

              // Security note
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: KubelyColors.running.withValues(alpha: 0.06),
                  border: Border.all(
                      color: KubelyColors.running.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.shieldCheck,
                        size: 14, color: KubelyColors.running),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stored encrypted on this device only',
                        style: KubelyTypography.caption.copyWith(
                            color: KubelyColors.running, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 50,
                child: GestureDetector(
                  onTap: _isValid ? _submit : null,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _isValid
                          ? KubelyColors.providerEks
                          : KubelyColors.textDim,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text('Authenticate',
                        style: KubelyTypography.buttonText
                            .copyWith(fontSize: 14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CredentialField extends StatelessWidget {
  const _CredentialField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: KubelyColors.inkDeep,
        border: Border.all(color: KubelyColors.hairline),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: KubelyTypography.monoBody.copyWith(fontSize: 12),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: KubelyTypography.monoCaption
              .copyWith(color: KubelyColors.textFaint),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
