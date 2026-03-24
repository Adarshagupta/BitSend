import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:solana/solana.dart' show isValidAddress;

import '../app/app.dart';
import '../app/theme.dart';
import '../models/app_models.dart';
import '../services/transport_contract.dart';
import '../state/app_state.dart';
import '../widgets/app_widgets.dart';
import '../widgets/chain_logo.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen>
    with SingleTickerProviderStateMixin {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    final BitsendAppState state = BitsendStateScope.of(context);
    try {
      await state.initialize().timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException(
          'Startup is taking too long. Check the backend endpoint or network, then reopen the app.',
        ),
      );
      if (!mounted) {
        return;
      }
      if (state.hasWallet) {
        state.lockWalletForSession();
        Navigator.of(context).pushReplacementNamed(AppRoutes.unlock);
        return;
      }
      Navigator.of(context).pushReplacementNamed(state.bootRoute);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _messageFor(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                const _BobbingBrandLogo(
                  tone: BitsendLogoTone.transparent,
                  height: 96,
                ),
                const SizedBox(height: 8),
                Text(
                  'Offline handoff now. Online settlement later.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.slate),
                ),
                const SizedBox(height: 32),
                if (_error == null)
                  const LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: AppColors.line,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.ink),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _error!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: AppColors.ink),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _initialize,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.line),
                        ),
                        child: const Text('Retry startup'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BobbingBrandLogo extends StatefulWidget {
  const _BobbingBrandLogo({
    required this.tone,
    required this.height,
    this.distance = 10,
  });

  final BitsendLogoTone tone;
  final double height;
  final double distance;

  @override
  State<_BobbingBrandLogo> createState() => _BobbingBrandLogoState();
}

class _BobbingBrandLogoState extends State<_BobbingBrandLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _lift;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _lift = Tween<double>(
      begin: 0,
      end: -widget.distance,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _lift,
      builder: (BuildContext context, Widget? child) {
        return Transform.translate(
          offset: Offset(0, _lift.value),
          child: child,
        );
      },
      child: BitsendBrandLogo(tone: widget.tone, height: widget.height),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BitsendPageScaffold(
      title: 'Welcome',
      showBack: false,
      showHeader: false,
      scrollable: false,
      child: FadeSlideIn(
        delay: 0,
        child: _WelcomeHero(
          onContinue: () {
            Navigator.of(
              context,
            ).pushReplacementNamed(AppRoutes.onboardingWallet);
          },
        ),
      ),
    );
  }
}

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  String? _error;
  bool _unlocking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _unlock();
    });
  }

  Future<void> _unlock() async {
    if (_unlocking) {
      return;
    }
    final BitsendAppState state = BitsendStateScope.of(context);
    if (state.requiresBiometricSetup) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error =
            'Bitsend requires fingerprint or face unlock. Set up biometrics in system settings, then reopen Bitsend.';
      });
      return;
    }
    if (!state.requiresDeviceUnlock) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      return;
    }
    setState(() {
      _unlocking = true;
      _error = null;
    });
    try {
      final bool unlocked = await state.authenticateDevice(
        forcePrompt: true,
        reason: 'Unlock Bitsend with your ${state.deviceUnlockMethodLabel}.',
      );
      if (!mounted) {
        return;
      }
      if (unlocked) {
        final String route =
            state.pendingHomeWidgetRoute ?? AppRoutes.home;
        state.clearPendingHomeWidgetRoute();
        Navigator.of(context).pushReplacementNamed(route);
        return;
      }
      setState(() {
        _error =
            'Unlock was cancelled. Use your ${state.deviceUnlockMethodLabel} to continue.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _messageFor(error);
      });
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _unlocking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final bool needsBiometricSetup = state.requiresBiometricSetup;
    return BitsendPageScaffold(
      title: needsBiometricSetup ? 'Set up biometrics' : 'Unlock wallet',
      subtitle: needsBiometricSetup
          ? 'Bitsend requires biometric unlock before opening the wallet.'
          : 'Use your ${state.deviceUnlockMethodLabel} before opening Bitsend.',
      showBack: false,
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  needsBiometricSetup
                      ? Icons.fingerprint_rounded
                      : Icons.fingerprint_rounded,
                  size: 32,
                  color: AppColors.ink,
                ),
                const SizedBox(height: 16),
                Text(
                  needsBiometricSetup
                      ? 'Biometric unlock required'
                      : 'Security check',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  needsBiometricSetup
                      ? 'Add a fingerprint or face unlock in your phone settings. Bitsend will stay locked until biometrics are enrolled.'
                      : 'Bitsend will ask for your ${state.deviceUnlockMethodLabel} before showing wallet data on this device.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 16),
            InlineBanner(
              title: 'Unlock required',
              caption: _error!,
              icon: Icons.lock_clock_rounded,
            ),
          ],
        ],
      ),
      bottom: Row(
        children: <Widget>[
          if (needsBiometricSetup)
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  await state.openSystemSettings();
                },
                child: const Text('Open settings'),
              ),
            ),
          if (needsBiometricSetup) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _unlocking ? null : _unlock,
              child: Text(
                needsBiometricSetup
                    ? 'Check again'
                    : (_unlocking
                          ? 'Checking ${state.deviceUnlockMethodLabel}...'
                          : 'Unlock now'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WalletSetupScreen extends StatefulWidget {
  const WalletSetupScreen({super.key});

  @override
  State<WalletSetupScreen> createState() => _WalletSetupScreenState();
}

enum _WalletSetupAction { create, restore }

class _WalletSetupScreenState extends State<WalletSetupScreen> {
  final TextEditingController _phraseController = TextEditingController();
  String? _backupPath;
  _WalletSetupAction? _activeSetupAction;
  bool _recoveryPhraseVisible = false;

  @override
  void dispose() {
    _phraseController.dispose();
    super.dispose();
  }

  Future<void> _createWallet(BitsendAppState state) async {
    if (_activeSetupAction != null) {
      return;
    }
    setState(() {
      _activeSetupAction = _WalletSetupAction.create;
      _backupPath = null;
      _recoveryPhraseVisible = false;
    });
    try {
      await state.createWallet();
    } catch (error) {
      _showSnack(context, _messageFor(error));
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _activeSetupAction = null;
      });
    }
  }

  Future<void> _restoreWallet(BitsendAppState state) async {
    if (_activeSetupAction != null) {
      return;
    }
    setState(() {
      _activeSetupAction = _WalletSetupAction.restore;
      _backupPath = null;
      _recoveryPhraseVisible = false;
    });
    try {
      await state.restoreWallet(_phraseController.text);
    } catch (error) {
      _showSnack(context, _messageFor(error));
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _activeSetupAction = null;
      });
    }
  }

  Future<void> _exportBackup(BitsendAppState state) async {
    final bool authorized = await _authorizeDeviceAction(
      context,
      state,
      reason:
          'Confirm your ${state.deviceUnlockMethodLabel} before exporting the wallet backup.',
    );
    if (!authorized) {
      return;
    }
    try {
      final WalletBackupExport export = await state.exportWalletBackup();
      if (!mounted) {
        return;
      }
      setState(() {
        _backupPath = export.filePath;
      });
      _showSnack(context, 'Backup saved as ${export.fileName}.');
    } catch (error) {
      _showSnack(context, _messageFor(error));
    }
  }

  Future<void> _copyPhrase(BitsendAppState state) async {
    final WalletProfile? wallet = state.wallet;
    if (wallet == null) {
      return;
    }
    final bool authorized = await _authorizeDeviceAction(
      context,
      state,
      reason:
          'Confirm your ${state.deviceUnlockMethodLabel} before copying the recovery phrase.',
    );
    if (!authorized) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: wallet.seedPhrase));
    if (!mounted) {
      return;
    }
    _showSnack(context, 'Recovery phrase copied.');
  }

  Future<void> _revealRecoveryPhrase(BitsendAppState state) async {
    final WalletProfile? wallet = state.wallet;
    if (wallet == null) {
      return;
    }
    final bool authorized = await _authorizeDeviceAction(
      context,
      state,
      reason:
          'Confirm your ${state.deviceUnlockMethodLabel} before revealing the recovery phrase.',
    );
    if (!authorized || !mounted) {
      return;
    }
    setState(() {
      _recoveryPhraseVisible = true;
    });
  }

  Future<void> _copyBackupPath() async {
    final String? backupPath = _backupPath;
    if (backupPath == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: backupPath));
    if (!mounted) {
      return;
    }
    _showSnack(context, 'Backup path copied.');
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final WalletProfile? wallet = state.wallet;
    final WalletProfile? offlineWallet = state.offlineWallet;
    final bool walletReady = wallet != null;
    final bool isCreated = wallet?.mode == WalletSetupMode.created;
    final bool creatingWallet = _activeSetupAction == _WalletSetupAction.create;
    final bool restoringWallet =
        _activeSetupAction == _WalletSetupAction.restore;
    final bool setupActionRunning = _activeSetupAction != null;
    final bool hideRecoveryPhrase =
        state.deviceAuthAvailable && !_recoveryPhraseVisible;
    return BitsendPageScaffold(
      title: walletReady ? 'Secure your wallet' : 'Set up this device',
      subtitle: walletReady
          ? 'Download the backup before you continue to funding.'
          : 'Create a wallet or restore an existing one.',
      child: walletReady
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.emeraldTint.withValues(
                                alpha: 0.92,
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              isCreated
                                  ? Icons.verified_user_rounded
                                  : Icons.restore_rounded,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  isCreated
                                      ? 'Wallet created'
                                      : 'Wallet restored',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isCreated
                                      ? 'Save the backup file now. It includes the recovery phrase and the main-wallet private keys.'
                                      : 'This wallet is live on this device. Save another backup file if you need an offline copy.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      DetailRow(
                        label: 'Main wallet',
                        value: wallet.displayAddress,
                      ),
                      DetailRow(
                        label: 'Offline wallet',
                        value:
                            offlineWallet?.displayAddress ??
                            'Device signer unavailable',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const InlineBanner(
                  title: 'Handle with care',
                  caption:
                      'The backup file contains sensitive key material. Move it to safe storage and delete stray copies after saving it.',
                  icon: Icons.key_rounded,
                ),
                const SizedBox(height: 16),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Recovery phrase',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This phrase restores the main wallet only. The offline wallet stays on this device and is not recoverable from the phrase.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      if (!hideRecoveryPhrase)
                        SelectableText(
                          wallet.seedPhrase,
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        Text(
                          'Use your ${state.deviceUnlockMethodLabel} to reveal the recovery phrase on this device.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: hideRecoveryPhrase
                                ? () => _revealRecoveryPhrase(state)
                                : null,
                            icon: Icon(
                              hideRecoveryPhrase
                                  ? Icons.fingerprint_rounded
                                  : Icons.lock_open_rounded,
                            ),
                            label: Text(
                              hideRecoveryPhrase
                                  ? 'Reveal phrase'
                                  : 'Phrase unlocked',
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: state.working
                                ? null
                                : () => _exportBackup(state),
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Download backup'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _copyPhrase(state),
                            icon: const Icon(Icons.copy_rounded),
                            label: const Text('Copy phrase'),
                          ),
                        ],
                      ),
                      if (_backupPath != null) ...<Widget>[
                        const SizedBox(height: 18),
                        Text(
                          'Saved file',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          _backupPath!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: _copyBackupPath,
                          icon: const Icon(Icons.content_paste_go_rounded),
                          label: const Text('Copy file path'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'New wallet',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Generate a wallet for this device and continue to funding.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: state.working || setupActionRunning
                            ? null
                            : () => _createWallet(state),
                        child: creatingWallet
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Creating wallet...'),
                                ],
                              )
                            : const Text('Create new wallet'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Restore wallet',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Paste the recovery phrase used by this wallet.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _phraseController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Enter recovery phrase',
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: state.working || setupActionRunning
                            ? null
                            : () => _restoreWallet(state),
                        child: restoringWallet
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Restoring wallet...'),
                                ],
                              )
                            : const Text('Restore wallet'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottom: walletReady
          ? ElevatedButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pushReplacementNamed(AppRoutes.onboardingFund);
              },
              child: const Text('Continue to funding'),
            )
          : null,
    );
  }
}

class FundWalletScreen extends StatelessWidget {
  const FundWalletScreen({super.key});

  Future<void> _copyAddress(BuildContext context, BitsendAppState state) async {
    final String? address = state.wallet?.address;
    if (address == null || address.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: address));
    if (!context.mounted) {
      return;
    }
    _showSnack(context, 'Address copied.');
  }

  Future<void> _requestAirdrop(
    BuildContext context,
    BitsendAppState state,
  ) async {
    try {
      await state.requestAirdrop();
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    }
  }

  Future<void> _refresh(BuildContext context, BitsendAppState state) async {
    try {
      await state.refreshStatus();
      if (state.hasInternet) {
        await state.refreshWalletData();
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    }
  }

  void _skip(BuildContext context) {
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final ChainKind chain = state.activeChain;
    final bool funded = state.hasEnoughFunding;
    final ChainNetwork network = state.activeNetwork;
    final double minimumFunding = chain.minimumFundingAmountFor(network);
    final bool canAirdrop =
        chain == ChainKind.solana && network.supportsAirdrop;
    return BitsendPageScaffold(
      title: 'Fund this wallet',
      subtitle: canAirdrop
          ? 'Add a little test SOL now, or skip and fund it later from Home.'
          : 'Send ${chain.assetDisplayLabel} on ${network.shortLabelFor(chain)}, or skip and fund it later from Home.',
      onRefresh: state.working ? null : () => _refresh(context, state),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.amberTint.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        funded
                            ? Icons.account_balance_wallet_rounded
                            : Icons.south_west_rounded,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            funded
                                ? 'Wallet funded'
                                : 'Needs ${chain.shortLabel}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            funded
                                ? 'Setup balance is ready. You can enter the app and top up the offline wallet later.'
                                : 'Target ${Formatters.asset(minimumFunding, chain)} so setup can move forward cleanly.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  Formatters.asset(state.mainBalanceSol, chain),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Main wallet balance',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                DetailRow(
                  label: 'Wallet',
                  value: state.wallet?.displayAddress ?? 'Wallet missing',
                ),
                DetailRow(
                  label: 'Address',
                  value:
                      state.wallet?.address ??
                      'Create or restore a wallet first.',
                ),
                if (chain.isEvm) ...<Widget>[
                  const SizedBox(height: 14),
                  InlineBanner(
                    title: 'Shared EVM address',
                    caption: chain.addressScopeNoteFor(network),
                    icon: Icons.hub_rounded,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  canAirdrop
                      ? 'Get test SOL'
                      : 'Fund on ${network.shortLabelFor(chain)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  canAirdrop
                      ? 'Request 1 SOL from the devnet faucet, then refresh the balance.'
                      : 'Copy the address, fund it on ${network.labelFor(chain)}, then refresh the balance.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: state.working
                            ? null
                            : canAirdrop
                            ? () => _requestAirdrop(context, state)
                            : () => _copyAddress(context, state),
                        child: Text(
                          canAirdrop ? 'Airdrop 1 SOL' : 'Copy address',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: state.working
                            ? null
                            : () => _refresh(context, state),
                        child: const Text('Refresh balance'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _MiniCue(
                      icon: Icons.cloud_done_rounded,
                      label: network.shortLabelFor(chain),
                      active: state.hasDevnet,
                    ),
                    _MiniCue(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Min ${Formatters.asset(minimumFunding, chain)}',
                      active: funded,
                    ),
                    _MiniCue(
                      icon: Icons.skip_next_rounded,
                      label: 'Skip later',
                      active: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InlineBanner(
            title: funded ? 'Ready to continue' : 'Funding can wait',
            caption: funded
                ? 'The wallet has enough ${chain.shortLabel} for setup.'
                : canAirdrop
                ? 'If the faucet is slow, skip for now and come back from Deposit or Home later.'
                : 'Skip for now, then fund from Deposit on ${network.shortLabelFor(chain)} later.',
            icon: funded
                ? Icons.check_circle_outline_rounded
                : Icons.schedule_rounded,
          ),
        ],
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ElevatedButton(
            onPressed: funded
                ? () {
                    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
                  }
                : null,
            child: const Text('Continue'),
          ),
          if (!funded) ...<Widget>[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _skip(context),
              child: const Text('Skip for now'),
            ),
          ],
        ],
      ),
    );
  }
}

class OnboardingPrepareScreen extends StatelessWidget {
  const OnboardingPrepareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final WalletSummary summary = state.walletSummary;
    final ChainKind chain = state.activeChain;
    final String mainAddress =
        state.wallet?.displayAddress ?? 'Main unavailable';
    final String offlineAddress = summary.offlineWalletAddress == null
        ? 'Offline unavailable'
        : Formatters.shortAddress(summary.offlineWalletAddress!);
    return BitsendPageScaffold(
      title: 'Offline wallet',
      subtitle:
          'A device-bound ${chain.shortLabel} signer lives on this phone only. Top it up from Home before any offline send.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _OfflineWalletScene(
            summary: summary,
            hasWallet: state.hasWallet,
            pendingCount: 0,
            mainUsdTotal: null,
            offlineUsdTotal: null,
            spendableUsdTotal: null,
            onShowInfo: () {
              _showOfflineWalletInfoSheet(
                context,
                summary: summary,
                pendingCount: 0,
              );
            },
          ),
          const SizedBox(height: 14),
          SectionCard(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Before your first nearby send',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 14),
                _PrepareInfoRow(
                  label: 'Local endpoint',
                  value:
                      summary.localEndpoint ??
                      'Appears when Receive is listening',
                ),
                const SizedBox(height: 12),
                _PrepareInfoRow(label: 'Main wallet', value: mainAddress),
                const SizedBox(height: 12),
                _PrepareInfoRow(label: 'Offline wallet', value: offlineAddress),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InlineBanner(
            title: 'Permissions',
            caption: state.localPermissionsGranted
                ? 'Local transport access is already granted.'
                : 'Android needs nearby-device access for local transport. Older Android versions may also ask for location.',
            icon: Icons.perm_device_information_rounded,
          ),
        ],
      ),
      bottom: ElevatedButton(
        onPressed: () {
          Navigator.of(context).pushReplacementNamed(AppRoutes.home);
        },
        child: const Text('Go to home'),
      ),
    );
  }
}

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  String? _selectedAssetId;

  Future<void> _refreshAssets(BitsendAppState state) async {
    try {
      await state.refreshStatus();
      if (state.hasInternet) {
        await state.refreshPortfolioBalances();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    }
  }

  Future<void> _importToken(BitsendAppState state) async {
    final TextEditingController controller = TextEditingController();
    try {
      final String? contractAddress = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Import token'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Contract address',
                hintText: '0x...',
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(controller.text.trim());
                },
                child: const Text('Import'),
              ),
            ],
          );
        },
      );
      if (!mounted || contractAddress == null || contractAddress.isEmpty) {
        return;
      }
      final TrackedAssetDefinition asset = await state.importTrackedToken(
        contractAddress: contractAddress,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedAssetId = asset.id;
      });
      _showSnack(context, '${asset.symbol} imported.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    } finally {
      controller.dispose();
    }
  }

  AssetPortfolioHolding _resolveFeaturedHolding(
    List<AssetPortfolioHolding> holdings,
    ChainKind fallbackChain,
  ) {
    final String preferredAssetId =
        _selectedAssetId ??
        '${fallbackChain.name}:${BitsendStateScope.of(context).activeNetwork.name}:native';
    for (final AssetPortfolioHolding holding in holdings) {
      if (holding.resolvedAssetId == preferredAssetId) {
        return holding;
      }
    }
    return holdings.first;
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final WalletSummary summary = state.walletSummary;
    final List<AssetPortfolioHolding> holdings = state.portfolioHoldings;

    if (holdings.isEmpty) {
      final bool hasWallet = state.hasWallet;
      return BitsendPageScaffold(
        title: 'Assets',
        showBack: false,
        primaryTab: BitsendPrimaryTab.assets,
        onPrimaryTabSelected: (BitsendPrimaryTab tab) {
          _navigatePrimaryTab(context, tab);
        },
        overlay: _HomeDashboardOverlay(
          onScan: state.hasWallet ? () => _scanAndStartSendFromContext(context) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            EmptyStateCard(
              title: hasWallet ? 'No assets yet' : 'No assets yet',
              caption: hasWallet
                  ? 'Deposit into a supported chain and it will appear here.'
                  : 'Create or restore a wallet to view your holdings.',
              icon: Icons.pie_chart_outline_rounded,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pushNamed(hasWallet ? AppRoutes.deposit : AppRoutes.prepare);
              },
              child: Text(hasWallet ? 'Deposit' : 'Set up wallet'),
            ),
          ],
        ),
      );
    }

    final AssetPortfolioHolding featuredHolding = _resolveFeaturedHolding(
      holdings,
      summary.chain,
    );
    final double? featuredHoldingUsd = _usdValueForHolding(
      state,
      featuredHolding,
      featuredHolding.totalBalance,
    );

    return BitsendPageScaffold(
      title: 'Assets',
      showBack: false,
      onRefresh: state.working ? null : () => _refreshAssets(state),
      primaryTab: BitsendPrimaryTab.assets,
      onPrimaryTabSelected: (BitsendPrimaryTab tab) {
        _navigatePrimaryTab(context, tab);
      },
      overlay: _HomeDashboardOverlay(
        onScan: state.hasWallet ? () => _scanAndStartSendFromContext(context) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _FeaturedAssetCard(
            holding: featuredHolding,
            assetCount: holdings.length,
            usdValue: featuredHoldingUsd,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              if (state.activeChain.isEvm)
                OutlinedButton.icon(
                  onPressed: state.working ? null : () => _importToken(state),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Import token'),
                ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.accounts);
                },
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Accounts'),
              ),
              if (state.activeChain.isEvm)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.approvals);
                  },
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Approvals'),
                ),
              if (state.activeChain.isEvm)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.nfts);
                  },
                  icon: const Icon(Icons.collections_outlined),
                  label: const Text('NFTs'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'All assets',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.canvasTint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${holdings.length}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (
                  int index = 0;
                  index < holdings.length;
                  index += 1
                ) ...<Widget>[
                  _AssetHoldingRow(
                    holding: holdings[index],
                    usdValue: _usdValueForHolding(
                      state,
                      holdings[index],
                      holdings[index].totalBalance,
                    ),
                    selected:
                        holdings[index].resolvedAssetId ==
                        featuredHolding.resolvedAssetId,
                    onTap: () {
                      setState(() {
                        _selectedAssetId = holdings[index].resolvedAssetId;
                      });
                    },
                  ),
                  if (index < holdings.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  Future<List<WalletAccountSummary>>? _accountsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _accountsFuture ??= BitsendStateScope.of(
      context,
    ).loadAccountSummariesForActiveChain();
  }

  Future<void> _reload(BitsendAppState state) async {
    final Future<List<WalletAccountSummary>> future = state
        .loadAccountSummariesForActiveChain();
    setState(() {
      _accountsFuture = future;
    });
    await future;
  }

  Future<void> _switchAccount(
    BitsendAppState state,
    WalletAccountSummary summary,
  ) async {
    try {
      await state.switchActiveAccountSlot(summary.slotIndex);
      if (!mounted) {
        return;
      }
      await _reload(state);
      _showSnack(context, '${summary.label} is now active.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    }
  }

  Future<void> _addAccount(BitsendAppState state) async {
    try {
      await state.addAccountForActiveChain();
      if (!mounted) {
        return;
      }
      await _reload(state);
      _showSnack(context, 'Added Account ${state.accountCountForActiveChain}.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final Future<List<WalletAccountSummary>> future = _accountsFuture ??= state
        .loadAccountSummariesForActiveChain();
    return BitsendPageScaffold(
      title: 'Accounts',
      subtitle: 'Switch the active wallet account on this chain.',
      onRefresh: () => _reload(state),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InlineBanner(
            title:
                '${state.activeChain.networkLabelFor(state.activeNetwork)} · ${state.activeWalletEngine.walletLabel}',
            caption:
                'Each account includes a main wallet and a protected signer for nearby sends.',
            icon: Icons.account_balance_wallet_rounded,
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<WalletAccountSummary>>(
            future: future,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<WalletAccountSummary>> snapshot,
                ) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SectionCard(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return SectionCard(
                      child: Text(_messageFor(snapshot.error!)),
                    );
                  }
                  final List<WalletAccountSummary> accounts =
                      snapshot.data ?? const <WalletAccountSummary>[];
                  if (accounts.isEmpty) {
                    return const EmptyStateCard(
                      title: 'No accounts yet',
                      caption: 'Create or restore a wallet to derive accounts.',
                      icon: Icons.account_balance_wallet_outlined,
                    );
                  }
                  return SectionCard(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Column(
                      children: <Widget>[
                        for (
                          int index = 0;
                          index < accounts.length;
                          index += 1
                        ) ...<Widget>[
                          _AccountSummaryRow(
                            summary: accounts[index],
                            onTap: accounts[index].selected
                                ? null
                                : () => _switchAccount(state, accounts[index]),
                          ),
                          if (index < accounts.length - 1)
                            const Divider(height: 1),
                        ],
                      ],
                    ),
                  );
                },
          ),
        ],
      ),
      bottom: FilledButton.icon(
        onPressed: state.working ? null : () => _addAccount(state),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add account'),
      ),
    );
  }
}

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  final TextEditingController _spenderLabelController = TextEditingController();
  final TextEditingController _spenderAddressController =
      TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String? _selectedAssetId;
  TokenAllowanceEntry? _activeEntry;
  TokenAllowanceQuote? _quote;
  bool _working = false;

  @override
  void dispose() {
    _spenderLabelController.dispose();
    _spenderAddressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _preview(BitsendAppState state) async {
    final String? assetId = _selectedAssetId;
    if (assetId == null) {
      return;
    }
    final double amount = double.tryParse(_amountController.text.trim()) ?? -1;
    if (amount < 0) {
      _showSnack(context, 'Enter an allowance amount.');
      return;
    }
    setState(() {
      _working = true;
    });
    try {
      final TokenAllowanceQuote quote = await state.quoteTokenAllowance(
        assetId: assetId,
        spenderAddress: _spenderAddressController.text.trim(),
        amount: amount,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _quote = quote;
      });
    } catch (error) {
      if (mounted) {
        _showSnack(context, _messageFor(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _refreshAllowance(BitsendAppState state) async {
    final String? assetId = _selectedAssetId;
    if (assetId == null) {
      return;
    }
    setState(() {
      _working = true;
    });
    try {
      final TokenAllowanceEntry entry = await state.refreshTokenAllowance(
        assetId: assetId,
        spenderAddress: _spenderAddressController.text.trim(),
        spenderLabel: _spenderLabelController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _activeEntry = entry;
      });
    } catch (error) {
      if (mounted) {
        _showSnack(context, _messageFor(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _approve(BitsendAppState state, {required bool revoke}) async {
    final String? assetId = _selectedAssetId;
    if (assetId == null) {
      return;
    }
    final double amount = revoke
        ? 0
        : (double.tryParse(_amountController.text.trim()) ?? -1);
    if (!revoke && amount < 0) {
      _showSnack(context, 'Enter an allowance amount.');
      return;
    }
    setState(() {
      _working = true;
    });
    try {
      final TokenAllowanceEntry entry = revoke
          ? await state.revokeTokenAllowance(
              assetId: assetId,
              spenderAddress: _spenderAddressController.text.trim(),
              spenderLabel: _spenderLabelController.text.trim(),
            )
          : await state.approveTokenAllowance(
              assetId: assetId,
              spenderAddress: _spenderAddressController.text.trim(),
              spenderLabel: _spenderLabelController.text.trim(),
              amount: amount,
            );
      if (!mounted) {
        return;
      }
      setState(() {
        _activeEntry = entry;
      });
      _showSnack(
        context,
        revoke
            ? '${entry.tokenSymbol} allowance revoked.'
            : '${entry.tokenSymbol} allowance updated.',
      );
    } catch (error) {
      if (mounted) {
        _showSnack(context, _messageFor(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  void _loadSavedEntry(TokenAllowanceEntry entry) {
    setState(() {
      _selectedAssetId = entry.assetId;
      _activeEntry = entry;
      _quote = null;
    });
    _spenderLabelController.text = entry.spenderLabel;
    _spenderAddressController.text = entry.spenderAddress;
    _amountController.text = entry.allowanceAmount.toStringAsFixed(
      entry.allowanceAmount >= 1 ? 3 : 6,
    );
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final List<TrackedAssetDefinition> assets = state.tokenAssetsForActiveScope;
    _selectedAssetId ??= assets.isEmpty ? null : assets.first.id;
    TrackedAssetDefinition? selectedAsset;
    for (final TrackedAssetDefinition asset in assets) {
      if (asset.id == _selectedAssetId) {
        selectedAsset = asset;
        break;
      }
    }
    if (assets.isNotEmpty && selectedAsset == null) {
      _selectedAssetId = assets.first.id;
      selectedAsset = assets.first;
    }
    return BitsendPageScaffold(
      title: 'Approvals',
      subtitle:
          'Review and update ERC-20 allowances for app and spender contracts.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!state.activeChain.isEvm)
            const EmptyStateCard(
              title: 'Approvals are EVM only',
              caption: 'Switch to Ethereum or Base to manage token allowances.',
              icon: Icons.verified_user_outlined,
            )
          else if (assets.isEmpty)
            const EmptyStateCard(
              title: 'No tokens to manage yet',
              caption: 'Import a token or receive one on this network first.',
              icon: Icons.local_offer_outlined,
            )
          else ...<Widget>[
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: selectedAsset?.id,
                    decoration: const InputDecoration(labelText: 'Token'),
                    items: assets
                        .map(
                          (TrackedAssetDefinition asset) =>
                              DropdownMenuItem<String>(
                                value: asset.id,
                                child: Text(
                                  '${asset.symbol} · ${asset.displayName}',
                                ),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: (String? value) {
                      setState(() {
                        _selectedAssetId = value;
                        _activeEntry = null;
                        _quote = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _spenderLabelController,
                    decoration: const InputDecoration(
                      labelText: 'Spender label',
                      hintText: 'Uniswap router',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _spenderAddressController,
                    decoration: const InputDecoration(
                      labelText: 'Spender address',
                      hintText: '0x...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: selectedAsset == null
                          ? 'Allowance amount'
                          : 'Allowance amount (${selectedAsset.symbol})',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      OutlinedButton(
                        onPressed: _working
                            ? null
                            : () => _refreshAllowance(state),
                        child: const Text('Refresh allowance'),
                      ),
                      OutlinedButton(
                        onPressed: _working ? null : () => _preview(state),
                        child: const Text('Preview'),
                      ),
                      FilledButton(
                        onPressed: _working
                            ? null
                            : () => _approve(state, revoke: false),
                        child: const Text('Approve'),
                      ),
                      TextButton(
                        onPressed: _working
                            ? null
                            : () => _approve(state, revoke: true),
                        child: const Text('Revoke'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_activeEntry != null) ...<Widget>[
              const SizedBox(height: 14),
              SectionCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Current allowance',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    DetailRow(
                      label: 'Spender',
                      value: _activeEntry!.resolvedSpenderLabel,
                    ),
                    DetailRow(
                      label: 'Allowance',
                      value: Formatters.tokenAmount(
                        _activeEntry!.allowanceAmount,
                        _activeEntry!.tokenSymbol,
                      ),
                    ),
                    if (_activeEntry!.lastTransactionHash != null)
                      DetailRow(
                        label: 'Last tx',
                        value: Formatters.shortAddress(
                          _activeEntry!.lastTransactionHash!,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (_quote != null && selectedAsset != null) ...<Widget>[
              const SizedBox(height: 14),
              SectionCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Preview',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    DetailRow(
                      label: 'Current',
                      value: Formatters.tokenAmount(
                        selectedAsset.amountFromBaseUnits(
                          _quote!.currentAllowanceBaseUnits,
                        ),
                        selectedAsset.symbol,
                      ),
                    ),
                    DetailRow(
                      label: 'New',
                      value: Formatters.tokenAmount(
                        selectedAsset.amountFromBaseUnits(
                          _quote!.proposedAllowanceBaseUnits,
                        ),
                        selectedAsset.symbol,
                      ),
                    ),
                    DetailRow(
                      label: 'Fee',
                      value: Formatters.asset(
                        state.activeChain.amountFromBaseUnits(
                          _quote!.networkFeeBaseUnits,
                        ),
                        state.activeChain,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (state.allowanceEntriesForActiveScope.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              SectionCard(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                      child: Text(
                        'Saved spenders',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    for (
                      int index = 0;
                      index < state.allowanceEntriesForActiveScope.length;
                      index += 1
                    ) ...<Widget>[
                      _AllowanceEntryRow(
                        entry: state.allowanceEntriesForActiveScope[index],
                        onTap: () => _loadSavedEntry(
                          state.allowanceEntriesForActiveScope[index],
                        ),
                      ),
                      if (index <
                          state.allowanceEntriesForActiveScope.length - 1)
                        const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class NftsScreen extends StatefulWidget {
  const NftsScreen({super.key});

  @override
  State<NftsScreen> createState() => _NftsScreenState();
}

class _NftsScreenState extends State<NftsScreen> {
  bool _refreshing = false;

  Future<void> _refresh(BitsendAppState state) async {
    setState(() {
      _refreshing = true;
    });
    try {
      await state.refreshNftHoldings();
    } catch (error) {
      if (mounted) {
        _showSnack(context, _messageFor(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final BitsendAppState state = BitsendStateScope.of(context);
    if (state.activeChain.isEvm &&
        state.nftHoldingsForActiveScope.isEmpty &&
        !_refreshing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _refresh(state);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final List<NftHolding> holdings = state.nftHoldingsForActiveScope;
    return BitsendPageScaffold(
      title: 'NFTs',
      subtitle: 'ERC-721 collectibles detected on the active wallet account.',
      onRefresh: state.activeChain.isEvm ? () => _refresh(state) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!state.activeChain.isEvm)
            const EmptyStateCard(
              title: 'NFTs are EVM only',
              caption: 'Switch to Ethereum or Base to scan ERC-721 holdings.',
              icon: Icons.collections_outlined,
            )
          else if (_refreshing && holdings.isEmpty)
            const SectionCard(child: Center(child: CircularProgressIndicator()))
          else if (holdings.isEmpty)
            const EmptyStateCard(
              title: 'No NFTs found',
              caption:
                  'Bitsend scans ERC-721 transfer history on the active address when you refresh this page.',
              icon: Icons.image_not_supported_outlined,
            )
          else
            SectionCard(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                children: <Widget>[
                  for (
                    int index = 0;
                    index < holdings.length;
                    index += 1
                  ) ...<Widget>[
                    _NftHoldingRow(holding: holdings[index]),
                    if (index < holdings.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
        ],
      ),
      bottom: OutlinedButton.icon(
        onPressed: _refreshing || !state.activeChain.isEvm
            ? null
            : () => _refresh(state),
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Refresh NFTs'),
      ),
    );
  }
}

class BuyScreen extends StatelessWidget {
  const BuyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final WalletSummary summary = state.walletSummary;
    final String address =
        summary.primaryAddress ?? state.wallet?.address ?? '';
    final List<TrackedAssetDefinition> assets =
        state.trackedAssetsForActiveScope;
    return BitsendPageScaffold(
      title: 'Buy',
      subtitle: 'Add funds to the current wallet account.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Receive on ${state.activeChain.networkLabelFor(state.activeNetwork)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (address.isEmpty)
                  const Text('Create or restore a wallet first.')
                else ...<Widget>[
                  Center(
                    child: QrImageView(
                      data: address,
                      size: 192,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    address,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton(
                      onPressed: address.isEmpty
                          ? null
                          : () {
                              Navigator.of(
                                context,
                              ).pushNamed(AppRoutes.deposit);
                            },
                      child: const Text('Open deposit'),
                    ),
                    OutlinedButton(
                      onPressed: address.isEmpty
                          ? null
                          : () async {
                              await Clipboard.setData(
                                ClipboardData(text: address),
                              );
                              if (context.mounted) {
                                _showSnack(context, 'Address copied.');
                              }
                            },
                      child: const Text('Copy address'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Supported assets',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (final TrackedAssetDefinition asset in assets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: <Widget>[
                        _AssetDefinitionMark(asset: asset),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('${asset.symbol} · ${asset.displayName}'),
                        ),
                        Text(
                          asset.isNative ? 'Native' : 'Token',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.slate),
                        ),
                      ],
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

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  final TextEditingController _amountController = TextEditingController();
  String? _fromAssetId;
  String? _toAssetId;
  SwapQuote? _quote;
  String? _quoteError;
  bool _quoting = false;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  List<AssetPortfolioHolding> _sourceHoldings(BitsendAppState state) {
    return state.portfolioHoldings
        .where(
          (AssetPortfolioHolding holding) =>
              holding.chain == state.activeChain &&
              holding.network == state.activeNetwork &&
              holding.mainBalance > 0,
        )
        .toList(growable: false);
  }

  void _clearQuote() {
    setState(() {
      _quote = null;
      _quoteError = null;
    });
  }

  AssetPortfolioHolding? _findSourceHolding(
    List<AssetPortfolioHolding> holdings,
    String? assetId,
  ) {
    for (final AssetPortfolioHolding holding in holdings) {
      if (holding.resolvedAssetId == assetId) {
        return holding;
      }
    }
    return null;
  }

  TrackedAssetDefinition? _findTrackedAsset(
    List<TrackedAssetDefinition> assets,
    String? assetId,
  ) {
    for (final TrackedAssetDefinition asset in assets) {
      if (asset.id == assetId) {
        return asset;
      }
    }
    return null;
  }

  Future<void> _reviewSwap(BitsendAppState state) async {
    final double amount = double.tryParse(_amountController.text.trim()) ?? -1;
    if (_fromAssetId == null || _toAssetId == null || amount <= 0) {
      setState(() {
        _quote = null;
        _quoteError = 'Choose source, destination, and an amount.';
      });
      return;
    }
    setState(() {
      _quoting = true;
      _quoteError = null;
    });
    try {
      final SwapQuote quote = await state.quoteSwap(
        sellAssetId: _fromAssetId!,
        buyAssetId: _toAssetId!,
        sellAmount: amount,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _quote = quote;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _quote = null;
        _quoteError = _messageFor(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _quoting = false;
        });
      }
    }
  }

  Future<void> _submitSwap(BitsendAppState state) async {
    final double amount = double.tryParse(_amountController.text.trim()) ?? -1;
    if (_fromAssetId == null || _toAssetId == null || amount <= 0) {
      _showSnack(context, 'Choose source, destination, and an amount.');
      return;
    }
    setState(() {
      _submitting = true;
      _quoteError = null;
    });
    try {
      final PendingTransfer transfer = await state.executeSwap(
        sellAssetId: _fromAssetId!,
        buyAssetId: _toAssetId!,
        sellAmount: amount,
      );
      if (!mounted) {
        return;
      }
      _showSnack(context, 'Swap submitted on-chain.');
      await Navigator.of(
        context,
      ).pushNamed(AppRoutes.transferDetail(transfer.transferId));
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String message = _messageFor(error);
      setState(() {
        _quoteError = message;
      });
      _showSnack(context, message);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String _slippageLabel(int? slippageBps) {
    if (slippageBps == null) {
      return 'Auto';
    }
    final double percent = slippageBps / 100;
    return percent == percent.roundToDouble()
        ? '${percent.toStringAsFixed(0)}%'
        : '${percent.toStringAsFixed(1)}%';
  }

  String _routeLabel(SwapQuote quote) {
    final List<String> sources = <String>[];
    for (final SwapRouteFill fill in quote.routeFills) {
      if (fill.source.isEmpty || sources.contains(fill.source)) {
        continue;
      }
      sources.add(fill.source);
    }
    return sources.isEmpty ? '0x route' : sources.join(' + ');
  }

  String _swapSupportCaption(BitsendAppState state) {
    if (!state.activeChain.isEvm) {
      return 'Switch to Ethereum, Base, BNB, or Polygon to swap.';
    }
    if (!state.activeNetwork.isMainnet) {
      return 'Switch this chain to mainnet to use live swaps.';
    }
    if (state.activeWalletEngine != WalletEngine.local) {
      return 'Swaps are available only in Local wallet mode right now.';
    }
    return 'Swap support is not available for this scope yet.';
  }

  String _submitLabel({
    required TrackedAssetDefinition sourceAsset,
    required SwapQuote? quote,
  }) {
    if (_submitting) {
      return 'Submitting...';
    }
    if (quote != null && !sourceAsset.isNative && quote.requiresAllowance) {
      return 'Approve & swap';
    }
    return 'Swap now';
  }

  Widget _quoteCard({
    required BuildContext context,
    required BitsendAppState state,
    required SwapQuote quote,
    required TrackedAssetDefinition sourceAsset,
    required TrackedAssetDefinition destinationAsset,
  }) {
    final double buyAmount = destinationAsset.amountFromBaseUnits(
      quote.buyAmountBaseUnits,
    );
    final double minBuyAmount = destinationAsset.amountFromBaseUnits(
      quote.minBuyAmountBaseUnits,
    );
    final double? routingFee = quote.zeroExFee == null
        ? null
        : sourceAsset.amountFromBaseUnits(quote.zeroExFee!.amountBaseUnits);
    final double? networkFee = quote.totalNetworkFeeBaseUnits == null
        ? null
        : state.activeChain.amountFromBaseUnits(quote.totalNetworkFeeBaseUnits!);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Live quote',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.emeraldTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  quote.isFirmQuote ? 'Firm' : 'Indicative',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.emerald,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DetailRow(
            label: 'You receive',
            value: Formatters.trackedAsset(buyAmount, destinationAsset),
          ),
          DetailRow(
            label: 'Minimum',
            value: Formatters.trackedAsset(minBuyAmount, destinationAsset),
          ),
          if (networkFee != null)
            DetailRow(
              label: 'Network fee',
              value: Formatters.asset(networkFee, state.activeChain),
            ),
          if (routingFee != null)
            DetailRow(
              label: 'Routing fee',
              value: Formatters.trackedAsset(routingFee, sourceAsset),
            ),
          DetailRow(label: 'Slippage', value: _slippageLabel(state.swapSlippageBps)),
          DetailRow(label: 'Route', value: _routeLabel(quote)),
          if (!sourceAsset.isNative && quote.requiresAllowance) ...<Widget>[
            const SizedBox(height: 14),
            const InlineBanner(
              title: 'Approval needed',
              caption:
                  'This token needs one approval before the swap transaction can be signed.',
              icon: Icons.verified_user_outlined,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final List<AssetPortfolioHolding> sources = _sourceHoldings(state);
    final List<TrackedAssetDefinition> trackedAssets =
        state.trackedAssetsForActiveScope;
    _fromAssetId ??= sources.isEmpty ? null : sources.first.resolvedAssetId;
    if (_findSourceHolding(sources, _fromAssetId) == null) {
      _fromAssetId = sources.isEmpty ? null : sources.first.resolvedAssetId;
      _quote = null;
      _quoteError = null;
    }
    if (_toAssetId == null ||
        _toAssetId == _fromAssetId ||
        _findTrackedAsset(trackedAssets, _toAssetId) == null) {
      TrackedAssetDefinition? destination;
      for (final TrackedAssetDefinition asset in trackedAssets) {
        if (asset.id != _fromAssetId) {
          destination = asset;
          break;
        }
      }
      destination ??= trackedAssets.isEmpty ? null : trackedAssets.first;
      _toAssetId = destination?.id;
      _quote = null;
      _quoteError = null;
    }
    final AssetPortfolioHolding? selectedSource = _findSourceHolding(
      sources,
      _fromAssetId,
    );
    final TrackedAssetDefinition? selectedSourceAsset = _findTrackedAsset(
      trackedAssets,
      _fromAssetId,
    );
    final TrackedAssetDefinition? selectedDestination = _findTrackedAsset(
      trackedAssets,
      _toAssetId,
    );
    return BitsendPageScaffold(
      title: 'Swap',
      subtitle: 'Swap assets on the active chain with a live on-chain route.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!state.swapSupportedOnActiveScope)
            EmptyStateCard(
              title: 'Swaps are not available here',
              caption: _swapSupportCaption(state),
              icon: Icons.swap_horiz_rounded,
            )
          else if (!state.hasSwapApiKey)
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Add your 0x API key',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Live quotes and swap execution stay disabled until a routing key is saved in Settings.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.settings),
                    icon: const Icon(Icons.settings_rounded),
                    label: const Text('Open settings'),
                  ),
                ],
              ),
            )
          else if (sources.isEmpty || trackedAssets.length < 2)
            const EmptyStateCard(
              title: 'Need at least two assets',
              caption:
                  'Fund this wallet or import another token on the current network before swapping.',
              icon: Icons.swap_horiz_rounded,
            )
          else if (selectedSource == null ||
              selectedSourceAsset == null ||
              selectedDestination == null)
            const EmptyStateCard(
              title: 'Choose a swap pair',
              caption:
                  'Pick a source balance and a destination asset to continue.',
              icon: Icons.tune_rounded,
            )
          else ...<Widget>[
            SectionCard(
              child: Column(
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: selectedSource.resolvedAssetId,
                    decoration: const InputDecoration(labelText: 'From'),
                    items: sources
                        .map(
                          (
                            AssetPortfolioHolding holding,
                          ) => DropdownMenuItem<String>(
                            value: holding.resolvedAssetId,
                            child: Text(
                              '${holding.resolvedSymbol} · ${Formatters.holding(holding.mainBalance, holding)}',
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      _clearQuote();
                      setState(() {
                        _fromAssetId = value;
                        if (_toAssetId == value) {
                          for (final TrackedAssetDefinition asset in trackedAssets) {
                            if (asset.id != value) {
                              _toAssetId = asset.id;
                              break;
                            }
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDestination.id,
                    decoration: const InputDecoration(labelText: 'To'),
                    items: trackedAssets
                        .where(
                          (TrackedAssetDefinition asset) =>
                              asset.id != selectedSource.resolvedAssetId,
                        )
                        .map(
                          (TrackedAssetDefinition asset) =>
                              DropdownMenuItem<String>(
                                value: asset.id,
                                child: Text(asset.symbol),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: (String? value) {
                      _clearQuote();
                      setState(() {
                        _toAssetId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => _clearQuote(),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      helperText:
                          'Available ${Formatters.holding(selectedSource.mainBalance, selectedSource)}',
                      suffix: TextButton(
                        onPressed: () {
                          _amountController.text = selectedSource.mainBalance
                              .toStringAsFixed(
                                selectedSource.mainBalance >= 1 ? 4 : 6,
                              );
                          _clearQuote();
                        },
                        child: const Text('Max'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _quoting || _submitting
                        ? null
                        : () => _reviewSwap(state),
                    child: Text(_quoting ? 'Loading quote...' : 'Review swap'),
                  ),
                ],
              ),
            ),
            if (_quoteError != null) ...<Widget>[
              const SizedBox(height: 14),
              InlineBanner(
                title: 'Swap status',
                caption: _quoteError!,
                icon: Icons.info_outline_rounded,
              ),
            ],
            if (_quote != null) ...<Widget>[
              const SizedBox(height: 14),
              _quoteCard(
                context: context,
                state: state,
                quote: _quote!,
                sourceAsset: selectedSourceAsset,
                destinationAsset: selectedDestination,
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _submitting ? null : () => _submitSwap(state),
                child: Text(
                  _submitLabel(
                    sourceAsset: selectedSourceAsset,
                    quote: _quote,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _quoting || _submitting
                    ? null
                    : () => _reviewSwap(state),
                child: const Text('Refresh quote'),
              ),
            ] else if (state.swapSlippageBps != null) ...<Widget>[
              const SizedBox(height: 14),
              InlineBanner(
                title: 'Slippage preset',
                caption:
                    'Current tolerance is ${_slippageLabel(state.swapSlippageBps)}. Change it in Settings if this pair needs more room.',
                icon: Icons.tune_rounded,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class BridgeScreen extends StatefulWidget {
  const BridgeScreen({super.key});

  @override
  State<BridgeScreen> createState() => _BridgeScreenState();
}

class _BridgeScreenState extends State<BridgeScreen> {
  String? _sourceAssetId;
  ChainKind? _destinationChain;

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final List<AssetPortfolioHolding> sources = state.portfolioHoldings
        .where((AssetPortfolioHolding holding) => holding.totalBalance > 0)
        .toList(growable: false);
    _sourceAssetId ??= sources.isEmpty ? null : sources.first.resolvedAssetId;
    _destinationChain ??= ChainKind.values.firstWhere(
      (ChainKind chain) => chain != state.activeChain,
      orElse: () => state.activeChain,
    );
    if (sources.isNotEmpty &&
        !sources.any(
          (AssetPortfolioHolding holding) =>
              holding.resolvedAssetId == _sourceAssetId,
        )) {
      _sourceAssetId = sources.first.resolvedAssetId;
    }
    AssetPortfolioHolding? source;
    for (final AssetPortfolioHolding item in sources) {
      if (item.resolvedAssetId == _sourceAssetId) {
        source = item;
        break;
      }
    }
    AssetPortfolioHolding? destination;
    for (final AssetPortfolioHolding item in state.portfolioHoldings) {
      if (item.chain == _destinationChain &&
          item.network == state.activeNetwork) {
        destination = item;
        break;
      }
    }
    final AssetPortfolioHolding? resolvedDestination = destination;
    return BitsendPageScaffold(
      title: 'Bridge',
      subtitle: 'Plan a move between supported chains.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (sources.isEmpty)
            const EmptyStateCard(
              title: 'No assets to bridge yet',
              caption:
                  'Receive funds first, then plan the destination route here.',
              icon: Icons.route_outlined,
            )
          else ...<Widget>[
            SectionCard(
              child: Column(
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: _sourceAssetId,
                    decoration: const InputDecoration(
                      labelText: 'Source asset',
                    ),
                    items: sources
                        .map(
                          (
                            AssetPortfolioHolding holding,
                          ) => DropdownMenuItem<String>(
                            value: holding.resolvedAssetId,
                            child: Text(
                              '${holding.resolvedSymbol} · ${holding.chain.label}',
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (String? value) {
                      setState(() {
                        _sourceAssetId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ChainKind>(
                    initialValue: _destinationChain,
                    decoration: const InputDecoration(
                      labelText: 'Destination chain',
                    ),
                    items: ChainKind.values
                        .where(
                          (ChainKind chain) =>
                              source == null || chain != source.chain,
                        )
                        .map(
                          (ChainKind chain) => DropdownMenuItem<ChainKind>(
                            value: chain,
                            child: Text(
                              chain.networkLabelFor(state.activeNetwork),
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (ChainKind? value) {
                      setState(() {
                        _destinationChain = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            InlineBanner(
              title: resolvedDestination == null
                  ? 'Destination wallet unavailable'
                  : 'Bridge plan ready',
              caption: resolvedDestination == null
                  ? 'Bitsend could not resolve a destination account on that chain yet.'
                  : 'Send ${source?.resolvedSymbol ?? 'assets'} out on ${(source ?? resolvedDestination).chain.label}, then receive on ${resolvedDestination.chain.label} at ${Formatters.shortAddress(resolvedDestination.mainAddress ?? '')}.',
              icon: Icons.compare_arrows_rounded,
              action: resolvedDestination == null
                  ? null
                  : Wrap(
                      spacing: 8,
                      children: <Widget>[
                        TextButton(
                          onPressed: () async {
                            await state.setActiveChain(
                              resolvedDestination.chain,
                            );
                            if (context.mounted) {
                              Navigator.of(
                                context,
                              ).pushNamed(AppRoutes.deposit);
                            }
                          },
                          child: const Text('Open destination'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await state.setActiveChain(
                              source?.chain ?? state.activeChain,
                            );
                            state.setSendTransport(TransportKind.online);
                            if (context.mounted) {
                              Navigator.of(
                                context,
                              ).pushNamed(AppRoutes.sendTransport);
                            }
                          },
                          child: const Text('Open send'),
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AssetDefinitionMark extends StatelessWidget {
  const _AssetDefinitionMark({required this.asset});

  final TrackedAssetDefinition asset;

  @override
  Widget build(BuildContext context) {
    final Color surface = switch (asset.symbol) {
      'USDC' => const Color(0xFFE9F1FF),
      'EURC' => const Color(0xFFF2ECFF),
      _ => switch (asset.chain) {
        ChainKind.solana => const Color(0xFFEAF9F2),
        ChainKind.ethereum => const Color(0xFFEEF1FF),
        ChainKind.base => const Color(0xFFE8F1FF),
        ChainKind.bnb => const Color(0xFFFFF7E5),
        ChainKind.polygon => const Color(0xFFF4EDFF),
      },
    };
    final Color border = switch (asset.symbol) {
      'USDC' => const Color(0xFF9FC2FF),
      'EURC' => const Color(0xFFC8B4FF),
      _ => switch (asset.chain) {
        ChainKind.solana => const Color(0xFF8ED5B0),
        ChainKind.ethereum => const Color(0xFFADB8FF),
        ChainKind.base => const Color(0xFF97B9FF),
        ChainKind.bnb => const Color(0xFFF2CB70),
        ChainKind.polygon => const Color(0xFFC6A7FF),
      },
    };
    final Color foreground = switch (asset.symbol) {
      'USDC' => const Color(0xFF2775CA),
      'EURC' => const Color(0xFF6A4DFF),
      _ => switch (asset.chain) {
        ChainKind.solana => const Color(0xFF14A865),
        ChainKind.ethereum => const Color(0xFF627EEA),
        ChainKind.base => const Color(0xFF0052FF),
        ChainKind.bnb => const Color(0xFFF0B90B),
        ChainKind.polygon => const Color(0xFF8247E5),
      },
    };
    final String label = asset.symbol.length <= 4
        ? asset.symbol
        : asset.symbol.substring(0, 4);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class DappConnectScreen extends StatefulWidget {
  const DappConnectScreen({super.key});

  @override
  State<DappConnectScreen> createState() => _DappConnectScreenState();
}

class _DappConnectScreenState extends State<DappConnectScreen> {
  final TextEditingController _requestController = TextEditingController();
  DappSignRequest? _request;
  DappSignResult? _result;
  String? _error;
  bool _working = false;

  @override
  void dispose() {
    _requestController.dispose();
    super.dispose();
  }

  void _parse(BitsendAppState state) {
    try {
      final DappSignRequest request = DappSignRequest.fromJsonString(
        _requestController.text,
        preferredChain: state.activeChain,
        preferredNetwork: state.activeNetwork,
      );
      setState(() {
        _request = request;
        _result = null;
        _error = null;
      });
    } catch (error) {
      setState(() {
        _error = _messageFor(error);
        _request = null;
        _result = null;
      });
    }
  }

  Future<void> _scanQr() async {
    final String? raw = await _scanRawQrText(context);
    if (!mounted || raw == null || raw.trim().isEmpty) {
      return;
    }
    _requestController.text = raw;
  }

  Future<void> _sign(BitsendAppState state) async {
    if (_request == null) {
      _parse(state);
      if (_request == null) {
        return;
      }
    }
    setState(() {
      _working = true;
    });
    try {
      final DappSignResult result = await state.signDappRequest(_request!);
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _messageFor(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    return BitsendPageScaffold(
      title: 'Dapp connect',
      subtitle: 'Paste or scan a message-sign or eth_sendTransaction request.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: _requestController,
                  minLines: 6,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Request JSON',
                    hintText:
                        '{"method":"personal_sign","params":["0x68656c6c6f","0x..."]}',
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    OutlinedButton(
                      onPressed: _working ? null : _scanQr,
                      child: const Text('Scan QR'),
                    ),
                    OutlinedButton(
                      onPressed: _working ? null : () => _parse(state),
                      child: const Text('Parse request'),
                    ),
                    FilledButton(
                      onPressed: _working ? null : () => _sign(state),
                      child: const Text('Sign / submit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_request != null) ...<Widget>[
            const SizedBox(height: 14),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _request!.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  DetailRow(
                    label: 'Network',
                    value: _request!.chain.networkLabelFor(_request!.network),
                  ),
                  if ((_request!.origin ?? '').isNotEmpty)
                    DetailRow(label: 'Origin', value: _request!.origin!),
                  DetailRow(label: 'Summary', value: _request!.summary),
                  if (_request!.method == DappRequestMethod.sendTransaction)
                    DetailRow(
                      label: 'Value',
                      value: Formatters.asset(
                        _request!.chain.amountFromBaseUnits(
                          _request!.valueBaseUnits,
                        ),
                        _request!.chain,
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: 14),
            InlineBanner(
              title: 'Request error',
              caption: _error!,
              icon: Icons.error_outline_rounded,
            ),
          ],
          if (_result != null) ...<Widget>[
            const SizedBox(height: 14),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _result!.isTransaction ? 'Submitted' : 'Signature',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    _result!.result,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: _result!.result),
                      );
                      if (context.mounted) {
                        _showSnack(context, 'Copied.');
                      }
                    },
                    child: const Text('Copy result'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountSummaryRow extends StatelessWidget {
  const _AccountSummaryRow({required this.summary, this.onTap});

  final WalletAccountSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: summary.selected
                      ? AppColors.emeraldTint
                      : AppColors.canvasTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: summary.selected ? AppColors.emerald : AppColors.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          summary.label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 8),
                        if (summary.selected) _SendMiniBadge(label: 'Active'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (summary.mainWallet != null)
                      Text(
                        'Main ${summary.mainWallet!.displayAddress}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (summary.protectedWallet != null)
                      Text(
                        'Protected ${summary.protectedWallet!.displayAddress}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllowanceEntryRow extends StatelessWidget {
  const _AllowanceEntryRow({required this.entry, required this.onTap});

  final TokenAllowanceEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.canvasTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.verified_user_outlined, color: AppColors.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${entry.tokenSymbol} · ${entry.resolvedSpenderLabel}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.shortAddress(entry.spenderAddress),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                    ),
                  ],
                ),
              ),
              Text(
                Formatters.tokenAmount(
                  entry.allowanceAmount,
                  entry.tokenSymbol,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NftHoldingRow extends StatelessWidget {
  const _NftHoldingRow({required this.holding});

  final NftHolding holding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.canvasTint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  holding.resolvedCollectionName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${holding.resolvedSymbol} #${holding.tokenId}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.shortAddress(holding.contractAddress),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                ),
                if ((holding.tokenUri ?? '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    holding.tokenUri!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  bool _switchingScope = false;
  String _switchingLabel = '';
  bool _normalizingHomeScope = false;

  Future<void> _refreshHome(BuildContext context, BitsendAppState state) async {
    try {
      await state.refreshStatus();
      if (state.hasInternet) {
        await state.refreshWalletData();
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    }
  }

  Future<void> _switchChain(BitsendAppState state, ChainKind chain) async {
    if (_switchingScope || state.activeChain == chain) {
      return;
    }
    await _runScopeSwitch(
      label: chain.networkLabelFor(state.activeNetwork),
      action: () => state.setActiveChain(chain),
    );
  }

  Future<void> _switchNetwork(
    BitsendAppState state,
    ChainNetwork network,
  ) async {
    if (_switchingScope || state.activeNetwork == network) {
      return;
    }
    await _runScopeSwitch(
      label: network.labelFor(state.activeChain),
      action: () => state.setActiveNetwork(network),
    );
  }

  Future<void> _switchWalletEngine(
    BitsendAppState state,
    WalletEngine engine,
  ) async {
    if (_switchingScope || state.activeWalletEngine == engine) {
      return;
    }
    await _runScopeSwitch(
      label:
          '${state.activeChain.networkLabelFor(state.activeNetwork)} · ${engine.walletLabel}',
      action: () => state.setActiveWalletEngine(engine),
    );
  }

  Future<void> _runScopeSwitch({
    required String label,
    required Future<void> Function() action,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _switchingScope = true;
      _switchingLabel = label;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    } finally {
      if (mounted) {
        setState(() {
          _switchingScope = false;
        });
      }
    }
  }

  void _ensureSupportedHomeScope(BitsendAppState state) {
    if (_switchingScope || _normalizingHomeScope) {
      return;
    }
    final bool resetEngine = state.activeWalletEngine == WalletEngine.bitgo;
    if (!resetEngine) {
      return;
    }
    _normalizingHomeScope = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (resetEngine && state.activeWalletEngine == WalletEngine.bitgo) {
          await state.setActiveWalletEngine(WalletEngine.local);
        }
      } catch (error) {
        if (mounted) {
          _showSnack(context, _messageFor(error));
        }
      } finally {
        if (mounted) {
          setState(() {
            _normalizingHomeScope = false;
          });
        } else {
          _normalizingHomeScope = false;
        }
      }
    });
  }

  Future<void> _scanAndStartSend(BitsendAppState state) async {
    await _scanAndStartSendFromContext(context);
  }

  Future<void> _showHomeMoreSheet(BitsendAppState state) async {
    Future<void> closeAndRun(Future<void> Function() action) async {
      Navigator.of(context).pop();
      await action();
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.12),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.72,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'More',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        _HomeMoreActionTile(
                          icon: Icons.qr_code_scanner_rounded,
                          label: 'Scan send code',
                          onTap:
                              state.hasWallet &&
                                  !_switchingScope &&
                                  !state.working
                              ? () =>
                                    closeAndRun(() => _scanAndStartSend(state))
                              : null,
                        ),
                        _HomeMoreActionTile(
                          icon: Icons.call_received_rounded,
                          label: 'Receive',
                          onTap: state.hasWallet
                              ? () => closeAndRun(() async {
                                  Navigator.of(
                                    context,
                                  ).pushNamed(AppRoutes.receiveListen);
                                })
                              : null,
                        ),
                        _HomeMoreActionTile(
                          icon: Icons.shopping_bag_outlined,
                          label: 'Buy',
                          onTap: state.hasWallet
                              ? () => closeAndRun(() async {
                                  Navigator.of(
                                    context,
                                  ).pushNamed(AppRoutes.buy);
                                })
                              : null,
                        ),
                        _HomeMoreActionTile(
                          icon: Icons.swap_horiz_rounded,
                          label: 'Swap',
                          onTap: state.hasWallet
                              ? () => closeAndRun(() async {
                                  Navigator.of(
                                    context,
                                  ).pushNamed(AppRoutes.swap);
                                })
                              : null,
                        ),
                        _HomeMoreActionTile(
                          icon: Icons.compare_arrows_rounded,
                          label: 'Bridge',
                          onTap: state.hasWallet
                              ? () => closeAndRun(() async {
                                  Navigator.of(
                                    context,
                                  ).pushNamed(AppRoutes.bridge);
                                })
                              : null,
                        ),
                        _HomeMoreActionTile(
                          icon: Icons.verified_user_outlined,
                          label: 'Approvals',
                          onTap: state.hasWallet && state.activeChain.isEvm
                              ? () => closeAndRun(() async {
                                  Navigator.of(
                                    context,
                                  ).pushNamed(AppRoutes.approvals);
                                })
                              : null,
                        ),
                        _HomeMoreActionTile(
                          icon: Icons.collections_outlined,
                          label: 'NFTs',
                          onTap: state.hasWallet && state.activeChain.isEvm
                              ? () => closeAndRun(() async {
                                  Navigator.of(
                                    context,
                                  ).pushNamed(AppRoutes.nfts);
                                })
                              : null,
                        ),
                        _HomeMoreActionTile(
                          icon: Icons.link_rounded,
                          label: 'Dapp connect',
                          onTap: state.hasWallet
                              ? () => closeAndRun(() async {
                                  Navigator.of(
                                    context,
                                  ).pushNamed(AppRoutes.dappConnect);
                                })
                              : null,
                        ),
                        _HomeMoreActionTile(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Accounts',
                          onTap: state.hasWallet
                              ? () => closeAndRun(() async {
                                  Navigator.of(
                                    context,
                                  ).pushNamed(AppRoutes.accounts);
                                })
                              : null,
                        ),
                        _HomeMoreActionTile(
                          icon: Icons.refresh_rounded,
                          label: 'Refresh',
                          onTap: !_switchingScope && !state.working
                              ? () => closeAndRun(
                                  () => _refreshHome(context, state),
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    _ensureSupportedHomeScope(state);
    final HomeStatus status = state.homeStatus;
    final WalletSummary summary = state.walletSummary;
    final List<PendingTransfer> recent = state.recentActivity();
    final ChainNetwork network = state.activeNetwork;
    final bool usingBitGo = state.activeWalletEngine == WalletEngine.bitgo;
    final String scopeKey =
        '${state.activeChain.name}:${network.name}:${state.activeWalletEngine.name}';
    final String sendRoute = state.hasWallet
        ? AppRoutes.sendTransport
        : AppRoutes.prepare;
    final int pendingCount = state.pendingTransfers.length;
    final List<AssetPortfolioHolding> activeScopeHoldings = state
        .portfolioHoldings
        .where(
          (AssetPortfolioHolding holding) =>
              holding.chain == summary.chain &&
              holding.network == summary.network,
        )
        .toList(growable: false);
    final double? scopeMainUsdTotal = usingBitGo
        ? state.activeScopeUsdTotal
        : _usdTotalForHoldings(
            state,
            activeScopeHoldings,
            (AssetPortfolioHolding holding) => holding.mainBalance,
          );
    final double? scopeOfflineUsdTotal = usingBitGo
        ? state.activeScopeUsdTotal
        : _usdTotalForHoldings(
            state,
            activeScopeHoldings,
            (AssetPortfolioHolding holding) => holding.protectedBalance,
          );
    final double? scopeSpendableUsdTotal = usingBitGo
        ? state.activeScopeUsdTotal
        : _usdTotalForHoldings(
            state,
            activeScopeHoldings,
            (AssetPortfolioHolding holding) => holding.spendableBalance,
          );

    return BitsendPageScaffold(
      title: 'bitsend',
      header: _HomeScopeHeader(
        chain: state.activeChain,
        network: network,
        walletEngine: state.activeWalletEngine,
        accountSlot: state.activeAccountSlot,
        switching: _switchingScope,
        onChainChanged: (ChainKind chain) {
          _switchChain(state, chain);
        },
        onNetworkChanged: (ChainNetwork next) {
          _switchNetwork(state, next);
        },
        onWalletEngineChanged: (WalletEngine next) {
          _switchWalletEngine(state, next);
        },
        onAccountsTap: () {
          Navigator.of(context).pushNamed(AppRoutes.accounts);
        },
      ),
      overlay: _HomeDashboardOverlay(
        switchingLabel: _switchingScope ? _switchingLabel : null,
        onScan: state.hasWallet && !_switchingScope && !state.working
            ? () => _scanAndStartSendFromContext(context)
            : null,
      ),
      showBack: false,
      onRefresh: state.working || _switchingScope
          ? null
          : () => _refreshHome(context, state),
      primaryTab: BitsendPrimaryTab.home,
      onPrimaryTabSelected: (BitsendPrimaryTab tab) {
        _navigatePrimaryTab(context, tab);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final Animation<Offset> slide = Tween<Offset>(
            begin: const Offset(0.02, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<String>(scopeKey),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              FadeSlideIn(
                delay: 0,
                child: _DashboardHero(
                  summary: summary,
                  hasWallet: state.hasWallet,
                  activeScopeUsdTotal: state.activeScopeUsdTotal,
                ),
              ),
              const SizedBox(height: 22),
              FadeSlideIn(
                delay: 40,
                child: _HomeHeroActions(
                  onDeposit: () {
                    Navigator.of(context).pushNamed(
                      state.hasWallet ? AppRoutes.deposit : sendRoute,
                    );
                  },
                  onAssets: state.hasWallet
                      ? () {
                          Navigator.of(context).pushNamed(AppRoutes.assets);
                        }
                      : null,
                  onSend: () {
                    if (state.hasWallet &&
                        state.activeWalletEngine == WalletEngine.local) {
                      state.setSendTransport(
                        state.hasInternet
                            ? TransportKind.online
                            : TransportKind.hotspot,
                      );
                    }
                    Navigator.of(context).pushNamed(sendRoute);
                  },
                  onMore: () {
                    _showHomeMoreSheet(state);
                  },
                ),
              ),
              const SizedBox(height: 22),
              FadeSlideIn(
                delay: 80,
                child: _HomeSummaryPanel(
                  summary: summary,
                  pendingCount: pendingCount,
                  hasWallet: state.hasWallet,
                  mainUsdTotal: scopeMainUsdTotal,
                  offlineUsdTotal: scopeOfflineUsdTotal,
                  spendableUsdTotal: scopeSpendableUsdTotal,
                  onTopUp: () {
                    Navigator.of(context).pushNamed(AppRoutes.prepare);
                  },
                  onReceive: () {
                    Navigator.of(context).pushNamed(AppRoutes.receiveListen);
                  },
                  onOpenOffline: () {
                    Navigator.of(context).pushNamed(AppRoutes.prepare);
                  },
                ),
              ),
              const SizedBox(height: 18),
              FadeSlideIn(
                delay: 120,
                child: SizedBox(
                  width: double.infinity,
                  child: SectionCard(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Transactions',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (recent.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.receipt_long_rounded,
                                  color: AppColors.slate.withValues(
                                    alpha: 0.85,
                                  ),
                                  size: 28,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No activity',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ],
                            ),
                          )
                        else
                          Column(
                            children: recent
                                .asMap()
                                .entries
                                .map(
                                  (MapEntry<int, PendingTransfer> entry) =>
                                      Padding(
                                        padding: EdgeInsets.only(
                                          bottom: entry.key == recent.length - 1
                                              ? 0
                                              : 4,
                                        ),
                                        child: _HomeActivityRow(
                                          transfer: entry.value,
                                          showDivider:
                                              entry.key != recent.length - 1,
                                          onTap: () {
                                            Navigator.of(context).pushNamed(
                                              AppRoutes.transferDetail(
                                                entry.value.transferId,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                )
                                .toList(growable: false),
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
}

class _HomeDashboardOverlay extends StatelessWidget {
  const _HomeDashboardOverlay({this.switchingLabel, this.onScan});

  final String? switchingLabel;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    if (switchingLabel == null && onScan == null) {
      return const SizedBox.shrink();
    }
    return Stack(
      children: <Widget>[
        if (switchingLabel != null) _ScopeSwitchOverlay(label: switchingLabel!),
        if (onScan != null)
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 18, bottom: 98),
              child: SafeArea(
                top: false,
                child: _HomeScanShortcutButton(
                  key: const Key('primary-nav-scan-button'),
                  onPressed: onScan!,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HomeScanShortcutButton extends StatelessWidget {
  const _HomeScanShortcutButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Scan QR code and send',
      child: Semantics(
        button: true,
        label: 'Scan QR code and send',
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.12),
                blurRadius: 22,
                spreadRadius: -8,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipOval(
            child: Material(
              color: Colors.transparent,
              child: Ink(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.line, width: 1),
                ),
                child: InkWell(
                  onTap: onPressed,
                  customBorder: const CircleBorder(),
                  splashColor: AppColors.ink.withValues(alpha: 0.08),
                  highlightColor: AppColors.ink.withValues(alpha: 0.04),
                  child: const Center(
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppColors.ink,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum DepositWalletTarget { main, offline }

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key, this.initialTarget});

  final DepositWalletTarget? initialTarget;

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen>
    with WidgetsBindingObserver {
  late DepositWalletTarget _target;
  bool _didAutoRefresh = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _target = widget.initialTarget ?? DepositWalletTarget.main;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didAutoRefresh) {
      return;
    }
    _didAutoRefresh = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_refreshOnResume());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) {
      return;
    }
    unawaited(_refreshOnResume());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refreshOnResume() async {
    try {
      await BitsendStateScope.of(context).refreshWalletData();
    } catch (_) {
      // Leave the last known balance on screen when the network refresh fails.
    }
  }

  Future<void> _copyAddress(BuildContext context, String address) async {
    await Clipboard.setData(ClipboardData(text: address));
    if (!context.mounted) {
      return;
    }
    _showSnack(context, 'Address copied.');
  }

  Future<void> _requestAirdrop(BitsendAppState state) async {
    try {
      await state.requestAirdrop(
        toOfflineWallet: _target == DepositWalletTarget.offline,
      );
      if (!mounted) {
        return;
      }
      _showSnack(context, 'Airdrop requested.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final ChainKind chain = state.activeChain;
    final ChainNetwork network = state.activeNetwork;
    final bool usingBitGo = state.activeWalletEngine == WalletEngine.bitgo;
    final WalletProfile? targetWallet = usingBitGo
        ? null
        : _target == DepositWalletTarget.main
        ? state.wallet
        : state.offlineWallet;
    final String title = usingBitGo
        ? 'BitGo wallet'
        : _target == DepositWalletTarget.main
        ? 'Main wallet'
        : 'Offline wallet';
    final String? fullAddress = usingBitGo
        ? state.bitgoWallet?.address
        : targetWallet?.address;
    final String shortAddress = usingBitGo
        ? (state.bitgoWallet?.displayLabel ??
              state.bitgoWallet?.address ??
              'Unavailable')
        : (targetWallet?.displayAddress ?? 'Unavailable');
    final String balance = usingBitGo
        ? Formatters.asset(state.mainBalanceSol, chain)
        : _target == DepositWalletTarget.main
        ? Formatters.asset(state.mainBalanceSol, chain)
        : Formatters.asset(state.offlineBalanceSol, chain);

    return BitsendPageScaffold(
      title: 'Deposit ${chain.assetDisplayLabel}',
      subtitle: usingBitGo
          ? 'Share the BitGo-backed ${network.shortLabelFor(chain)} ${chain.assetDisplayLabel} address.'
          : 'Pick a wallet and share the ${network.shortLabelFor(chain)} ${chain.assetDisplayLabel} address.',
      onRefresh: state.working
          ? null
          : () async {
              try {
                await state.refreshWalletData();
              } catch (error) {
                if (!context.mounted) {
                  return;
                }
                _showSnack(context, _messageFor(error));
              }
            },
      showBack: false,
      primaryTab: BitsendPrimaryTab.deposit,
      onPrimaryTabSelected: (BitsendPrimaryTab tab) {
        _navigatePrimaryTab(context, tab);
      },
      overlay: _HomeDashboardOverlay(
        onScan: state.hasWallet ? () => _scanAndStartSendFromContext(context) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!usingBitGo) ...<Widget>[
            SegmentedButton<DepositWalletTarget>(
              segments: const <ButtonSegment<DepositWalletTarget>>[
                ButtonSegment<DepositWalletTarget>(
                  value: DepositWalletTarget.main,
                  label: Text('Main'),
                  icon: Icon(Icons.account_balance_wallet_rounded),
                ),
                ButtonSegment<DepositWalletTarget>(
                  value: DepositWalletTarget.offline,
                  label: Text('Offline'),
                  icon: Icon(Icons.lock_clock_rounded),
                ),
              ],
              selected: <DepositWalletTarget>{_target},
              onSelectionChanged: (Set<DepositWalletTarget> value) {
                setState(() {
                  _target = value.first;
                });
              },
            ),
            const SizedBox(height: 16),
          ],
          _DepositHero(
            title: title,
            shortAddress: shortAddress,
            balance: balance,
            statusLabel: usingBitGo
                ? 'BitGo'
                : _target == DepositWalletTarget.main
                ? network.shortLabelFor(chain)
                : state.hasOfflineReadyBlockhash
                ? 'Ready'
                : state.autoRefreshingReadiness
                ? 'Syncing'
                : 'Auto-sync',
            statusIcon: usingBitGo
                ? Icons.shield_outlined
                : _target == DepositWalletTarget.main
                ? Icons.cloud_done_rounded
                : state.hasOfflineReadyBlockhash
                ? Icons.check_circle_outline_rounded
                : Icons.update_rounded,
            statusActive:
                usingBitGo ||
                _target == DepositWalletTarget.main ||
                state.hasOfflineReadyBlockhash,
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Address', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                SelectableText(
                  fullAddress ?? 'Wallet unavailable',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                    height: 1.6,
                  ),
                ),
                if (chain.isEvm) ...<Widget>[
                  const SizedBox(height: 14),
                  InlineBanner(
                    title: 'Same address, different network',
                    caption: chain.addressScopeNoteFor(network),
                    icon: Icons.layers_rounded,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: fullAddress == null
                            ? null
                            : () => _copyAddress(context, fullAddress),
                        child: const Text('Copy address'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: state.working || fullAddress == null
                            ? null
                            : !usingBitGo &&
                                  chain == ChainKind.solana &&
                                  network.supportsAirdrop
                            ? () => _requestAirdrop(state)
                            : () => state.refreshWalletData(),
                        child: Text(
                          !usingBitGo &&
                                  chain == ChainKind.solana &&
                                  network.supportsAirdrop
                              ? 'Airdrop'
                              : 'Refresh',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PrepareOfflineScreen extends StatefulWidget {
  const PrepareOfflineScreen({super.key});

  @override
  State<PrepareOfflineScreen> createState() => _PrepareOfflineScreenState();
}

class _PrepareOfflineScreenState extends State<PrepareOfflineScreen> {
  late final TextEditingController _topUpController;
  late final TextEditingController _settlementContractController;
  String? _seededSettlementScopeKey;
  String? _selectedTopUpAssetId;

  @override
  void initState() {
    super.initState();
    _topUpController = TextEditingController();
    _settlementContractController = TextEditingController();
  }

  @override
  void dispose() {
    _topUpController.dispose();
    _settlementContractController.dispose();
    super.dispose();
  }

  void _applyTopUpPreset(String value) {
    _topUpController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Future<void> _topUp(
    BitsendAppState state,
    AssetPortfolioHolding selectedAsset,
  ) async {
    final double amount = double.tryParse(_topUpController.text.trim()) ?? 0;
    try {
      await state.topUpOfflineWallet(
        amount,
        assetId: selectedAsset.resolvedAssetId,
      );
      if (!mounted) {
        return;
      }
      _showSnack(
        context,
        'Offline wallet funded with ${selectedAsset.resolvedSymbol}.',
      );
    } catch (error) {
      _showSnack(context, _messageFor(error));
    }
  }

  Future<void> _refreshReadiness(BitsendAppState state) async {
    try {
      await state.prepareForOffline();
      if (!mounted) {
        return;
      }
      _showSnack(context, 'Offline send readiness refreshed.');
    } catch (error) {
      _showSnack(context, _messageFor(error));
    }
  }

  Future<void> _saveSettlementContract(BitsendAppState state) async {
    try {
      await state.setOfflineVoucherSettlementContractAddress(
        _settlementContractController.text,
      );
      if (!mounted) {
        return;
      }
      _showSnack(context, 'Settlement contract saved.');
    } catch (error) {
      _showSnack(context, _messageFor(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final WalletSummary summary = state.walletSummary;
    final ChainKind chain = state.activeChain;
    final ChainNetwork network = state.activeNetwork;
    final bool usingBitGo = state.activeWalletEngine == WalletEngine.bitgo;
    final int pendingCount = state.pendingTransfers.length;
    final String settlementScopeKey =
        '${chain.name}:${network.name}:${state.activeWalletEngine.name}';
    if (_seededSettlementScopeKey != settlementScopeKey) {
      _seededSettlementScopeKey = settlementScopeKey;
      _settlementContractController.text =
          state.offlineVoucherSettlementContractAddress;
    }
    final AssetPortfolioHolding fallbackTopUpAsset = AssetPortfolioHolding(
      chain: chain,
      network: network,
      totalBalance: summary.balanceSol + summary.offlineBalanceSol,
      mainBalance: summary.balanceSol,
      protectedBalance: summary.offlineBalanceSol,
      spendableBalance: summary.offlineAvailableSol,
      reservedBalance: math.max(
        summary.offlineBalanceSol - summary.offlineAvailableSol,
        0,
      ),
      assetId: '${chain.name}:${network.name}:native',
      symbol: chain.assetDisplayLabel,
      displayName: chain.label,
      assetDecimals: chain.decimals,
      isNative: true,
      mainAddress: state.wallet?.address,
      protectedAddress: state.offlineWallet?.address,
    );
    final List<AssetPortfolioHolding> topUpAssets =
        state.portfolioHoldings.where((AssetPortfolioHolding holding) {
          if (holding.chain != chain || holding.network != network) {
            return false;
          }
          if (!holding.isNative && !chain.isEvm) {
            return false;
          }
          return holding.isNative ||
              holding.mainBalance > 0 ||
              holding.protectedBalance > 0;
        }).toList(growable: true);
    if (!topUpAssets.any((AssetPortfolioHolding holding) => holding.isNative)) {
      topUpAssets.add(fallbackTopUpAsset);
    }
    topUpAssets.sort((AssetPortfolioHolding a, AssetPortfolioHolding b) {
      if (a.isNative != b.isNative) {
        return a.isNative ? -1 : 1;
      }
      final int balanceCompare = b.mainBalance.compareTo(a.mainBalance);
      if (balanceCompare != 0) {
        return balanceCompare;
      }
      return a.resolvedSymbol.compareTo(b.resolvedSymbol);
    });
    final AssetPortfolioHolding selectedTopUpAsset = (() {
      if (_selectedTopUpAssetId != null) {
        for (final AssetPortfolioHolding asset in topUpAssets) {
          if (asset.resolvedAssetId == _selectedTopUpAssetId) {
            return asset;
          }
        }
      }
      for (final AssetPortfolioHolding asset in topUpAssets) {
        if (asset.isNative) {
          return asset;
        }
      }
      return topUpAssets.isEmpty ? fallbackTopUpAsset : topUpAssets.first;
    })();
    final List<AssetPortfolioHolding> activeScopeHoldings = state
        .portfolioHoldings
        .where(
          (AssetPortfolioHolding holding) =>
              holding.chain == chain && holding.network == network,
        )
        .toList(growable: false);
    final double? activeScopeMainUsdTotal = _usdTotalForHoldings(
      state,
      activeScopeHoldings,
      (AssetPortfolioHolding holding) => holding.mainBalance,
    );
    final double? activeScopeOfflineUsdTotal = _usdTotalForHoldings(
      state,
      activeScopeHoldings,
      (AssetPortfolioHolding holding) => holding.protectedBalance,
    );
    final double? activeScopeSpendableUsdTotal = _usdTotalForHoldings(
      state,
      activeScopeHoldings,
      (AssetPortfolioHolding holding) => holding.spendableBalance,
    );
    final double? selectedTopUpMainUsd = _usdValueForHolding(
      state,
      selectedTopUpAsset,
      selectedTopUpAsset.mainBalance,
    );
    final double? selectedTopUpOfflineUsd = _usdValueForHolding(
      state,
      selectedTopUpAsset,
      selectedTopUpAsset.protectedBalance,
    );
    final List<OfflineVoucherClaimAttempt> scopedVoucherClaims = state
        .pendingOfflineVoucherClaims
        .where(
          (OfflineVoucherClaimAttempt claim) =>
              claim.chain == chain && claim.network == network,
        )
        .toList(growable: false);
    return BitsendPageScaffold(
      title: usingBitGo ? 'BitGo Wallet' : 'Offline Wallet',
      subtitle: usingBitGo
          ? 'BitGo mode is online-only. Manage the backend wallet here.'
          : 'Fund it and keep it ready.',
      onRefresh: state.working ? null : state.refreshStatus,
      showBack: false,
      primaryTab: BitsendPrimaryTab.offline,
      onPrimaryTabSelected: (BitsendPrimaryTab tab) {
        _navigatePrimaryTab(context, tab);
      },
      overlay: _HomeDashboardOverlay(
        onScan: state.hasWallet ? () => _scanAndStartSendFromContext(context) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (usingBitGo) ...<Widget>[
            InlineBanner(
              title: state.bitgoBackendIsLive
                  ? 'Local handoff is disabled'
                  : 'BitGo fallback is ready',
              caption: state.bitgoBackendIsLive
                  ? 'Switch the header back to Local mode to top up the offline wallet or refresh offline readiness.'
                  : 'If the BitGo backend is not live or goes down, the app will switch to Local mode and use the offline wallet flow automatically.',
              icon: Icons.shield_outlined,
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'BitGo wallet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  DetailRow(
                    label: 'Wallet',
                    value: state.bitgoWallet?.displayLabel ?? 'Unavailable',
                  ),
                  DetailRow(
                    label: 'Address',
                    value:
                        state.bitgoWallet?.address ?? 'Connect wallet backend',
                  ),
                  DetailRow(
                    label: 'Balance',
                    value: Formatters.asset(summary.balanceSol, chain),
                  ),
                  DetailRow(
                    label: 'Backend',
                    value: state.bitgoBackendMode.label,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: state.working ? null : state.connectBitGo,
                    child: const Text('Refresh BitGo wallet'),
                  ),
                ],
              ),
            ),
          ] else ...<Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FadeSlideIn(
                  delay: 0,
                  child: _OfflineWalletScene(
                    summary: summary,
                    hasWallet: state.hasWallet,
                    pendingCount: pendingCount,
                    mainUsdTotal: activeScopeMainUsdTotal,
                    offlineUsdTotal: activeScopeOfflineUsdTotal,
                    spendableUsdTotal: activeScopeSpendableUsdTotal,
                    onShowInfo: () {
                      _showOfflineWalletInfoSheet(
                        context,
                        summary: summary,
                        pendingCount: pendingCount,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                FadeSlideIn(
                  delay: 40,
                  child: _OfflineActionComposer(
                    chain: chain,
                    selectedAsset: selectedTopUpAsset,
                    availableAssets: topUpAssets.isEmpty
                        ? <AssetPortfolioHolding>[fallbackTopUpAsset]
                        : topUpAssets,
                    selectedAssetMainUsd: selectedTopUpMainUsd,
                    selectedAssetOfflineUsd: selectedTopUpOfflineUsd,
                    controller: _topUpController,
                    working: state.working,
                    statusMessage: state.statusMessage,
                    readyForOffline: summary.readyForOffline,
                    onAssetSelected: (String value) {
                      setState(() {
                        _selectedTopUpAssetId = value;
                        _topUpController.clear();
                      });
                    },
                    onPresetSelected: _applyTopUpPreset,
                    onTopUp: () => _topUp(state, selectedTopUpAsset),
                    onRefreshReadiness: () => _refreshReadiness(state),
                  ),
                ),
                const SizedBox(height: 14),
                FadeSlideIn(
                  delay: 80,
                  child: _OfflineDepositChooser(
                    onDepositMain: () {
                      Navigator.of(context).pushNamed(
                        AppRoutes.deposit,
                        arguments: DepositWalletTarget.main,
                      );
                    },
                    onDepositOffline: () {
                      Navigator.of(context).pushNamed(
                        AppRoutes.deposit,
                        arguments: DepositWalletTarget.offline,
                      );
                    },
                  ),
                ),
                if (chain.isEvm) ...<Widget>[
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delay: 120,
                    child: _OfflineVoucherPanel(
                      chain: chain,
                      contractController: _settlementContractController,
                      sessions: state.offlineVoucherEscrowSessionsForActiveScope,
                      claims: scopedVoucherClaims,
                      onSaveContract: () => _saveSettlementContract(state),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class SendTransportScreen extends StatefulWidget {
  const SendTransportScreen({super.key});

  @override
  State<SendTransportScreen> createState() => _SendTransportScreenState();
}

class _SendTransportScreenState extends State<SendTransportScreen> {
  late final TextEditingController _addressController;
  late final TextEditingController _endpointController;
  String? _selectedBleReceiverId;
  String? _selectedBleReceiverName;
  bool _autoScannedBle = false;
  bool _resolvingEns = false;
  bool _syncingReceiverText = false;
  String? _resolvedReceiverLabel;
  String? _resolvedReceiverAddress;
  EnsPaymentPreference? _resolvedReceiverPreference;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
    _endpointController = TextEditingController();
    _addressController.addListener(_clearResolvedReceiverPreview);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final BitsendAppState state = BitsendStateScope.of(context);
    final bool showReceiverLabel =
        state.sendDraft.receiverLabel.isNotEmpty &&
        state.looksLikeEthereumEnsName(state.sendDraft.receiverLabel);
    final String displayReceiver = showReceiverLabel
        ? state.sendDraft.receiverLabel
        : state.sendDraft.receiverAddress;
    if (_addressController.text != displayReceiver) {
      _syncingReceiverText = true;
      _addressController.text = displayReceiver;
      _syncingReceiverText = false;
    }
    _endpointController.text = state.sendDraft.receiverEndpoint;
    _selectedBleReceiverId = state.sendDraft.receiverPeripheralId.isEmpty
        ? null
        : state.sendDraft.receiverPeripheralId;
    _selectedBleReceiverName = state.sendDraft.receiverPeripheralName.isEmpty
        ? null
        : state.sendDraft.receiverPeripheralName;
    _resolvedReceiverLabel = showReceiverLabel
        ? state.sendDraft.receiverLabel
        : null;
    _resolvedReceiverAddress = showReceiverLabel
        ? state.sendDraft.receiverAddress
        : null;
    _resolvedReceiverPreference = showReceiverLabel
        ? EnsPaymentPreference(
            ensName: state.sendDraft.receiverLabel,
            preferredChain: state.sendDraft.receiverPreferredChain,
            preferredToken: state.sendDraft.receiverPreferredToken,
          )
        : null;
    if (state.sendDraft.transport == TransportKind.ble &&
        !_autoScannedBle &&
        state.bleReceivers.isEmpty &&
        !state.bleDiscovering) {
      _autoScannedBle = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _scanBleReceivers(state);
      });
    }
  }

  @override
  void dispose() {
    _addressController.removeListener(_clearResolvedReceiverPreview);
    _addressController.dispose();
    _endpointController.dispose();
    super.dispose();
  }

  void _clearResolvedReceiverPreview() {
    if (_syncingReceiverText) {
      return;
    }
    if (_resolvedReceiverLabel == null && _resolvedReceiverAddress == null) {
      return;
    }
    setState(() {
      _resolvedReceiverLabel = null;
      _resolvedReceiverAddress = null;
      _resolvedReceiverPreference = null;
    });
  }

  Future<void> _continue(BitsendAppState state) async {
    final bool offlineMode = state.sendDraft.transport != TransportKind.online;
    final bool offlineRouteResolved = switch (state.sendDraft.transport) {
      TransportKind.online => true,
      TransportKind.hotspot =>
        state.activeWalletEngine == WalletEngine.bitgo
            ? state.sendDraft.receiverAddress.isNotEmpty
            : state.sendDraft.receiverEndpoint.isNotEmpty,
      TransportKind.ble => true,
      TransportKind.ultrasonic => true,
    };
    if (offlineMode && !offlineRouteResolved) {
      _showSnack(
        context,
        'Scan the receiver code to choose the offline method.',
      );
      return;
    }
    final String rawReceiver =
        state.sendDraft.transport == TransportKind.ultrasonic
        ? state.sendDraft.receiverAddress
        : _addressController.text.trim();
    String receiverAddress = rawReceiver;
    String receiverLabel = '';
    String receiverPreferredChain = '';
    String receiverPreferredToken = '';
    if (rawReceiver.isEmpty) {
      _showSnack(context, 'Receiver address is required.');
      return;
    }
    if (state.activeChain.isEvm &&
        !state.looksLikeEthereumEnsName(rawReceiver) &&
        !_isValidAddressForChain(rawReceiver, state.activeChain)) {
      _showSnack(context, 'Receiver address or ENS name is not valid.');
      return;
    }
    if (state.activeChain.isEvm &&
        state.looksLikeEthereumEnsName(rawReceiver)) {
      setState(() {
        _resolvingEns = true;
      });
      try {
        receiverAddress = await state.resolveEthereumEnsName(rawReceiver);
        final EnsPaymentPreference preference = await state
            .readEthereumEnsPaymentPreference(rawReceiver);
        receiverLabel = rawReceiver.toLowerCase();
        receiverPreferredChain = preference.preferredChain;
        receiverPreferredToken = preference.preferredToken;
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showSnack(context, _messageFor(error));
        return;
      } finally {
        if (mounted) {
          setState(() {
            _resolvingEns = false;
          });
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvedReceiverLabel = receiverLabel;
        _resolvedReceiverAddress = receiverAddress;
        _resolvedReceiverPreference = EnsPaymentPreference(
          ensName: receiverLabel,
          preferredChain: receiverPreferredChain,
          preferredToken: receiverPreferredToken,
        );
      });
    }
    if (state.sendDraft.transport == TransportKind.hotspot) {
      state.updateReceiver(
        receiverAddress: receiverAddress,
        receiverLabel: receiverLabel,
        receiverEndpoint: _endpointController.text,
        receiverPreferredChain: receiverPreferredChain,
        receiverPreferredToken: receiverPreferredToken,
      );
    } else if (state.sendDraft.transport == TransportKind.ble) {
      state.updateReceiver(
        receiverAddress: receiverAddress,
        receiverLabel: receiverLabel,
        receiverPeripheralId: _selectedBleReceiverId ?? '',
        receiverPeripheralName: _selectedBleReceiverName ?? '',
        receiverPreferredChain: receiverPreferredChain,
        receiverPreferredToken: receiverPreferredToken,
      );
    } else {
      state.updateReceiver(
        receiverAddress: receiverAddress,
        receiverLabel: receiverLabel,
        receiverSessionToken: state.sendDraft.receiverSessionToken,
        receiverRelayId: state.sendDraft.receiverRelayId,
        receiverPreferredChain: receiverPreferredChain,
        receiverPreferredToken: receiverPreferredToken,
      );
    }
    if (state.sendDraft.transport == TransportKind.ultrasonic &&
        state.sendDraft.receiverRelayId.isEmpty) {
      _showSnack(context, 'Scan the receiver QR code before continuing.');
      return;
    }
    if (!state.sendDraft.hasReceiver) {
      _showSnack(
        context,
        state.activeWalletEngine == WalletEngine.bitgo
            ? 'Receiver address is required for BitGo mode.'
            : state.sendDraft.transport == TransportKind.hotspot
            ? 'Receiver address and endpoint are required.'
            : state.sendDraft.transport == TransportKind.ble
            ? 'Receiver address and a discovered BLE device are required.'
            : 'Scan the receiver QR code before continuing.',
      );
      return;
    }
    Navigator.of(context).pushNamed(AppRoutes.sendAmount);
  }

  Future<void> _scanBleReceivers(
    BitsendAppState state, {
    String? preferredAddress,
  }) async {
    try {
      await state.scanBleReceivers();
      if (!mounted || preferredAddress == null || preferredAddress.isEmpty) {
        return;
      }
      for (final ReceiverDiscoveryItem item in state.bleReceivers) {
        if (item.resolvedAddress == preferredAddress) {
          setState(() {
            _selectedBleReceiverId = item.id;
            _selectedBleReceiverName = item.label;
          });
          break;
        }
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String message = _messageFor(error);
      if (_looksLikeBluetoothNeedsAttention(message)) {
        await _showBluetoothPrompt(context, message);
        return;
      }
      _showSnack(context, message);
    }
  }

  Future<void> _scanReceiverQr(BitsendAppState state) async {
    final _ScannedQrPayload? scanned = await _scanReceiverInvite(
      context,
      chain: state.activeChain,
      network: state.activeNetwork,
    );
    if (!mounted || scanned == null) {
      return;
    }

    try {
      final bool switchedToOnline =
          scanned.directTransfer != null &&
          state.sendDraft.transport != TransportKind.online;
      final bool readyForAmount = scanned.invite != null
          ? await _prepareScannedReceiverDraft(state, scanned.invite!)
          : await _prepareScannedDirectTransferDraft(
              state,
              scanned.directTransfer!,
            );
      if (!mounted) {
        return;
      }
      final SendDraft draft = state.sendDraft;
      setState(() {
        _addressController.text = draft.receiverAddress;
        _endpointController.text = draft.receiverEndpoint;
        _selectedBleReceiverId = draft.receiverPeripheralId.isEmpty
            ? null
            : draft.receiverPeripheralId;
        _selectedBleReceiverName = draft.receiverPeripheralName.isEmpty
            ? null
            : draft.receiverPeripheralName;
        _resolvedReceiverLabel = null;
        _resolvedReceiverAddress = null;
        _resolvedReceiverPreference = null;
      });
      if (!readyForAmount &&
          scanned.invite?.transport == TransportKind.ble &&
          state.activeWalletEngine == WalletEngine.local) {
        _showSnack(
          context,
          'QR code scanned. Select the nearby BLE receiver to continue.',
        );
      } else if (switchedToOnline) {
        _showSnack(context, 'Wallet QR scanned. Switched to Online transfer.');
      }
    } catch (error) {
      final String message = _messageFor(error);
      if (_looksLikeBluetoothDisabled(message)) {
        await _showBluetoothPrompt(context, message);
        return;
      }
      _showSnack(context, message);
    }
  }

  Future<void> _pickContact(BitsendAppState state) async {
    final List<SendContact> contacts = state.contactsForActiveScope;
    if (contacts.isEmpty) {
      _showSnack(context, 'No saved contacts on this network yet.');
      return;
    }
    final SendContact? selected = await showDialog<SendContact>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Saved contacts'),
          content: SizedBox(
            width: 360,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: contacts.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final SendContact contact = contacts[index];
                return ListTile(
                  title: Text(contact.name),
                  subtitle: Text(Formatters.shortAddress(contact.address)),
                  onTap: () => Navigator.of(context).pop(contact),
                );
              },
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) {
      return;
    }
    state.selectContact(selected);
    setState(() {
      _addressController.text = selected.address;
      _resolvedReceiverLabel = null;
      _resolvedReceiverAddress = null;
      _resolvedReceiverPreference = null;
    });
  }

  Future<void> _saveCurrentAsContact(BitsendAppState state) async {
    final String rawReceiver = _addressController.text.trim();
    if (!_isValidAddressForChain(rawReceiver, state.activeChain) &&
        !(state.sendDraft.receiverAddress.isNotEmpty &&
            _isValidAddressForChain(
              state.sendDraft.receiverAddress,
              state.activeChain,
            ))) {
      _showSnack(context, 'Enter or scan a wallet address first.');
      return;
    }
    final TextEditingController nameController = TextEditingController(
      text:
          state.sendDraft.receiverLabel.isNotEmpty &&
              !state.looksLikeEthereumEnsName(state.sendDraft.receiverLabel)
          ? state.sendDraft.receiverLabel
          : '',
    );
    try {
      final String? name = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Save contact'),
            content: TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Alice',
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(nameController.text.trim()),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
      if (name == null || name.isEmpty || !mounted) {
        return;
      }
      if (_isValidAddressForChain(rawReceiver, state.activeChain)) {
        state.updateReceiver(
          receiverAddress: rawReceiver,
          receiverLabel: state.sendDraft.receiverLabel,
          receiverEndpoint: state.sendDraft.receiverEndpoint,
          receiverPeripheralId: state.sendDraft.receiverPeripheralId,
          receiverPeripheralName: state.sendDraft.receiverPeripheralName,
          receiverSessionToken: state.sendDraft.receiverSessionToken,
          receiverRelayId: state.sendDraft.receiverRelayId,
          receiverPreferredChain: state.sendDraft.receiverPreferredChain,
          receiverPreferredToken: state.sendDraft.receiverPreferredToken,
        );
      }
      await state.saveCurrentReceiverAsContact(name);
      if (!mounted) {
        return;
      }
      _showSnack(context, 'Contact saved.');
    } finally {
      nameController.dispose();
    }
  }

  void _selectTransport(BitsendAppState state, TransportKind transport) {
    state.setSendTransport(transport);
    setState(() {
      _selectedBleReceiverId = null;
      _selectedBleReceiverName = null;
      if (transport == TransportKind.ble) {
        _autoScannedBle = true;
      }
    });
    if (transport == TransportKind.ble && state.bleReceivers.isEmpty) {
      _scanBleReceivers(state);
    }
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final TransportKind transport = state.sendDraft.transport;
    final bool offlineMode = transport != TransportKind.online;
    final bool usingBitGo = state.activeWalletEngine == WalletEngine.bitgo;
    final String offlineMethodLabel = switch (transport) {
      TransportKind.online => 'Offline',
      TransportKind.hotspot => 'Hotspot',
      TransportKind.ble => 'Bluetooth',
      TransportKind.ultrasonic => 'Ultrasonic',
    };
    final bool offlineRouteResolved = switch (transport) {
      TransportKind.online => false,
      TransportKind.hotspot =>
        usingBitGo
            ? state.sendDraft.receiverAddress.isNotEmpty
            : state.sendDraft.receiverEndpoint.isNotEmpty,
      TransportKind.ble => true,
      TransportKind.ultrasonic => true,
    };
    return BitsendPageScaffold(
      title: 'Send',
      subtitle: usingBitGo
          ? 'Address and route.'
          : transport == TransportKind.online
          ? 'Direct wallet transfer.'
          : 'Address and route.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (usingBitGo && !state.bitgoBackendIsLive) ...<Widget>[
            const InlineBanner(
              title: 'Backend not live',
              caption:
                  'Send will switch to Local mode automatically and continue with the offline wallet flow until the BitGo backend is live.',
              icon: Icons.info_outline_rounded,
            ),
            const SizedBox(height: 16),
          ],
          SegmentedButton<bool>(
            segments: const <ButtonSegment<bool>>[
              ButtonSegment<bool>(
                value: false,
                label: Text('Online'),
                icon: Icon(Icons.public_rounded),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('Offline'),
                icon: Icon(Icons.wifi_tethering_rounded),
              ),
            ],
            selected: <bool>{offlineMode},
            onSelectionChanged: (Set<bool> value) {
              if (value.first) {
                _selectTransport(
                  state,
                  transport == TransportKind.online
                      ? TransportKind.hotspot
                      : transport,
                );
                return;
              }
              _selectTransport(state, TransportKind.online);
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _scanReceiverQr(state),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: Text(
              offlineMode && offlineRouteResolved
                  ? 'Scan another QR'
                  : 'Scan QR',
            ),
          ),
          const SizedBox(height: 16),
          if (offlineMode && !offlineRouteResolved)
            SectionCard(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: const _SendCompactEmptyState(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Scan receiver code',
                caption:
                    'Bitsend picks Hotspot, Bluetooth, or Ultrasonic automatically.',
              ),
            )
          else
            SectionCard(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        transport == TransportKind.online ? 'To' : 'Receiver',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (offlineMode) ...<Widget>[
                        const Spacer(),
                        _SendMiniBadge(label: offlineMethodLabel),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _addressController,
                    readOnly: transport == TransportKind.ultrasonic,
                    decoration: InputDecoration(
                      labelText: state.activeChain.isEvm
                          ? 'Receiver address or ENS'
                          : 'Receiver address',
                      hintText: state.activeChain.isEvm
                          ? 'alice.eth or 0x...'
                          : state.activeChain.receiverHintFor(
                              state.activeNetwork,
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: () => _pickContact(state),
                        icon: const Icon(Icons.bookmarks_rounded, size: 18),
                        label: const Text('Contacts'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _saveCurrentAsContact(state),
                        icon: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 18,
                        ),
                        label: const Text('Save'),
                      ),
                    ],
                  ),
                  if (state.activeChain.isEvm) ...<Widget>[
                    if (_resolvedReceiverAddress != null) ...<Widget>[
                      const SizedBox(height: 10),
                      _SendResolvedReceiverCard(
                        title: _resolvedReceiverLabel!,
                        address: _resolvedReceiverAddress!,
                      ),
                    ],
                    if (_resolvedReceiverPreference?.hasPreference ==
                        true) ...<Widget>[
                      const SizedBox(height: 10),
                      _SendCompactHint(
                        icon: Icons.tune_rounded,
                        text: 'Prefers ${_resolvedReceiverPreference!.summary}',
                      ),
                    ],
                  ],
                  if (transport == TransportKind.ultrasonic) ...<Widget>[
                    const SizedBox(height: 14),
                    const _SendCompactHint(
                      icon: Icons.phonelink_lock_rounded,
                      title: 'Pair ready',
                      text: 'Session is attached to this receiver.',
                    ),
                  ] else if (usingBitGo &&
                      transport == TransportKind.hotspot) ...<Widget>[
                    const SizedBox(height: 14),
                    const _SendCompactHint(
                      icon: Icons.cloud_sync_rounded,
                      title: 'Address only',
                      text: 'Hotspot just fills the receiver in BitGo mode.',
                    ),
                  ] else if (transport == TransportKind.hotspot) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      'Endpoint',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _endpointController,
                      decoration: const InputDecoration(
                        labelText: 'Receiver endpoint',
                        hintText: 'http://192.168.1.22:8787',
                      ),
                    ),
                  ] else if (transport == TransportKind.ble) ...<Widget>[
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Nearby',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: state.bleDiscovering
                              ? null
                              : () => _scanBleReceivers(state),
                          child: Text(
                            state.bleDiscovering
                                ? 'Scanning...'
                                : state.bleReceivers.isEmpty
                                ? 'Scan'
                                : 'Rescan',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (state.bleReceivers.isEmpty)
                      const _SendCompactEmptyState(
                        icon: Icons.bluetooth_searching_rounded,
                        title: 'No devices',
                        caption: 'Open Receive on the other phone.',
                      )
                    else
                      Column(
                        children: state.bleReceivers
                            .map(
                              (ReceiverDiscoveryItem item) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _SelectableReceiverCard(
                                  title: item.label,
                                  caption: item.hasVerifiedAddress
                                      ? item.address
                                      : item.subtitle,
                                  detail: item.metadataVerified
                                      ? item.signalLabel
                                      : '${item.signalLabel} · Wallet not verified yet',
                                  verified: item.metadataVerified,
                                  selected: _selectedBleReceiverId == item.id,
                                  onTap: () {
                                    setState(() {
                                      _selectedBleReceiverId = item.id;
                                      _selectedBleReceiverName = item.label;
                                      if (_isValidAddressForChain(
                                        item.resolvedAddress,
                                        state.activeChain,
                                      )) {
                                        _addressController.text =
                                            item.resolvedAddress;
                                      }
                                    });
                                  },
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
      bottom: ElevatedButton(
        onPressed: _resolvingEns ? null : () => _continue(state),
        child: Text(_resolvingEns ? 'Resolving ENS...' : 'Continue'),
      ),
    );
  }
}

class _SendTransportOptionTile extends StatelessWidget {
  const _SendTransportOptionTile({
    required this.title,
    this.caption,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? caption;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color tone = selected ? AppColors.ink : AppColors.slate;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.canvasTint
                : Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? AppColors.ink.withValues(alpha: 0.16)
                  : AppColors.line.withValues(alpha: 0.7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? AppColors.ink : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : AppColors.ink,
                  size: 20,
                ),
              ),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (caption != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  caption!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tone),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SendRouteRow extends StatelessWidget {
  const _SendRouteRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.canvasTint : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppColors.ink.withValues(alpha: 0.16)
                  : AppColors.line.withValues(alpha: 0.85),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected ? AppColors.ink : AppColors.canvasTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : AppColors.ink,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.ink : AppColors.slate,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendBlock extends StatelessWidget {
  const _SendBlock({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line, width: 1.2),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SendRouteChoice extends StatelessWidget {
  const _SendRouteChoice({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.canvasTint : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? AppColors.ink : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppColors.ink
                        : AppColors.line.withValues(alpha: 0.9),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.ink : AppColors.slate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendCompactHint extends StatelessWidget {
  const _SendCompactHint({required this.icon, required this.text, this.title});

  final IconData icon;
  final String text;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.canvasTint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: AppColors.slate),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (title != null) ...<Widget>[
                  Text(title!, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                ],
                Text(
                  text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SendMiniBadge extends StatelessWidget {
  const _SendMiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.canvasTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
      ),
    );
  }
}

class _SendMicroNote extends StatelessWidget {
  const _SendMicroNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
    );
  }
}

class _SendResolvedReceiverCard extends StatelessWidget {
  const _SendResolvedReceiverCard({required this.title, required this.address});

  final String title;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.emeraldTint.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.verified_rounded,
            color: AppColors.emerald,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  Formatters.shortAddress(address),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SendCompactEmptyState extends StatelessWidget {
  const _SendCompactEmptyState({
    required this.icon,
    required this.title,
    required this.caption,
  });

  final IconData icon;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      decoration: BoxDecoration(
        color: AppColors.canvasTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: AppColors.slate, size: 24),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
          ),
        ],
      ),
    );
  }
}

class SendAmountScreen extends StatefulWidget {
  const SendAmountScreen({super.key});

  @override
  State<SendAmountScreen> createState() => _SendAmountScreenState();
}

class _SendAmountScreenState extends State<SendAmountScreen> {
  late final TextEditingController _amountController;

  String? _sendReadinessMessage(BitsendAppState state) {
    if (state.activeWalletEngine == WalletEngine.bitgo) {
      if (!state.hasInternet) {
        return 'Connect online before submitting with BitGo mode.';
      }
      if (state.mainBalanceSol <= 0) {
        return 'Fund the BitGo wallet first.';
      }
      return null;
    }
    if (state.sendDraft.transport == TransportKind.online) {
      if (!state.hasWallet) {
        return 'Set up the wallet first.';
      }
      if (!state.hasInternet) {
        return 'Connect online before sending directly from your wallet.';
      }
      if (state.mainBalanceSol <= 0) {
        return 'Fund the wallet first.';
      }
      return null;
    }
    if (!state.hasWallet || !state.hasOfflineWallet) {
      return 'Set up the wallet first.';
    }
    if (!state.hasOfflineFunds) {
      if (state.offlineBalanceSol > 0 &&
          state.offlineSpendableBalanceSol <= 0) {
        return 'Offline wallet funds are fully reserved by pending transfers on this chain and network.';
      }
      return 'Top up the offline wallet first.';
    }
    if (!state.hasOfflineReadyBlockhash && !state.hasInternet) {
      return 'Connect online so Bitsend can refresh readiness before signing.';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final double amountSol = BitsendStateScope.of(context).sendDraft.amountSol;
    _amountController.text = amountSol > 0 ? amountSol.toStringAsFixed(3) : '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _continue(BitsendAppState state) {
    final double amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final String? amountMessage = amount <= 0
        ? 'Enter an amount greater than zero.'
        : null;
    if (amountMessage != null) {
      _showSnack(context, amountMessage);
      return;
    }
    state.updateAmount(amount);
    final String? readinessMessage = _sendReadinessMessage(state);
    if (readinessMessage != null) {
      _showSnack(context, readinessMessage);
      return;
    }
    final String? validationMessage = state.validateSendAmount(amount);
    if (validationMessage != null) {
      _showSnack(context, validationMessage);
      return;
    }
    Navigator.of(context).pushNamed(AppRoutes.sendReview);
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final WalletSummary summary = state.walletSummary;
    final ChainKind chain = state.activeChain;
    final AssetPortfolioHolding sendAsset = state.currentSendAssetHolding;
    final TrackedAssetDefinition sendAssetDefinition =
        state.currentSendAssetDefinition;
    final List<AssetPortfolioHolding> sendableAssets =
        state.availableSendAssetHoldings;
    final bool tokenSend = !sendAsset.isNative;
    final double amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final int baseUnits = sendAsset.amountToBaseUnits(amount);
    final String? readinessMessage = _sendReadinessMessage(state);
    final String? amountLimitMessage = amount > 0 && readinessMessage == null
        ? state.validateSendAmount(amount)
        : null;
    final bool usingBitGo = state.activeWalletEngine == WalletEngine.bitgo;
    final bool directOnline =
        !usingBitGo && state.sendDraft.transport == TransportKind.online;
    final bool autoRefreshOnSign =
        state.activeWalletEngine == WalletEngine.local &&
        !directOnline &&
        state.hasOfflineFunds &&
        !state.hasOfflineReadyBlockhash &&
        state.hasInternet;
    final double reservedOfflineBalance =
        usingBitGo || summary.offlineBalanceSol <= summary.offlineAvailableSol
        ? 0
        : summary.offlineBalanceSol - summary.offlineAvailableSol;
    return BitsendPageScaffold(
      title: 'Amount',
      subtitle: 'Enter the amount in ${chain.shortLabel}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (readinessMessage != null)
            InlineBanner(
              title: directOnline
                  ? 'Direct send needs internet'
                  : 'Finish offline prep',
              caption: readinessMessage,
              icon: directOnline
                  ? Icons.public_off_rounded
                  : Icons.lock_clock_rounded,
              action: directOnline
                  ? null
                  : OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRoutes.prepare);
                      },
                      child: const Text('Open offline wallet'),
                    ),
            ),
          if (autoRefreshOnSign)
            InlineBanner(
              title: 'Will refresh on sign',
              caption: chain == ChainKind.solana
                  ? 'Offline funds are ready. A fresh ${state.activeNetwork.shortLabelFor(chain).toLowerCase()} blockhash will be fetched automatically when you sign.'
                  : 'Offline funds are ready. A fresh ${state.activeNetwork.shortLabelFor(chain)} nonce and gas quote will be fetched automatically when you sign.',
              icon: Icons.sync_rounded,
            ),
          if (readinessMessage != null || autoRefreshOnSign)
            const SizedBox(height: 16),
          if (amountLimitMessage != null) ...<Widget>[
            InlineBanner(
              title: 'Amount too high',
              caption: amountLimitMessage,
              icon: Icons.account_balance_wallet_outlined,
            ),
            const SizedBox(height: 16),
          ],
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  onChanged: (_) {
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    labelText: 'Amount in ${sendAsset.resolvedSymbol}',
                    hintText: tokenSend
                        ? '0.00'
                        : chain == ChainKind.solana
                        ? '0.250'
                        : '0.010',
                  ),
                ),
                if (sendableAssets.length > 1) ...<Widget>[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: sendAsset.resolvedAssetId,
                    decoration: const InputDecoration(labelText: 'Asset'),
                    items: sendableAssets
                        .map(
                          (
                            AssetPortfolioHolding holding,
                          ) => DropdownMenuItem<String>(
                            value: holding.resolvedAssetId,
                            child: Text(
                              '${holding.resolvedSymbol}  ·  ${Formatters.holding(holding.mainBalance, holding)}',
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      state.selectSendAsset(value);
                      _amountController.clear();
                      setState(() {});
                    },
                  ),
                ],
                const SizedBox(height: 16),
                DetailRow(
                  label: tokenSend
                      ? '${sendAsset.resolvedSymbol} base units'
                      : 'Base units',
                  value: tokenSend
                      ? '$baseUnits'
                      : Formatters.baseUnits(baseUnits, chain),
                ),
                DetailRow(
                  label: tokenSend
                      ? 'Token available'
                      : usingBitGo
                      ? 'BitGo wallet available'
                      : directOnline
                      ? 'Wallet available'
                      : 'Spendable now',
                  value: tokenSend
                      ? Formatters.holding(
                          state.sourceBalanceForCurrentSendAsset,
                          sendAsset,
                        )
                      : Formatters.asset(
                          usingBitGo
                              ? state.mainBalanceSol
                              : directOnline
                              ? state.mainBalanceSol
                              : summary.offlineAvailableSol,
                          chain,
                        ),
                ),
                if (!tokenSend && !usingBitGo && !directOnline)
                  DetailRow(
                    label: 'Offline wallet total',
                    value: Formatters.asset(summary.offlineBalanceSol, chain),
                  ),
                if (!tokenSend && !usingBitGo && !directOnline)
                  DetailRow(
                    label: 'Reserved by pending',
                    value: Formatters.asset(reservedOfflineBalance, chain),
                  ),
                DetailRow(
                  label: tokenSend
                      ? 'Network fee in ${chain.shortLabel}'
                      : directOnline
                      ? 'Estimated network fee'
                      : usingBitGo
                      ? 'Network fee'
                      : 'Fee buffer',
                  value: Formatters.asset(
                    directOnline
                        ? state.estimatedOnlineSendFeeHeadroomSol
                        : state.estimatedSendFeeHeadroomSol,
                    chain,
                  ),
                ),
                DetailRow(
                  label: 'Max send now',
                  value: tokenSend
                      ? Formatters.holding(
                          state.maxSendAmountForCurrentAsset,
                          sendAsset,
                        )
                      : Formatters.asset(
                          directOnline
                              ? state.maxOnlineSendAmountSol
                              : state.maxSendAmountSol,
                          chain,
                        ),
                ),
                if (directOnline)
                  const DetailRow(label: 'Slippage', value: 'Not applicable'),
                if (!usingBitGo && !directOnline)
                  DetailRow(
                    label: usingBitGo ? 'Source wallet' : 'Offline wallet',
                    value: usingBitGo
                        ? (state.bitgoWallet?.displayLabel ??
                              state.bitgoWallet?.address ??
                              'Unavailable')
                        : (state.offlineWallet?.displayAddress ??
                              'Unavailable'),
                  ),
                if (directOnline)
                  DetailRow(
                    label: 'Source wallet',
                    value: state.wallet?.displayAddress ?? 'Unavailable',
                  ),
                if (usingBitGo)
                  DetailRow(
                    label: 'Source wallet',
                    value:
                        state.bitgoWallet?.displayLabel ??
                        state.bitgoWallet?.address ??
                        'Unavailable',
                  ),
                if (directOnline)
                  DetailRow(
                    label: 'Send type',
                    value: tokenSend
                        ? 'Direct token transfer'
                        : 'Direct on-chain',
                  ),
                if (!usingBitGo && !directOnline)
                  DetailRow(label: 'Send type', value: 'Nearby handoff'),
                if (usingBitGo)
                  DetailRow(label: 'Send type', value: 'BitGo online submit'),
              ],
            ),
          ),
        ],
      ),
      bottom: ElevatedButton(
        onPressed: () => _continue(state),
        child: const Text('Review transfer'),
      ),
    );
  }
}

class SendReviewScreen extends StatelessWidget {
  const SendReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final SendDraft draft = state.sendDraft;
    final WalletSummary summary = state.walletSummary;
    final ChainKind chain = draft.chain;
    final TrackedAssetDefinition sendAsset = state.currentSendAssetDefinition;
    final bool tokenSend = !sendAsset.isNative;
    final bool usingBitGo = draft.walletEngine == WalletEngine.bitgo;
    final bool directOnline =
        !usingBitGo && draft.transport == TransportKind.online;
    final String? amountLimitMessage = state.validateSendAmount(
      draft.amountSol,
    );
    if (!draft.hasReceiver || !draft.hasAmount) {
      return BitsendPageScaffold(
        title: 'Review transfer',
        subtitle: 'Receiver and amount are required before signing.',
        child: const EmptyStateCard(
          title: 'Transfer not ready',
          caption: 'Go back and finish the receiver and amount steps.',
          icon: Icons.assignment_late_rounded,
        ),
      );
    }

    return BitsendPageScaffold(
      title: 'Review transfer',
      subtitle: usingBitGo
          ? 'Check the receiver and amount before BitGo submits online.'
          : directOnline
          ? 'Check the address, fee estimate, and total before sending on-chain.'
          : 'Check the receiver, amount, and transport before signing.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InlineBanner(
            title: usingBitGo
                ? 'How submit works'
                : directOnline
                ? 'How direct send works'
                : 'When funds move',
            caption: usingBitGo
                ? 'This transfer is sent online through the BitGo backend. BLE or hotspot only helps capture the receiver details.'
                : directOnline
                ? 'Funds go straight from your wallet to the receiver on-chain. Network fee is estimated before submit.'
                : 'The receiver gets a signed transaction now. Settlement happens after broadcast.',
            icon: usingBitGo
                ? Icons.shield_outlined
                : directOnline
                ? Icons.public_rounded
                : Icons.info_outline_rounded,
          ),
          if (amountLimitMessage != null) ...<Widget>[
            const SizedBox(height: 16),
            InlineBanner(
              title: 'Amount too high',
              caption: amountLimitMessage,
              icon: Icons.account_balance_wallet_outlined,
            ),
          ],
          const SizedBox(height: 16),
          if (directOnline && chain.isEvm) ...<Widget>[
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Gas speed',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<GasSpeed>(
                    segments: GasSpeed.values
                        .map(
                          (GasSpeed speed) => ButtonSegment<GasSpeed>(
                            value: speed,
                            label: Text(speed.label),
                          ),
                        )
                        .toList(growable: false),
                    selected: <GasSpeed>{draft.gasSpeed},
                    onSelectionChanged: (Set<GasSpeed> value) {
                      state.setSendGasSpeed(value.first);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          SectionCard(
            child: Column(
              children: <Widget>[
                DetailRow(
                  label: 'Receiver',
                  value: draft.receiverLabel.isEmpty
                      ? Formatters.shortAddress(draft.receiverAddress)
                      : draft.receiverLabel,
                ),
                if (draft.receiverLabel.isNotEmpty)
                  DetailRow(
                    label: 'Resolved address',
                    value: Formatters.shortAddress(draft.receiverAddress),
                  ),
                if (draft.receiverPreferredChain.isNotEmpty ||
                    draft.receiverPreferredToken.isNotEmpty)
                  DetailRow(
                    label: 'ENS preference',
                    value: [
                      if (draft.receiverPreferredChain.isNotEmpty)
                        draft.receiverPreferredChain,
                      if (draft.receiverPreferredToken.isNotEmpty)
                        draft.receiverPreferredToken,
                    ].join(' / '),
                  ),
                DetailRow(
                  label: 'Source wallet',
                  value: usingBitGo
                      ? (state.bitgoWallet?.displayLabel ??
                            state.bitgoWallet?.address ??
                            'BitGo wallet unavailable')
                      : directOnline
                      ? (state.wallet?.displayAddress ?? 'Wallet unavailable')
                      : (state.offlineWallet?.displayAddress ??
                            'Offline wallet unavailable'),
                ),
                DetailRow(
                  label: directOnline
                      ? 'Route'
                      : usingBitGo
                      ? 'Discovery'
                      : draft.transport == TransportKind.hotspot
                      ? 'Endpoint'
                      : draft.transport == TransportKind.ble
                      ? 'BLE receiver'
                      : 'Session',
                  value: directOnline
                      ? 'Direct on-chain'
                      : usingBitGo
                      ? draft.transport.label
                      : draft.transport == TransportKind.hotspot
                      ? draft.receiverEndpoint
                      : draft.transport == TransportKind.ble
                      ? draft.receiverPeripheralName
                      : draft.receiverRelayId,
                ),
                DetailRow(
                  label: 'Amount',
                  value: tokenSend
                      ? Formatters.trackedAsset(draft.amountSol, sendAsset)
                      : Formatters.asset(draft.amountSol, chain),
                ),
                DetailRow(
                  label: tokenSend
                      ? 'Token balance left'
                      : directOnline
                      ? 'Wallet balance left'
                      : usingBitGo
                      ? 'BitGo balance left'
                      : 'Offline balance left',
                  value: tokenSend
                      ? Formatters.trackedAsset(
                          state.sourceBalanceForCurrentSendAsset >
                                  draft.amountSol
                              ? state.sourceBalanceForCurrentSendAsset -
                                    draft.amountSol
                              : 0,
                          sendAsset,
                        )
                      : Formatters.asset(
                          (directOnline
                                      ? state.mainBalanceSol
                                      : usingBitGo
                                      ? summary.balanceSol
                                      : summary.offlineAvailableSol) >
                                  draft.amountSol
                              ? (directOnline
                                        ? state.mainBalanceSol
                                        : usingBitGo
                                        ? summary.balanceSol
                                        : summary.offlineAvailableSol) -
                                    draft.amountSol
                              : 0,
                          chain,
                        ),
                ),
                if (directOnline)
                  FutureBuilder<SendQuote>(
                    future: state.quoteCurrentDraft(),
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<SendQuote> snapshot,
                        ) {
                          final SendQuote? quote = snapshot.data;
                          final double fee = quote == null
                              ? state.estimatedOnlineSendFeeHeadroomSol
                              : chain.amountFromBaseUnits(
                                  quote.networkFeeBaseUnits,
                                );
                          final double total = quote == null
                              ? (tokenSend
                                    ? draft.amountSol
                                    : draft.amountSol +
                                          state
                                              .estimatedOnlineSendFeeHeadroomSol)
                              : tokenSend
                              ? sendAsset.amountFromBaseUnits(
                                  quote.totalDebitBaseUnits,
                                )
                              : chain.amountFromBaseUnits(
                                  quote.totalDebitBaseUnits,
                                );
                          final String quoteMode = quote?.isEstimate == false
                              ? 'Live'
                              : 'Estimate';
                          return Column(
                            children: <Widget>[
                              DetailRow(
                                label: tokenSend
                                    ? 'Network fee in ${chain.shortLabel}'
                                    : 'Network fee',
                                value: Formatters.asset(fee, chain),
                              ),
                              DetailRow(
                                label: tokenSend
                                    ? 'Token debit'
                                    : 'Total debit',
                                value: tokenSend
                                    ? Formatters.trackedAsset(total, sendAsset)
                                    : Formatters.asset(total, chain),
                              ),
                              const DetailRow(
                                label: 'Slippage',
                                value: 'Not applicable',
                              ),
                              if (chain.isEvm)
                                DetailRow(
                                  label: 'Gas speed',
                                  value: draft.gasSpeed.label,
                                ),
                              DetailRow(label: 'Quote', value: quoteMode),
                            ],
                          );
                        },
                  ),
                if (!usingBitGo)
                  DetailRow(
                    label: 'Readiness age',
                    value: Formatters.durationLabel(summary.blockhashAge),
                  ),
                DetailRow(label: 'Chain', value: draft.network.labelFor(chain)),
                if (tokenSend)
                  DetailRow(label: 'Asset', value: sendAsset.displayName),
                if (!directOnline)
                  DetailRow(
                    label: usingBitGo ? 'Wallet mode' : 'Transport',
                    value: usingBitGo
                        ? '${draft.walletEngine.label} · ${draft.transport.label}'
                        : draft.transport.label,
                  ),
              ],
            ),
          ),
        ],
      ),
      bottom: draft.transport == TransportKind.ultrasonic && !usingBitGo
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const InlineBanner(
                  title: 'Courier relay available',
                  caption:
                      'Open the relay screen to copy a browser courier link for a phone without Bitsend. No QR is shown in this flow.',
                  icon: Icons.link_rounded,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: amountLimitMessage != null
                      ? null
                      : () {
                          Navigator.of(
                            context,
                          ).pushNamed(AppRoutes.sendProgress);
                        },
                  child: const Text('Sign and send'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: amountLimitMessage != null
                      ? null
                      : () {
                          Navigator.of(context).pushNamed(AppRoutes.sendRelay);
                        },
                  child: const Text('Open courier relay'),
                ),
              ],
            )
          : ElevatedButton(
              onPressed: amountLimitMessage != null
                  ? null
                  : () {
                      Navigator.of(context).pushNamed(AppRoutes.sendProgress);
                    },
              child: Text(
                usingBitGo
                    ? 'Submit with BitGo'
                    : directOnline
                    ? 'Send on-chain'
                    : 'Sign and send',
              ),
            ),
    );
  }
}

class SendRelayScreen extends StatefulWidget {
  const SendRelayScreen({super.key});

  @override
  State<SendRelayScreen> createState() => _SendRelayScreenState();
}

class _SendRelayScreenState extends State<SendRelayScreen> {
  PreparedRelayCapsule? _prepared;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepare();
    });
  }

  Future<void> _prepare() async {
    final BitsendAppState state = BitsendStateScope.of(context);
    try {
      final PreparedRelayCapsule prepared = await state
          .prepareRelayCapsuleForCurrentDraft();
      if (!mounted) {
        return;
      }
      setState(() {
        _prepared = prepared;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _messageFor(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final PreparedRelayCapsule? prepared = _prepared;
    return BitsendPageScaffold(
      title: 'Browser relay',
      subtitle:
          'Copy or share a courier link for a phone without Bitsend. The browser stores the encrypted capsule and uploads it later when internet is available.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_error != null) ...<Widget>[
            InlineBanner(
              title: 'Relay setup failed',
              caption: _error!,
              icon: Icons.error_outline_rounded,
            ),
            const SizedBox(height: 16),
          ],
          if (prepared == null && _error == null)
            const SectionCard(
              child: SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (prepared != null) ...<Widget>[
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: QrImageView(
                      data: prepared.relayUrl.toString(),
                      size: 220,
                      padding: EdgeInsets.zero,
                      semanticsLabel: 'Browser courier QR code',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const InlineBanner(
                    title: 'Courier QR ready',
                    caption:
                        'Scan or copy this encrypted courier link on any browser-capable phone. The browser stores it and uploads later when internet is available.',
                    icon: Icons.public_rounded,
                  ),
                  const SizedBox(height: 16),
                  DetailRow(
                    label: 'Relay ID',
                    value: prepared.relayCapsule.relayId,
                  ),
                  DetailRow(
                    label: 'Transfer',
                    value: prepared.transfer.transferId,
                  ),
                  DetailRow(
                    label: 'Amount',
                    value: Formatters.transferAmount(prepared.transfer),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: SelectionArea(
                child: Text(
                  prepared.relayUrl.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ],
      ),
      bottom: prepared == null
          ? (_error == null
                ? const SizedBox(
                    height: 56,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _prepared = null;
                      });
                      _prepare();
                    },
                    child: const Text('Try again'),
                  ))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ElevatedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: prepared.relayUrl.toString()),
                    );
                    if (!mounted) {
                      return;
                    }
                    _showSnack(context, 'Relay link copied.');
                  },
                  icon: const Icon(Icons.copy_all_rounded),
                  label: const Text('Copy link'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pushReplacementNamed(AppRoutes.sendSuccess);
                  },
                  child: const Text('Open success'),
                ),
              ],
            ),
    );
  }
}

class SendProgressScreen extends StatefulWidget {
  const SendProgressScreen({super.key});

  @override
  State<SendProgressScreen> createState() => _SendProgressScreenState();
}

class _SendProgressScreenState extends State<SendProgressScreen> {
  int _stage = 0;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _run();
    });
  }

  Future<void> _run() async {
    final BitsendAppState state = BitsendStateScope.of(context);
    try {
      setState(() {
        _stage = 1;
      });
      await state.sendCurrentDraft();
      if (!mounted) {
        return;
      }
      setState(() {
        _stage = 2;
      });
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(AppRoutes.sendSuccess);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _messageFor(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final TransportKind transport = state.sendDraft.transport;
    final bool usingBitGo = state.sendDraft.walletEngine == WalletEngine.bitgo;
    final bool directOnline = !usingBitGo && transport == TransportKind.online;
    final List<_ProgressStep> steps = usingBitGo
        ? <_ProgressStep>[
            _ProgressStep(
              title: 'Queue transfer',
              caption: 'The destination and amount are queued for BitGo.',
              complete: _stage > 0,
              current: _stage == 0,
            ),
            _ProgressStep(
              title: 'Submit online',
              caption:
                  'The BitGo backend orchestrates submission for the selected chain.',
              complete: _stage > 1,
              current: _stage == 1,
            ),
            _ProgressStep(
              title: 'Stored in queue',
              caption:
                  'The transfer is now tracked in Pending until the backend confirms it.',
              complete: _stage > 1 && _error == null,
              current: _stage == 2,
            ),
          ]
        : directOnline
        ? <_ProgressStep>[
            _ProgressStep(
              title: 'Estimate fee',
              caption:
                  'Bitsend prepares the network fee and final debit before submit.',
              complete: _stage > 0,
              current: _stage == 0,
            ),
            _ProgressStep(
              title: 'Submit on-chain',
              caption:
                  'The transfer is sent directly from your wallet to the network.',
              complete: _stage > 1,
              current: _stage == 1,
            ),
            _ProgressStep(
              title: 'Track confirmation',
              caption:
                  'Pending watches for the chain confirmation after the hash is accepted.',
              complete: _stage > 1 && _error == null,
              current: _stage == 2,
            ),
          ]
        : <_ProgressStep>[
            _ProgressStep(
              title: 'Sign transfer',
              caption: 'The offline wallet signs the transfer locally.',
              complete: _stage > 0,
              current: _stage == 0,
            ),
            _ProgressStep(
              title: 'Deliver offline',
              caption: transport == TransportKind.hotspot
                  ? 'The signed envelope is sent to the receiver over the local network.'
                  : transport == TransportKind.ble
                  ? 'The signed envelope is sent to the receiver over BLE.'
                  : 'The signed envelope is sent over the ultrasonic session.',
              complete: _stage > 1,
              current: _stage == 1,
            ),
            _ProgressStep(
              title: 'Delivered',
              caption: 'The receiver stored the signed transfer.',
              complete: _stage > 1 && _error == null,
              current: _stage == 2,
            ),
          ];

    return BitsendPageScaffold(
      title: 'Sending',
      subtitle: _error == null
          ? usingBitGo
                ? 'Submitting through the BitGo backend.'
                : directOnline
                ? 'Sending directly on-chain from your wallet.'
                : 'Signing locally and delivering over the selected link.'
          : 'Delivery stopped before completion.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_error != null) ...<Widget>[
            InlineBanner(
              title: 'Send failed',
              caption: _error!,
              icon: Icons.error_outline_rounded,
            ),
            const SizedBox(height: 16),
          ],
          SectionCard(
            child: Column(
              children: steps
                  .asMap()
                  .entries
                  .map(
                    (MapEntry<int, _ProgressStep> entry) => Padding(
                      padding: EdgeInsets.only(
                        bottom: entry.key == steps.length - 1 ? 0 : 16,
                      ),
                      child: _ProgressTile(step: entry.value),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
      bottom: _error == null
          ? const SizedBox(
              height: 56,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _stage = 0;
                    });
                    _run();
                  },
                  child: const Text('Try again'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Back'),
                ),
              ],
            ),
    );
  }
}

class SendSuccessScreen extends StatefulWidget {
  const SendSuccessScreen({super.key});

  @override
  State<SendSuccessScreen> createState() => _SendSuccessScreenState();
}

class _SendSuccessScreenState extends State<SendSuccessScreen> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _didCelebrate = false;
  bool _savingToFileverse = false;
  String? _fileverseProgressText;
  bool _queuedReceiptRefresh = false;

  void _celebrate(PendingTransfer? transfer) {
    if (_didCelebrate || transfer == null) {
      return;
    }
    _didCelebrate = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HapticFeedback.heavyImpact();
      unawaited(SystemSound.play(SystemSoundType.alert));
    });
  }

  Future<void> _saveReceipt(PendingTransfer transfer) async {
    try {
      final String path = await _captureReceiptImage(
        context,
        _receiptKey,
        transfer.transferId,
      );
      await Clipboard.setData(ClipboardData(text: path));
      if (!mounted) {
        return;
      }
      _showSnack(context, 'Receipt image saved. Path copied.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    }
  }

  Future<void> _saveReceiptToFileverse(
    BitsendAppState state,
    PendingTransfer transfer,
  ) async {
    setState(() {
      _savingToFileverse = true;
      _fileverseProgressText = 'Checking backend...';
    });
    try {
      BitGoBackendHealth? health;
      try {
        health = await state.fetchBackendHealth();
      } catch (_) {}
      if (!mounted) {
        return;
      }
      setState(() {
        _fileverseProgressText =
            '${health == null ? 'Backend' : _fileverseBackendLabel(health)} ready. Encrypting receipt...';
      });
      final Uint8List bytes = await _captureReceiptPngBytesForFileverse(
        context,
        _receiptKey,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _fileverseProgressText = 'Publishing encrypted receipt to Fileverse...';
      });
      final PendingTransfer updated = await state.saveReceiptToFileverse(
        transferId: transfer.transferId,
        receiptPngBytes: bytes,
      );
      if (updated.fileverseReceiptUrl != null &&
          updated.fileverseReceiptUrl!.isNotEmpty) {
        await Clipboard.setData(
          ClipboardData(text: updated.fileverseReceiptUrl!),
        );
      }
      if (!mounted) {
        return;
      }
      _showSnack(
        context,
        _receiptOnlineActionMessage(
          previousTransfer: transfer,
          updatedTransfer: updated,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    } finally {
      if (mounted) {
        setState(() {
          _savingToFileverse = false;
          _fileverseProgressText = null;
        });
      }
    }
  }

  Future<void> _refreshReceiptArchive(
    BitsendAppState state,
    PendingTransfer transfer,
  ) async {
    try {
      for (int attempt = 0; attempt < 6; attempt += 1) {
        await Future<void>.delayed(Duration(seconds: attempt == 0 ? 3 : 5));
        if (!mounted) {
          return;
        }
        final PendingTransfer? updated = await state.refreshReceiptArchive(
          transfer.transferId,
        );
        if (updated == null ||
            updated.isReceiptSavedInFileverse ||
            !updated.hasReceiptArchive) {
          return;
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final PendingTransfer? transfer = state.lastSentTransfer;
    _celebrate(transfer);
    if (transfer != null &&
        transfer.hasReceiptArchive &&
        !transfer.isReceiptSavedInFileverse &&
        !_queuedReceiptRefresh) {
      _queuedReceiptRefresh = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_refreshReceiptArchive(state, transfer));
      });
    }
    final bool usingBitGo = transfer?.walletEngine == WalletEngine.bitgo;
    final bool directOnchain = transfer?.isDirectOnchainTransfer == true;
    return BitsendPageScaffold(
      title: usingBitGo || directOnchain ? 'Submitted' : 'Delivered',
      subtitle: usingBitGo
          ? 'The transfer was submitted through BitGo and will keep syncing in Pending.'
          : directOnchain
          ? 'The transfer was submitted directly to the chain and Pending will keep syncing confirmation.'
          : 'The signed transfer was delivered. Any online device can settle it.',
      showBack: false,
      child: transfer == null
          ? const EmptyStateCard(
              title: 'No transfer found',
              caption: 'Send a transfer first to see the delivery receipt.',
              icon: Icons.assignment_late_rounded,
            )
          : _TransferReceiptSurface(
              boundaryKey: _receiptKey,
              eyebrow: usingBitGo
                  ? 'BitGo receipt'
                  : directOnchain
                  ? 'On-chain receipt'
                  : 'Delivery receipt',
              title: usingBitGo
                  ? 'Submitted with BitGo'
                  : directOnchain
                  ? 'Submitted on-chain'
                  : 'Sent offline',
              caption: usingBitGo
                  ? 'BitGo accepted the transfer. Confirmation will continue automatically while the app is online.'
                  : directOnchain
                  ? 'The chain RPC accepted the transaction. Confirmation will keep syncing automatically while the app is online.'
                  : 'Receiver stored the signed transfer. Settlement can continue automatically when any device is online.',
              icon: usingBitGo
                  ? Icons.shield_outlined
                  : directOnchain
                  ? Icons.public_rounded
                  : Icons.check_circle_rounded,
              tone: usingBitGo || directOnchain
                  ? AppColors.blue
                  : AppColors.emerald,
              transfer: transfer,
              focusLabel: 'Receiver',
              focusValue: transfer.receiverAddress,
            ),
      bottom: transfer == null
          ? ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.pending,
                  ModalRoute.withName(AppRoutes.home),
                );
              },
              child: const Text('Open pending'),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _saveReceipt(transfer),
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Save image'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _savingToFileverse
                            ? null
                            : () => _saveReceiptToFileverse(state, transfer),
                        icon: _savingToFileverse
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                !transfer.hasReceiptLink
                                    ? Icons.cloud_upload_outlined
                                    : Icons.link_rounded,
                              ),
                        label: Text(
                          _savingToFileverse
                              ? 'Saving...'
                              : _receiptOnlineButtonLabel(transfer),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_savingToFileverse &&
                    _fileverseProgressText != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _fileverseProgressText!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.pending,
                        ModalRoute.withName(AppRoutes.home),
                      );
                    },
                    child: const Text('Open pending'),
                  ),
                ),
              ],
            ),
    );
  }
}

class ReceiveListenScreen extends StatefulWidget {
  const ReceiveListenScreen({super.key});

  @override
  State<ReceiveListenScreen> createState() => _ReceiveListenScreenState();
}

class _ReceiveListenScreenState extends State<ReceiveListenScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _seenTransferId;
  int _seenAnnouncementSerial = 0;
  bool _started = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final BitsendAppState state = BitsendStateScope.of(context);
    if (!_started && state.activeWalletEngine == WalletEngine.local) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startListening(state);
      });
    }
    if (state.announcementMessage != null &&
        state.announcementSerial != _seenAnnouncementSerial) {
      final String message = state.announcementMessage!;
      _seenAnnouncementSerial = state.announcementSerial;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _showEventToast(
          context,
          message: message,
          icon: _iconForReceiveMessage(message),
        );
        state.clearAnnouncement();
      });
    }
    if (state.lastReceivedTransferId != null &&
        state.lastReceivedTransferId != _seenTransferId) {
      final String transferId = state.lastReceivedTransferId!;
      _seenTransferId = transferId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final PendingTransfer? transfer = state.transferById(transferId);
        _showReceivedTransferToast(context, transfer);
        Future<void>.delayed(const Duration(milliseconds: 450), () {
          if (!mounted) {
            return;
          }
          state.acknowledgeLastReceivedTransfer();
          Navigator.of(
            context,
          ).pushNamed(AppRoutes.receiveResult, arguments: transferId);
        });
      });
    }
  }

  Future<void> _startListening(BitsendAppState state) async {
    try {
      await state.startReceiver();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String message = _messageFor(error);
      if (state.receiveTransport == TransportKind.ble &&
          _looksLikeBluetoothNeedsAttention(message)) {
        await _showBluetoothPrompt(context, message);
        return;
      }
      _showSnack(context, message);
    }
  }

  Future<void> _toggle(BitsendAppState state) async {
    try {
      if (state.listenerRunning) {
        await state.stopReceiver();
      } else {
        await state.startReceiver();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String message = _messageFor(error);
      if (state.receiveTransport == TransportKind.ble &&
          _looksLikeBluetoothNeedsAttention(message)) {
        await _showBluetoothPrompt(context, message);
        return;
      }
      _showSnack(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final TransportKind transport = state.receiveTransport;
    final bool usingBitGo = state.activeWalletEngine == WalletEngine.bitgo;
    final bool showUltrasonic = !usingBitGo && state.ultrasonicSupported;
    final bool activeListener = transport == TransportKind.hotspot
        ? state.hotspotListenerRunning
        : transport == TransportKind.ble
        ? state.bleListenerRunning
        : state.ultrasonicListenerRunning;
    final ReceiverInvitePayload? invite = _receiverInvitePayload(
      state,
      transport,
      activeListener: activeListener && !usingBitGo,
    );
    return BitsendPageScaffold(
      title: 'Receive',
      subtitle: usingBitGo
          ? 'BitGo mode does not listen offline. Switch back to Local mode to receive over hotspot, BLE, or ultrasonic.'
          : 'Catch a signed handoff over hotspot, BLE, or ultrasonic.',
      onRefresh: state.working ? null : state.refreshStatus,
      showBack: false,
      showHeader: false,
      scrollController: _scrollController,
      primaryTab: BitsendPrimaryTab.home,
      onPrimaryTabSelected: (BitsendPrimaryTab tab) {
        _navigatePrimaryTab(context, tab);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (usingBitGo) ...<Widget>[
            const InlineBanner(
              title: 'BitGo mode does not listen offline',
              caption:
                  'Switch back to Local mode from the header to receive over hotspot, BLE, or ultrasonic.',
              icon: Icons.shield_outlined,
            ),
            const SizedBox(height: 16),
          ],
          _ReceiveStudioCard(
            scrollController: _scrollController,
            transport: transport,
            activeListener: activeListener && !usingBitGo,
            hasWallet: state.hasWallet,
            showUltrasonic: showUltrasonic,
            invite: invite,
            receiverDisplayAddress:
                state.wallet?.displayAddress ?? 'Wallet missing',
            receiverAddress:
                state.wallet?.address ?? 'Set up the wallet first.',
            endpoint: state.localEndpoint,
            onTransportChanged: (TransportKind next) async {
              if (usingBitGo) {
                return;
              }
              if (state.listenerRunning) {
                await state.stopReceiver();
              }
              state.setReceiveTransport(next);
            },
            onToggle: state.hasWallet && !usingBitGo
                ? () => _toggle(state)
                : null,
            onOpenPending: () {
              Navigator.of(context).pushNamed(AppRoutes.pending);
            },
          ),
        ],
      ),
    );
  }
}

class ReceiveResultScreen extends StatefulWidget {
  const ReceiveResultScreen({super.key, this.transferId});

  final String? transferId;

  @override
  State<ReceiveResultScreen> createState() => _ReceiveResultScreenState();
}

class _ReceiveResultScreenState extends State<ReceiveResultScreen> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _didCelebrate = false;
  bool _savingToFileverse = false;
  String? _fileverseProgressText;
  bool _queuedReceiptRefresh = false;

  void _celebrate(PendingTransfer? transfer) {
    if (_didCelebrate || transfer == null) {
      return;
    }
    _didCelebrate = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HapticFeedback.mediumImpact();
      unawaited(SystemSound.play(SystemSoundType.alert));
    });
  }

  Future<void> _saveReceipt(PendingTransfer transfer) async {
    try {
      final String path = await _captureReceiptImage(
        context,
        _receiptKey,
        transfer.transferId,
      );
      await Clipboard.setData(ClipboardData(text: path));
      if (!mounted) {
        return;
      }
      _showSnack(context, 'Receipt image saved. Path copied.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    }
  }

  Future<void> _saveReceiptToFileverse(
    BitsendAppState state,
    PendingTransfer transfer,
  ) async {
    setState(() {
      _savingToFileverse = true;
      _fileverseProgressText = 'Checking backend...';
    });
    try {
      BitGoBackendHealth? health;
      try {
        health = await state.fetchBackendHealth();
      } catch (_) {}
      if (!mounted) {
        return;
      }
      setState(() {
        _fileverseProgressText =
            '${health == null ? 'Backend' : _fileverseBackendLabel(health)} ready. Encrypting receipt...';
      });
      final Uint8List bytes = await _captureReceiptPngBytesForFileverse(
        context,
        _receiptKey,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _fileverseProgressText = 'Publishing encrypted receipt to Fileverse...';
      });
      final PendingTransfer updated = await state.saveReceiptToFileverse(
        transferId: transfer.transferId,
        receiptPngBytes: bytes,
      );
      if (updated.fileverseReceiptUrl != null &&
          updated.fileverseReceiptUrl!.isNotEmpty) {
        await Clipboard.setData(
          ClipboardData(text: updated.fileverseReceiptUrl!),
        );
      }
      if (!mounted) {
        return;
      }
      _showSnack(
        context,
        _receiptOnlineActionMessage(
          previousTransfer: transfer,
          updatedTransfer: updated,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    } finally {
      if (mounted) {
        setState(() {
          _savingToFileverse = false;
          _fileverseProgressText = null;
        });
      }
    }
  }

  Future<void> _refreshReceiptArchive(
    BitsendAppState state,
    PendingTransfer transfer,
  ) async {
    try {
      for (int attempt = 0; attempt < 6; attempt += 1) {
        await Future<void>.delayed(Duration(seconds: attempt == 0 ? 3 : 5));
        if (!mounted) {
          return;
        }
        final PendingTransfer? updated = await state.refreshReceiptArchive(
          transfer.transferId,
        );
        if (updated == null ||
            updated.isReceiptSavedInFileverse ||
            !updated.hasReceiptArchive) {
          return;
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final PendingTransfer? transfer = widget.transferId == null
        ? state.lastReceivedTransfer
        : state.transferById(widget.transferId!);
    _celebrate(transfer);
    if (transfer != null &&
        transfer.hasReceiptArchive &&
        !transfer.isReceiptSavedInFileverse &&
        !_queuedReceiptRefresh) {
      _queuedReceiptRefresh = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_refreshReceiptArchive(state, transfer));
      });
    }
    return BitsendPageScaffold(
      title: 'Transfer received',
      subtitle: 'Stored locally and ready for later settlement.',
      child: transfer == null
          ? const EmptyStateCard(
              title: 'No transfer loaded',
              caption:
                  'Go back to Receive and wait for the next offline handoff.',
              icon: Icons.inbox_rounded,
            )
          : _TransferReceiptSurface(
              boundaryKey: _receiptKey,
              eyebrow: 'Receive receipt',
              title: 'Signed handoff stored',
              caption:
                  'This transfer can settle from any device that later comes online.',
              icon: Icons.inventory_2_rounded,
              tone: AppColors.amber,
              transfer: transfer,
              focusLabel: 'Sender',
              focusValue: transfer.senderAddress,
            ),
      bottom: transfer == null
          ? ElevatedButton(
              onPressed: () {
                Navigator.of(context).maybePop();
              },
              child: const Text('Back to receive'),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _saveReceipt(transfer),
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Save image'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _savingToFileverse
                            ? null
                            : () => _saveReceiptToFileverse(state, transfer),
                        icon: _savingToFileverse
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                !transfer.hasReceiptLink
                                    ? Icons.cloud_upload_outlined
                                    : Icons.link_rounded,
                              ),
                        label: Text(
                          _savingToFileverse
                              ? 'Saving...'
                              : _receiptOnlineButtonLabel(transfer),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_savingToFileverse &&
                    _fileverseProgressText != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _fileverseProgressText!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed(
                        AppRoutes.transferDetail(transfer.transferId),
                      );
                    },
                    child: const Text('Open timeline'),
                  ),
                ),
              ],
            ),
    );
  }
}

const int _fileverseReceiptMaxBytes = 420 * 1024;

Future<Uint8List> _captureReceiptPngBytes(
  BuildContext context,
  GlobalKey boundaryKey, {
  List<double>? preferredPixelRatios,
}) async {
  final BuildContext? boundaryContext = boundaryKey.currentContext;
  if (boundaryContext == null) {
    throw StateError('Receipt is still preparing. Try again in a moment.');
  }
  final RenderRepaintBoundary boundary =
      boundaryContext.findRenderObject()! as RenderRepaintBoundary;
  final double devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  final List<double> pixelRatios = preferredPixelRatios?.isNotEmpty == true
      ? preferredPixelRatios!
      : <double>[devicePixelRatio.clamp(1.8, 3.0).toDouble()];
  for (final double pixelRatio in pixelRatios) {
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } finally {
      image.dispose();
    }
  }
  throw StateError('Could not generate the receipt image.');
}

Future<Uint8List> _captureReceiptPngBytesForFileverse(
  BuildContext context,
  GlobalKey boundaryKey,
) async {
  final double devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  final List<double> uploadPixelRatios = <double>[
    devicePixelRatio.clamp(1.2, 1.6).toDouble(),
    devicePixelRatio.clamp(1.0, 1.25).toDouble(),
    0.9,
    0.75,
    0.6,
  ].toSet().toList();
  Uint8List? smallestBytes;
  for (final double pixelRatio in uploadPixelRatios) {
    final Uint8List bytes = await _captureReceiptPngBytes(
      context,
      boundaryKey,
      preferredPixelRatios: <double>[pixelRatio],
    );
    smallestBytes = bytes;
    if (bytes.lengthInBytes <= _fileverseReceiptMaxBytes) {
      return bytes;
    }
  }
  return smallestBytes!;
}

Future<String> _captureReceiptImage(
  BuildContext context,
  GlobalKey boundaryKey,
  String transferId,
) async {
  final Uint8List bytes = await _captureReceiptPngBytes(context, boundaryKey);
  final Directory directory = await path_provider
      .getApplicationDocumentsDirectory();
  final String safeTransferId = transferId.replaceAll(
    RegExp(r'[^A-Za-z0-9_-]'),
    '_',
  );
  final File file = File(
    '${directory.path}/bitsend-receipt-$safeTransferId.png',
  );
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

String _receiptOnlineButtonLabel(PendingTransfer transfer) {
  if (!transfer.hasReceiptLink) {
    return 'Save to Fileverse';
  }
  return transfer.isReceiptSavedInFileverse
      ? 'Copy Fileverse link'
      : 'Copy receipt link';
}

String _receiptOnlineActionMessage({
  required PendingTransfer previousTransfer,
  required PendingTransfer updatedTransfer,
}) {
  if (previousTransfer.fileverseReceiptUrl ==
      updatedTransfer.fileverseReceiptUrl) {
    return updatedTransfer.isReceiptSavedInFileverse
        ? 'Fileverse link copied.'
        : 'Receipt link copied.';
  }
  return switch (updatedTransfer.fileverseStorageMode) {
    'fileverse' => 'Encrypted Fileverse receipt saved. Link copied.',
    'worker' =>
      'Receipt archived online. Link copied while Fileverse finishes syncing.',
    _ => 'Receipt link copied.',
  };
}

String _fileverseBackendLabel(BitGoBackendHealth health) {
  if (health.version.isNotEmpty) {
    return 'Backend v${health.version}';
  }
  return 'Backend ${health.mode.label}';
}

String _receiptIdLabel(PendingTransfer transfer) {
  return switch (transfer.fileverseStorageMode) {
    'fileverse' => 'Fileverse ID',
    'worker' => 'Archive ID',
    _ => 'Receipt ID',
  };
}

String _receiptLinkLabel(PendingTransfer transfer) {
  return transfer.isReceiptSavedInFileverse ? 'Fileverse link' : 'Receipt link';
}

String? _receiptStorageCaption(PendingTransfer transfer) {
  if (transfer.fileverseMessage != null &&
      transfer.fileverseMessage!.isNotEmpty) {
    return transfer.fileverseMessage!;
  }
  return switch (transfer.fileverseStorageMode) {
    'fileverse' => 'This link points to the Fileverse record for this receipt.',
    'worker' =>
      'This link points to the Bitsend archive while Fileverse sync continues in the background.',
    _ => null,
  };
}

class _TransferReceiptSurface extends StatelessWidget {
  const _TransferReceiptSurface({
    required this.boundaryKey,
    required this.eyebrow,
    required this.title,
    required this.caption,
    required this.icon,
    required this.tone,
    required this.transfer,
    required this.focusLabel,
    required this.focusValue,
  });

  final GlobalKey boundaryKey;
  final String eyebrow;
  final String title;
  final String caption;
  final IconData icon;
  final Color tone;
  final PendingTransfer transfer;
  final String focusLabel;
  final String focusValue;

  @override
  Widget build(BuildContext context) {
    final List<_ReceiptMilestone> milestones = _receiptMilestones(transfer);
    final List<_ReceiptIndicator> indicators = _receiptIndicators(transfer);
    final String? receiptStorageLabel = transfer.receiptStorageLabel;
    final String? receiptStorageCaption = _receiptStorageCaption(transfer);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 540),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? child) {
        return Transform.translate(
          offset: Offset(0, 28 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: RepaintBoundary(
        key: boundaryKey,
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.98),
                tone.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(color: tone.withValues(alpha: 0.14)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      eyebrow.toUpperCase(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: tone,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ),
                  StatusPill(status: transfer.status),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: tone, size: 30),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              Text(
                caption,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.slate),
              ),
              const SizedBox(height: 24),
              Text(
                Formatters.transferAmount(transfer),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$focusLabel ${Formatters.shortAddress(focusValue)}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppColors.slate),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: indicators
                    .map(
                      (_ReceiptIndicator indicator) =>
                          _ReceiptIndicatorChip(indicator: indicator),
                    )
                    .toList(growable: false),
              ),
              if (receiptStorageLabel != null &&
                  transfer.hasReceiptArchive &&
                  receiptStorageCaption != null) ...<Widget>[
                const SizedBox(height: 18),
                InlineBanner(
                  title: receiptStorageLabel,
                  caption: receiptStorageCaption,
                  icon: transfer.isReceiptSavedInFileverse
                      ? Icons.verified_rounded
                      : Icons.inventory_2_outlined,
                ),
              ],
              const SizedBox(height: 24),
              _ReceiptDivider(color: tone),
              const SizedBox(height: 18),
              Text(
                'Status journey',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              _ReceiptTimeline(milestones: milestones, tone: tone),
              const SizedBox(height: 24),
              _ReceiptDivider(color: tone),
              const SizedBox(height: 18),
              Text(
                'Transfer details',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              DetailRow(label: 'Transfer ID', value: transfer.transferId),
              DetailRow(
                label: 'Wallet mode',
                value: transfer.walletEngine.label,
              ),
              DetailRow(label: focusLabel, value: focusValue),
              DetailRow(
                label: transfer.walletEngine == WalletEngine.bitgo
                    ? 'Discovery'
                    : 'Transport',
                value: transfer.transport.shortLabel,
              ),
              DetailRow(
                label: 'Updated',
                value: Formatters.dateTime(transfer.updatedAt),
              ),
              if (transfer.remoteEndpoint != null)
                DetailRow(label: 'Endpoint', value: transfer.remoteEndpoint!),
              if (transfer.transactionSignature != null)
                DetailRow(
                  label: 'Signature',
                  value: Formatters.shortAddress(
                    transfer.transactionSignature!,
                  ),
                ),
              if (transfer.backendStatus != null)
                DetailRow(
                  label: 'Backend status',
                  value: transfer.backendStatus!,
                ),
              if (transfer.hasReceiptArchive &&
                  transfer.fileverseSavedAt != null)
                DetailRow(
                  label: 'Receipt saved',
                  value: Formatters.dateTime(transfer.fileverseSavedAt!),
                ),
              if (receiptStorageLabel != null)
                DetailRow(
                  label: 'Receipt provider',
                  value: receiptStorageLabel,
                ),
              if (transfer.hasReceiptArchive &&
                  transfer.fileverseReceiptId != null)
                DetailRow(
                  label: _receiptIdLabel(transfer),
                  value: transfer.fileverseReceiptId!,
                ),
              if (transfer.hasReceiptArchive &&
                  transfer.fileverseMessage != null)
                DetailRow(
                  label: 'Receipt note',
                  value: transfer.fileverseMessage!,
                ),
              if (transfer.lastError != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  transfer.lastError!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: transfer.status == TransferStatus.expired
                        ? AppColors.red
                        : AppColors.amber,
                  ),
                ),
              ],
              if (transfer.explorerUrl != null) ...<Widget>[
                const SizedBox(height: 18),
                Text(
                  'Explorer',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  transfer.explorerUrl!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                ),
              ],
              if (transfer.hasReceiptLink &&
                  transfer.fileverseReceiptUrl != null) ...<Widget>[
                const SizedBox(height: 18),
                Text(
                  _receiptLinkLabel(transfer),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  transfer.fileverseReceiptUrl!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptTimeline extends StatelessWidget {
  const _ReceiptTimeline({required this.milestones, required this.tone});

  final List<_ReceiptMilestone> milestones;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 520;
        if (compact) {
          return Column(
            children: milestones
                .map(
                  (_ReceiptMilestone milestone) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ReceiptTimelineRow(
                      milestone: milestone,
                      tone: tone,
                    ),
                  ),
                )
                .toList(growable: false),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: milestones
              .asMap()
              .entries
              .map(
                (MapEntry<int, _ReceiptMilestone> entry) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: entry.key == milestones.length - 1 ? 0 : 12,
                    ),
                    child: _ReceiptTimelineRow(
                      milestone: entry.value,
                      tone: tone,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _ReceiptTimelineRow extends StatelessWidget {
  const _ReceiptTimelineRow({required this.milestone, required this.tone});

  final _ReceiptMilestone milestone;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (milestone.state) {
      _ReceiptMilestoneState.complete => tone,
      _ReceiptMilestoneState.current => AppColors.amber,
      _ReceiptMilestoneState.error => AppColors.red,
      _ReceiptMilestoneState.pending => AppColors.slateTint,
    };
    final Color background = switch (milestone.state) {
      _ReceiptMilestoneState.complete => tone.withValues(alpha: 0.12),
      _ReceiptMilestoneState.current => AppColors.amberTint.withValues(
        alpha: 0.92,
      ),
      _ReceiptMilestoneState.error => AppColors.redTint.withValues(alpha: 0.92),
      _ReceiptMilestoneState.pending => AppColors.canvasWarm,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: milestone.state == _ReceiptMilestoneState.complete
                  ? color
                  : Colors.white,
              border: Border.all(color: color, width: 2),
            ),
            child: milestone.state == _ReceiptMilestoneState.complete
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : milestone.state == _ReceiptMilestoneState.error
                ? Icon(Icons.close_rounded, size: 14, color: color)
                : milestone.state == _ReceiptMilestoneState.current
                ? Container(
                    margin: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              milestone.label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptIndicatorChip extends StatelessWidget {
  const _ReceiptIndicatorChip({required this.indicator});

  final _ReceiptIndicator indicator;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: indicator.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(indicator.icon, size: 16, color: indicator.color),
          const SizedBox(width: 8),
          Text(
            indicator.label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: indicator.color),
          ),
        ],
      ),
    );
  }
}

class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: color.withValues(alpha: 0.12));
  }
}

class _ReceiptIndicator {
  const _ReceiptIndicator({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color background;
}

enum _ReceiptMilestoneState { pending, current, complete, error }

class _ReceiptMilestone {
  const _ReceiptMilestone({required this.label, required this.state});

  final String label;
  final _ReceiptMilestoneState state;
}

List<_ReceiptIndicator> _receiptIndicators(PendingTransfer transfer) {
  final _ReceiptIndicator settlementIndicator = switch (transfer.status) {
    TransferStatus.confirmed => const _ReceiptIndicator(
      label: 'Confirmed',
      icon: Icons.verified_rounded,
      color: AppColors.emerald,
      background: AppColors.emeraldTint,
    ),
    TransferStatus.broadcastSubmitted => const _ReceiptIndicator(
      label: 'Awaiting confirmation',
      icon: Icons.cloud_done_rounded,
      color: AppColors.blue,
      background: AppColors.blueTint,
    ),
    TransferStatus.broadcastFailed ||
    TransferStatus.expired => const _ReceiptIndicator(
      label: 'Needs resend',
      icon: Icons.error_outline_rounded,
      color: AppColors.red,
      background: AppColors.redTint,
    ),
    _ => const _ReceiptIndicator(
      label: 'Awaiting settlement',
      icon: Icons.hourglass_top_rounded,
      color: AppColors.amber,
      background: AppColors.amberTint,
    ),
  };

  if (transfer.walletEngine == WalletEngine.bitgo) {
    return <_ReceiptIndicator>[
      const _ReceiptIndicator(
        label: 'Managed by BitGo',
        icon: Icons.shield_outlined,
        color: AppColors.blue,
        background: AppColors.blueTint,
      ),
      const _ReceiptIndicator(
        label: 'Online submit',
        icon: Icons.cloud_upload_outlined,
        color: AppColors.emerald,
        background: AppColors.emeraldTint,
      ),
      settlementIndicator,
    ];
  }

  if (transfer.isDirectOnchainTransfer) {
    return <_ReceiptIndicator>[
      const _ReceiptIndicator(
        label: 'Signed locally',
        icon: Icons.gesture_rounded,
        color: AppColors.emerald,
        background: AppColors.emeraldTint,
      ),
      const _ReceiptIndicator(
        label: 'Submitted online',
        icon: Icons.public_rounded,
        color: AppColors.blue,
        background: AppColors.blueTint,
      ),
      settlementIndicator,
    ];
  }

  return <_ReceiptIndicator>[
    const _ReceiptIndicator(
      label: 'Signed by sender',
      icon: Icons.gesture_rounded,
      color: AppColors.emerald,
      background: AppColors.emeraldTint,
    ),
    const _ReceiptIndicator(
      label: 'Amount locked',
      icon: Icons.lock_outline_rounded,
      color: AppColors.blue,
      background: AppColors.blueTint,
    ),
    settlementIndicator,
  ];
}

List<_ReceiptMilestone> _receiptMilestones(PendingTransfer transfer) {
  if (transfer.walletEngine == WalletEngine.bitgo) {
    return switch (transfer.status) {
      TransferStatus.created ||
      TransferStatus.broadcasting => <_ReceiptMilestone>[
        const _ReceiptMilestone(
          label: 'Prepared',
          state: _ReceiptMilestoneState.complete,
        ),
        const _ReceiptMilestone(
          label: 'Submitting',
          state: _ReceiptMilestoneState.current,
        ),
        const _ReceiptMilestone(
          label: 'Confirmed',
          state: _ReceiptMilestoneState.pending,
        ),
      ],
      TransferStatus.broadcastSubmitted => <_ReceiptMilestone>[
        const _ReceiptMilestone(
          label: 'Prepared',
          state: _ReceiptMilestoneState.complete,
        ),
        const _ReceiptMilestone(
          label: 'Submitted',
          state: _ReceiptMilestoneState.complete,
        ),
        const _ReceiptMilestone(
          label: 'Confirmed',
          state: _ReceiptMilestoneState.current,
        ),
      ],
      TransferStatus.confirmed => <_ReceiptMilestone>[
        const _ReceiptMilestone(
          label: 'Prepared',
          state: _ReceiptMilestoneState.complete,
        ),
        const _ReceiptMilestone(
          label: 'Submitted',
          state: _ReceiptMilestoneState.complete,
        ),
        const _ReceiptMilestone(
          label: 'Confirmed',
          state: _ReceiptMilestoneState.complete,
        ),
      ],
      TransferStatus.broadcastFailed ||
      TransferStatus.expired => <_ReceiptMilestone>[
        const _ReceiptMilestone(
          label: 'Prepared',
          state: _ReceiptMilestoneState.complete,
        ),
        const _ReceiptMilestone(
          label: 'Submitting',
          state: _ReceiptMilestoneState.error,
        ),
        const _ReceiptMilestone(
          label: 'Confirmed',
          state: _ReceiptMilestoneState.pending,
        ),
      ],
      TransferStatus.sentOffline ||
      TransferStatus.receivedPendingBroadcast => <_ReceiptMilestone>[
        const _ReceiptMilestone(
          label: 'Prepared',
          state: _ReceiptMilestoneState.complete,
        ),
        const _ReceiptMilestone(
          label: 'Submitting',
          state: _ReceiptMilestoneState.current,
        ),
        const _ReceiptMilestone(
          label: 'Confirmed',
          state: _ReceiptMilestoneState.pending,
        ),
      ],
    };
  }
  if (transfer.isDirectOnchainTransfer) {
    return switch (transfer.status) {
      TransferStatus.created => <_ReceiptMilestone>[
        const _ReceiptMilestone(
          label: 'Prepared',
          state: _ReceiptMilestoneState.current,
        ),
        const _ReceiptMilestone(
          label: 'Submitted',
          state: _ReceiptMilestoneState.pending,
        ),
        const _ReceiptMilestone(
          label: 'Confirmed',
          state: _ReceiptMilestoneState.pending,
        ),
      ],
      TransferStatus.sentOffline ||
      TransferStatus.receivedPendingBroadcast ||
      TransferStatus.broadcasting => <_ReceiptMilestone>[
        const _ReceiptMilestone(
          label: 'Prepared',
          state: _ReceiptMilestoneState.complete,
        ),
        const _ReceiptMilestone(
          label: 'Submitted',
          state: _ReceiptMilestoneState.current,
        ),
        const _ReceiptMilestone(
          label: 'Confirmed',
          state: _ReceiptMilestoneState.pending,
        ),
      ],
      TransferStatus.broadcastSubmitted => <_ReceiptMilestone>[
        const _ReceiptMilestone(
          label: 'Prepared',
          state: _ReceiptMilestoneState.complete,
        ),
        const _ReceiptMilestone(
          label: 'Submitted',
          state: _ReceiptMilestoneState.complete,
        ),
        const _ReceiptMilestone(
          label: 'Confirmed',
          state: _ReceiptMilestoneState.current,
        ),
      ],
      TransferStatus.confirmed => <_ReceiptMilestone>[
        const _ReceiptMilestone(
          label: 'Prepared',
          state: _ReceiptMilestoneState.complete,
        ),
        const _ReceiptMilestone(
          label: 'Submitted',
          state: _ReceiptMilestoneState.complete,
        ),
        const _ReceiptMilestone(
          label: 'Confirmed',
          state: _ReceiptMilestoneState.complete,
        ),
      ],
      TransferStatus.broadcastFailed ||
      TransferStatus.expired => <_ReceiptMilestone>[
        const _ReceiptMilestone(
          label: 'Prepared',
          state: _ReceiptMilestoneState.complete,
        ),
        const _ReceiptMilestone(
          label: 'Submitted',
          state: _ReceiptMilestoneState.error,
        ),
        const _ReceiptMilestone(
          label: 'Confirmed',
          state: _ReceiptMilestoneState.pending,
        ),
      ],
    };
  }
  final String firstLabel = transfer.isInbound
      ? 'Received offline'
      : 'Sent offline';
  return switch (transfer.status) {
    TransferStatus.created ||
    TransferStatus.sentOffline ||
    TransferStatus.receivedPendingBroadcast => <_ReceiptMilestone>[
      const _ReceiptMilestone(
        label: 'Signed',
        state: _ReceiptMilestoneState.complete,
      ),
      _ReceiptMilestone(
        label: firstLabel,
        state: _ReceiptMilestoneState.complete,
      ),
      const _ReceiptMilestone(
        label: 'Broadcasting',
        state: _ReceiptMilestoneState.pending,
      ),
      const _ReceiptMilestone(
        label: 'Confirmed',
        state: _ReceiptMilestoneState.pending,
      ),
    ],
    TransferStatus.broadcasting => <_ReceiptMilestone>[
      const _ReceiptMilestone(
        label: 'Signed',
        state: _ReceiptMilestoneState.complete,
      ),
      _ReceiptMilestone(
        label: firstLabel,
        state: _ReceiptMilestoneState.complete,
      ),
      const _ReceiptMilestone(
        label: 'Broadcasting',
        state: _ReceiptMilestoneState.current,
      ),
      const _ReceiptMilestone(
        label: 'Confirmed',
        state: _ReceiptMilestoneState.pending,
      ),
    ],
    TransferStatus.broadcastSubmitted => <_ReceiptMilestone>[
      const _ReceiptMilestone(
        label: 'Signed',
        state: _ReceiptMilestoneState.complete,
      ),
      _ReceiptMilestone(
        label: firstLabel,
        state: _ReceiptMilestoneState.complete,
      ),
      const _ReceiptMilestone(
        label: 'Broadcasting',
        state: _ReceiptMilestoneState.complete,
      ),
      const _ReceiptMilestone(
        label: 'Confirmed',
        state: _ReceiptMilestoneState.current,
      ),
    ],
    TransferStatus.confirmed => <_ReceiptMilestone>[
      const _ReceiptMilestone(
        label: 'Signed',
        state: _ReceiptMilestoneState.complete,
      ),
      _ReceiptMilestone(
        label: firstLabel,
        state: _ReceiptMilestoneState.complete,
      ),
      const _ReceiptMilestone(
        label: 'Broadcasting',
        state: _ReceiptMilestoneState.complete,
      ),
      const _ReceiptMilestone(
        label: 'Confirmed',
        state: _ReceiptMilestoneState.complete,
      ),
    ],
    TransferStatus.broadcastFailed ||
    TransferStatus.expired => <_ReceiptMilestone>[
      const _ReceiptMilestone(
        label: 'Signed',
        state: _ReceiptMilestoneState.complete,
      ),
      _ReceiptMilestone(
        label: firstLabel,
        state: _ReceiptMilestoneState.complete,
      ),
      const _ReceiptMilestone(
        label: 'Broadcasting',
        state: _ReceiptMilestoneState.error,
      ),
      const _ReceiptMilestone(
        label: 'Confirmed',
        state: _ReceiptMilestoneState.pending,
      ),
    ],
  };
}

class PendingScreen extends StatefulWidget {
  const PendingScreen({super.key});

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  TransferDirection _direction = TransferDirection.inbound;

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final List<PendingTransfer> transfers = state.transfersFor(_direction);
    return BitsendPageScaffold(
      title: 'Pending',
      subtitle: 'Track transfers still waiting for broadcast or confirmation.',
      onRefresh: state.working
          ? null
          : () async {
              try {
                await state.refreshStatus();
              } catch (error) {
                if (!context.mounted) {
                  return;
                }
                _showSnack(context, _messageFor(error));
              }
            },
      showBack: false,
      primaryTab: BitsendPrimaryTab.pending,
      onPrimaryTabSelected: (BitsendPrimaryTab tab) {
        _navigatePrimaryTab(context, tab);
      },
      overlay: _HomeDashboardOverlay(
        onScan: state.hasWallet ? () => _scanAndStartSendFromContext(context) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SegmentedButton<TransferDirection>(
            segments: const <ButtonSegment<TransferDirection>>[
              ButtonSegment<TransferDirection>(
                value: TransferDirection.inbound,
                label: Text('Inbound'),
                icon: Icon(Icons.call_received_rounded),
              ),
              ButtonSegment<TransferDirection>(
                value: TransferDirection.outbound,
                label: Text('Outbound'),
                icon: Icon(Icons.send_rounded),
              ),
            ],
            selected: <TransferDirection>{_direction},
            onSelectionChanged: (Set<TransferDirection> value) {
              setState(() {
                _direction = value.first;
              });
            },
          ),
          const SizedBox(height: 18),
          if (transfers.isEmpty)
            EmptyStateCard(
              title: _direction == TransferDirection.inbound
                  ? 'No inbound transfers yet'
                  : 'No outbound transfers yet',
              caption: _direction == TransferDirection.inbound
                  ? 'Open Receive to store signed transfers from another device.'
                  : 'Use Send to sign and deliver a transfer to another device.',
              icon: _direction == TransferDirection.inbound
                  ? Icons.call_received_rounded
                  : Icons.send_rounded,
            )
          else
            Column(
              children: transfers
                  .map(
                    (PendingTransfer transfer) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TransferCard(
                        transfer: transfer,
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.transferDetail(transfer.transferId),
                          );
                        },
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class TransferDetailScreen extends StatelessWidget {
  const TransferDetailScreen({super.key, required this.transferId});

  final String transferId;

  Future<void> _retry(
    BuildContext context,
    BitsendAppState state,
    PendingTransfer transfer,
  ) async {
    try {
      await state.retryBroadcast(transfer.transferId);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showSnack(context, _messageFor(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final PendingTransfer? transfer = state.transferById(transferId);
    if (transfer == null) {
      return const BitsendPageScaffold(
        title: 'Transfer not found',
        subtitle: 'This transfer is not in the local queue.',
        child: EmptyStateCard(
          title: 'Missing transfer',
          caption: 'Return to Pending and choose another item.',
          icon: Icons.find_in_page_rounded,
        ),
      );
    }

    final List<TransferTimelineState> timeline = state.timelineFor(transfer);
    return BitsendPageScaffold(
      title: 'Transfer detail',
      subtitle: 'Timeline, transfer data, and the next available action.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        transfer.isInbound
                            ? 'Inbound transfer'
                            : 'Outbound transfer',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    StatusPill(status: transfer.status),
                  ],
                ),
                const SizedBox(height: 20),
                DetailRow(label: 'Transfer ID', value: transfer.transferId),
                DetailRow(
                  label: 'Wallet mode',
                  value: transfer.walletEngine.label,
                ),
                DetailRow(label: 'Sender', value: transfer.senderAddress),
                DetailRow(label: 'Receiver', value: transfer.receiverAddress),
                DetailRow(
                  label: 'Amount',
                  value: Formatters.transferAmount(transfer),
                ),
                DetailRow(
                  label: 'Created',
                  value: Formatters.dateTime(transfer.createdAt),
                ),
                DetailRow(
                  label: 'Updated',
                  value: Formatters.dateTime(transfer.updatedAt),
                ),
                if (transfer.remoteEndpoint != null)
                  DetailRow(label: 'Endpoint', value: transfer.remoteEndpoint!),
                if (transfer.transactionSignature != null)
                  DetailRow(
                    label: 'Signature',
                    value: transfer.transactionSignature!,
                  ),
                if (transfer.backendStatus != null)
                  DetailRow(
                    label: 'Backend status',
                    value: transfer.backendStatus!,
                  ),
                if (transfer.hasReceiptArchive &&
                    transfer.fileverseSavedAt != null)
                  DetailRow(
                    label: 'Receipt saved',
                    value: Formatters.dateTime(transfer.fileverseSavedAt!),
                  ),
                if (transfer.receiptStorageLabel != null)
                  DetailRow(
                    label: 'Receipt provider',
                    value: transfer.receiptStorageLabel!,
                  ),
                if (transfer.hasReceiptArchive &&
                    transfer.fileverseReceiptId != null)
                  DetailRow(
                    label: _receiptIdLabel(transfer),
                    value: transfer.fileverseReceiptId!,
                  ),
                if (transfer.hasReceiptArchive &&
                    transfer.fileverseMessage != null)
                  DetailRow(
                    label: 'Receipt note',
                    value: transfer.fileverseMessage!,
                  ),
                if (transfer.bitgoWalletId != null)
                  DetailRow(
                    label: 'BitGo wallet',
                    value: transfer.bitgoWalletId!,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (transfer.lastError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InlineBanner(
                title: transfer.status == TransferStatus.expired
                    ? 'Transfer expired'
                    : 'Broadcast error',
                caption: transfer.lastError!,
                icon: Icons.error_outline_rounded,
              ),
            ),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Timeline', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 18),
                Column(
                  children: timeline
                      .asMap()
                      .entries
                      .map(
                        (MapEntry<int, TransferTimelineState> entry) =>
                            TimelineStepTile(
                              step: entry.value,
                              isLast: entry.key == timeline.length - 1,
                            ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
          if (transfer.explorerUrl != null) ...<Widget>[
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Explorer',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    transfer.explorerUrl!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: transfer.explorerUrl!),
                      );
                      if (!context.mounted) {
                        return;
                      }
                      _showSnack(context, 'Explorer link copied.');
                    },
                    child: const Text('Copy explorer link'),
                  ),
                ],
              ),
            ),
          ],
          if (transfer.hasReceiptLink &&
              transfer.fileverseReceiptUrl != null) ...<Widget>[
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _receiptLinkLabel(transfer),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    transfer.fileverseReceiptUrl!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: transfer.fileverseReceiptUrl!),
                      );
                      if (!context.mounted) {
                        return;
                      }
                      _showSnack(
                        context,
                        transfer.isReceiptSavedInFileverse
                            ? 'Fileverse link copied.'
                            : 'Receipt link copied.',
                      );
                    },
                    child: Text(_receiptOnlineButtonLabel(transfer)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottom: _TransferDetailActions(
        transfer: transfer,
        onRetry: transfer.canBroadcast
            ? () => _retry(context, state, transfer)
            : null,
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _rpcController;
  late final TextEditingController _bitgoController;
  late final TextEditingController _swapApiKeyController;
  late final TextEditingController _ensNameController;
  late final TextEditingController _ensChainController;
  late final TextEditingController _ensTokenController;
  String? _backupPath;
  EnsPaymentPreference? _loadedEnsPreference;
  bool _recoveryPhraseVisible = false;
  bool _swapApiKeyVisible = false;

  @override
  void initState() {
    super.initState();
    _rpcController = TextEditingController();
    _bitgoController = TextEditingController();
    _swapApiKeyController = TextEditingController();
    _ensNameController = TextEditingController();
    _ensChainController = TextEditingController();
    _ensTokenController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rpcController.text = BitsendStateScope.of(context).rpcEndpoint;
    _bitgoController.text = BitsendStateScope.of(context).bitgoEndpoint;
    _swapApiKeyController.text = BitsendStateScope.of(context).swapApiKey;
  }

  @override
  void dispose() {
    _rpcController.dispose();
    _bitgoController.dispose();
    _swapApiKeyController.dispose();
    _ensNameController.dispose();
    _ensChainController.dispose();
    _ensTokenController.dispose();
    super.dispose();
  }

  Future<void> _saveRpc(BitsendAppState state) async {
    try {
      await state.setRpcEndpoint(_rpcController.text);
      if (!mounted) {
        return;
      }
      _showSnack(context, 'RPC endpoint updated.');
    } catch (error) {
      _showSnack(context, _messageFor(error));
    }
  }

  Future<void> _clearAll(BitsendAppState state) async {
    final bool authorized = await _authorizeDeviceAction(
      context,
      state,
      reason:
          'Confirm your ${state.deviceUnlockMethodLabel} before clearing all wallet data from this device.',
    );
    if (!authorized) {
      return;
    }
    WalletBackupExport? export;
    if (state.wallet != null) {
      try {
        export = await state.exportWalletBackup();
        if (!mounted) {
          return;
        }
        setState(() {
          _backupPath = export!.filePath;
        });
      } catch (error) {
        _showSnack(context, _messageFor(error));
        return;
      }
    }
    final bool confirmed = await _confirmClearAll(state, export: export);
    if (!confirmed) {
      return;
    }
    try {
      await state.clearLocalData();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.onboardingWelcome,
        (Route<dynamic> route) => false,
      );
    } catch (error) {
      _showSnack(context, _messageFor(error));
    }
  }

  Future<bool> _confirmClearAll(
    BitsendAppState state, {
    WalletBackupExport? export,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Clear local data?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (export != null) ...<Widget>[
                  Text(
                    'A recovery backup was downloaded before reset. It includes the recovery phrase and the main-wallet private keys.',
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Backup file',
                    style: Theme.of(dialogContext).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    export.filePath,
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Make sure you can access this file before continuing.',
                    style: Theme.of(
                      dialogContext,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Clearing local data removes the wallet, queue, cached readiness data, and saved RPC settings from this device.',
                  style: Theme.of(dialogContext).textTheme.bodyMedium,
                ),
                if (state.offlineWallet != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    'The offline wallet on this phone is device-bound and will be deleted permanently.',
                    style: Theme.of(
                      dialogContext,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.red),
                  ),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                export == null
                    ? 'Clear local data'
                    : 'I saved the backup, clear data',
              ),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _saveBitGo(BitsendAppState state) async {
    try {
      await state.setBitGoEndpoint(_bitgoController.text);
      if (!mounted) {
        return;
      }
      _showSnack(context, 'BitGo backend endpoint updated.');
    } catch (error) {
      _showSnack(context, _messageFor(error));
    }
  }

  Future<void> _saveSwapSettings(BitsendAppState state) async {
    try {
      await state.setSwapApiKey(_swapApiKeyController.text);
      if (!mounted) {
        return;
      }
      _showSnack(
        context,
        state.hasSwapApiKey
            ? 'Swap routing key updated.'
            : 'Swap routing key cleared.',
      );
    } catch (error) {
      _showSnack(context, _messageFor(error));
    }
  }

  Future<void> _connectBitGo(BitsendAppState state) async {
    try {
      await state.connectBitGo();
      if (!mounted) {
        return;
      }
      _showSnack(
        context,
        'BitGo wallet connected (${state.bitgoBackendMode.label} backend).',
      );
    } catch (error) {
      _showSnack(context, _messageFor(error));
    }
  }

  Future<void> _exportBackup(BitsendAppState state) async {
    final bool authorized = await _authorizeDeviceAction(
      context,
      state,
      reason:
          'Confirm your ${state.deviceUnlockMethodLabel} before exporting the wallet backup.',
    );
    if (!authorized) {
      return;
    }
    try {
      final WalletBackupExport export = await state.exportWalletBackup();
      if (!mounted) {
        return;
      }
      setState(() {
        _backupPath = export.filePath;
      });
      _showSnack(context, 'Backup saved as ${export.fileName}.');
    } catch (error) {
      _showSnack(context, _messageFor(error));
    }
  }

  Future<void> _copyPhrase(BitsendAppState state) async {
    final WalletProfile? wallet = state.wallet;
    if (wallet == null) {
      return;
    }
    final bool authorized = await _authorizeDeviceAction(
      context,
      state,
      reason:
          'Confirm your ${state.deviceUnlockMethodLabel} before copying the recovery phrase.',
    );
    if (!authorized) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: wallet.seedPhrase));
    if (!mounted) {
      return;
    }
    _showSnack(context, 'Recovery phrase copied.');
  }

  Future<void> _revealRecoveryPhrase(BitsendAppState state) async {
    if (state.wallet == null) {
      return;
    }
    final bool authorized = await _authorizeDeviceAction(
      context,
      state,
      reason:
          'Confirm your ${state.deviceUnlockMethodLabel} before revealing the recovery phrase.',
    );
    if (!authorized || !mounted) {
      return;
    }
    setState(() {
      _recoveryPhraseVisible = true;
    });
  }

  Future<void> _readEnsPreference(BitsendAppState state) async {
    try {
      final EnsPaymentPreference preference = await state
          .readEthereumEnsPaymentPreference(_ensNameController.text.trim());
      if (!mounted) {
        return;
      }
      setState(() {
        _loadedEnsPreference = preference;
        _ensChainController.text = preference.preferredChain;
        _ensTokenController.text = preference.preferredToken;
      });
      _showSnack(
        context,
        preference.hasPreference
            ? 'ENS payment preference loaded.'
            : 'No Bitsend payment preference is set on this ENS name yet.',
      );
    } catch (error) {
      _showSnack(context, _messageFor(error));
    }
  }

  Future<void> _saveEnsPreference(BitsendAppState state) async {
    try {
      await state.saveEthereumEnsPaymentPreference(
        ensName: _ensNameController.text.trim(),
        preferredChain: _ensChainController.text.trim(),
        preferredToken: _ensTokenController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _loadedEnsPreference = EnsPaymentPreference(
          ensName: _ensNameController.text.trim().toLowerCase(),
          preferredChain: _ensChainController.text.trim(),
          preferredToken: _ensTokenController.text.trim(),
        );
      });
      _showSnack(
        context,
        'ENS preference submitted on Ethereum mainnet. Wait for confirmation, then read it again.',
      );
    } catch (error) {
      _showSnack(context, _messageFor(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final bool hideRecoveryPhrase =
        state.wallet != null &&
        state.deviceAuthAvailable &&
        !_recoveryPhraseVisible;
    final bool hasWallet = state.wallet != null;
    final String scopeLabel = state.activeChain.networkLabelFor(
      state.activeNetwork,
    );
    final String walletEngineLabel = state.activeWalletEngine.walletLabel;
    final String biometricStatus = !hasWallet
        ? 'Set up a wallet first'
        : state.deviceAuthHasBiometricOption
        ? 'Biometric unlock on'
        : 'Biometric setup required';
    final String backupStatus = _backupPath == null
        ? 'Backup not downloaded in this session'
        : 'Backup downloaded';
    final String permissionStatus = state.localPermissionsGranted
        ? 'Nearby permissions granted'
        : 'Nearby permissions need access';
    final String defaultRpcHint = switch ((
      state.activeChain,
      state.activeNetwork,
    )) {
      (ChainKind.solana, ChainNetwork.testnet) =>
        defaultSolanaTestnetRpcEndpoint,
      (ChainKind.solana, ChainNetwork.mainnet) =>
        defaultSolanaMainnetRpcEndpoint,
      (ChainKind.ethereum, ChainNetwork.testnet) =>
        defaultEthereumTestnetRpcEndpoint,
      (ChainKind.ethereum, ChainNetwork.mainnet) =>
        defaultEthereumMainnetRpcEndpoint,
      (ChainKind.base, ChainNetwork.testnet) => defaultBaseTestnetRpcEndpoint,
      (ChainKind.base, ChainNetwork.mainnet) => defaultBaseMainnetRpcEndpoint,
      (ChainKind.bnb, ChainNetwork.testnet) => defaultBnbTestnetRpcEndpoint,
      (ChainKind.bnb, ChainNetwork.mainnet) => defaultBnbMainnetRpcEndpoint,
      (ChainKind.polygon, ChainNetwork.testnet) =>
        defaultPolygonTestnetRpcEndpoint,
      (ChainKind.polygon, ChainNetwork.mainnet) =>
        defaultPolygonMainnetRpcEndpoint,
    };
    return BitsendPageScaffold(
      title: 'Settings',
      subtitle: 'Wallet safety first, then connections and recovery.',
      showBack: false,
      primaryTab: BitsendPrimaryTab.settings,
      onPrimaryTabSelected: (BitsendPrimaryTab tab) {
        _navigatePrimaryTab(context, tab);
      },
      overlay: _HomeDashboardOverlay(
        onScan: state.hasWallet ? () => _scanAndStartSendFromContext(context) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FadeSlideIn(
            delay: 0,
            child: _SettingsOverviewCard(
              scopeLabel: scopeLabel,
              walletEngineLabel: walletEngineLabel,
              biometricStatus: biometricStatus,
              backupStatus: backupStatus,
              permissionStatus: permissionStatus,
              mainWalletLabel: state.wallet?.displayAddress ?? 'Not set up',
              offlineWalletLabel:
                  state.offlineWallet?.displayAddress ?? 'Unavailable',
              bitgoStatus: state.bitgoBackendMode.label,
              backupPath: _backupPath,
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: 20,
            child: SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _SettingsSectionIntro(
                    title: 'Recovery phrase',
                    caption:
                        'Keep the main wallet recoverable. The offline wallet remains bound to this phone.',
                  ),
                  const SizedBox(height: 14),
                  _SettingsSurfaceBlock(
                    icon: hideRecoveryPhrase
                        ? Icons.lock_outline_rounded
                        : Icons.key_rounded,
                    title: hideRecoveryPhrase
                        ? 'Recovery phrase locked'
                        : 'Recovery phrase visible',
                    tone: hideRecoveryPhrase
                        ? AppColors.blueTint
                        : AppColors.emeraldTint,
                    child: state.wallet == null
                        ? const Text('Wallet not created yet.')
                        : !hideRecoveryPhrase
                        ? SelectableText(
                            state.wallet!.seedPhrase,
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        : Text(
                            'Use your ${state.deviceUnlockMethodLabel} to reveal the recovery phrase on this device.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.amberTint.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      state.offlineWallet == null
                          ? 'Offline wallet unavailable.'
                          : 'Offline wallet ${state.offlineWallet!.displayAddress} is device-bound on this phone and is not recoverable from this phrase.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: state.wallet == null || !hideRecoveryPhrase
                            ? null
                            : () => _revealRecoveryPhrase(state),
                        icon: const Icon(Icons.visibility_outlined),
                        label: Text(
                          hideRecoveryPhrase
                              ? 'Reveal phrase'
                              : 'Phrase unlocked',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: state.wallet == null
                            ? null
                            : () => _copyPhrase(state),
                        icon: const Icon(Icons.copy_all_rounded),
                        label: const Text('Copy phrase'),
                      ),
                      ElevatedButton.icon(
                        onPressed: state.wallet == null || state.working
                            ? null
                            : () => _exportBackup(state),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Download backup'),
                      ),
                    ],
                  ),
                  if (_backupPath != null) ...<Widget>[
                    const SizedBox(height: 16),
                    _SettingsSurfaceBlock(
                      icon: Icons.download_done_rounded,
                      title: 'Latest backup',
                      tone: AppColors.emeraldTint,
                      child: SelectableText(
                        _backupPath!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: 40,
            child: SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _SettingsSectionIntro(
                    title: 'Connections',
                    caption:
                        'Tune the backend and RPC endpoints for the active scope without digging through separate screens.',
                  ),
                  const SizedBox(height: 14),
                  _SettingsSubsectionCard(
                    icon: Icons.shield_outlined,
                    title: 'BitGo backend',
                    caption:
                        'Use your laptop or backend host address here. Physical devices cannot reach localhost on the phone itself.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        DetailRow(
                          label: 'Backend mode',
                          value: state.bitgoBackendMode.label,
                        ),
                        if (state.bitgoWallet != null)
                          DetailRow(
                            label: 'Wallet',
                            value: state.bitgoWallet!.displayLabel,
                          ),
                        if (state.bitgoWallet != null)
                          DetailRow(
                            label: 'Address',
                            value: state.bitgoWallet!.address,
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _bitgoController,
                          decoration: const InputDecoration(
                            labelText: 'BitGo endpoint',
                            hintText: defaultBitGoBackendEndpoint,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            ElevatedButton.icon(
                              onPressed: () => _saveBitGo(state),
                              icon: const Icon(Icons.save_rounded),
                              label: const Text('Save BitGo endpoint'),
                            ),
                            OutlinedButton.icon(
                              onPressed: state.working
                                  ? null
                                  : () => _connectBitGo(state),
                              icon: const Icon(Icons.link_rounded),
                              label: const Text('Connect BitGo'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SettingsSubsectionCard(
                    icon: Icons.settings_ethernet_rounded,
                    title: 'RPC endpoint',
                    caption:
                        'This endpoint is used for ${state.activeChain.networkLabelFor(state.activeNetwork)} while this scope is active.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        DetailRow(label: 'Active scope', value: scopeLabel),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _rpcController,
                          decoration: InputDecoration(
                            labelText: '${state.activeChain.rpcLabel} endpoint',
                            hintText: defaultRpcHint,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () => _saveRpc(state),
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Save RPC'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: 50,
            child: SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _SettingsSectionIntro(
                    title: 'Swaps',
                    caption:
                        '0x powers live routing on Ethereum, Base, BNB, and Polygon mainnet.',
                  ),
                  const SizedBox(height: 14),
                  _SettingsSubsectionCard(
                    icon: Icons.swap_horiz_rounded,
                    title: 'Routing key',
                    caption:
                        'Paste your 0x API key here to enable live swap quotes and execution.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        TextField(
                          controller: _swapApiKeyController,
                          autocorrect: false,
                          enableSuggestions: false,
                          obscureText: !_swapApiKeyVisible,
                          decoration: InputDecoration(
                            labelText: '0x API key',
                            hintText: 'Paste API key',
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _swapApiKeyVisible = !_swapApiKeyVisible;
                                });
                              },
                              icon: Icon(
                                _swapApiKeyVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DetailRow(
                          label: 'Status',
                          value: state.hasSwapApiKey ? 'Ready' : 'Needs key',
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () => _saveSwapSettings(state),
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Save swap key'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SettingsSubsectionCard(
                    icon: Icons.tune_rounded,
                    title: 'Slippage',
                    caption:
                        'Leave it on Auto unless you are trading thin liquidity.',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        ChoiceChip(
                          label: const Text('Auto'),
                          selected: state.swapSlippageBps == null,
                          onSelected: (_) => state.setSwapSlippageBps(null),
                        ),
                        ChoiceChip(
                          label: const Text('0.5%'),
                          selected: state.swapSlippageBps == 50,
                          onSelected: (_) => state.setSwapSlippageBps(50),
                        ),
                        ChoiceChip(
                          label: const Text('1%'),
                          selected: state.swapSlippageBps == 100,
                          onSelected: (_) => state.setSwapSlippageBps(100),
                        ),
                        ChoiceChip(
                          label: const Text('2%'),
                          selected: state.swapSlippageBps == 200,
                          onSelected: (_) => state.setSwapSlippageBps(200),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: 60,
            child: SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _SettingsSectionIntro(
                    title: 'ENS payment preference',
                    caption:
                        'Publish routing hints so senders can see which chain and token you prefer for payments.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _ensNameController,
                    decoration: const InputDecoration(
                      labelText: 'ENS name',
                      hintText: 'alice.eth',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ensChainController,
                    decoration: const InputDecoration(
                      labelText: 'Preferred chain',
                      hintText: 'base or arbitrum',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ensTokenController,
                    decoration: const InputDecoration(
                      labelText: 'Preferred token',
                      hintText: 'USDC or USDT',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: state.working
                            ? null
                            : () => _readEnsPreference(state),
                        icon: const Icon(Icons.travel_explore_rounded),
                        label: const Text('Read ENS'),
                      ),
                      ElevatedButton.icon(
                        onPressed: state.working
                            ? null
                            : () => _saveEnsPreference(state),
                        icon: const Icon(Icons.publish_rounded),
                        label: const Text('Save to ENS'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const InlineBanner(
                    title: 'Mainnet write',
                    caption:
                        'Saving ENS text records requires an Ethereum mainnet transaction from the ENS manager wallet and enough ETH for gas.',
                    icon: Icons.public_rounded,
                  ),
                  if (_loadedEnsPreference != null) ...<Widget>[
                    const SizedBox(height: 16),
                    _SettingsSurfaceBlock(
                      icon: Icons.route_rounded,
                      title: 'Loaded preference',
                      tone: AppColors.blueTint,
                      child: Text(
                        _loadedEnsPreference!.hasPreference
                            ? _loadedEnsPreference!.summary
                            : 'No Bitsend ENS preference set',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: 80,
            child: SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _SettingsSectionIntro(
                    title: 'Device access',
                    caption:
                        'Nearby transfers depend on biometric unlock and local transport permissions staying available.',
                  ),
                  const SizedBox(height: 14),
                  _SettingsSubsectionCard(
                    icon: Icons.fingerprint_rounded,
                    title: 'Unlock',
                    caption: state.deviceAuthHasBiometricOption
                        ? 'Sensitive actions stay behind biometric unlock.'
                        : 'Fingerprint or face unlock still needs to be configured in system settings.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        DetailRow(label: 'Status', value: biometricStatus),
                        DetailRow(
                          label: 'Method',
                          value: state.deviceUnlockMethodLabel,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SettingsSubsectionCard(
                    icon: Icons.wifi_tethering_rounded,
                    title: 'Permissions',
                    caption: state.localPermissionsGranted
                        ? 'Local transport access is ready for nearby transfer handoff.'
                        : 'Bluetooth, local network, or nearby device permissions still need approval.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        DetailRow(
                          label: 'Local transport',
                          value: state.localPermissionsGranted
                              ? 'Granted'
                              : 'Needs access',
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: state.requestLocalPermissions,
                          icon: const Icon(Icons.verified_user_outlined),
                          label: const Text('Request access'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: 100,
            child: SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _SettingsSectionIntro(
                    title: 'Danger zone',
                    caption:
                        'Reset is intentionally hard: biometric unlock, forced backup download, then one final confirmation.',
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.redTint.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.82),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.red,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Reset this device',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'This removes the wallet, queue, cached readiness data, and saved RPC settings from this device.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_backupPath != null) ...<Widget>[
                          const SizedBox(height: 12),
                          SelectableText(
                            _backupPath!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottom: OutlinedButton(
        onPressed: state.working ? null : () => _clearAll(state),
        child: const Text('Clear local data'),
      ),
    );
  }
}

class _SettingsOverviewCard extends StatelessWidget {
  const _SettingsOverviewCard({
    required this.scopeLabel,
    required this.walletEngineLabel,
    required this.biometricStatus,
    required this.backupStatus,
    required this.permissionStatus,
    required this.mainWalletLabel,
    required this.offlineWalletLabel,
    required this.bitgoStatus,
    this.backupPath,
  });

  final String scopeLabel;
  final String walletEngineLabel;
  final String biometricStatus;
  final String backupStatus;
  final String permissionStatus;
  final String mainWalletLabel;
  final String offlineWalletLabel;
  final String bitgoStatus;
  final String? backupPath;

  @override
  Widget build(BuildContext context) {
    final String addressSummary = mainWalletLabel == 'Not set up'
        ? 'No wallet is active on this device yet.'
        : 'Main $mainWalletLabel  •  Offline $offlineWalletLabel';
    final String lockValue = biometricStatus.contains('on')
        ? 'On'
        : biometricStatus.contains('required')
        ? 'Setup'
        : 'Needed';
    final String backupValue = backupStatus == 'Backup downloaded'
        ? 'Ready'
        : 'Needed';
    final String permissionValue = permissionStatus.contains('granted')
        ? 'Granted'
        : 'Needed';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: 26,
            spreadRadius: -4,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.canvasTint,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.ink,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Current setup',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          addressSummary,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.slate),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _SettingsHeroChip(
                    icon: Icons.blur_circular_rounded,
                    label: scopeLabel,
                  ),
                  _SettingsHeroChip(
                    icon: Icons.account_balance_wallet_outlined,
                    label: walletEngineLabel,
                  ),
                  _SettingsHeroChip(
                    icon: Icons.shield_outlined,
                    label: 'BitGo ${bitgoStatus.toLowerCase()}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _SettingsHeroMetric(
                      label: 'Lock',
                      value: lockValue,
                      caption: biometricStatus,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SettingsHeroMetric(
                      label: 'Backup',
                      value: backupValue,
                      caption: backupStatus,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SettingsHeroMetric(
                      label: 'Nearby',
                      value: permissionValue,
                      caption: permissionStatus,
                    ),
                  ),
                ],
              ),
              if (backupPath != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  'Latest backup: $backupPath',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsHeroChip extends StatelessWidget {
  const _SettingsHeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.canvasTint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: AppColors.ink),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsHeroMetric extends StatelessWidget {
  const _SettingsHeroMetric({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.canvasTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 3),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionIntro extends StatelessWidget {
  const _SettingsSectionIntro({required this.title, required this.caption});

  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          caption,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
        ),
      ],
    );
  }
}

class _SettingsSurfaceBlock extends StatelessWidget {
  const _SettingsSurfaceBlock({
    required this.icon,
    required this.title,
    required this.tone,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Color tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.ink, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SettingsSubsectionCard extends StatelessWidget {
  const _SettingsSubsectionCard({
    required this.icon,
    required this.title,
    required this.caption,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.canvasTint,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: Icon(icon, color: AppColors.ink, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      caption,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DepositHero extends StatelessWidget {
  const _DepositHero({
    required this.title,
    required this.shortAddress,
    required this.balance,
    required this.statusLabel,
    required this.statusIcon,
    required this.statusActive,
  });

  final String title;
  final String shortAddress;
  final String balance;
  final String statusLabel;
  final IconData statusIcon;
  final bool statusActive;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const _DepositSourceIcon(icon: Icons.south_west_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _MiniCue(
                icon: statusIcon,
                label: statusLabel,
                active: statusActive,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              const _DepositSourceIcon(
                icon: Icons.call_received_rounded,
                faint: true,
              ),
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const _DepositSourceIcon(
                icon: Icons.account_balance_wallet_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(balance, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            shortAddress,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
          ),
        ],
      ),
    );
  }
}

class _DepositSourceIcon extends StatelessWidget {
  const _DepositSourceIcon({required this.icon, this.faint = false});

  final IconData icon;
  final bool faint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: faint
            ? AppColors.canvasTint
            : AppColors.emeraldTint.withValues(alpha: 0.8),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: faint ? AppColors.slate : AppColors.emerald,
        size: 20,
      ),
    );
  }
}

class _HomeScopeHeader extends StatefulWidget {
  const _HomeScopeHeader({
    required this.chain,
    required this.network,
    required this.walletEngine,
    required this.accountSlot,
    required this.switching,
    required this.onChainChanged,
    required this.onNetworkChanged,
    required this.onWalletEngineChanged,
    required this.onAccountsTap,
  });

  final ChainKind chain;
  final ChainNetwork network;
  final WalletEngine walletEngine;
  final int accountSlot;
  final bool switching;
  final ValueChanged<ChainKind> onChainChanged;
  final ValueChanged<ChainNetwork> onNetworkChanged;
  final ValueChanged<WalletEngine> onWalletEngineChanged;
  final VoidCallback onAccountsTap;

  @override
  State<_HomeScopeHeader> createState() => _HomeScopeHeaderState();
}

class _HomeScopeHeaderState extends State<_HomeScopeHeader> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _HomeScopeHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.switching && _expanded) {
      _expanded = false;
    }
  }

  void _toggleExpanded() {
    if (widget.switching) {
      return;
    }
    setState(() {
      _expanded = !_expanded;
    });
  }

  void _selectChain(ChainKind chain) {
    setState(() {
      _expanded = false;
    });
    widget.onChainChanged(chain);
  }

  void _selectNetwork(ChainNetwork network) {
    setState(() {
      _expanded = false;
    });
    widget.onNetworkChanged(network);
  }

  void _selectWalletEngine(WalletEngine engine) {
    setState(() {
      _expanded = false;
    });
    widget.onWalletEngineChanged(engine);
  }

  @override
  Widget build(BuildContext context) {
    final ChainKind chain = widget.chain;
    final ChainNetwork network = widget.network;
    final WalletEngine walletEngine = widget.walletEngine;
    final int accountSlot = widget.accountSlot;
    final bool switching = widget.switching;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const BitsendBrandLogo(
                      tone: BitsendLogoTone.transparent,
                      height: 44,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _HeaderActionPill(
                        onTap: switching ? null : _toggleExpanded,
                        tooltip: 'Change chain and network',
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: <Widget>[
                            ChainLogo(chain: chain, size: 18),
                            Positioned(
                              right: -8,
                              bottom: -8,
                              child: AnimatedRotation(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                turns: _expanded ? 0.5 : 0,
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 15,
                                  color: switching
                                      ? AppColors.mutedInk
                                      : AppColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _HeaderActionPill(
                        onTap: switching ? null : widget.onAccountsTap,
                        tooltip: 'Open account ${accountSlot + 1}',
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 18,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
              final Animation<Offset> offset = Tween<Offset>(
                begin: const Offset(0, -0.08),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offset, child: child),
              );
            },
            child: _expanded
                ? Container(
                    key: const ValueKey<String>('scope-panel'),
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.ink.withValues(alpha: 0.06),
                          blurRadius: 26,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _ScopeToggleRow<ChainKind>(
                          label: 'Chain',
                          selected: chain,
                          enabled: !switching,
                          items: <_ScopeToggleItem<ChainKind>>[
                            for (final ChainKind option in ChainKind.values)
                              _ScopeToggleItem<ChainKind>(
                                value: option,
                                label: option.label,
                                iconBuilder: (_) =>
                                    ChainLogo(chain: option, size: 18),
                              ),
                          ],
                          onChanged: _selectChain,
                        ),
                        const SizedBox(height: 12),
                        _ScopeToggleRow<WalletEngine>(
                          label: 'Wallet mode',
                          selected: walletEngine,
                          enabled: !switching,
                          items: const <_ScopeToggleItem<WalletEngine>>[
                            _ScopeToggleItem<WalletEngine>(
                              value: WalletEngine.local,
                              label: 'Local',
                              iconBuilder: _localWalletIconBuilder,
                            ),
                          ],
                          onChanged: _selectWalletEngine,
                        ),
                        const SizedBox(height: 12),
                        _ScopeToggleRow<ChainNetwork>(
                          label: 'Environment',
                          selected: network,
                          enabled: !switching,
                          items: <_ScopeToggleItem<ChainNetwork>>[
                            _ScopeToggleItem<ChainNetwork>(
                              value: ChainNetwork.testnet,
                              label: ChainNetwork.testnet.shortLabelFor(chain),
                              iconBuilder: _testnetIconBuilder,
                            ),
                            const _ScopeToggleItem<ChainNetwork>(
                              value: ChainNetwork.mainnet,
                              label: 'Mainnet',
                              iconBuilder: _mainnetIconBuilder,
                            ),
                          ],
                          onChanged: _selectNetwork,
                        ),
                      ],
                    ),
                  )
                : const SizedBox(key: ValueKey<String>('scope-panel-closed')),
          ),
        ],
      ),
    );
  }
}

class _ScopeToggleItem<T> {
  const _ScopeToggleItem({
    required this.value,
    required this.label,
    required this.iconBuilder,
  });

  final T value;
  final String label;
  final Widget Function(Color color) iconBuilder;
}

class _ScopeToggleRow<T> extends StatelessWidget {
  const _ScopeToggleRow({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T selected;
  final bool enabled;
  final List<_ScopeToggleItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: items
                  .map(
                    (_ScopeToggleItem<T> item) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _ScopeToggleButton<T>(
                          item: item,
                          selected: selected == item.value,
                          enabled: enabled,
                          onTap: () => onChanged(item.value),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScopeToggleButton<T> extends StatelessWidget {
  const _ScopeToggleButton({
    required this.item,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final _ScopeToggleItem<T> item;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              boxShadow: selected
                  ? <BoxShadow>[
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.16),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                item.iconBuilder(
                  selected ? Colors.white : AppColors.ink,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? Colors.white : AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _localWalletIconBuilder(Color color) => Icon(
  Icons.offline_bolt_rounded,
  size: 18,
  color: color,
);

Widget _testnetIconBuilder(Color color) => Icon(
  Icons.science_rounded,
  size: 18,
  color: color,
);

Widget _mainnetIconBuilder(Color color) => Icon(
  Icons.public_rounded,
  size: 18,
  color: color,
);

class _ScopeSwitchOverlay extends StatelessWidget {
  const _ScopeSwitchOverlay({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: AnimatedOpacity(
        opacity: 1,
        duration: const Duration(milliseconds: 180),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.canvas.withValues(alpha: 0.52),
            ),
            child: Center(
              child: Container(
                width: 230,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.08),
                      blurRadius: 26,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const _BobbingBrandLogo(
                      tone: BitsendLogoTone.transparent,
                      height: 58,
                      distance: 8,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Switching',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
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

class _HeaderActionPill extends StatelessWidget {
  const _HeaderActionPill({required this.child, this.onTap, this.tooltip});

  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.96),
                AppColors.emeraldTint.withValues(alpha: 0.88),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.05),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.labelLarge,
              child: IconTheme.merge(
                data: const IconThemeData(color: AppColors.ink),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
    if (tooltip == null || tooltip!.isEmpty) {
      return button;
    }
    return Tooltip(message: tooltip!, child: button);
  }
}

class _HomeHeroActions extends StatelessWidget {
  const _HomeHeroActions({
    required this.onDeposit,
    required this.onAssets,
    required this.onSend,
    required this.onMore,
  });

  final VoidCallback onDeposit;
  final VoidCallback? onAssets;
  final VoidCallback onSend;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    const double spacing = 12;
    final List<
      ({
        String label,
        IconData icon,
        Color tone,
        Color surface,
        VoidCallback? onTap,
        bool filled,
      })
    >
    actions =
        <
          ({
            String label,
            IconData icon,
            Color tone,
            Color surface,
            VoidCallback? onTap,
            bool filled,
          })
        >[
          (
            label: 'Send',
            icon: Icons.send_rounded,
            tone: Colors.white,
            surface: AppColors.ink,
            onTap: onSend,
            filled: true,
          ),
          (
            label: 'Deposit',
            icon: Icons.add_rounded,
            tone: AppColors.ink,
            surface: Colors.white.withValues(alpha: 0.72),
            onTap: onDeposit,
            filled: false,
          ),
          (
            label: 'Assets',
            icon: Icons.pie_chart_outline_rounded,
            tone: AppColors.ink,
            surface: Colors.white.withValues(alpha: 0.72),
            onTap: onAssets,
            filled: false,
          ),
          (
            label: 'More',
            icon: Icons.more_horiz_rounded,
            tone: AppColors.ink,
            surface: Colors.white.withValues(alpha: 0.72),
            onTap: onMore,
            filled: false,
          ),
        ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int index = 0; index < actions.length; index++) ...<Widget>[
          Expanded(
            child: _HomeActionShortcut(
              label: actions[index].label,
              icon: actions[index].icon,
              tone: actions[index].tone,
              surface: actions[index].surface,
              onTap: actions[index].onTap,
              filled: actions[index].filled,
            ),
          ),
          if (index != actions.length - 1) const SizedBox(width: spacing),
        ],
      ],
    );
  }
}

class _HomeActionShortcut extends StatelessWidget {
  const _HomeActionShortcut({
    required this.label,
    required this.icon,
    required this.tone,
    required this.surface,
    required this.onTap,
    required this.filled,
  });

  final String label;
  final IconData icon;
  final Color tone;
  final Color surface;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.56,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: surface,
                    shape: BoxShape.circle,
                    border: filled
                        ? null
                        : Border.all(
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: tone, size: 26),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: enabled ? AppColors.ink : AppColors.slate,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePrimaryBanner extends StatelessWidget {
  const _HomePrimaryBanner({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.icon,
    required this.tone,
    required this.onPressed,
  });

  final String title;
  final String body;
  final String actionLabel;
  final IconData icon;
  final Color tone;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle buttonStyle = FilledButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: tone,
      minimumSize: const Size(0, 42),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF556172),
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget message = Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        maxLines: constraints.maxWidth < 360 ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          final Widget action = FilledButton(
            style: buttonStyle,
            onPressed: onPressed,
            child: Text(actionLabel),
          );

          if (constraints.maxWidth < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[message],
                ),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: action),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[message, const SizedBox(width: 12), action],
          );
        },
      ),
    );
  }
}

class _HomeSummaryPanel extends StatelessWidget {
  const _HomeSummaryPanel({
    required this.summary,
    required this.pendingCount,
    required this.hasWallet,
    required this.mainUsdTotal,
    required this.offlineUsdTotal,
    required this.spendableUsdTotal,
    required this.onTopUp,
    required this.onReceive,
    required this.onOpenOffline,
  });

  final WalletSummary summary;
  final int pendingCount;
  final bool hasWallet;
  final double? mainUsdTotal;
  final double? offlineUsdTotal;
  final double? spendableUsdTotal;
  final VoidCallback onTopUp;
  final VoidCallback onReceive;
  final VoidCallback onOpenOffline;

  @override
  Widget build(BuildContext context) {
    final bool usingBitGo = summary.walletEngine == WalletEngine.bitgo;
    final bool showGoldAccent = hasWallet && !usingBitGo;
    final bool hasOfflineFunds =
        hasWallet &&
        (usingBitGo ? summary.balanceSol > 0 : summary.offlineBalanceSol > 0);
    final bool readyForSend =
        hasWallet && (usingBitGo ? true : summary.readyForOffline);
    final String title = usingBitGo ? 'Wallet' : 'Offline wallet';
    final String mainValue = hasWallet
        ? Formatters.asset(summary.balanceSol, summary.chain)
        : '--';
    final String offlineValue = hasWallet
        ? usingBitGo
              ? Formatters.asset(summary.balanceSol, summary.chain)
              : Formatters.asset(summary.offlineBalanceSol, summary.chain)
        : '--';
    final String spendableValue = hasWallet
        ? usingBitGo
              ? Formatters.asset(summary.balanceSol, summary.chain)
              : Formatters.asset(summary.offlineAvailableSol, summary.chain)
        : '--';
    final ({String primary, String? secondary}) mainDisplay =
        _balanceDisplay(assetValue: mainValue, usdValue: mainUsdTotal);
    final ({String primary, String? secondary}) offlineDisplay =
        _balanceDisplay(assetValue: offlineValue, usdValue: offlineUsdTotal);
    final ({String primary, String? secondary}) spendableDisplay =
        _balanceDisplay(
          assetValue: spendableValue,
          usdValue: spendableUsdTotal,
        );
    final String walletLabel = !hasWallet
        ? 'Set up first'
        : usingBitGo
        ? (summary.primaryDisplayLabel ?? 'Custodied wallet')
        : summary.offlineWalletAddress == null
        ? 'Unavailable'
        : Formatters.shortAddress(summary.offlineWalletAddress!);
    final String caption = !hasWallet
        ? 'Set up to start nearby sends.'
        : usingBitGo
        ? (summary.primaryDisplayLabel ?? 'Custodied wallet')
        : 'Signer · $walletLabel';
    final String statusLabel = !hasWallet
        ? 'Setup'
        : usingBitGo
        ? 'Custodied'
        : !hasOfflineFunds
        ? 'Needs funds'
        : readyForSend
        ? 'Ready'
        : 'Syncing';
    final Color statusTone = !hasWallet
        ? AppColors.slate
        : usingBitGo
        ? AppColors.blue
        : !hasOfflineFunds
        ? AppColors.slate
        : readyForSend
        ? AppColors.emerald
        : AppColors.amber;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: 26,
            spreadRadius: -4,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          if (showGoldAccent)
            BoxShadow(
              color: AppColors.amber.withValues(alpha: 0.1),
              blurRadius: 26,
              spreadRadius: -12,
              offset: const Offset(0, 14),
            ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpenOffline,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: showGoldAccent
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        AppColors.amberTint.withValues(alpha: 0.64),
                        Colors.white,
                        Colors.white,
                      ],
                      stops: const <double>[0, 0.34, 1],
                    )
                  : null,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: showGoldAccent
                    ? AppColors.amber.withValues(alpha: 0.2)
                    : AppColors.line,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                if (showGoldAccent)
                  Positioned(
                    top: -28,
                    right: -18,
                    child: IgnorePointer(
                      child: Container(
                        width: 118,
                        height: 118,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: <Color>[
                              AppColors.amber.withValues(alpha: 0.18),
                              AppColors.amberTint.withValues(alpha: 0.16),
                              Colors.transparent,
                            ],
                            stops: const <double>[0, 0.42, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.slate),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                if (pendingCount > 0)
                                  _HomeSummaryChip(
                                    icon: Icons.schedule_rounded,
                                    label: '$pendingCount pending',
                                    tone: AppColors.blue,
                                  ),
                                _HomeSummaryChip(
                                  icon: usingBitGo
                                      ? Icons.shield_outlined
                                      : !hasOfflineFunds
                                      ? Icons.add_card_rounded
                                      : readyForSend
                                      ? Icons.check_circle_rounded
                                      : Icons.update_rounded,
                                  label: statusLabel,
                                  tone: statusTone,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!usingBitGo) ...<Widget>[
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: _HomeInfoButton(
                              key: const Key('offline-wallet-info-button'),
                              tooltip: 'How offline wallet works',
                              onTap: () {
                                _showOfflineWalletInfoSheet(
                                  context,
                                  summary: summary,
                                  pendingCount: pendingCount,
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        if (usingBitGo) ...<Widget>[
                          Expanded(
                            child: _HomeMiniStat(
                              label: 'Main',
                              value: mainDisplay.primary,
                              detail: mainDisplay.secondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: _HomeMiniStat(
                            label: usingBitGo ? 'Wallet' : 'Offline',
                            value: offlineDisplay.primary,
                            detail: offlineDisplay.secondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _HomeMiniStat(
                            label: 'Can send',
                            value: spendableDisplay.primary,
                            detail: spendableDisplay.secondary,
                          ),
                        ),
                      ],
                    ),
                    if (hasWallet && !usingBitGo) ...<Widget>[
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onTopUp,
                              icon: const Icon(
                                Icons.south_west_rounded,
                                size: 16,
                              ),
                              label: const Text('Top up'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onReceive,
                              icon: const Icon(
                                Icons.call_received_rounded,
                                size: 16,
                              ),
                              label: const Text('Receive'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showOfflineWalletInfoSheet(
  BuildContext context, {
  required WalletSummary summary,
  required int pendingCount,
}) async {
  final double reservedAmount =
      summary.offlineBalanceSol > summary.offlineAvailableSol
      ? summary.offlineBalanceSol - summary.offlineAvailableSol
      : 0;
  final String pendingMessage = pendingCount <= 0 || reservedAmount <= 0
      ? 'No funds are locked right now.'
      : '$pendingCount pending transfer${pendingCount == 1 ? '' : 's'} lock ${Formatters.asset(reservedAmount, summary.chain)}.';
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (BuildContext modalContext) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(modalContext).height * 0.72,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Offline wallet',
                              style: Theme.of(
                                modalContext,
                              ).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(modalContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                      Text(
                        'A separate signer lives on this phone for nearby sends on ${summary.chain.networkLabelFor(summary.network)}.',
                        style: Theme.of(modalContext).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.slate, height: 1.45),
                      ),
                      const SizedBox(height: 16),
                      const _OfflineWalletInfoPoint(
                        icon: Icons.south_west_rounded,
                        title: '1. Fund it',
                        body: 'Move funds from Main to Offline first.',
                      ),
                      const SizedBox(height: 12),
                      const _OfflineWalletInfoPoint(
                        icon: Icons.draw_rounded,
                        title: '2. Sign here',
                        body: 'This phone signs before handoff.',
                      ),
                      const SizedBox(height: 12),
                      const _OfflineWalletInfoPoint(
                        icon: Icons.wifi_tethering_rounded,
                        title: '3. Send nearby',
                        body: 'Use QR, hotspot, BLE, or ultrasonic.',
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        decoration: BoxDecoration(
                          color: AppColors.canvasTint,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'What the card numbers mean',
                              style: Theme.of(
                                modalContext,
                              ).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 10),
                            _OfflineWalletInfoMetric(
                              label: 'Offline total',
                              value: Formatters.asset(
                                summary.offlineBalanceSol,
                                summary.chain,
                              ),
                              detail: 'All funds in Offline.',
                            ),
                            const SizedBox(height: 10),
                            _OfflineWalletInfoMetric(
                              label: 'Can send now',
                              value: Formatters.asset(
                                summary.offlineAvailableSol,
                                summary.chain,
                              ),
                              detail: 'Ready to use right now.',
                            ),
                            const SizedBox(height: 10),
                            Text(
                              pendingMessage,
                              style: Theme.of(modalContext).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.slate,
                                    height: 1.4,
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
    },
  );
}

class _HomeInfoButton extends StatelessWidget {
  const _HomeInfoButton({
    super.key,
    required this.tooltip,
    required this.onTap,
  });

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.canvasTint,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.slate,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

double? _usdTotalForHoldings(
  BitsendAppState state,
  Iterable<AssetPortfolioHolding> holdings,
  double Function(AssetPortfolioHolding holding) selector,
) {
  double total = 0;
  bool hasPrice = false;
  for (final AssetPortfolioHolding holding in holdings) {
    final double? price = state.usdPriceForHolding(holding);
    if (price == null) {
      continue;
    }
    hasPrice = true;
    total += selector(holding) * price;
  }
  return hasPrice ? total : null;
}

double? _usdValueForHolding(
  BitsendAppState state,
  AssetPortfolioHolding holding,
  double amount,
) {
  final double? price = state.usdPriceForHolding(holding);
  if (price == null) {
    return null;
  }
  return amount * price;
}

({String primary, String? secondary}) _balanceDisplay({
  required String assetValue,
  double? usdValue,
}) {
  if (usdValue == null) {
    return (primary: assetValue, secondary: null);
  }
  return (primary: Formatters.usd(usdValue), secondary: assetValue);
}

class _HomeMiniStat extends StatelessWidget {
  const _HomeMiniStat({
    required this.label,
    required this.value,
    this.detail,
  });

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.canvasTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.ink,
              height: 1.05,
            ),
          ),
          if (detail != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.slate,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OfflineWalletInfoPoint extends StatelessWidget {
  const _OfflineWalletInfoPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.canvasTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Icon(icon, size: 18, color: AppColors.ink),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                body,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.slate,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OfflineWalletInfoMetric extends StatelessWidget {
  const _OfflineWalletInfoMetric({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.slate,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.slate,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: AppColors.ink),
        ),
      ],
    );
  }
}

class _HomeSummaryChip extends StatelessWidget {
  const _HomeSummaryChip({
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: tone),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeMoreActionTile extends StatelessWidget {
  const _HomeMoreActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.46,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.canvasTint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletBalancesCard extends StatelessWidget {
  const _WalletBalancesCard({required this.summary, required this.hasWallet});

  final WalletSummary summary;
  final bool hasWallet;

  @override
  Widget build(BuildContext context) {
    final bool usingBitGo = summary.walletEngine == WalletEngine.bitgo;
    final List<({String label, String value})> metrics =
        <({String label, String value})>[
          (
            label: usingBitGo ? 'Wallet' : 'Main',
            value: hasWallet
                ? Formatters.asset(summary.balanceSol, summary.chain)
                : 'Set up first',
          ),
          (
            label: usingBitGo ? 'Connected' : 'Protected signer',
            value: !hasWallet
                ? 'Set up first'
                : usingBitGo
                ? (summary.bitgoWallet?.displayLabel ?? 'Not connected')
                : Formatters.asset(summary.offlineBalanceSol, summary.chain),
          ),
          (
            label: usingBitGo ? 'Ready' : 'Spendable',
            value: !hasWallet
                ? 'Set up first'
                : usingBitGo
                ? Formatters.asset(summary.balanceSol, summary.chain)
                : Formatters.asset(summary.offlineAvailableSol, summary.chain),
          ),
          (
            label: usingBitGo ? 'Flow' : 'Protected',
            value: !hasWallet
                ? 'Set up first'
                : usingBitGo
                ? 'Custodied'
                : summary.offlineWalletAddress == null
                ? 'Unavailable'
                : Formatters.shortAddress(summary.offlineWalletAddress!),
          ),
        ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 420 ? 3 : 1;
        final double spacing = 10;
        final double itemWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map(
                (({String label, String value}) item) => SizedBox(
                  width: itemWidth,
                  child: _OverviewMetric(label: item.label, value: item.value),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _WalletHealthCard extends StatelessWidget {
  const _WalletHealthCard({
    required this.status,
    required this.summary,
    required this.pendingCount,
    required this.canRefresh,
  });

  final HomeStatus status;
  final WalletSummary summary;
  final int pendingCount;
  final VoidCallback? canRefresh;

  @override
  Widget build(BuildContext context) {
    final bool healthy =
        summary.walletEngine == WalletEngine.bitgo || summary.readyForOffline;
    final Color readinessTone = healthy ? AppColors.emerald : AppColors.amber;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _WalletHealthPill(
          icon: Icons.language_rounded,
          semanticsLabel: status.hasInternet
              ? 'Internet online'
              : 'Internet offline',
          tone: status.hasInternet ? AppColors.emerald : AppColors.slate,
        ),
        _WalletHealthPill(
          icon: healthy
              ? Icons.check_circle_outline_rounded
              : Icons.update_rounded,
          semanticsLabel: summary.walletEngine == WalletEngine.bitgo
              ? 'Custodial wallet active'
              : summary.readyForOffline
              ? 'Offline signer ready'
              : summary.blockhashAge == null
              ? 'Offline signer needs refresh'
              : 'Offline signer freshness ${Formatters.durationLabel(summary.blockhashAge)}',
          tone: readinessTone,
        ),
        _WalletHealthPill(
          icon: Icons.wifi_tethering_rounded,
          semanticsLabel: status.hasLocalLink
              ? 'Nearby local link available'
              : 'No nearby local link',
          tone: status.hasLocalLink ? AppColors.emerald : AppColors.slate,
        ),
        _WalletHealthPill(
          icon: Icons.schedule_send_rounded,
          semanticsLabel: pendingCount == 0
              ? 'Transfer queue clear'
              : 'Transfer queue has $pendingCount items',
          tone: pendingCount == 0 ? AppColors.blue : AppColors.amber,
          badge: pendingCount == 0 ? null : '$pendingCount',
        ),
        if (canRefresh != null)
          _WalletHealthPill(
            icon: Icons.refresh_rounded,
            semanticsLabel: 'Refresh wallet readiness',
            tone: AppColors.ink,
            onTap: canRefresh,
            filled: true,
            accentSurface: Colors.white.withValues(alpha: 0.82),
          ),
        if (summary.walletEngine == WalletEngine.bitgo && !status.hasInternet)
          _WalletHealthPill(
            icon: Icons.cloud_off_rounded,
            semanticsLabel: 'BitGo send requires internet',
            tone: AppColors.red,
          ),
        if (summary.walletEngine == WalletEngine.local &&
            !summary.readyForOffline &&
            summary.offlineBalanceSol <= 0)
          _WalletHealthPill(
            icon: Icons.south_west_rounded,
            semanticsLabel: 'Fund offline signer to send',
            tone: AppColors.amber,
          ),
      ],
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.slate,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _FeaturedAssetCard extends StatelessWidget {
  const _FeaturedAssetCard({
    required this.holding,
    required this.assetCount,
    this.usdValue,
  });

  final AssetPortfolioHolding holding;
  final int assetCount;
  final double? usdValue;

  @override
  Widget build(BuildContext context) {
    final _AssetPalette palette = _assetPaletteForHolding(holding);
    final ({String primary, String? secondary}) totalDisplay = _balanceDisplay(
      assetValue: Formatters.holding(holding.totalBalance, holding),
      usdValue: usdValue,
    );
    final List<Widget> stats = <Widget>[
      _AssetStatPill(
        label: 'Main',
        value: Formatters.holding(holding.mainBalance, holding),
        tone: palette.main,
      ),
      if (holding.protectedBalance > 0)
        _AssetStatPill(
          label: 'Protected',
          value: Formatters.holding(holding.protectedBalance, holding),
          tone: palette.protected,
        ),
      _AssetStatPill(
        label: holding.reservedBalance > 0 ? 'Reserved' : 'Spendable',
        value: Formatters.holding(
          holding.reservedBalance > 0
              ? holding.reservedBalance
              : holding.spendableBalance,
          holding,
        ),
        tone: holding.reservedBalance > 0 ? palette.reserved : palette.accent,
      ),
    ];

    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _AssetLogoBadge(holding: holding, size: 54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    holding.resolvedSymbol,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${holding.resolvedDisplayName} • ${holding.chain.label}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                  ),
                ],
              ),
            ),
            _AssetTag(text: holding.network.shortLabelFor(holding.chain)),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          totalDisplay.primary,
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(fontSize: 34, height: 0.98),
        ),
        if (totalDisplay.secondary != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            totalDisplay.secondary!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: stats),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            if (holding.mainAddress != null && holding.mainAddress!.isNotEmpty)
              _AssetTag(
                text: 'Main ${Formatters.shortAddress(holding.mainAddress!)}',
              ),
            if (holding.protectedAddress != null &&
                holding.protectedAddress!.isNotEmpty)
              _AssetTag(
                text:
                    'Protected ${Formatters.shortAddress(holding.protectedAddress!)}',
              ),
            if (assetCount > 1) _AssetTag(text: '$assetCount assets'),
          ],
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white,
            palette.surface.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.main.withValues(alpha: 0.12)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.main.withValues(alpha: 0.08),
            blurRadius: 28,
            spreadRadius: -10,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool stacked = constraints.maxWidth < 430;
            final Widget chart = _HoldingCompositionChart(
              holding: holding,
              size: stacked ? 172 : 152,
            );
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  details,
                  const SizedBox(height: 18),
                  Align(alignment: Alignment.center, child: chart),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: details),
                const SizedBox(width: 18),
                chart,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AssetHoldingRow extends StatelessWidget {
  const _AssetHoldingRow({
    required this.holding,
    this.usdValue,
    this.selected = false,
    this.onTap,
  });

  final AssetPortfolioHolding holding;
  final double? usdValue;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final _AssetPalette palette = _assetPaletteForHolding(holding);
    final ({String primary, String? secondary}) totalDisplay = _balanceDisplay(
      assetValue: Formatters.holding(holding.totalBalance, holding),
      usdValue: usdValue,
    );
    final String detail = holding.protectedBalance > 0
        ? 'Main ${Formatters.holding(holding.mainBalance, holding)}  •  Protected ${Formatters.holding(holding.protectedBalance, holding)}'
        : 'Main ${Formatters.holding(holding.mainBalance, holding)}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: selected
                ? palette.surface
                : Colors.white.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? palette.main.withValues(alpha: 0.22)
                  : AppColors.line.withValues(alpha: 0.8),
            ),
          ),
          child: Column(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _AssetLogoBadge(holding: holding, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                holding.resolvedSymbol,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            _AssetTag(
                              text: holding.network.shortLabelFor(
                                holding.chain,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${holding.chain.label} • $detail',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.slate),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        totalDisplay.primary,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (totalDisplay.secondary != null) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          totalDisplay.secondary!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.slate),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _AssetDistributionBar(holding: holding),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoldingCompositionChart extends StatelessWidget {
  const _HoldingCompositionChart({required this.holding, this.size = 168});

  final AssetPortfolioHolding holding;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String amountLabel = holding.totalBalance >= 10
        ? holding.totalBalance.toStringAsFixed(1)
        : holding.totalBalance.toStringAsFixed(3);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: Size.square(size),
            painter: _HoldingCompositionChartPainter(holding: holding),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                amountLabel,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: size * 0.19,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                holding.resolvedSymbol,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HoldingCompositionChartPainter extends CustomPainter {
  const _HoldingCompositionChartPainter({required this.holding});

  final AssetPortfolioHolding holding;

  @override
  void paint(Canvas canvas, Size size) {
    final _AssetPalette palette = _assetPaletteForHolding(holding);
    final double strokeWidth = size.width * 0.12;
    final Rect rect = Offset.zero & size;
    final Paint trackPaint = Paint()
      ..color = AppColors.line.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      0,
      math.pi * 2,
      false,
      trackPaint,
    );

    final double protectedAvailable = math.max(
      holding.protectedBalance - holding.reservedBalance,
      0,
    );
    final List<({double value, Color color})> segments =
        <({double value, Color color})>[
              (value: holding.mainBalance, color: palette.main),
              (value: protectedAvailable, color: palette.protected),
              (value: holding.reservedBalance, color: palette.reserved),
            ]
            .where((({double value, Color color}) segment) => segment.value > 0)
            .toList(growable: false);
    final double total = segments.fold<double>(
      0,
      (double sum, ({double value, Color color}) segment) =>
          sum + segment.value,
    );
    if (total <= 0) {
      return;
    }

    final double gap = segments.length == 1 ? 0 : 0.08;
    double startAngle = -math.pi / 2;
    for (final ({double value, Color color}) segment in segments) {
      final double rawSweep = (segment.value / total) * math.pi * 2;
      final double sweep = math.max(rawSweep - gap, 0.04);
      final Paint segmentPaint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        startAngle,
        sweep,
        false,
        segmentPaint,
      );
      startAngle += rawSweep;
    }
  }

  @override
  bool shouldRepaint(_HoldingCompositionChartPainter oldDelegate) {
    return oldDelegate.holding != holding;
  }
}

class _AssetDistributionBar extends StatelessWidget {
  const _AssetDistributionBar({required this.holding});

  final AssetPortfolioHolding holding;

  @override
  Widget build(BuildContext context) {
    final _AssetPalette palette = _assetPaletteForHolding(holding);
    final double total = holding.totalBalance;
    final double protectedAvailable = math.max(
      holding.protectedBalance - holding.reservedBalance,
      0,
    );

    Widget segment(double value, Color color) {
      final int flex = math.max((value * 1000).round(), 1);
      return Expanded(
        flex: flex,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.line.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(999),
          ),
          child: total <= 0
              ? null
              : Row(
                  children: <Widget>[
                    segment(holding.mainBalance, palette.main),
                    if (protectedAvailable > 0) ...<Widget>[
                      const SizedBox(width: 2),
                      segment(protectedAvailable, palette.protected),
                    ],
                    if (holding.reservedBalance > 0) ...<Widget>[
                      const SizedBox(width: 2),
                      segment(holding.reservedBalance, palette.reserved),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: <Widget>[
            _AssetLegendDot(label: 'Main', color: palette.main),
            if (holding.protectedBalance > 0)
              _AssetLegendDot(label: 'Protected', color: palette.protected),
            if (holding.reservedBalance > 0)
              _AssetLegendDot(label: 'Reserved', color: palette.reserved),
          ],
        ),
      ],
    );
  }
}

class _AssetLegendDot extends StatelessWidget {
  const _AssetLegendDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
        ),
      ],
    );
  }
}

class _AssetStatPill extends StatelessWidget {
  const _AssetStatPill({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _AssetTag extends StatelessWidget {
  const _AssetTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.8)),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
      ),
    );
  }
}

class _AssetLogoBadge extends StatelessWidget {
  const _AssetLogoBadge({required this.holding, this.size = 48});

  final AssetPortfolioHolding holding;
  final double size;

  @override
  Widget build(BuildContext context) {
    final _AssetPalette palette = _assetPaletteForHolding(holding);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(size * 0.34),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.main.withValues(alpha: 0.1),
            blurRadius: size * 0.24,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.16),
        child: switch (holding.resolvedSymbol) {
          'USDC' => _UsdcMark(size: size * 0.68),
          'EURC' => _EurcMark(size: size * 0.68),
          _ => ChainLogo(chain: holding.chain, size: size * 0.68),
        },
      ),
    );
  }
}

class _AssetPalette {
  const _AssetPalette({
    required this.main,
    required this.protected,
    required this.reserved,
    required this.accent,
    required this.surface,
  });

  final Color main;
  final Color protected;
  final Color reserved;
  final Color accent;
  final Color surface;
}

_AssetPalette _assetPaletteFor(ChainKind chain) {
  return switch (chain) {
    ChainKind.solana => const _AssetPalette(
      main: Color(0xFF14F195),
      protected: Color(0xFF9945FF),
      reserved: AppColors.amber,
      accent: Color(0xFF1F8A61),
      surface: Color(0xFFF2F0FF),
    ),
    ChainKind.ethereum => const _AssetPalette(
      main: Color(0xFF627EEA),
      protected: Color(0xFF99A9FF),
      reserved: AppColors.amber,
      accent: Color(0xFF404B8C),
      surface: Color(0xFFF2F4FF),
    ),
    ChainKind.base => const _AssetPalette(
      main: Color(0xFF0052FF),
      protected: Color(0xFF79A7FF),
      reserved: AppColors.amber,
      accent: Color(0xFF003ECC),
      surface: Color(0xFFF0F5FF),
    ),
    ChainKind.bnb => const _AssetPalette(
      main: Color(0xFFF0B90B),
      protected: Color(0xFFF8D96B),
      reserved: AppColors.amber,
      accent: Color(0xFF8A6A00),
      surface: Color(0xFFFFF8E7),
    ),
    ChainKind.polygon => const _AssetPalette(
      main: Color(0xFF8247E5),
      protected: Color(0xFFC09CFF),
      reserved: AppColors.amber,
      accent: Color(0xFF5A2BB6),
      surface: Color(0xFFF5EEFF),
    ),
  };
}

_AssetPalette _assetPaletteForHolding(AssetPortfolioHolding holding) {
  if (holding.resolvedSymbol == 'USDC') {
    return const _AssetPalette(
      main: Color(0xFF2775CA),
      protected: Color(0xFF79A7FF),
      reserved: AppColors.amber,
      accent: Color(0xFF1659A5),
      surface: Color(0xFFF1F7FF),
    );
  }
  if (holding.resolvedSymbol == 'EURC') {
    return const _AssetPalette(
      main: Color(0xFF00A86B),
      protected: Color(0xFF72D8B0),
      reserved: AppColors.amber,
      accent: Color(0xFF0B7A52),
      surface: Color(0xFFF2FBF7),
    );
  }
  return _assetPaletteFor(holding.chain);
}

class _UsdcMark extends StatelessWidget {
  const _UsdcMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF2775CA),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '\$',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.55,
          height: 1,
        ),
      ),
    );
  }
}

class _EurcMark extends StatelessWidget {
  const _EurcMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF00A86B),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '€',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.6,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class _WalletHealthPill extends StatelessWidget {
  const _WalletHealthPill({
    required this.icon,
    required this.semanticsLabel,
    required this.tone,
    this.badge,
    this.onTap,
    this.filled = false,
    this.accentSurface,
  });

  final IconData icon;
  final String semanticsLabel;
  final Color tone;
  final String? badge;
  final VoidCallback? onTap;
  final bool filled;
  final Color? accentSurface;

  @override
  Widget build(BuildContext context) {
    final Widget child = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color:
            accentSurface ??
            Colors.white.withValues(alpha: filled ? 0.72 : 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Center(child: Icon(icon, color: tone, size: 18)),
          if (badge != null)
            Positioned(
              right: -2,
              top: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: tone,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      label: semanticsLabel,
      child: Tooltip(
        message: semanticsLabel,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _HomeActivityRow extends StatelessWidget {
  const _HomeActivityRow({
    required this.transfer,
    required this.onTap,
    this.showDivider = true,
  });

  final PendingTransfer transfer;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final bool inbound = transfer.isInbound;
    final Color tone = transfer.status.isError
        ? AppColors.red
        : inbound
        ? AppColors.emerald
        : AppColors.ink;
    final IconData icon = transfer.status.isError
        ? Icons.error_outline_rounded
        : inbound
        ? Icons.call_received_rounded
        : Icons.send_rounded;
    final String counterparty = Formatters.shortAddress(
      transfer.counterpartyAddress,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: tone, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          counterparty,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          transfer.status.label,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.slate),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        Formatters.transferAmount(transfer),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Formatters.relativeAge(
                          transfer.updatedAt,
                          DateTime.now(),
                        ),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                      ),
                    ],
                  ),
                ],
              ),
              if (showDivider) ...<Widget>[
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: AppColors.line.withValues(alpha: 0.7),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniCue extends StatelessWidget {
  const _MiniCue({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: active
            ? AppColors.emeraldTint
            : Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 16,
            color: active ? AppColors.emerald : AppColors.slate,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: active ? AppColors.emerald : AppColors.slate,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineWalletScene extends StatelessWidget {
  const _OfflineWalletScene({
    required this.summary,
    required this.hasWallet,
    required this.pendingCount,
    required this.mainUsdTotal,
    required this.offlineUsdTotal,
    required this.spendableUsdTotal,
    required this.onShowInfo,
  });

  final WalletSummary summary;
  final bool hasWallet;
  final int pendingCount;
  final double? mainUsdTotal;
  final double? offlineUsdTotal;
  final double? spendableUsdTotal;
  final VoidCallback onShowInfo;

  @override
  Widget build(BuildContext context) {
    final bool hasOfflineFunds = hasWallet && summary.offlineBalanceSol > 0;
    final bool readyForSend = hasWallet && summary.readyForOffline;
    final String mainValue = hasWallet
        ? Formatters.asset(summary.balanceSol, summary.chain)
        : '--';
    final String offlineValue = hasWallet
        ? Formatters.asset(summary.offlineBalanceSol, summary.chain)
        : '--';
    final String spendableValue = hasWallet
        ? Formatters.asset(summary.offlineAvailableSol, summary.chain)
        : '--';
    final ({String primary, String? secondary}) mainDisplay =
        _balanceDisplay(assetValue: mainValue, usdValue: mainUsdTotal);
    final ({String primary, String? secondary}) offlineDisplay =
        _balanceDisplay(assetValue: offlineValue, usdValue: offlineUsdTotal);
    final ({String primary, String? secondary}) spendableDisplay =
        _balanceDisplay(
          assetValue: spendableValue,
          usdValue: spendableUsdTotal,
        );
    final String caption = !hasWallet
        ? 'Set up to start nearby sends.'
        : summary.offlineWalletAddress == null
        ? 'Signer unavailable'
        : 'Signer · ${Formatters.shortAddress(summary.offlineWalletAddress!)}';
    final String statusLabel = !hasWallet
        ? 'Setup'
        : !hasOfflineFunds
        ? 'Needs funds'
        : readyForSend
        ? 'Ready'
        : 'Syncing';
    final Color statusTone = !hasWallet
        ? AppColors.slate
        : !hasOfflineFunds
        ? AppColors.slate
        : readyForSend
        ? AppColors.emerald
        : AppColors.amber;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: 26,
            spreadRadius: -4,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          if (hasWallet)
            BoxShadow(
              color: AppColors.amber.withValues(alpha: 0.1),
              blurRadius: 26,
              spreadRadius: -12,
              offset: const Offset(0, 14),
            ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            gradient: hasWallet
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      AppColors.amberTint.withValues(alpha: 0.64),
                      Colors.white,
                      Colors.white,
                    ],
                    stops: const <double>[0, 0.34, 1],
                  )
                : null,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: hasWallet
                  ? AppColors.amber.withValues(alpha: 0.2)
                  : AppColors.line,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              if (hasWallet)
                Positioned(
                  top: -28,
                  right: -18,
                  child: IgnorePointer(
                    child: Container(
                      width: 118,
                      height: 118,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            AppColors.amber.withValues(alpha: 0.18),
                            AppColors.amberTint.withValues(alpha: 0.16),
                            Colors.transparent,
                          ],
                          stops: const <double>[0, 0.42, 1],
                        ),
                      ),
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Offline wallet',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.slate),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              if (pendingCount > 0)
                                _HomeSummaryChip(
                                  icon: Icons.schedule_rounded,
                                  label: '$pendingCount pending',
                                  tone: AppColors.blue,
                                ),
                              _HomeSummaryChip(
                                icon: !hasOfflineFunds
                                    ? Icons.add_card_rounded
                                    : readyForSend
                                    ? Icons.check_circle_rounded
                                    : Icons.update_rounded,
                                label: statusLabel,
                                tone: statusTone,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: _HomeInfoButton(
                          tooltip: 'How offline wallet works',
                          onTap: onShowInfo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Can send now',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.slate,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    spendableDisplay.primary,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                  if (spendableDisplay.secondary != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      spendableDisplay.secondary!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.slate,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    readyForSend
                        ? 'Ready for nearby send.'
                        : 'Refresh before handoff.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.slate,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _HomeMiniStat(
                          label: 'Main',
                          value: mainDisplay.primary,
                          detail: mainDisplay.secondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _HomeMiniStat(
                          label: 'Offline',
                          value: offlineDisplay.primary,
                          detail: offlineDisplay.secondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _HomeMiniStat(
                          label: 'Can send',
                          value: spendableDisplay.primary,
                          detail: spendableDisplay.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineActionComposer extends StatelessWidget {
  const _OfflineActionComposer({
    required this.chain,
    required this.selectedAsset,
    required this.availableAssets,
    required this.selectedAssetMainUsd,
    required this.selectedAssetOfflineUsd,
    required this.controller,
    required this.working,
    required this.statusMessage,
    required this.readyForOffline,
    required this.onAssetSelected,
    required this.onPresetSelected,
    required this.onTopUp,
    required this.onRefreshReadiness,
  });

  final ChainKind chain;
  final AssetPortfolioHolding selectedAsset;
  final List<AssetPortfolioHolding> availableAssets;
  final double? selectedAssetMainUsd;
  final double? selectedAssetOfflineUsd;
  final TextEditingController controller;
  final bool working;
  final String? statusMessage;
  final bool readyForOffline;
  final ValueChanged<String> onAssetSelected;
  final ValueChanged<String> onPresetSelected;
  final VoidCallback onTopUp;
  final VoidCallback onRefreshReadiness;

  @override
  Widget build(BuildContext context) {
    final List<String> presets = selectedAsset.isNative
        ? chain == ChainKind.solana
              ? const <String>['0.050', '0.100', '0.250']
              : const <String>['0.005', '0.010', '0.025']
        : selectedAsset.mainBalance >= 25
        ? const <String>['5', '10', '25']
        : selectedAsset.mainBalance >= 5
        ? const <String>['1', '2', '5']
        : const <String>['0.5', '1', '2'];
    final String selectedAssetHint = selectedAsset.isNative
        ? 'Move ${selectedAsset.resolvedSymbol} from Main to Offline.'
        : 'Move ${selectedAsset.resolvedSymbol} into Offline.';
    final String helperText = selectedAsset.isNative
        ? 'Needed for gas and nearby sends.'
        : 'Keep some ${chain.assetDisplayLabel} in Main for gas.';
    final ({String primary, String? secondary}) mainDisplay =
        _balanceDisplay(
          assetValue: Formatters.holding(
            selectedAsset.mainBalance,
            selectedAsset,
          ),
          usdValue: selectedAssetMainUsd,
        );
    final ({String primary, String? secondary}) offlineDisplay =
        _balanceDisplay(
          assetValue: Formatters.holding(
            selectedAsset.protectedBalance,
            selectedAsset,
          ),
          usdValue: selectedAssetOfflineUsd,
        );

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Top up',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      selectedAssetHint,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.canvasTint.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.south_east_rounded,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (availableAssets.length > 1) ...<Widget>[
            DropdownButtonFormField<String>(
              key: const Key('offline-topup-asset'),
              value: selectedAsset.resolvedAssetId,
              decoration: const InputDecoration(labelText: 'Asset'),
              items: availableAssets
                  .map(
                    (AssetPortfolioHolding asset) => DropdownMenuItem<String>(
                      value: asset.resolvedAssetId,
                      child: Text(
                        '${asset.resolvedSymbol}  ·  ${Formatters.holding(asset.mainBalance, asset)}',
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: working
                  ? null
                  : (String? value) {
                      if (value == null) {
                        return;
                      }
                      onAssetSelected(value);
                    },
            ),
            const SizedBox(height: 14),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.emeraldTint.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: AppColors.ink,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        selectedAsset.resolvedDisplayName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _HomeMiniStat(
                        label: 'Main',
                        value: mainDisplay.primary,
                        detail: mainDisplay.secondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HomeMiniStat(
                        label: 'Offline',
                        value: offlineDisplay.primary,
                        detail: offlineDisplay.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            helperText,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
          ),
          if (working && statusMessage != null) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: readyForOffline
                    ? AppColors.emeraldTint
                    : AppColors.amberTint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: <Widget>[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      statusMessage!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          _TopUpAmountField(controller: controller, chain: chain),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets
                .map(
                  (String amount) => _OfflineAmountPreset(
                    label: amount,
                    onTap: () => onPresetSelected(amount),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: working ? null : onTopUp,
                  child: working
                      ? const Text('Moving funds...')
                      : const Text('Top up offline wallet'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: working ? null : onRefreshReadiness,
                  child: const Text('Refresh now'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OfflineDepositChooser extends StatelessWidget {
  const _OfflineDepositChooser({
    required this.onDepositMain,
    required this.onDepositOffline,
  });

  final VoidCallback onDepositMain;
  final VoidCallback onDepositOffline;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Receive',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Choose which wallet QR to show.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('offline-page-deposit-main'),
                  onPressed: onDepositMain,
                  icon: const Icon(Icons.account_balance_wallet_rounded),
                  label: const Text('Main wallet'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('offline-page-deposit-offline'),
                  onPressed: onDepositOffline,
                  icon: const Icon(Icons.lock_clock_rounded),
                  label: const Text('Offline wallet'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OfflineVoucherPanel extends StatelessWidget {
  const _OfflineVoucherPanel({
    required this.chain,
    required this.contractController,
    required this.sessions,
    required this.claims,
    required this.onSaveContract,
  });

  final ChainKind chain;
  final TextEditingController contractController;
  final List<OfflineVoucherEscrowSession> sessions;
  final List<OfflineVoucherClaimAttempt> claims;
  final VoidCallback onSaveContract;

  @override
  Widget build(BuildContext context) {
    final BigInt availableBaseUnits = sessions.fold<BigInt>(
      BigInt.zero,
      (
        BigInt total,
        OfflineVoucherEscrowSession session,
      ) => total + session.availableBaseUnits,
    );
    final String availableLabel = Formatters.asset(
      chain.amountFromBaseUnits(int.parse(availableBaseUnits.toString())),
      chain,
    );
    final int pendingClaims = claims
        .where((OfflineVoucherClaimAttempt claim) => !claim.isTerminal)
        .length;
    final List<OfflineVoucherClaimAttempt> recentClaims =
        List<OfflineVoucherClaimAttempt>.from(claims)
          ..sort(
            (
              OfflineVoucherClaimAttempt a,
              OfflineVoucherClaimAttempt b,
            ) => b.queuedAt.compareTo(a.queuedAt),
          );

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Secure offline vouchers',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Set the settlement contract once, then Bitsend can lock value into escrow and claim it later from received voucher bundles.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: contractController,
                  decoration: const InputDecoration(
                    labelText: 'Settlement contract',
                    hintText: '0x...',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: onSaveContract,
                child: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final List<Widget> stats = <Widget>[
                Expanded(
                  child: _OfflineVoucherStat(
                    label: 'Escrows',
                    value: '${sessions.length}',
                    icon: Icons.account_balance_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _OfflineVoucherStat(
                    label: 'Available',
                    value: availableLabel,
                    icon: Icons.lock_open_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _OfflineVoucherStat(
                    label: 'Claims',
                    value: '$pendingClaims pending',
                    icon: Icons.verified_outlined,
                  ),
                ),
              ];
              if (constraints.maxWidth < 560) {
                return Column(
                  children: <Widget>[
                    Row(children: <Widget>[stats[0], stats[1]]),
                    const SizedBox(height: 10),
                    Row(children: <Widget>[stats[2]]),
                  ],
                );
              }
              return Row(children: stats);
            },
          ),
          const SizedBox(height: 14),
          if (sessions.isEmpty)
            const InlineBanner(
              title: 'No escrow inventory yet',
              caption:
                  'After the contract is saved, the first secure offline send will mint voucher inventory from the offline wallet.',
              icon: Icons.account_balance_wallet_outlined,
            )
          else
            ...sessions
                .take(2)
                .map(
                  (OfflineVoucherEscrowSession session) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OfflineVoucherSessionRow(
                      chain: chain,
                      session: session,
                    ),
                  ),
                ),
          if (recentClaims.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Recent claims',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            ...recentClaims
                .take(2)
                .map(
                  (OfflineVoucherClaimAttempt claim) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OfflineVoucherClaimRow(claim: claim),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _OfflineVoucherStat extends StatelessWidget {
  const _OfflineVoucherStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.canvasTint.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.ink, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.slate,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineVoucherSessionRow extends StatelessWidget {
  const _OfflineVoucherSessionRow({
    required this.chain,
    required this.session,
  });

  final ChainKind chain;
  final OfflineVoucherEscrowSession session;

  @override
  Widget build(BuildContext context) {
    final String availableLabel = Formatters.asset(
      chain.amountFromBaseUnits(int.parse(session.availableBaseUnits.toString())),
      chain,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.canvasTint.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Escrow ${_shortHash(session.commitment.escrowId)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '$availableLabel available · ${session.inventory.where((OfflineVoucherInventoryEntry item) => item.isAvailable).length} vouchers',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _expiryLabel(session.commitment.expiresAt),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
          ),
        ],
      ),
    );
  }
}

class _OfflineVoucherClaimRow extends StatelessWidget {
  const _OfflineVoucherClaimRow({required this.claim});

  final OfflineVoucherClaimAttempt claim;

  @override
  Widget build(BuildContext context) {
    final Color tone = switch (claim.status) {
      OfflineVoucherClaimStatus.confirmedOnchain => AppColors.emerald,
      OfflineVoucherClaimStatus.submittedOnchain => AppColors.blue,
      OfflineVoucherClaimStatus.accepted => AppColors.amber,
      OfflineVoucherClaimStatus.invalidRejected ||
      OfflineVoucherClaimStatus.duplicateRejected ||
      OfflineVoucherClaimStatus.expiredRejected => AppColors.red,
    };
    final String caption = switch (claim.status) {
      OfflineVoucherClaimStatus.accepted => 'Queued for claim',
      OfflineVoucherClaimStatus.submittedOnchain => 'Submitted on-chain',
      OfflineVoucherClaimStatus.confirmedOnchain => 'Confirmed on-chain',
      OfflineVoucherClaimStatus.invalidRejected => 'Rejected as invalid',
      OfflineVoucherClaimStatus.duplicateRejected => 'Rejected as duplicate',
      OfflineVoucherClaimStatus.expiredRejected => 'Expired before claim',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Voucher ${_shortHash(claim.voucherId)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  caption,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _shortHash(String value) {
  final String normalized = value.trim();
  if (normalized.length <= 12) {
    return normalized;
  }
  return '${normalized.substring(0, 6)}...${normalized.substring(normalized.length - 4)}';
}

String _expiryLabel(DateTime value) {
  final Duration remaining = value.toUtc().difference(DateTime.now().toUtc());
  if (remaining.inSeconds <= 0) {
    return 'Expired';
  }
  if (remaining.inHours >= 1) {
    return '${remaining.inHours}h left';
  }
  if (remaining.inMinutes >= 1) {
    return '${remaining.inMinutes}m left';
  }
  return '${remaining.inSeconds}s left';
}

class _PrepareInfoRow extends StatelessWidget {
  const _PrepareInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.slate,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _OfflineAmountPreset extends StatelessWidget {
  const _OfflineAmountPreset({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.line.withValues(alpha: 0.5)),
          ),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}

class _TopUpAmountField extends StatelessWidget {
  const _TopUpAmountField({required this.controller, required this.chain});

  final TextEditingController controller;
  final ChainKind chain;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(
        labelText: 'Top up amount in ${chain.shortLabel}',
        hintText: chain == ChainKind.solana ? '0.100' : '0.010',
        suffixIcon: IconButton(
          tooltip: 'Clear amount',
          onPressed: controller.clear,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
    );
  }
}

class _OfflineRunbookCard extends StatelessWidget {
  const _OfflineRunbookCard({
    required this.readyForOffline,
    required this.readinessAge,
    required this.mainAddress,
    required this.offlineAddress,
    required this.hasOfflineFunds,
  });

  final bool readyForOffline;
  final String readinessAge;
  final String mainAddress;
  final String offlineAddress;
  final bool hasOfflineFunds;

  @override
  Widget build(BuildContext context) {
    final String statusTitle = readyForOffline
        ? 'Ready for the next handoff'
        : 'Sync pending for the next handoff';
    final String statusCaption = readyForOffline
        ? 'The signer has a fresh readiness snapshot. Keep it offline until you need to send.'
        : 'Bitsend refreshes readiness automatically while the phone stays online. If you need it immediately, tap Refresh now.';

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Handoff checklist',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Funding still happens explicitly. Readiness now keeps itself fresh while the phone stays online.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _MiniCue(
                icon: readyForOffline
                    ? Icons.check_circle_outline_rounded
                    : Icons.update_rounded,
                label: readyForOffline ? 'Ready' : 'Syncing',
                active: readyForOffline,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: readyForOffline
                  ? AppColors.emeraldTint.withValues(alpha: 0.88)
                  : AppColors.amberTint.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  readyForOffline
                      ? Icons.lock_clock_rounded
                      : Icons.warning_amber_rounded,
                  color: readyForOffline ? AppColors.emerald : AppColors.amber,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        statusTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusCaption,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _OfflineChecklistTile(
            icon: hasOfflineFunds
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            title: 'Signer funded',
            caption:
                'Top up from the main wallet so the offline signer can cover the amount and network fees.',
            accent: hasOfflineFunds ? AppColors.emerald : AppColors.slate,
          ),
          const SizedBox(height: 12),
          _OfflineChecklistTile(
            icon: readyForOffline
                ? Icons.check_circle_rounded
                : Icons.update_rounded,
            title: 'Readiness snapshot',
            caption: readyForOffline
                ? 'Fresh blockhash captured. Current age: $readinessAge.'
                : 'Current age: $readinessAge. Bitsend will refresh it automatically while online, or you can tap Refresh now.',
            accent: readyForOffline ? AppColors.emerald : AppColors.amber,
          ),
          const SizedBox(height: 12),
          _OfflineChecklistTile(
            icon: Icons.send_rounded,
            title: 'Next step',
            caption:
                'Once readiness is fresh, keep the signer offline and use it for the next local send.',
            accent: AppColors.ink,
          ),
          const SizedBox(height: 18),
          Text('Wallets', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DetailRow(label: 'Main wallet', value: mainAddress),
          DetailRow(label: 'Offline signer', value: offlineAddress),
          DetailRow(label: 'Readiness age', value: readinessAge),
        ],
      ),
    );
  }
}

class _OfflineChecklistTile extends StatelessWidget {
  const _OfflineChecklistTile({
    required this.icon,
    required this.title,
    required this.caption,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String caption;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(caption, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.summary,
    required this.hasWallet,
    required this.activeScopeUsdTotal,
  });

  final WalletSummary summary;
  final bool hasWallet;
  final double? activeScopeUsdTotal;

  @override
  Widget build(BuildContext context) {
    final bool usingBitGo = summary.walletEngine == WalletEngine.bitgo;
    final String balanceValue = hasWallet
        ? activeScopeUsdTotal == null
              ? '\$--.--'
              : Formatters.usd(activeScopeUsdTotal!)
        : 'Set up wallet';
    final String helperText = !hasWallet
        ? 'Create or restore a wallet to get started.'
        : activeScopeUsdTotal == null
        ? 'Refreshing market prices...'
        : usingBitGo
        ? 'Available ${Formatters.asset(summary.balanceSol, summary.chain)}'
        : 'Main ${Formatters.asset(summary.balanceSol, summary.chain)}  •  Protected ${Formatters.asset(summary.offlineBalanceSol, summary.chain)}';

    return Semantics(
      container: true,
      label: 'Wallet overview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Est. chain value',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.remove_red_eye_outlined,
                size: 16,
                color: AppColors.slate.withValues(alpha: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                balanceValue,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppColors.ink,
                  fontSize: 38,
                  height: 0.96,
                ),
              ),
              if (hasWallet) ...<Widget>[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    summary.chain.shortLabel,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: AppColors.ink),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            helperText,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
          ),
        ],
      ),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact =
            constraints.maxHeight < 640 || constraints.maxWidth < 380;
        return Semantics(
          container: true,
          label: 'Send locally first, then settle later on-chain.',
          child: SizedBox.expand(
            child: Stack(
              children: <Widget>[
                Positioned(
                  top: compact ? 18 : 24,
                  right: 0,
                  child: IgnorePointer(
                    child: Text(
                      'NOW',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: AppColors.emerald.withValues(alpha: 0.12),
                        fontSize: compact ? 68 : 88,
                        height: 0.92,
                        letterSpacing: -3,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: compact ? 98 : 112,
                  child: IgnorePointer(
                    child: Text(
                      'LATER',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: AppColors.amber.withValues(alpha: 0.14),
                        fontSize: compact ? 60 : 76,
                        height: 0.92,
                        letterSpacing: -3,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 18 : 22,
                    compact ? 10 : 16,
                    compact ? 18 : 22,
                    compact ? 14 : 18,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const BitsendBrandLogo(
                        tone: BitsendLogoTone.transparent,
                        height: 28,
                      ),
                      SizedBox(height: compact ? 28 : 40),
                      Text(
                        'LOCAL HANDOFF',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.slate,
                          letterSpacing: 1.4,
                        ),
                      ),
                      SizedBox(height: compact ? 10 : 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Text(
                          'Send now. Settle later.',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontSize: compact ? 38 : 48,
                            height: 0.94,
                            letterSpacing: -1.8,
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 12 : 14),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Text(
                          'Sign nearby first. Broadcast on-chain when either side reconnects.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.mutedInk,
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 24 : 34),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Wrap(
                          spacing: 18,
                          runSpacing: 14,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: const <Widget>[
                            _WelcomeLinearStep(
                              index: '01',
                              title: 'Sign',
                              caption: 'offline',
                            ),
                            _WelcomeLinearDivider(),
                            _WelcomeLinearStep(
                              index: '02',
                              title: 'Share',
                              caption: 'nearby',
                            ),
                            _WelcomeLinearDivider(),
                            _WelcomeLinearStep(
                              index: '03',
                              title: 'Settle',
                              caption: 'later',
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Text(
                          'Create or restore your wallet on the next screen.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.slate,
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 12 : 16),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onContinue,
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  'Set up wallet',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.ink,
                                    decorationThickness: 1.4,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Icon(Icons.arrow_forward_rounded),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WelcomeLinearStep extends StatelessWidget {
  const _WelcomeLinearStep({
    required this.index,
    required this.title,
    required this.caption,
  });

  final String index;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          index,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.slate,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 8),
        RichText(
          text: TextSpan(
            style: theme.textTheme.titleMedium?.copyWith(color: AppColors.ink),
            children: <InlineSpan>[
              TextSpan(text: title),
              TextSpan(
                text: ' $caption',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.slate,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WelcomeLinearDivider extends StatelessWidget {
  const _WelcomeLinearDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 26, height: 1, color: AppColors.line);
  }
}

class _WelcomeTonePill extends StatelessWidget {
  const _WelcomeTonePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeTransferScene extends StatelessWidget {
  const _WelcomeTransferScene({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double sceneHeight = compact ? 212 : 248;
        final double cardWidth = constraints.maxWidth < 360 ? 130 : 152;
        return Center(
          child: SizedBox(
            height: sceneHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  left: 48,
                  right: 48,
                  top: sceneHeight * 0.38,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.white.withValues(alpha: 0.14),
                          Colors.white.withValues(alpha: 0.55),
                          Colors.white.withValues(alpha: 0.14),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: sceneHeight * 0.26,
                  child: _WelcomeSceneDevice(
                    width: cardWidth,
                    icon: Icons.phone_android_rounded,
                    title: 'Sender',
                    caption: 'Signs offline',
                    accent: AppColors.amber,
                  ),
                ),
                Positioned(
                  right: 0,
                  top: sceneHeight * 0.26,
                  child: _WelcomeSceneDevice(
                    width: cardWidth,
                    icon: Icons.phone_iphone_rounded,
                    title: 'Receiver',
                    caption: 'Stores handoff',
                    accent: AppColors.emerald,
                    alignEnd: true,
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Text(
                      'Signed handoff nearby',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, -0.02),
                  child: Container(
                    width: compact ? 72 : 80,
                    height: compact ? 72 : 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[AppColors.amber, AppColors.emerald],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.ink.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.swap_horiz_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                Positioned(
                  left: constraints.maxWidth * 0.18,
                  right: constraints.maxWidth * 0.18,
                  bottom: 8,
                  child: const Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: <Widget>[
                      _WelcomeSceneCue(
                        icon: Icons.lock_outline_rounded,
                        label: 'Local sign',
                      ),
                      _WelcomeSceneCue(
                        icon: Icons.bluetooth_searching_rounded,
                        label: 'BLE / Hotspot',
                      ),
                      _WelcomeSceneCue(
                        icon: Icons.cloud_upload_rounded,
                        label: 'Later settle',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WelcomeSceneDevice extends StatelessWidget {
  const _WelcomeSceneDevice({
    required this.width,
    required this.icon,
    required this.title,
    required this.caption,
    required this.accent,
    this.alignEnd = false,
  });

  final double width;
  final IconData icon;
  final String title;
  final String caption;
  final Color accent;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.74),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeSceneCue extends StatelessWidget {
  const _WelcomeSceneCue({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeFlowRibbon extends StatelessWidget {
  const _WelcomeFlowRibbon({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 16,
        vertical: compact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: const <Widget>[
          Expanded(
            child: _WelcomeFlowStep(
              icon: Icons.draw_rounded,
              title: 'Sign',
              caption: 'Local',
            ),
          ),
          _WelcomeFlowDivider(),
          Expanded(
            child: _WelcomeFlowStep(
              icon: Icons.swap_horiz_rounded,
              title: 'Share',
              caption: 'Nearby',
            ),
          ),
          _WelcomeFlowDivider(),
          Expanded(
            child: _WelcomeFlowStep(
              icon: Icons.cloud_upload_rounded,
              title: 'Settle',
              caption: 'Later',
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeFlowStep extends StatelessWidget {
  const _WelcomeFlowStep({
    required this.icon,
    required this.title,
    required this.caption,
  });

  final IconData icon;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

class _WelcomeFlowDivider extends StatelessWidget {
  const _WelcomeFlowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 16,
        height: 2,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.transfer, required this.onTap});

  final PendingTransfer transfer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String directionLabel = transfer.isInbound
        ? 'Inbound transfer'
        : 'Outbound transfer';
    return Semantics(
      button: true,
      label: directionLabel,
      value: '${Formatters.transferAmount(transfer)}, ${transfer.status.label}',
      hint: 'Open transfer details',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        directionLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    StatusPill(status: transfer.status),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  Formatters.transferAmount(transfer),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  transfer.isInbound
                      ? 'From ${Formatters.shortAddress(transfer.senderAddress)}'
                      : 'To ${Formatters.shortAddress(transfer.receiverAddress)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Updated ${Formatters.relativeAge(transfer.updatedAt, DateTime.now())}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectableReceiverCard extends StatelessWidget {
  const _SelectableReceiverCard({
    required this.title,
    required this.caption,
    required this.detail,
    required this.verified,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String caption;
  final String detail;
  final bool verified;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      hint: caption,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.emeraldTint.withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.56),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? AppColors.emerald : AppColors.mutedInk,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        caption,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: verified
                                  ? AppColors.emeraldTint
                                  : AppColors.amberTint,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              verified ? 'Verified' : 'Preview',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: verified
                                        ? AppColors.emerald
                                        : AppColors.amber,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              detail,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TransferDetailActions extends StatelessWidget {
  const _TransferDetailActions({required this.transfer, this.onRetry});

  final PendingTransfer transfer;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (onRetry == null) {
      return const SizedBox.shrink();
    }

    return ElevatedButton(
      onPressed: onRetry,
      child: Text(
        transfer.walletEngine == WalletEngine.bitgo
            ? 'Retry submit'
            : transfer.needsInitialBroadcast
            ? 'Broadcast now'
            : 'Retry broadcast',
      ),
    );
  }
}

class _ProgressStep {
  const _ProgressStep({
    required this.title,
    required this.caption,
    required this.complete,
    required this.current,
  });

  final String title;
  final String caption;
  final bool complete;
  final bool current;
}

class _ProgressTile extends StatelessWidget {
  const _ProgressTile({required this.step});

  final _ProgressStep step;

  @override
  Widget build(BuildContext context) {
    final Color color = step.complete || step.current
        ? AppColors.ink
        : AppColors.line;
    return Semantics(
      label: step.title,
      value: step.complete
          ? 'Complete'
          : step.current
          ? 'In progress'
          : 'Pending',
      hint: step.caption,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: step.complete ? AppColors.emerald : Colors.transparent,
              border: Border.all(color: color, width: 2),
            ),
            child: step.complete
                ? const Icon(Icons.check, size: 10, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  step.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  step.caption,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

ReceiverInvitePayload? _receiverInvitePayload(
  BitsendAppState state,
  TransportKind transport, {
  required bool activeListener,
}) {
  final WalletProfile? wallet = state.wallet;
  if (wallet == null) {
    return null;
  }
  final PendingRelaySession? ultrasonicSession = state.activeUltrasonicSession;
  if (transport == TransportKind.hotspot &&
      (!activeListener || state.localEndpoint == null)) {
    return null;
  }
  if (transport == TransportKind.ultrasonic &&
      (!activeListener || ultrasonicSession == null)) {
    return null;
  }
  return ReceiverInvitePayload(
    chain: state.activeChain,
    network: state.activeNetwork,
    transport: transport,
    address: wallet.address,
    displayAddress: wallet.displayAddress,
    endpoint: transport == TransportKind.hotspot ? state.localEndpoint : null,
    sessionToken: transport == TransportKind.ultrasonic
        ? ultrasonicSession!.sessionToken
        : null,
    relayId: transport == TransportKind.ultrasonic
        ? ultrasonicSession!.relayId
        : null,
  );
}

bool _looksLikeBluetoothDisabled(String message) {
  final String normalized = message.toLowerCase();
  return normalized.contains('bluetooth is turned off') ||
      normalized.contains('bluetooth is still initializing') ||
      normalized.contains('turn it on');
}

bool _looksLikeBluetoothNeedsAttention(String message) {
  final String normalized = message.toLowerCase();
  return _looksLikeBluetoothDisabled(message) ||
      normalized.contains('bluetooth permission is not granted') ||
      normalized.contains('disconnect airpods') ||
      normalized.contains('another bluetooth accessory') ||
      normalized.contains('another accessory or app is already using it') ||
      normalized.contains('bluetooth is busy on this phone') ||
      normalized.contains('bluetooth receive could not start cleanly') ||
      normalized.contains('bluetooth scan could not start cleanly') ||
      normalized.contains('bluetooth low energy is not supported');
}

bool _isValidAddressForChain(String value, ChainKind chain) {
  final String normalized = value.trim();
  return chain == ChainKind.solana
      ? isValidAddress(normalized)
      : RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(normalized);
}

Future<void> _showBluetoothPrompt(BuildContext context, String message) async {
  final String normalized = message.toLowerCase();
  final String title = _looksLikeBluetoothDisabled(message)
      ? 'Turn on Bluetooth'
      : normalized.contains('permission')
      ? 'Allow Bluetooth'
      : normalized.contains('not supported')
      ? 'Bluetooth not supported'
      : 'Bluetooth busy';
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

class _ReceiveStudioCard extends StatelessWidget {
  const _ReceiveStudioCard({
    required this.scrollController,
    required this.transport,
    required this.activeListener,
    required this.hasWallet,
    required this.showUltrasonic,
    required this.invite,
    required this.receiverDisplayAddress,
    required this.receiverAddress,
    required this.endpoint,
    required this.onTransportChanged,
    required this.onToggle,
    required this.onOpenPending,
  });

  final ScrollController scrollController;
  final TransportKind transport;
  final bool activeListener;
  final bool hasWallet;
  final bool showUltrasonic;
  final ReceiverInvitePayload? invite;
  final String receiverDisplayAddress;
  final String receiverAddress;
  final String? endpoint;
  final Future<void> Function(TransportKind value) onTransportChanged;
  final VoidCallback? onToggle;
  final VoidCallback onOpenPending;

  @override
  Widget build(BuildContext context) {
    final String title = !hasWallet
        ? 'Wallet needed before receive'
        : activeListener
        ? 'Ready to catch a handoff'
        : switch (transport) {
            TransportKind.online => 'Open online receive',
            TransportKind.hotspot => 'Open same-network receive',
            TransportKind.ble => 'Open Bluetooth receive',
            TransportKind.ultrasonic => 'Open ultrasonic receive',
          };
    final String caption = !hasWallet
        ? 'Create or restore a wallet first.'
        : switch (transport) {
            TransportKind.online =>
              activeListener
                  ? 'Direct wallet transfers do not need a receive session.'
                  : 'Use online send for direct wallet-to-wallet transfers.',
            TransportKind.hotspot =>
              activeListener
                  ? 'Share the QR code on the same Wi-Fi or hotspot. The sender fills your address and endpoint in one scan.'
                  : 'Start when both phones share the same Wi-Fi or hotspot.',
            TransportKind.ble =>
              activeListener
                  ? 'Keep Bluetooth on and leave this screen open so nearby senders can discover this receiver.'
                  : 'Start when Bluetooth is on and both phones are nearby.',
            TransportKind.ultrasonic =>
              activeListener
                  ? 'Share the QR code to start a direct or browser relay session. The sender gets your address, session token, and relay id in one scan.'
                  : 'Start to mint a fresh ultrasonic session token and relay id.',
          };
    final String helper = switch (transport) {
      TransportKind.online => 'Wallet address only',
      TransportKind.hotspot =>
        endpoint ?? 'Join a local Wi-Fi or hotspot first.',
      TransportKind.ble => 'bitsend BLE receiver',
      TransportKind.ultrasonic =>
        invite?.relayId ??
            'A fresh relay id appears after ultrasonic receive starts.',
    };
    final String helperLabel = switch (transport) {
      TransportKind.online => 'Mode',
      TransportKind.hotspot => 'Endpoint',
      TransportKind.ble => 'Signal',
      TransportKind.ultrasonic => 'Relay ID',
    };
    final bool showEndpointWarning =
        transport == TransportKind.hotspot && endpoint == null;

    return Semantics(
      container: true,
      label: 'Receive setup',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= 620;
          final Widget transportSwitch = SegmentedButton<TransportKind>(
            segments: <ButtonSegment<TransportKind>>[
              const ButtonSegment<TransportKind>(
                value: TransportKind.hotspot,
                label: Text('Hotspot'),
                icon: Icon(Icons.wifi_tethering_rounded),
              ),
              const ButtonSegment<TransportKind>(
                value: TransportKind.ble,
                label: Text('BLE'),
                icon: Icon(Icons.bluetooth_rounded),
              ),
              if (showUltrasonic)
                const ButtonSegment<TransportKind>(
                  value: TransportKind.ultrasonic,
                  label: Text('Ultrasonic'),
                  icon: Icon(Icons.graphic_eq_rounded),
                ),
            ],
            selected: <TransportKind>{transport},
            onSelectionChanged: (Set<TransportKind> value) {
              onTransportChanged(value.first);
            },
          );

          return AnimatedBuilder(
            animation: scrollController,
            builder: (BuildContext context, Widget? child) {
              final double rawOffset = scrollController.hasClients
                  ? scrollController.offset
                  : 0;
              final double collapse = (rawOffset / 220).clamp(0, 1).toDouble();
              final double qrScale = ui.lerpDouble(1, 0.54, collapse)!;
              final double qrOpacity = ui.lerpDouble(1, 0.06, collapse)!;
              final double qrTop = ui.lerpDouble(62, 8, collapse)!;
              final double heroHeight = wide ? 362 : 338;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    height: heroHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        Positioned(
                          top: 28,
                          child: IgnorePointer(
                            child: Container(
                              width: wide ? 340 : 280,
                              height: wide ? 340 : 280,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: <Color>[
                                    _transportTone(transport).withValues(
                                      alpha: activeListener ? 0.16 : 0.1,
                                    ),
                                    AppColors.canvas.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              runSpacing: 10,
                              children: <Widget>[
                                _ReceiveSoftPill(
                                  icon: transport.icon,
                                  label: transport.shortLabel,
                                  color: _transportTone(transport),
                                  background: _transportTone(
                                    transport,
                                  ).withValues(alpha: 0.14),
                                ),
                                _ReceiveSoftPill(
                                  icon: activeListener
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.pause_circle_outline_rounded,
                                  label: activeListener ? 'Live' : 'Standby',
                                  color: activeListener
                                      ? AppColors.emerald
                                      : AppColors.amber,
                                  background:
                                      (activeListener
                                              ? AppColors.emeraldTint
                                              : AppColors.amberTint)
                                          .withValues(alpha: 0.92),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: qrTop,
                          child: Transform.scale(
                            scale: qrScale,
                            alignment: Alignment.topCenter,
                            child: Opacity(
                              opacity: qrOpacity,
                              child: _ReceiveHeroQr(
                                invite: invite,
                                transport: transport,
                                activeListener: activeListener,
                                hasWallet: hasWallet,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.ink.withValues(alpha: 0.06),
                          blurRadius: 26,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Receive',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: transportSwitch),
                            ],
                          )
                        else ...<Widget>[
                          Text(
                            'Receive',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          transportSwitch,
                          const SizedBox(height: 14),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                        const SizedBox(height: 18),
                        Text(
                          caption,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        _ReceiveScene(
                          transport: transport,
                          activeListener: activeListener,
                        ),
                        const SizedBox(height: 18),
                        const _ReceiveSectionDivider(),
                        const SizedBox(height: 18),
                        Text(
                          receiverDisplayAddress,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: AppColors.ink),
                        ),
                        const SizedBox(height: 6),
                        SelectionArea(
                          child: Text(
                            receiverAddress,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.slate, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _ReceiveMetaLine(
                          icon: transport.icon,
                          label: helperLabel,
                          value: helper,
                        ),
                        const SizedBox(height: 8),
                        _ReceiveMetaLine(
                          icon: Icons.rule_rounded,
                          label: 'Check',
                          value:
                              'Only matching signer, receiver, amount, and checksum are stored.',
                        ),
                        if (showEndpointWarning) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            'Connect to the same Wi-Fi or hotspot, then start listening to publish a live local endpoint.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.amber),
                          ),
                        ],
                        const SizedBox(height: 18),
                        const _ReceiveSectionDivider(),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            ElevatedButton.icon(
                              onPressed: onToggle,
                              icon: Icon(
                                activeListener
                                    ? Icons.stop_circle_outlined
                                    : Icons.play_arrow_rounded,
                              ),
                              label: Text(
                                activeListener
                                    ? 'Stop listener'
                                    : 'Start listener',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: onOpenPending,
                              icon: const Icon(Icons.schedule_send_rounded),
                              label: const Text('Open pending'),
                            ),
                            if (invite != null)
                              TextButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(
                                      text: invite!.toPairCodeData(),
                                    ),
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  _showSnack(context, 'QR data copied.');
                                },
                                icon: const Icon(Icons.copy_all_rounded),
                                label: const Text('Copy QR data'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ReceiveHeroQr extends StatelessWidget {
  const _ReceiveHeroQr({
    required this.invite,
    required this.transport,
    required this.activeListener,
    required this.hasWallet,
  });

  final ReceiverInvitePayload? invite;
  final TransportKind transport;
  final bool activeListener;
  final bool hasWallet;

  @override
  Widget build(BuildContext context) {
    final String caption = !hasWallet
        ? 'Set up the wallet first.'
        : invite == null
        ? switch (transport) {
            TransportKind.online =>
              activeListener
                  ? 'Direct sends do not need a QR code.'
                  : 'Choose a nearby method to show a QR code.',
            TransportKind.hotspot =>
              activeListener
                  ? 'Waiting for the local endpoint.'
                  : 'Start hotspot receive to show the live QR code.',
            TransportKind.ble =>
              activeListener
                  ? 'BLE is live. Nearby senders can detect this receiver.'
                  : 'Start BLE receive to show the live QR code.',
            TransportKind.ultrasonic =>
              activeListener
                  ? 'Ultrasonic receive is live. Senders can scan this QR code for direct handoff or browser relay.'
                  : 'Start ultrasonic receive to show the live QR code.',
          }
        : switch (transport) {
            TransportKind.online =>
              'Online send uses the receiver address directly.',
            TransportKind.hotspot => 'Scan to fill address and endpoint.',
            TransportKind.ble => 'Scan to switch the sender into BLE.',
            TransportKind.ultrasonic =>
              'Scan to fill the address, session token, and relay id.',
          };

    return Container(
      width: 292,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(30),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (invite != null)
            QrImageView(
              data: invite!.toQrData(),
              size: 236,
              padding: EdgeInsets.zero,
              semanticsLabel: 'Bitsend QR code',
            )
          else
            Container(
              width: 236,
              height: 236,
              decoration: BoxDecoration(
                color: AppColors.canvasWarm,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                hasWallet
                    ? switch (transport) {
                        TransportKind.online => Icons.public_rounded,
                        TransportKind.hotspot => Icons.wifi_tethering_rounded,
                        TransportKind.ble => Icons.bluetooth_searching_rounded,
                        TransportKind.ultrasonic =>
                          Icons.phonelink_lock_rounded,
                      }
                    : Icons.account_balance_wallet_outlined,
                size: 44,
                color: hasWallet ? _transportTone(transport) : AppColors.slate,
              ),
            ),
          const SizedBox(height: 14),
          Text(
            activeListener ? 'Share QR code' : 'Ready QR code',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ReceiveSoftPill extends StatelessWidget {
  const _ReceiveSoftPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color, height: 1),
          ),
        ],
      ),
    );
  }
}

class _ReceiveScene extends StatelessWidget {
  const _ReceiveScene({required this.transport, required this.activeListener});

  final TransportKind transport;
  final bool activeListener;

  @override
  Widget build(BuildContext context) {
    final Color tone = _transportTone(transport);
    return Row(
      children: <Widget>[
        const _ReceiveSceneNode(
          icon: Icons.send_to_mobile_rounded,
          label: 'Sender',
          emphasized: false,
        ),
        Expanded(
          child: _ReceiveSceneConnector(color: tone, active: activeListener),
        ),
        _ReceiveSceneNode(
          icon: transport.icon,
          label: transport.shortLabel,
          emphasized: true,
          color: tone,
        ),
        Expanded(
          child: _ReceiveSceneConnector(color: tone, active: activeListener),
        ),
        _ReceiveSceneNode(
          icon: Icons.account_balance_wallet_rounded,
          label: 'You',
          emphasized: activeListener,
          color: tone,
        ),
      ],
    );
  }
}

class _ReceiveSceneNode extends StatelessWidget {
  const _ReceiveSceneNode({
    required this.icon,
    required this.label,
    required this.emphasized,
    this.color,
  });

  final IconData icon;
  final String label;
  final bool emphasized;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color foreground = emphasized
        ? (color ?? AppColors.ink)
        : AppColors.slate;
    final Color background = emphasized
        ? foreground.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.64);
    return Column(
      children: <Widget>[
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Icon(icon, color: foreground, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: foreground),
        ),
      ],
    );
  }
}

class _ReceiveSceneConnector extends StatelessWidget {
  const _ReceiveSceneConnector({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            color.withValues(alpha: active ? 0.18 : 0.08),
            color.withValues(alpha: active ? 0.78 : 0.24),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _ReceiveMetaLine extends StatelessWidget {
  const _ReceiveMetaLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 16, color: AppColors.slate),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.ink.withValues(alpha: 0.82),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReceiveSectionDivider extends StatelessWidget {
  const _ReceiveSectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0),
            AppColors.line,
            Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _ScannedQrPayload {
  const _ScannedQrPayload.invite(this.invite) : directTransfer = null;

  const _ScannedQrPayload.direct(this.directTransfer) : invite = null;

  final ReceiverInvitePayload? invite;
  final DirectTransferQrPayload? directTransfer;
}

Future<_ScannedQrPayload?> _scanReceiverInvite(
  BuildContext context, {
  required ChainKind chain,
  required ChainNetwork network,
}) async {
  if (_pairScannerRouteOpen) {
    return null;
  }
  _pairScannerRouteOpen = true;
  try {
    return await Navigator.of(context).push<_ScannedQrPayload>(
      MaterialPageRoute<_ScannedQrPayload>(
        builder: (_) =>
            _ReceiverQrScannerScreen(chain: chain, network: network),
      ),
    );
  } finally {
    _pairScannerRouteOpen = false;
  }
}

Future<String?> _scanRawQrText(
  BuildContext context, {
  String title = 'Scan QR',
  String helper = 'Scan a QR code.',
}) async {
  return Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      builder: (_) => _RawQrScannerScreen(title: title, helper: helper),
    ),
  );
}

class _RawQrScannerScreen extends StatefulWidget {
  const _RawQrScannerScreen({required this.title, required this.helper});

  final String title;
  final String helper;

  @override
  State<_RawQrScannerScreen> createState() => _RawQrScannerScreenState();
}

class _RawQrScannerScreenState extends State<_RawQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );
  bool _handling = false;

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_handling) {
      return;
    }
    for (final Barcode barcode in capture.barcodes) {
      final String raw = (barcode.rawValue ?? '').trim();
      if (raw.isEmpty) {
        continue;
      }
      _handling = true;
      await _controller.stop();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(raw);
      return;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _handleDetection,
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 244,
                height: 244,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 28,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                widget.helper,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiverQrScannerScreen extends StatefulWidget {
  const _ReceiverQrScannerScreen({required this.chain, required this.network});

  final ChainKind chain;
  final ChainNetwork network;

  @override
  State<_ReceiverQrScannerScreen> createState() =>
      _ReceiverQrScannerScreenState();
}

class _ReceiverQrScannerScreenState extends State<_ReceiverQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );

  bool _handling = false;
  String? _error;

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_handling) {
      return;
    }
    for (final Barcode barcode in capture.barcodes) {
      final String raw = (barcode.rawValue ?? '').trim();
      if (raw.isEmpty) {
        continue;
      }
      _handling = true;
      try {
        final ReceiverInvitePayload invite = ReceiverInvitePayload.fromQrData(
          raw,
        );
        await _controller.stop();
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(_ScannedQrPayload.invite(invite));
        return;
      } catch (_) {
        final DirectTransferQrPayload? direct =
            DirectTransferQrPayload.tryParse(
              raw,
              preferredChain: widget.chain,
              preferredNetwork: widget.network,
            );
        if (direct != null) {
          await _controller.stop();
          if (!mounted) {
            return;
          }
          Navigator.of(context).pop(_ScannedQrPayload.direct(direct));
          return;
        }
        if (!mounted) {
          return;
        }
        setState(() {
          _error = 'Scan a Bitsend receive QR or a wallet address QR.';
        });
        _handling = false;
        return;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _handleDetection,
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 244,
                height: 244,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 28,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Scan a QR code',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _error ??
                        'Scan a Bitsend receive QR or a wallet address QR.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _error == null
                          ? Colors.white70
                          : AppColors.amberTint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> _prepareScannedReceiverDraft(
  BitsendAppState state,
  ReceiverInvitePayload invite,
) async {
  await state.setActiveChain(invite.chain);
  await state.setActiveNetwork(invite.network);
  if (state.activeWalletEngine == WalletEngine.bitgo &&
      invite.transport == TransportKind.ultrasonic) {
    throw const FormatException(
      'Ultrasonic is only available in Local wallet mode.',
    );
  }
  state.clearDraft();
  state.setSendTransport(invite.transport);

  if (invite.transport == TransportKind.hotspot) {
    state.updateReceiver(
      receiverAddress: invite.address,
      receiverEndpoint: state.activeWalletEngine == WalletEngine.local
          ? invite.endpoint ?? ''
          : '',
    );
    return true;
  }

  if (invite.transport == TransportKind.ultrasonic) {
    state.updateReceiver(
      receiverAddress: invite.address,
      receiverSessionToken: invite.sessionToken ?? '',
      receiverRelayId: invite.relayId ?? '',
    );
    return true;
  }

  if (state.activeWalletEngine != WalletEngine.local) {
    state.updateReceiver(
      receiverAddress: invite.address,
      receiverPeripheralName: invite.displayAddress,
    );
    return true;
  }

  await state.scanBleReceivers();
  final ReceiverDiscoveryItem? matched = _findMatchingBleReceiver(
    state.bleReceivers,
    invite.address,
  );
  state.updateReceiver(
    receiverAddress: invite.address,
    receiverPeripheralId: matched?.id ?? '',
    receiverPeripheralName: matched?.label ?? invite.displayAddress,
  );
  return matched != null;
}

Future<bool> _prepareScannedDirectTransferDraft(
  BitsendAppState state,
  DirectTransferQrPayload payload,
) async {
  await state.setActiveChain(payload.chain);
  await state.setActiveNetwork(payload.network);
  state.clearDraft();
  state.setSendTransport(TransportKind.online);
  state.updateReceiver(
    receiverAddress: payload.address,
    receiverLabel: payload.label ?? '',
  );
  if (payload.amount != null && payload.amount! > 0) {
    state.updateAmount(payload.amount!);
  }
  return true;
}

ReceiverDiscoveryItem? _findMatchingBleReceiver(
  List<ReceiverDiscoveryItem> receivers,
  String address,
) {
  for (final ReceiverDiscoveryItem item in receivers) {
    if (_addressesMatch(item.resolvedAddress, address)) {
      return item;
    }
  }
  return null;
}

bool _addressesMatch(String left, String right) {
  final String normalizedLeft = left.trim();
  final String normalizedRight = right.trim();
  if (normalizedLeft == normalizedRight) {
    return true;
  }
  if (normalizedLeft.startsWith('0x') && normalizedRight.startsWith('0x')) {
    return normalizedLeft.toLowerCase() == normalizedRight.toLowerCase();
  }
  return false;
}

bool _pairScannerRouteOpen = false;

Color _transportTone(TransportKind transport) => switch (transport) {
  TransportKind.online => AppColors.ink,
  TransportKind.hotspot => AppColors.blue,
  TransportKind.ble => AppColors.emerald,
  TransportKind.ultrasonic => AppColors.amber,
};

Future<void> _scanAndStartSendFromContext(BuildContext context) async {
  final BitsendAppState state = BitsendStateScope.of(context);
  final _ScannedQrPayload? scanned = await _scanReceiverInvite(
    context,
    chain: state.activeChain,
    network: state.activeNetwork,
  );
  if (!context.mounted || scanned == null) {
    return;
  }

  try {
    final bool readyForAmount = scanned.invite != null
        ? await _prepareScannedReceiverDraft(state, scanned.invite!)
        : await _prepareScannedDirectTransferDraft(
            state,
            scanned.directTransfer!,
          );
    if (!context.mounted) {
      return;
    }
    if (readyForAmount) {
      Navigator.of(context).pushNamed(AppRoutes.sendAmount);
      return;
    }
    _showSnack(
      context,
      'Code scanned. Select the nearby Bluetooth receiver to continue.',
    );
    Navigator.of(context).pushNamed(AppRoutes.sendTransport);
  } catch (error) {
    final String message = _messageFor(error);
    if (_looksLikeBluetoothDisabled(message)) {
      await _showBluetoothPrompt(context, message);
      return;
    }
    _showSnack(context, message);
  }
}

void _navigatePrimaryTab(BuildContext context, BitsendPrimaryTab tab) {
  final String route = switch (tab) {
    BitsendPrimaryTab.home => AppRoutes.home,
    BitsendPrimaryTab.assets => AppRoutes.assets,
    BitsendPrimaryTab.deposit => AppRoutes.deposit,
    BitsendPrimaryTab.offline => AppRoutes.prepare,
    BitsendPrimaryTab.pending => AppRoutes.pending,
    BitsendPrimaryTab.settings => AppRoutes.settings,
  };
  final String? currentRoute = ModalRoute.of(context)?.settings.name;
  if (currentRoute == route) {
    return;
  }
  Navigator.of(context).pushReplacementNamed(route);
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

void _showEventToast(
  BuildContext context, {
  required String message,
  required IconData icon,
  bool prominent = false,
}) {
  if (prominent) {
    HapticFeedback.heavyImpact();
  } else {
    HapticFeedback.mediumImpact();
  }
  unawaited(SystemSound.play(SystemSoundType.alert));
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 108),
      duration: const Duration(seconds: 2),
      content: Row(
        children: <Widget>[
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

void _showReceivedTransferToast(
  BuildContext context,
  PendingTransfer? transfer,
) {
  final String message = transfer == null
      ? 'Transfer received.'
      : '${Formatters.transferAmount(transfer)} received over ${transfer.transport.shortLabel}.';
  _showEventToast(
    context,
    message: message,
    icon: Icons.call_received_rounded,
    prominent: true,
  );
}

IconData _iconForReceiveMessage(String message) {
  final String normalized = message.toLowerCase();
  if (normalized.contains('bluetooth')) {
    return Icons.bluetooth_rounded;
  }
  if (normalized.contains('hotspot')) {
    return Icons.wifi_tethering_rounded;
  }
  if (normalized.contains('received')) {
    return Icons.call_received_rounded;
  }
  return Icons.notifications_active_rounded;
}

String _messageFor(Object error) {
  final String text = error.toString();
  if (text.startsWith('HttpException: ')) {
    return text.replaceFirst('HttpException: ', '');
  }
  if (text.startsWith('FormatException: ')) {
    return text.replaceFirst('FormatException: ', '');
  }
  if (text.startsWith('StateError: ')) {
    return text.replaceFirst('StateError: ', '');
  }
  if (text.startsWith('TimeoutException')) {
    final int separator = text.indexOf(': ');
    return separator == -1 ? text : text.substring(separator + 2);
  }
  return text;
}

Future<bool> _authorizeDeviceAction(
  BuildContext context,
  BitsendAppState state, {
  required String reason,
}) async {
  try {
    final bool authorized = await state.authenticateDevice(
      reason: reason,
      forcePrompt: true,
    );
    if (!authorized && context.mounted) {
      _showSnack(context, 'Device authentication was cancelled.');
    }
    return authorized;
  } catch (error) {
    if (context.mounted) {
      _showSnack(context, _messageFor(error));
    }
    return false;
  }
}
