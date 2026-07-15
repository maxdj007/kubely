import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/kubely_colors.dart';
import '../../core/theme/kubely_typography.dart';
import '../../core/theme/kubely_radii.dart';
import '../../data/services/gcp_auth.dart';

class GkeAuthSheet extends StatefulWidget {
  const GkeAuthSheet({super.key});

  static Future<GcpTokenResponse?> show(BuildContext context) {
    return showModalBottomSheet<GcpTokenResponse>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      builder: (_) => const GkeAuthSheet(),
    );
  }

  @override
  State<GkeAuthSheet> createState() => _GkeAuthSheetState();
}

enum _GkeAuthStep { loading, showCode, polling, done, error }

class _GkeAuthSheetState extends State<GkeAuthSheet> {
  _GkeAuthStep _step = _GkeAuthStep.loading;
  DeviceCodeResponse? _deviceCode;
  String _errorMessage = '';

  static const _clientId =
      '764086051850-6qr4p6gpi6hn506pt8ejuq83di341hur.apps.googleusercontent.com';

  @override
  void initState() {
    super.initState();
    _startFlow();
  }

  Future<void> _startFlow() async {
    final gcp = GcpDeviceAuth(clientId: _clientId);
    try {
      setState(() => _step = _GkeAuthStep.loading);
      final deviceCode = await gcp.requestDeviceCode();
      setState(() {
        _deviceCode = deviceCode;
        _step = _GkeAuthStep.showCode;
      });

      // Start polling
      setState(() => _step = _GkeAuthStep.polling);
      final token = await gcp.pollForToken(deviceCode);
      setState(() => _step = _GkeAuthStep.done);

      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.of(context).pop(token);
    } on GcpAuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _step = _GkeAuthStep.error;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start auth flow: $e';
        _step = _GkeAuthStep.error;
      });
    } finally {
      gcp.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: KubelyColors.sheetBackground,
        borderRadius: KubelyRadii.sheet,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: bottomPadding + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: KubelyColors.textFaint,
              borderRadius: BorderRadius.circular(2),
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
                  color: KubelyColors.providerGke.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(LucideIcons.globe,
                    size: 20, color: KubelyColors.providerGke),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Google Cloud Auth',
                      style: KubelyTypography.appBarTitle),
                  const SizedBox(height: 2),
                  Text('Sign in for GKE cluster access',
                      style: KubelyTypography.caption
                          .copyWith(color: KubelyColors.textDim)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          if (_step == _GkeAuthStep.loading)
            _buildLoading()
          else if (_step == _GkeAuthStep.showCode ||
              _step == _GkeAuthStep.polling)
            _buildCodeView()
          else if (_step == _GkeAuthStep.done)
            _buildDone()
          else if (_step == _GkeAuthStep.error)
            _buildError(),

          const SizedBox(height: 16),

          if (_step == _GkeAuthStep.error)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: KubelyColors.surface,
                        border: Border.all(color: KubelyColors.hairline),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Cancel',
                          style: KubelyTypography.sectionLabel
                              .copyWith(color: KubelyColors.textMuted)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _startFlow,
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: KubelyColors.providerGke,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Retry',
                          style: KubelyTypography.buttonText
                              .copyWith(fontSize: 14)),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(KubelyColors.providerGke),
          ),
        ),
        const SizedBox(height: 14),
        Text('Requesting device code...',
            style: KubelyTypography.body
                .copyWith(color: KubelyColors.textDim)),
      ],
    );
  }

  Widget _buildCodeView() {
    return Column(
      children: [
        Text('Open this URL in your browser:',
            style: KubelyTypography.body
                .copyWith(color: KubelyColors.textMuted)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            Clipboard.setData(
                ClipboardData(text: _deviceCode!.verificationUrl));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: KubelyColors.surface,
              border: Border.all(color: KubelyColors.hairline),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.externalLink,
                    size: 14, color: KubelyColors.providerGke),
                const SizedBox(width: 8),
                Text(_deviceCode!.verificationUrl,
                    style: KubelyTypography.monoBody
                        .copyWith(color: KubelyColors.providerGke, fontSize: 12)),
                const SizedBox(width: 8),
                Icon(LucideIcons.copy,
                    size: 12, color: KubelyColors.textDim),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Enter this code:',
            style: KubelyTypography.body
                .copyWith(color: KubelyColors.textMuted)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: _deviceCode!.userCode));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: KubelyColors.inkDeep,
              border: Border.all(
                  color: KubelyColors.providerGke.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _deviceCode!.userCode,
              style: KubelyTypography.monoHeroMetric.copyWith(
                fontSize: 28,
                letterSpacing: 4,
                color: KubelyColors.providerGke,
              ),
            ),
          ),
        ),
        if (_step == _GkeAuthStep.polling) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation(KubelyColors.textDim),
                ),
              ),
              const SizedBox(width: 8),
              Text('Waiting for approval...',
                  style: KubelyTypography.caption
                      .copyWith(color: KubelyColors.textDim)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDone() {
    return Column(
      children: [
        Icon(LucideIcons.checkCircle,
            size: 40, color: KubelyColors.running),
        const SizedBox(height: 12),
        Text('Authenticated',
            style: KubelyTypography.sectionLabel
                .copyWith(color: KubelyColors.running, fontSize: 16)),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      children: [
        Icon(LucideIcons.alertCircle,
            size: 40, color: KubelyColors.critical),
        const SizedBox(height: 12),
        Text(_errorMessage,
            style: KubelyTypography.body
                .copyWith(color: KubelyColors.criticalText),
            textAlign: TextAlign.center),
      ],
    );
  }
}
