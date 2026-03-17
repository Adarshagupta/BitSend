import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:solana/solana.dart' show isValidAddress;

import '../app/app.dart';
import '../app/theme.dart';
import '../models/app_models.dart';
import '../services/bitsend_pair_camera_service.dart';
import '../services/bitsend_pair_mark_service.dart';
import '../services/transport_contract.dart';
import '../state/app_state.dart';
import '../widgets/app_widgets.dart';
import '../widgets/bitsend_pair_code.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[AppColors.heroStart, AppColors.heroEnd],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(
                    Icons.wifi_protected_setup_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'bitsend',
                  style: Theme.of(
                    context,
                  ).textTheme.displaySmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Offline handoff now. Online settlement later.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 32),
                if (_error == null)
                  const LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _error!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _initialize,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
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
        reason:
            'Unlock Bitsend with your ${state.deviceUnlockMethodLabel}.',
      );
      if (!mounted) {
        return;
      }
      if (unlocked) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
        return;
      }
      setState(() {
        _error = 'Unlock was cancelled. Use your ${state.deviceUnlockMethodLabel} to continue.';
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
    return BitsendPageScaffold(
      title: 'Unlock wallet',
      subtitle: 'Use your ${state.deviceUnlockMethodLabel} before opening Bitsend.',
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
                  state.deviceAuthHasBiometricOption
                      ? Icons.fingerprint_rounded
                      : Icons.lock_rounded,
                  size: 32,
                  color: AppColors.ink,
                ),
                const SizedBox(height: 16),
                Text(
                  'Security check',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Bitsend will ask for your ${state.deviceUnlockMethodLabel} before showing wallet data on this device.',
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
      bottom: ElevatedButton(
        onPressed: _unlocking ? null : _unlock,
        child: Text(
          _unlocking
              ? 'Checking ${state.deviceUnlockMethodLabel}...'
              : 'Unlock now',
        ),
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
                                      ? 'Save the backup file now. It includes the recovery phrase plus both derived private keys.'
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
                            'Derived wallet unavailable',
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
                        'This phrase restores both the main and offline wallets.',
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
    return BitsendPageScaffold(
      title: 'Offline wallet',
      subtitle:
          'A second ${chain.shortLabel} wallet is derived automatically. Top it up from Home before any offline send.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionCard(
            child: Column(
              children: <Widget>[
                MetricCard(
                  label: 'Main wallet balance',
                  value: Formatters.asset(summary.balanceSol, chain),
                  caption: 'Source balance for later top-ups.',
                ),
                const SizedBox(height: 12),
                MetricCard(
                  label: 'Offline wallet',
                  value: summary.offlineWalletAddress == null
                      ? 'Unavailable'
                      : Formatters.shortAddress(summary.offlineWalletAddress!),
                  caption: 'Derived from the same recovery phrase.',
                ),
                const SizedBox(height: 12),
                MetricCard(
                  label: 'Offline wallet balance',
                  value: Formatters.asset(summary.offlineBalanceSol, chain),
                  caption: 'Move funds here before any offline send.',
                ),
                const SizedBox(height: 12),
                MetricCard(
                  label: 'Local endpoint',
                  value: summary.localEndpoint ?? 'Not available yet',
                  caption:
                      'The receiver shares this while listening on hotspot.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InlineBanner(
            title: 'Permissions',
            caption: state.localPermissionsGranted
                ? 'Local transport access is already granted.'
                : 'Android needs location and nearby-device access for local transport.',
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

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  bool _switchingScope = false;
  String _switchingLabel = '';

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

  Future<void> _scanAndStartSend(BitsendAppState state) async {
    final ReceiverInvitePayload? invite = await _scanReceiverInvite(context);
    if (!mounted || invite == null) {
      return;
    }

    try {
      final bool readyForAmount = await _prepareScannedReceiverDraft(
        state,
        invite,
      );
      if (!mounted) {
        return;
      }
      if (readyForAmount) {
        Navigator.of(context).pushNamed(AppRoutes.sendAmount);
        return;
      }
      _showSnack(
        context,
        'Pair code scanned. Select the nearby BLE receiver to continue.',
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

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final HomeStatus status = state.homeStatus;
    final WalletSummary summary = state.walletSummary;
    final List<PendingTransfer> recent = state.recentActivity();
    final ChainNetwork network = state.activeNetwork;
    final String scopeKey =
        '${state.activeChain.name}:${network.name}:${state.activeWalletEngine.name}';
    final bool canSend =
        state.hasWallet &&
        (state.activeWalletEngine == WalletEngine.local
            ? state.hasOfflineFunds && state.hasOfflineReadyBlockhash
            : state.hasInternet);
    final String sendRoute = state.hasWallet
        ? AppRoutes.sendTransport
        : AppRoutes.prepare;
    final bool usingBitGo = state.activeWalletEngine == WalletEngine.bitgo;
    final bool mainWalletCanFundOffline =
        !usingBitGo && state.hasEnoughFunding && !state.hasOfflineFunds;
    final bool offlineFundsReserved =
        !usingBitGo &&
        !state.hasOfflineFunds &&
        summary.offlineBalanceSol > 0 &&
        summary.offlineAvailableSol <= 0;
    final String sendCaption = !state.hasWallet
        ? 'Set up wallet'
        : usingBitGo && !state.hasInternet
        ? 'Go online'
        : usingBitGo && !state.bitgoBackendIsLive
        ? 'Auto-fallback'
        : usingBitGo
        ? 'Send online'
        : canSend
        ? 'Handoff'
        : offlineFundsReserved
        ? 'Funds reserved'
        : mainWalletCanFundOffline && !state.hasOfflineReadyBlockhash
        ? 'Move + refresh'
        : mainWalletCanFundOffline
        ? 'Move offline'
        : !state.hasOfflineFunds && !state.hasOfflineReadyBlockhash
        ? 'Fund + refresh'
        : !state.hasOfflineFunds
        ? 'Fund main wallet'
        : 'Refresh readiness';
    final String supportStatus = !state.hasWallet
        ? 'Set up wallet to start.'
        : usingBitGo && !state.hasInternet
        ? 'BitGo mode needs internet before submit.'
        : usingBitGo && !state.bitgoBackendIsLive
        ? 'BitGo backend is not live. Send will fall back to Local mode.'
        : usingBitGo
        ? 'BitGo wallet is ready for online submit.'
        : canSend
        ? 'Offline wallet is ready.'
        : offlineFundsReserved
        ? 'Offline wallet balance exists, but it is fully reserved by pending transfers on this chain and network.'
        : mainWalletCanFundOffline && !state.hasOfflineReadyBlockhash
        ? 'Main wallet is funded. Move funds to the offline wallet and refresh readiness before send.'
        : mainWalletCanFundOffline
        ? 'Main wallet is funded. Move funds to the offline wallet before send.'
        : !state.hasOfflineFunds && !state.hasOfflineReadyBlockhash
        ? 'Fund the main wallet, then move some funds to the offline wallet and refresh readiness before send.'
        : !state.hasOfflineFunds
        ? 'Fund the main wallet, then move some funds to the offline wallet before send.'
        : 'Refresh readiness before send.';

    return BitsendPageScaffold(
      title: 'bitsend',
      header: _HomeScopeHeader(
        chain: state.activeChain,
        network: network,
        walletEngine: state.activeWalletEngine,
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
      ),
      overlay: _HomeDashboardOverlay(
        switchingLabel: _switchingScope ? _switchingLabel : null,
        onScan:
            state.hasWallet && !_switchingScope && !state.working
                ? () => _scanAndStartSend(state)
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  StatusRailChip(
                    label: 'Internet',
                    active: status.hasInternet,
                    icon: Icons.language_rounded,
                  ),
                  StatusRailChip(
                    label: state.activeWalletEngine.label,
                    active: state.activeWalletEngine == WalletEngine.bitgo
                        ? status.hasInternet
                        : true,
                    icon: state.activeWalletEngine == WalletEngine.bitgo
                        ? Icons.shield_outlined
                        : Icons.offline_bolt_rounded,
                  ),
                  StatusRailChip(
                    label: 'Local link',
                    active: status.hasLocalLink,
                    icon: Icons.wifi_tethering_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FadeSlideIn(delay: 0, child: _DashboardHero(summary: summary)),
              const SizedBox(height: 14),
              FadeSlideIn(
                delay: 40,
                child: _HomeHeroActions(
                  sendCaption: sendCaption,
                  statusText: supportStatus,
                  onSend: () {
                    Navigator.of(context).pushNamed(sendRoute);
                  },
                  onReceive: state.hasWallet
                      ? () {
                          Navigator.of(
                            context,
                          ).pushNamed(AppRoutes.receiveListen);
                        }
                      : null,
                  onFund: () {
                    Navigator.of(context).pushNamed(AppRoutes.prepare);
                  },
                  onRefresh: state.working || _switchingScope
                      ? null
                      : () {
                          _refreshHome(context, state);
                        },
                ),
              ),
              const SizedBox(height: 20),
              Text('More', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              Column(
                children: <Widget>[
                  FadeSlideIn(
                    delay: 100,
                    child: ActionTile(
                      title: 'Deposit',
                      caption: 'Receive ${state.activeChain.shortLabel}',
                      icon: Icons.south_west_rounded,
                      onTap: () {
                        Navigator.of(context).pushNamed(AppRoutes.deposit);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    delay: 120,
                    child: ActionTile(
                      title: usingBitGo ? 'BitGo Wallet' : 'Offline Wallet',
                      caption: sendCaption,
                      icon: Icons.account_balance_wallet_outlined,
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          usingBitGo ? AppRoutes.deposit : AppRoutes.prepare,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    delay: 160,
                    child: ActionTile(
                      title: 'Pending',
                      caption: 'Queue',
                      icon: Icons.schedule_send_rounded,
                      enabled: true,
                      onTap: () {
                        Navigator.of(context).pushNamed(AppRoutes.pending);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Queue', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              if (recent.isEmpty)
                const EmptyStateCard(
                  title: 'No transfers yet',
                  caption: 'Your queue will show up here.',
                  icon: Icons.receipt_long_rounded,
                )
              else
                Column(
                  children: recent
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
        if (switchingLabel != null)
          _ScopeSwitchOverlay(label: switchingLabel!),
        if (onScan != null)
          Positioned(
            right: 20,
            bottom: 102,
            child: SafeArea(
              top: false,
              child: _HomeScanShortcutButton(onPressed: onScan!),
            ),
          ),
      ],
    );
  }
}

class _HomeScanShortcutButton extends StatelessWidget {
  const _HomeScanShortcutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Scan pair code and send',
      child: Semantics(
        button: true,
        label: 'Scan pair code and send',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Ink(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[AppColors.blue, AppColors.emerald],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.92),
                  width: 2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.18),
                    blurRadius: 28,
                    spreadRadius: -6,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _DepositTarget { main, offline }

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen>
    with WidgetsBindingObserver {
  _DepositTarget _target = _DepositTarget.main;
  bool _didAutoRefresh = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
        toOfflineWallet: _target == _DepositTarget.offline,
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
        : _target == _DepositTarget.main
        ? state.wallet
        : state.offlineWallet;
    final String title = usingBitGo
        ? 'BitGo wallet'
        : _target == _DepositTarget.main
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
        : _target == _DepositTarget.main
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!usingBitGo) ...<Widget>[
            SegmentedButton<_DepositTarget>(
              segments: const <ButtonSegment<_DepositTarget>>[
                ButtonSegment<_DepositTarget>(
                  value: _DepositTarget.main,
                  label: Text('Main'),
                  icon: Icon(Icons.account_balance_wallet_rounded),
                ),
                ButtonSegment<_DepositTarget>(
                  value: _DepositTarget.offline,
                  label: Text('Offline'),
                  icon: Icon(Icons.lock_clock_rounded),
                ),
              ],
              selected: <_DepositTarget>{_target},
              onSelectionChanged: (Set<_DepositTarget> value) {
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
                : _target == _DepositTarget.main
                ? network.shortLabelFor(chain)
                : state.hasOfflineReadyBlockhash
                ? 'Ready'
                : 'Needs refresh',
            statusIcon: usingBitGo
                ? Icons.shield_outlined
                : _target == _DepositTarget.main
                ? Icons.cloud_done_rounded
                : state.hasOfflineReadyBlockhash
                ? Icons.check_circle_outline_rounded
                : Icons.update_rounded,
            statusActive:
                usingBitGo ||
                _target == _DepositTarget.main ||
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

  @override
  void initState() {
    super.initState();
    _topUpController = TextEditingController();
  }

  @override
  void dispose() {
    _topUpController.dispose();
    super.dispose();
  }

  void _applyTopUpPreset(String value) {
    _topUpController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Future<void> _topUp(BitsendAppState state) async {
    final double amount = double.tryParse(_topUpController.text.trim()) ?? 0;
    try {
      await state.topUpOfflineWallet(amount);
      if (!mounted) {
        return;
      }
      _showSnack(context, 'Offline wallet funded.');
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

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final WalletSummary summary = state.walletSummary;
    final ChainKind chain = state.activeChain;
    final bool usingBitGo = state.activeWalletEngine == WalletEngine.bitgo;
    final String mainBalance = Formatters.asset(summary.balanceSol, chain);
    final String offlineBalance = Formatters.asset(
      summary.offlineBalanceSol,
      chain,
    );
    final String spendableBalance = Formatters.asset(
      summary.offlineAvailableSol,
      chain,
    );
    final String mainAddress =
        state.wallet?.displayAddress ?? 'Main unavailable';
    final String offlineAddress = summary.offlineWalletAddress == null
        ? 'Offline unavailable'
        : Formatters.shortAddress(summary.offlineWalletAddress!);
    return BitsendPageScaffold(
      title: usingBitGo ? 'BitGo Wallet' : 'Offline Wallet',
      subtitle: usingBitGo
          ? 'BitGo mode is online-only. Manage the backend wallet here.'
          : 'Fund and refresh before handoff.',
      onRefresh: state.working ? null : state.refreshStatus,
      bottom: usingBitGo
          ? null
          : _OfflineBottomActions(
              working: state.working,
              statusMessage: state.statusMessage,
              readyForOffline: summary.readyForOffline,
              onTopUp: () => _topUp(state),
              onRefreshReadiness: () => _refreshReadiness(state),
            ),
      showBack: false,
      primaryTab: BitsendPrimaryTab.offline,
      onPrimaryTabSelected: (BitsendPrimaryTab tab) {
        _navigatePrimaryTab(context, tab);
      },
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
                  DetailRow(label: 'Balance', value: mainBalance),
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
                    mainBalance: mainBalance,
                    offlineBalance: offlineBalance,
                    spendableBalance: spendableBalance,
                    mainAddress: mainAddress,
                    offlineAddress: offlineAddress,
                    readyForOffline: summary.readyForOffline,
                  ),
                ),
                const SizedBox(height: 14),
                FadeSlideIn(
                  delay: 40,
                  child: _OfflineMetricStrip(
                    mainBalance: mainBalance,
                    offlineBalance: offlineBalance,
                  ),
                ),
                const SizedBox(height: 14),
                FadeSlideIn(
                  delay: 80,
                  child: _OfflineActionComposer(
                    chain: chain,
                    mainBalance: mainBalance,
                    controller: _topUpController,
                    onPresetSelected: _applyTopUpPreset,
                  ),
                ),
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
    _resolvedReceiverLabel = showReceiverLabel ? state.sendDraft.receiverLabel : null;
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
      _showSnack(
        context,
        'Scan the receiver pair code before continuing.',
      );
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
            : 'Scan the receiver pair code before continuing.',
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
      if (_looksLikeBluetoothDisabled(message)) {
        await _showBluetoothPrompt(context, message);
        return;
      }
      _showSnack(context, message);
    }
  }

  Future<void> _scanReceiverQr(BitsendAppState state) async {
    final ReceiverInvitePayload? invite = await _scanReceiverInvite(context);
    if (!mounted || invite == null) {
      return;
    }

    try {
      final bool readyForAmount = await _prepareScannedReceiverDraft(
        state,
        invite,
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
          invite.transport == TransportKind.ble &&
          state.activeWalletEngine == WalletEngine.local) {
      _showSnack(
        context,
        'Pair code scanned. Select the nearby BLE receiver to continue.',
      );
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

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final TransportKind transport = state.sendDraft.transport;
    final bool usingBitGo = state.activeWalletEngine == WalletEngine.bitgo;
    final bool showUltrasonic = !usingBitGo && state.ultrasonicSupported;
    return BitsendPageScaffold(
      title: 'Choose receiver',
      subtitle: usingBitGo
          ? 'Pick a discovery method, then enter the destination address for BitGo submit.'
          : 'Pick the handoff method, then enter the receiver details.',
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
          SegmentedButton<TransportKind>(
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
                  label: Text('Bitsend Pair'),
                  icon: Icon(Icons.phonelink_lock_rounded),
                ),
            ],
            selected: <TransportKind>{transport},
            onSelectionChanged: (Set<TransportKind> value) {
              state.setSendTransport(value.first);
              setState(() {
                _selectedBleReceiverId = null;
                _selectedBleReceiverName = null;
                if (value.first == TransportKind.ble) {
                  _autoScannedBle = true;
                }
              });
              if (value.first == TransportKind.ble &&
                  state.bleReceivers.isEmpty) {
                _scanBleReceivers(state);
              }
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _scanReceiverQr(state),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Scan pair code'),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Receiver address',
                  style: Theme.of(context).textTheme.titleMedium,
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
                if (state.activeChain.isEvm) ...<Widget>[
                  const SizedBox(height: 10),
                  InlineBanner(
                    title: _resolvedReceiverAddress == null
                        ? 'ENS supported'
                        : 'ENS resolved',
                    caption: _resolvedReceiverAddress == null
                        ? 'You can paste a .eth name here. The app resolves it before signing.'
                        : '${_resolvedReceiverLabel!} -> ${Formatters.shortAddress(_resolvedReceiverAddress!)}',
                    icon: _resolvedReceiverAddress == null
                        ? Icons.alternate_email_rounded
                        : Icons.verified_rounded,
                  ),
                  if (_resolvedReceiverPreference?.hasPreference ==
                      true) ...<Widget>[
                    const SizedBox(height: 10),
                    InlineBanner(
                      title: 'ENS payment preference',
                      caption:
                          '${_resolvedReceiverPreference!.ensName} prefers ${_resolvedReceiverPreference!.summary}. This is advisory routing info from ENS text records.',
                      icon: Icons.tune_rounded,
                    ),
                  ],
                ],
                if (transport == TransportKind.ultrasonic) ...<Widget>[
                  const SizedBox(height: 18),
                  const InlineBanner(
                    title: 'Pair code required',
                    caption:
                        'Bitsend Pair is bootstrapped through the receiver pair code. Scan the pair code to fill the address, session token, and relay id before continuing.',
                    icon: Icons.phonelink_lock_rounded,
                  ),
                ] else if (usingBitGo &&
                    transport == TransportKind.hotspot) ...<Widget>[
                  const SizedBox(height: 18),
                  const InlineBanner(
                    title: 'Endpoint not needed',
                    caption:
                        'In BitGo mode, the hotspot pair code only prefills the receiver address. Submission happens online through the backend.',
                    icon: Icons.cloud_sync_rounded,
                  ),
                ] else if (transport == TransportKind.hotspot) ...<Widget>[
                  const SizedBox(height: 18),
                  Text(
                    'Receiver endpoint',
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
                ] else ...<Widget>[
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Nearby BLE receivers',
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
                    const InlineBanner(
                      title: 'No receiver selected',
                      caption:
                          'Open Receive on the other device, switch to BLE, and keep both phones nearby. Verified wallets rise to the top.',
                      icon: Icons.bluetooth_searching_rounded,
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
    if (!state.hasWallet || !state.hasOfflineWallet) {
      return 'Set up the wallet first.';
    }
    if (!state.hasOfflineFunds) {
      if (state.offlineBalanceSol > 0 && state.offlineSpendableBalanceSol <= 0) {
        return 'Offline wallet funds are fully reserved by pending transfers on this chain and network.';
      }
      return 'Top up the offline wallet first.';
    }
    if (!state.hasOfflineReadyBlockhash && !state.hasInternet) {
      return 'Connect online and refresh readiness before signing.';
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
    final double amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final int baseUnits = chain.amountToBaseUnits(amount);
    final String? readinessMessage = _sendReadinessMessage(state);
    final String? amountLimitMessage = amount > 0 && readinessMessage == null
        ? state.validateSendAmount(amount)
        : null;
    final bool autoRefreshOnSign =
        state.activeWalletEngine == WalletEngine.local &&
        state.hasOfflineFunds &&
        !state.hasOfflineReadyBlockhash &&
        state.hasInternet;
    final bool usingBitGo = state.activeWalletEngine == WalletEngine.bitgo;
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
              title: 'Finish offline prep',
              caption: readinessMessage,
              icon: Icons.lock_clock_rounded,
              action: OutlinedButton(
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
                  decoration: InputDecoration(
                    labelText: 'Amount in ${chain.shortLabel}',
                    hintText: chain == ChainKind.solana ? '0.250' : '0.010',
                  ),
                  onChanged: (_) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 16),
                DetailRow(
                  label: 'Base units',
                  value: Formatters.baseUnits(baseUnits, chain),
                ),
                DetailRow(
                  label: usingBitGo
                      ? 'BitGo wallet available'
                      : 'Spendable now',
                  value: Formatters.asset(
                    usingBitGo
                        ? state.mainBalanceSol
                        : summary.offlineAvailableSol,
                    chain,
                  ),
                ),
                if (!usingBitGo)
                  DetailRow(
                    label: 'Offline wallet total',
                    value: Formatters.asset(summary.offlineBalanceSol, chain),
                  ),
                if (!usingBitGo)
                  DetailRow(
                    label: 'Reserved by pending',
                    value: Formatters.asset(reservedOfflineBalance, chain),
                  ),
                if (!usingBitGo)
                  DetailRow(
                    label: 'Fee buffer',
                    value: Formatters.asset(
                      state.estimatedSendFeeHeadroomSol,
                      chain,
                    ),
                  ),
                if (!usingBitGo)
                  DetailRow(
                    label: 'Max send now',
                    value: Formatters.asset(state.maxSendAmountSol, chain),
                  ),
                DetailRow(
                  label: usingBitGo ? 'Source wallet' : 'Offline wallet',
                  value: usingBitGo
                      ? (state.bitgoWallet?.displayLabel ??
                            state.bitgoWallet?.address ??
                            'Unavailable')
                      : (state.offlineWallet?.displayAddress ?? 'Unavailable'),
                ),
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
    final bool usingBitGo = draft.walletEngine == WalletEngine.bitgo;
    final String? amountLimitMessage = state.validateSendAmount(draft.amountSol);
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
          : 'Check the receiver, amount, and transport before signing.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InlineBanner(
            title: usingBitGo ? 'How submit works' : 'When funds move',
            caption: usingBitGo
                ? 'This transfer is sent online through the BitGo backend. BLE or hotspot only helps capture the receiver details.'
                : 'The receiver gets a signed transaction now. Settlement happens after broadcast.',
            icon: usingBitGo
                ? Icons.shield_outlined
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
                      : (state.offlineWallet?.displayAddress ??
                            'Offline wallet unavailable'),
                ),
                DetailRow(
                  label: usingBitGo
                      ? 'Discovery'
                      : draft.transport == TransportKind.hotspot
                      ? 'Endpoint'
                      : draft.transport == TransportKind.ble
                      ? 'BLE receiver'
                      : 'Session',
                  value: usingBitGo
                      ? draft.transport.label
                      : draft.transport == TransportKind.hotspot
                      ? draft.receiverEndpoint
                      : draft.transport == TransportKind.ble
                      ? draft.receiverPeripheralName
                      : draft.receiverRelayId,
                ),
                DetailRow(
                  label: 'Amount',
                  value: Formatters.asset(draft.amountSol, chain),
                ),
                DetailRow(
                  label: usingBitGo
                      ? 'BitGo balance left'
                      : 'Offline balance left',
                  value: Formatters.asset(
                    (usingBitGo
                                ? summary.balanceSol
                                : summary.offlineAvailableSol) >
                            draft.amountSol
                        ? (usingBitGo
                                  ? summary.balanceSol
                                  : summary.offlineAvailableSol) -
                              draft.amountSol
                        : 0,
                    chain,
                  ),
                ),
                if (!usingBitGo)
                  DetailRow(
                    label: 'Readiness age',
                    value: Formatters.durationLabel(summary.blockhashAge),
                  ),
                DetailRow(label: 'Chain', value: draft.network.labelFor(chain)),
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
                          Navigator.of(context).pushNamed(AppRoutes.sendProgress);
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
              child: Text(usingBitGo ? 'Submit with BitGo' : 'Sign and send'),
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
      final PreparedRelayCapsule prepared =
          await state.prepareRelayCapsuleForCurrentDraft();
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
                    child: BitsendPairCodeView(
                      data: prepared.relayUrl.toString(),
                      size: 220,
                      semanticsLabel: 'Browser courier link',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const InlineBanner(
                    title: 'Courier link ready',
                    caption:
                        'Copy this encrypted courier link to any browser-capable phone. The relay path is link-only in this build, with no QR shown.',
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
                    value: Formatters.asset(
                      prepared.transfer.amountSol,
                      prepared.transfer.chain,
                    ),
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
                    Navigator.of(context).pushReplacementNamed(
                      AppRoutes.sendSuccess,
                    );
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
                  : 'The signed envelope is sent over the Bitsend Pair session.',
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
        await Future<void>.delayed(
          Duration(seconds: attempt == 0 ? 3 : 5),
        );
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
    return BitsendPageScaffold(
      title: usingBitGo ? 'Submitted' : 'Delivered',
      subtitle: usingBitGo
          ? 'The transfer was submitted through BitGo and will keep syncing in Pending.'
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
              eyebrow: usingBitGo ? 'BitGo receipt' : 'Delivery receipt',
              title: usingBitGo ? 'Submitted with BitGo' : 'Sent offline',
              caption: usingBitGo
                  ? 'BitGo accepted the transfer. Confirmation will continue automatically while the app is online.'
                  : 'Receiver stored the signed transfer. Settlement can continue automatically when any device is online.',
              icon: usingBitGo
                  ? Icons.shield_outlined
                  : Icons.check_circle_rounded,
              tone: usingBitGo ? AppColors.blue : AppColors.emerald,
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
                if (_savingToFileverse && _fileverseProgressText != null) ...<
                  Widget
                >[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _fileverseProgressText!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.slate,
                      ),
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
          _looksLikeBluetoothDisabled(message)) {
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
          _looksLikeBluetoothDisabled(message)) {
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
          ? 'BitGo mode does not listen offline. Switch back to Local mode to receive over hotspot, BLE, or Bitsend Pair.'
          : 'Catch a signed handoff over hotspot, BLE, or Bitsend Pair.',
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
                  'Switch back to Local mode from the header to receive over hotspot, BLE, or Bitsend Pair.',
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
        await Future<void>.delayed(
          Duration(seconds: attempt == 0 ? 3 : 5),
        );
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
                if (_savingToFileverse && _fileverseProgressText != null) ...<
                  Widget
                >[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _fileverseProgressText!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.slate,
                      ),
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
                Formatters.asset(transfer.amountSol, transfer.chain),
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
      subtitle: 'Track offline handoffs and broadcast status.',
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
                  value: Formatters.asset(transfer.amountSol, transfer.chain),
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
  late final TextEditingController _ensNameController;
  late final TextEditingController _ensChainController;
  late final TextEditingController _ensTokenController;
  String? _backupPath;
  EnsPaymentPreference? _loadedEnsPreference;
  bool _recoveryPhraseVisible = false;

  @override
  void initState() {
    super.initState();
    _rpcController = TextEditingController();
    _bitgoController = TextEditingController();
    _ensNameController = TextEditingController();
    _ensChainController = TextEditingController();
    _ensTokenController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rpcController.text = BitsendStateScope.of(context).rpcEndpoint;
    _bitgoController.text = BitsendStateScope.of(context).bitgoEndpoint;
  }

  @override
  void dispose() {
    _rpcController.dispose();
    _bitgoController.dispose();
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
    };
    return BitsendPageScaffold(
      title: 'Settings',
      subtitle: 'Recovery phrase, RPC, permissions, and reset.',
      showBack: false,
      primaryTab: BitsendPrimaryTab.settings,
      onPrimaryTabSelected: (BitsendPrimaryTab tab) {
        _navigatePrimaryTab(context, tab);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Recovery phrase',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (state.wallet == null)
                  const Text('Wallet not created yet.')
                else if (!hideRecoveryPhrase)
                  SelectableText(
                    state.wallet!.seedPhrase,
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  Text(
                    'Use your ${state.deviceUnlockMethodLabel} to reveal the recovery phrase on this device.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                const SizedBox(height: 12),
                Text(
                  state.offlineWallet == null
                      ? 'Offline wallet unavailable.'
                      : 'Offline wallet ${state.offlineWallet!.displayAddress} is derived from this phrase.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    OutlinedButton(
                      onPressed: state.wallet == null || !hideRecoveryPhrase
                          ? null
                          : () => _revealRecoveryPhrase(state),
                      child: Text(
                        hideRecoveryPhrase
                            ? 'Reveal phrase'
                            : 'Phrase unlocked',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: state.wallet == null
                          ? null
                          : () => _copyPhrase(state),
                      child: const Text('Copy phrase'),
                    ),
                    ElevatedButton(
                      onPressed: state.wallet == null || state.working
                          ? null
                          : () => _exportBackup(state),
                      child: const Text('Download backup'),
                    ),
                  ],
                ),
                if (_backupPath != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    'Latest backup',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _backupPath!,
                    style: Theme.of(context).textTheme.bodySmall,
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
                  'ENS payment preference',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Use ENS text records to publish which chain and token you prefer for payments. Bitsend reads these records as routing hints; writes happen on Ethereum mainnet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
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
                    OutlinedButton(
                      onPressed: state.working
                          ? null
                          : () => _readEnsPreference(state),
                      child: const Text('Read ENS'),
                    ),
                    ElevatedButton(
                      onPressed: state.working
                          ? null
                          : () => _saveEnsPreference(state),
                      child: const Text('Save to ENS'),
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
                  DetailRow(
                    label: 'Loaded preference',
                    value: _loadedEnsPreference!.hasPreference
                        ? _loadedEnsPreference!.summary
                        : 'No Bitsend ENS preference set',
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
                  'BitGo backend',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bitgoController,
                  decoration: const InputDecoration(
                    hintText: defaultBitGoBackendEndpoint,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Use your laptop or backend host address here. Physical devices cannot reach localhost on the phone itself.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    ElevatedButton(
                      onPressed: () => _saveBitGo(state),
                      child: const Text('Save BitGo endpoint'),
                    ),
                    OutlinedButton(
                      onPressed: state.working
                          ? null
                          : () => _connectBitGo(state),
                      child: const Text('Connect BitGo'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DetailRow(
                  label: 'Backend mode',
                  value: state.bitgoBackendMode.label,
                ),
                if (state.bitgoWallet != null) ...<Widget>[
                  const SizedBox(height: 16),
                  DetailRow(
                    label: 'Wallet',
                    value: state.bitgoWallet!.displayLabel,
                  ),
                  DetailRow(
                    label: 'Address',
                    value: state.bitgoWallet!.address,
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
                  'RPC endpoint',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rpcController,
                  decoration: InputDecoration(hintText: defaultRpcHint),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _saveRpc(state),
                  child: const Text('Save RPC'),
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
                  'Permissions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  state.localPermissionsGranted
                      ? 'Local transport access granted.'
                      : 'Local transport access still needs approval.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: state.requestLocalPermissions,
                  child: const Text('Request access'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const InlineBanner(
            title: 'Reset',
            caption:
                'Clearing local data removes the wallet, queue, cached readiness data, and saved RPC settings from this device.',
            icon: Icons.delete_outline_rounded,
          ),
        ],
      ),
      bottom: OutlinedButton(
        onPressed: () => _clearAll(state),
        child: const Text('Clear local data'),
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
    required this.switching,
    required this.onChainChanged,
    required this.onNetworkChanged,
    required this.onWalletEngineChanged,
  });

  final ChainKind chain;
  final ChainNetwork network;
  final WalletEngine walletEngine;
  final bool switching;
  final ValueChanged<ChainKind> onChainChanged;
  final ValueChanged<ChainNetwork> onNetworkChanged;
  final ValueChanged<WalletEngine> onWalletEngineChanged;

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
    final bool switching = widget.switching;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
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
                      'bitsend',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(letterSpacing: -0.4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chain / mode / network',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _toggleExpanded,
                      borderRadius: BorderRadius.circular(999),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
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
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AppColors.ink.withValues(alpha: 0.05),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(chain.icon, size: 16, color: AppColors.ink),
                            const SizedBox(width: 8),
                            Flexible(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: Text(
                                  '${chain.networkLabelFor(network)} · ${walletEngine.walletLabel}',
                                  key: ValueKey<String>(
                                    '${walletEngine.name}:${chain.name}:${network.name}',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedRotation(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              turns: _expanded ? 0.5 : 0,
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: switching
                                    ? AppColors.mutedInk
                                    : AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                          items: const <_ScopeToggleItem<ChainKind>>[
                            _ScopeToggleItem<ChainKind>(
                              value: ChainKind.solana,
                              label: 'Solana',
                              icon: Icons.blur_circular_rounded,
                            ),
                            _ScopeToggleItem<ChainKind>(
                              value: ChainKind.ethereum,
                              label: 'Ethereum',
                              icon: Icons.diamond_rounded,
                            ),
                            _ScopeToggleItem<ChainKind>(
                              value: ChainKind.base,
                              label: 'Base',
                              icon: Icons.layers_rounded,
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
                              icon: Icons.offline_bolt_rounded,
                            ),
                            _ScopeToggleItem<WalletEngine>(
                              value: WalletEngine.bitgo,
                              label: 'BitGo',
                              icon: Icons.shield_outlined,
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
                              label: chain == ChainKind.solana
                                  ? 'Devnet'
                                  : 'Sepolia',
                              icon: Icons.science_rounded,
                            ),
                            const _ScopeToggleItem<ChainNetwork>(
                              value: ChainNetwork.mainnet,
                              label: 'Mainnet',
                              icon: Icons.public_rounded,
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
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
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
                Icon(
                  item.icon,
                  size: 18,
                  color: selected ? Colors.white : AppColors.ink,
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
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                    const SizedBox(height: 14),
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

class _HomeHeroActions extends StatelessWidget {
  const _HomeHeroActions({
    required this.sendCaption,
    required this.statusText,
    required this.onSend,
    required this.onReceive,
    required this.onFund,
    required this.onRefresh,
  });

  final String sendCaption;
  final String statusText;
  final VoidCallback onSend;
  final VoidCallback? onReceive;
  final VoidCallback onFund;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _HomePrimaryActionButton(
                label: 'Send',
                icon: Icons.send_rounded,
                onPressed: onSend,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HomePrimaryActionButton(
                label: 'Receive',
                icon: Icons.call_received_rounded,
                onPressed: onReceive,
                outlined: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: _HomeUtilityActionButton(
                label: 'Fund',
                icon: Icons.account_balance_wallet_outlined,
                onPressed: onFund,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HomeUtilityActionButton(
                label: 'Refresh',
                icon: Icons.refresh_rounded,
                onPressed: onRefresh,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _HomeStatusLine(
          caption: statusText,
          tone: sendCaption == 'Handoff' ? AppColors.emerald : AppColors.amber,
        ),
      ],
    );
  }
}

class _HomePrimaryActionButton extends StatelessWidget {
  const _HomePrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = outlined
        ? OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          )
        : ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          );

    final Widget child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(label),
      ],
    );

    return outlined
        ? OutlinedButton(onPressed: onPressed, style: style, child: child)
        : ElevatedButton(onPressed: onPressed, style: style, child: child);
  }
}

class _HomeUtilityActionButton extends StatelessWidget {
  const _HomeUtilityActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(42),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        backgroundColor: Colors.white.withValues(alpha: 0.36),
        textStyle: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _HomeStatusLine extends StatelessWidget {
  const _HomeStatusLine({required this.caption, required this.tone});

  final String caption;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: caption,
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              caption,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.ink.withValues(alpha: 0.78),
              ),
            ),
          ),
        ],
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
    required this.mainBalance,
    required this.offlineBalance,
    required this.spendableBalance,
    required this.mainAddress,
    required this.offlineAddress,
    required this.readyForOffline,
  });

  final String mainBalance;
  final String offlineBalance;
  final String spendableBalance;
  final String mainAddress;
  final String offlineAddress;
  final bool readyForOffline;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.heroStart.withValues(alpha: 0.14),
            blurRadius: 28,
            spreadRadius: -4,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.heroStart,
              Color(0xFF1A5646),
              AppColors.heroEnd,
            ],
            stops: <double>[0, 0.58, 1],
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -36,
              right: -12,
              child: IgnorePointer(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -28,
              left: -18,
              child: IgnorePointer(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool stacked = constraints.maxWidth < 560;
                  final Widget mainNode = _OfflineFlowNode(
                    eyebrow: '',
                    title: 'Main wallet',
                    value: mainBalance,
                    caption: mainAddress,
                    icon: Icons.account_balance_wallet_rounded,
                  );
                  final Widget offlineNode = _OfflineFlowNode(
                    eyebrow: '',
                    title: 'Offline wallet',
                    value: offlineBalance,
                    caption: offlineAddress,
                    icon: Icons.lock_clock_rounded,
                  );

                  return Column(
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
                                  'OFFLINE',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.72,
                                        ),
                                        letterSpacing: 1.2,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  spendableBalance,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  readyForOffline
                                      ? 'Signer ready'
                                      : 'Refresh before handoff',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.82,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _OfflineHeroChip(
                            icon: readyForOffline
                                ? Icons.check_circle_outline_rounded
                                : Icons.update_rounded,
                            label: readyForOffline ? 'Ready' : 'Refresh',
                            active: readyForOffline,
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      if (stacked) ...<Widget>[
                        mainNode,
                        const SizedBox(height: 10),
                        const Center(
                          child: _OfflineFlowConnector(vertical: true),
                        ),
                        const SizedBox(height: 10),
                        offlineNode,
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Expanded(child: mainNode),
                            const SizedBox(width: 16),
                            const Expanded(child: _OfflineFlowConnector()),
                            const SizedBox(width: 16),
                            Expanded(child: offlineNode),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineFlowNode extends StatelessWidget {
  const _OfflineFlowNode({
    required this.eyebrow,
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
  });

  final String eyebrow;
  final String title;
  final String value;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (eyebrow.isNotEmpty) ...<Widget>[
          Text(
            eyebrow,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.64),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.74),
          ),
        ),
      ],
    );
  }
}

class _OfflineFlowConnector extends StatelessWidget {
  const _OfflineFlowConnector({this.vertical = false});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    if (vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 1.5,
            height: 16,
            color: Colors.white.withValues(alpha: 0.24),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.south_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          Container(
            width: 1.5,
            height: 16,
            color: Colors.white.withValues(alpha: 0.24),
          ),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            height: 1.5,
            color: Colors.white.withValues(alpha: 0.24),
          ),
        ),
        Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.east_rounded, color: Colors.white, size: 20),
        ),
        Expanded(
          child: Container(
            height: 1.5,
            color: Colors.white.withValues(alpha: 0.24),
          ),
        ),
      ],
    );
  }
}

class _OfflineHeroChip extends StatelessWidget {
  const _OfflineHeroChip({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color background = active
        ? Colors.white.withValues(alpha: 0.16)
        : AppColors.amberTint.withValues(alpha: 0.94);
    final Color foreground = active ? Colors.white : AppColors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _OfflineMetricStrip extends StatelessWidget {
  const _OfflineMetricStrip({
    required this.mainBalance,
    required this.offlineBalance,
  });

  final String mainBalance;
  final String offlineBalance;

  @override
  Widget build(BuildContext context) {
    final Widget mainMetric = _OfflineMetric(label: 'Main', value: mainBalance);
    final Widget offlineMetric = _OfflineMetric(
      label: 'Offline',
      value: offlineBalance,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              mainMetric,
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              offlineMetric,
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: mainMetric),
            const _OfflineMetricDivider(),
            Expanded(child: offlineMetric),
          ],
        );
      },
    );
  }
}

class _OfflineMetric extends StatelessWidget {
  const _OfflineMetric({required this.label, required this.value});

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

class _OfflineMetricDivider extends StatelessWidget {
  const _OfflineMetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      color: AppColors.line.withValues(alpha: 0.7),
    );
  }
}

class _OfflineActionComposer extends StatelessWidget {
  const _OfflineActionComposer({
    required this.chain,
    required this.mainBalance,
    required this.controller,
    required this.onPresetSelected,
  });

  final ChainKind chain;
  final String mainBalance;
  final TextEditingController controller;
  final ValueChanged<String> onPresetSelected;

  @override
  Widget build(BuildContext context) {
    final List<String> presets = chain == ChainKind.solana
        ? const <String>['0.050', '0.100', '0.250']
        : const <String>['0.005', '0.010', '0.025'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'Top up amount',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            Text(
              mainBalance,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
      ],
    );
  }
}

class _OfflineBottomActions extends StatelessWidget {
  const _OfflineBottomActions({
    required this.working,
    required this.statusMessage,
    required this.readyForOffline,
    required this.onTopUp,
    required this.onRefreshReadiness,
  });

  final bool working;
  final String? statusMessage;
  final bool readyForOffline;
  final VoidCallback onTopUp;
  final VoidCallback onRefreshReadiness;

  @override
  Widget build(BuildContext context) {
    final Widget topUpButton = ElevatedButton(
      onPressed: working ? null : onTopUp,
      child: working
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
                Text('Moving funds...'),
              ],
            )
          : const Text('Top up offline wallet'),
    );
    final Widget refreshButton = OutlinedButton(
      onPressed: working ? null : onRefreshReadiness,
      child: Text(readyForOffline ? 'Refresh again' : 'Refresh readiness'),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (working && statusMessage != null) ...<Widget>[
          Row(
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
          const SizedBox(height: 12),
        ],
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            if (constraints.maxWidth < 460) {
              return Column(
                children: <Widget>[
                  topUpButton,
                  const SizedBox(height: 10),
                  refreshButton,
                ],
              );
            }

            return Row(
              children: <Widget>[
                Expanded(child: topUpButton),
                const SizedBox(width: 10),
                Expanded(child: refreshButton),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OfflineFundingCard extends StatelessWidget {
  const _OfflineFundingCard({
    required this.chain,
    required this.mainBalance,
    required this.controller,
    required this.working,
    required this.statusMessage,
    required this.readyForOffline,
    required this.onPresetSelected,
    required this.onTopUp,
    required this.onRefreshReadiness,
  });

  final ChainKind chain;
  final String mainBalance;
  final TextEditingController controller;
  final bool working;
  final String? statusMessage;
  final bool readyForOffline;
  final ValueChanged<String> onPresetSelected;
  final VoidCallback onTopUp;
  final VoidCallback onRefreshReadiness;

  @override
  Widget build(BuildContext context) {
    final List<String> presets = chain == ChainKind.solana
        ? const <String>['0.050', '0.100', '0.250']
        : const <String>['0.005', '0.010', '0.025'];

    return SectionCard(
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
                      'Move ${chain.shortLabel} in',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Fund the signer from the main wallet before it leaves the network.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.canvasTint.withValues(alpha: 0.82),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.canvasTint.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
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
                        'Main wallet balance',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.slate,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mainBalance,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
          if (working && statusMessage != null) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.amberTint,
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
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: working ? null : onTopUp,
            child: working
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
                      Text('Moving funds...'),
                    ],
                  )
                : const Text('Top up offline wallet'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: working ? null : onRefreshReadiness,
            child: Text(
              readyForOffline ? 'Refresh again' : 'Refresh readiness',
            ),
          ),
        ],
      ),
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
        : 'Refresh before the next handoff';
    final String statusCaption = readyForOffline
        ? 'The signer has a fresh readiness snapshot. Keep it offline until you need to send.'
        : 'Update readiness right before the offline signer is handed off so the next transfer starts clean.';

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
                      'Keep funding and readiness separate so the signer only goes online when needed.',
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
                label: readyForOffline ? 'Ready' : 'Refresh',
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
                : 'Current age: $readinessAge. Refresh right before you hand off the signer.',
            accent: readyForOffline ? AppColors.emerald : AppColors.amber,
          ),
          const SizedBox(height: 12),
          _OfflineChecklistTile(
            icon: Icons.send_rounded,
            title: 'Next step',
            caption:
                'After the refresh, keep the signer offline and use it for the next local send.',
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
  const _DashboardHero({required this.summary});

  final WalletSummary summary;

  @override
  Widget build(BuildContext context) {
    final bool usingBitGo = summary.walletEngine == WalletEngine.bitgo;
    return Semantics(
      container: true,
      label: 'Wallet overview',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final int columns = constraints.maxWidth < 340 ? 1 : 2;
          const double spacing = 14;
          final double statWidth = columns == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - (spacing * (columns - 1))) / columns;

          return Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AppColors.heroStart,
                  Color(0xFF1A5646),
                  AppColors.heroEnd,
                ],
                stops: <double>[0, 0.58, 1],
              ),
              borderRadius: BorderRadius.circular(34),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.heroStart.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  right: -22,
                  top: -14,
                  child: IgnorePointer(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 38,
                  bottom: -36,
                  child: IgnorePointer(
                    child: Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          usingBitGo ? 'BitGo' : 'Main',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white70,
                                letterSpacing: 0.7,
                              ),
                        ),
                        const Spacer(),
                        _HeroStatusChip(
                          ready: usingBitGo ? true : summary.readyForOffline,
                          walletEngine: summary.walletEngine,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      Formatters.asset(summary.balanceSol, summary.chain),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontSize: 36,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: spacing,
                      runSpacing: 12,
                      children: <Widget>[
                        SizedBox(
                          width: statWidth,
                          child: _HeroMetric(
                            label: usingBitGo ? 'Wallet' : 'Offline',
                            value: usingBitGo
                                ? (summary.bitgoWallet?.displayLabel ??
                                      'Unavailable')
                                : Formatters.asset(
                                    summary.offlineBalanceSol,
                                    summary.chain,
                                  ),
                            icon: usingBitGo
                                ? Icons.shield_outlined
                                : Icons.account_balance_wallet_outlined,
                          ),
                        ),
                        SizedBox(
                          width: statWidth,
                          child: _HeroMetric(
                            label: usingBitGo ? 'Status' : 'Spendable',
                            value: usingBitGo
                                ? (summary.bitgoWallet?.connectivityStatus ??
                                      'Online')
                                : Formatters.asset(
                                    summary.offlineAvailableSol,
                                    summary.chain,
                                  ),
                            icon: usingBitGo
                                ? Icons.cloud_done_rounded
                                : Icons.arrow_outward_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: value,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: Colors.white, height: 1.1),
          ),
        ],
      ),
    );
  }
}

class _HeroStatusChip extends StatelessWidget {
  const _HeroStatusChip({required this.ready, required this.walletEngine});

  final bool ready;
  final WalletEngine walletEngine;

  @override
  Widget build(BuildContext context) {
    final bool usingBitGo = walletEngine == WalletEngine.bitgo;
    final Color textColor = ready ? Colors.white : AppColors.amberTint;
    return Semantics(
      label: usingBitGo ? 'Wallet mode' : 'Offline readiness',
      value: usingBitGo
          ? 'BitGo online mode'
          : ready
          ? 'Ready'
          : 'Needs refresh',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: ready
              ? Colors.white.withValues(alpha: 0.12)
              : AppColors.amber.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              usingBitGo
                  ? Icons.shield_outlined
                  : ready
                  ? Icons.check_circle_outline_rounded
                  : Icons.update_rounded,
              size: 14,
              color: textColor,
            ),
            const SizedBox(width: 5),
            Text(
              usingBitGo
                  ? 'BitGo'
                  : ready
                  ? 'Ready'
                  : 'Refresh',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: textColor, height: 1),
            ),
          ],
        ),
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
                      Text(
                        'bitsend',
                        style: theme.textTheme.titleLarge?.copyWith(
                          letterSpacing: -0.5,
                        ),
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
      value:
          '${Formatters.asset(transfer.amountSol, transfer.chain)}, ${transfer.status.label}',
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
                  Formatters.asset(transfer.amountSol, transfer.chain),
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

bool _isValidAddressForChain(String value, ChainKind chain) {
  final String normalized = value.trim();
  return chain == ChainKind.solana
      ? isValidAddress(normalized)
      : RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(normalized);
}

Future<void> _showBluetoothPrompt(BuildContext context, String message) async {
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Turn on Bluetooth'),
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
            TransportKind.hotspot => 'Open same-network receive',
            TransportKind.ble => 'Open Bluetooth receive',
            TransportKind.ultrasonic => 'Open Bitsend Pair receive',
          };
    final String caption = !hasWallet
        ? 'Create or restore a wallet first.'
        : switch (transport) {
            TransportKind.hotspot => activeListener
                ? 'Share the pair code on the same Wi-Fi or hotspot. The sender fills your address and endpoint in one scan.'
                : 'Start when both phones share the same Wi-Fi or hotspot.',
            TransportKind.ble => activeListener
                ? 'Keep Bluetooth on and leave this screen open so nearby senders can discover this receiver.'
                : 'Start when Bluetooth is on and both phones are nearby.',
            TransportKind.ultrasonic => activeListener
                ? 'Share the pair code to start a direct or browser relay session. The sender gets your address, session token, and relay id in one scan.'
                : 'Start to mint a fresh Bitsend Pair session token and relay id.',
          };
    final String helper = switch (transport) {
      TransportKind.hotspot => endpoint ?? 'Join a local Wi-Fi or hotspot first.',
      TransportKind.ble => 'bitsend BLE receiver',
      TransportKind.ultrasonic =>
        invite?.relayId ??
            'A fresh relay id appears after Bitsend Pair receive starts.',
    };
    final String helperLabel = switch (transport) {
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
                  label: Text('Bitsend Pair'),
                  icon: Icon(Icons.phonelink_lock_rounded),
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
                                  _showSnack(
                                    context,
                                    'Pair code payload copied.',
                                  );
                                },
                                icon: const Icon(Icons.copy_all_rounded),
                                label: const Text('Copy pair code'),
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
            TransportKind.hotspot => activeListener
                ? 'Waiting for the local endpoint.'
                : 'Start hotspot receive to show the live pair code.',
            TransportKind.ble => activeListener
                ? 'BLE is live. Nearby senders can detect this receiver.'
                : 'Start BLE receive to show the live pair code.',
            TransportKind.ultrasonic => activeListener
                ? 'Bitsend Pair is live. Senders can scan this pair code for direct handoff or browser relay.'
                : 'Start Bitsend Pair receive to show the live pair code.',
          }
        : switch (transport) {
            TransportKind.hotspot => 'Scan to fill address and endpoint.',
            TransportKind.ble => 'Scan to switch the sender into BLE.',
            TransportKind.ultrasonic =>
              'Scan to fill the address, session token, and relay id.',
          };

    return Container(
      width: 244,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
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
            BitsendPairMarkView(
              payloadBytes: invite!.toPairMarkBytes(),
              size: 184,
              semanticsLabel: 'Bitsend Pair code',
            )
          else
            Container(
              width: 184,
              height: 184,
              decoration: BoxDecoration(
                color: AppColors.canvasWarm,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                hasWallet
                    ? switch (transport) {
                        TransportKind.hotspot =>
                          Icons.wifi_tethering_rounded,
                        TransportKind.ble =>
                          Icons.bluetooth_searching_rounded,
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
            activeListener ? 'Share pair code' : 'Ready pair code',
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

Future<ReceiverInvitePayload?> _scanReceiverInvite(BuildContext context) {
  return Navigator.of(context).push<ReceiverInvitePayload>(
    MaterialPageRoute<ReceiverInvitePayload>(
      builder: (_) => const _ReceiverQrScannerScreen(),
    ),
  );
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
      'Bitsend Pair is only available in Local wallet mode.',
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

Color _transportTone(TransportKind transport) => switch (transport) {
  TransportKind.hotspot => AppColors.blue,
  TransportKind.ble => AppColors.emerald,
  TransportKind.ultrasonic => AppColors.amber,
};

class _ReceiverQrScannerScreen extends StatefulWidget {
  const _ReceiverQrScannerScreen();

  @override
  State<_ReceiverQrScannerScreen> createState() =>
      _ReceiverQrScannerScreenState();
}

class _ReceiverQrScannerScreenState extends State<_ReceiverQrScannerScreen> {
  final BitsendPairCameraService _cameraService = BitsendPairCameraService();
  final BitsendPairMarkService _markService = const BitsendPairMarkService();
  bool _capturing = false;
  bool _started = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCapture();
    });
  }

  Future<void> _startCapture() async {
    if (_capturing || _started) {
      return;
    }
    _started = true;
    await _capture();
  }

  Future<void> _capture() async {
    if (_capturing) {
      return;
    }
    try {
      if (mounted) {
        setState(() {
          _capturing = true;
          _error = null;
        });
      }
      final Uint8List captureBytes = await _cameraService.capturePreview();
      final Uint8List payloadBytes = _markService.decodeImageBytes(captureBytes);
      final ReceiverInvitePayload invite = ReceiverInvitePayload
          .fromPairMarkBytes(payloadBytes);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(invite);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _messageFor(error);
        _capturing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool supported = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          const IgnorePointer(
            child: Center(
              child: _PairScannerReticle(
                label: 'Frame the full Bitsend Pair mark',
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  IconButton.filledTonal(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Capture pair code',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          supported
                              ? 'Take a photo of the Bitsend Pair mark to fill the address and transport.'
                              : 'Custom pair capture is only available on Android in this build.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                        if (_error != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.amberTint),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: supported && !_capturing ? _capture : null,
                            icon: Icon(
                              _capturing
                                  ? Icons.hourglass_top_rounded
                                  : Icons.camera_alt_rounded,
                            ),
                            label: Text(
                              _capturing ? 'Opening camera...' : 'Open camera',
                            ),
                          ),
                        ),
                      ],
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

class _PairScannerReticle extends StatelessWidget {
  const _PairScannerReticle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 246,
          height: 246,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.92),
              width: 1.6,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.amberTint.withValues(alpha: 0.82),
                    width: 1.4,
                  ),
                ),
              ),
              Container(
                width: 136,
                height: 136,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.88),
                    width: 1.2,
                  ),
                ),
              ),
              for (final Alignment alignment in <Alignment>[
                Alignment.topCenter,
                Alignment.centerRight,
                Alignment.bottomCenter,
                Alignment.centerLeft,
              ])
                Align(
                  alignment: alignment,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.amber,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.amber.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

void _navigatePrimaryTab(BuildContext context, BitsendPrimaryTab tab) {
  final String route = switch (tab) {
    BitsendPrimaryTab.home => AppRoutes.home,
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
      : '${Formatters.asset(transfer.amountSol, transfer.chain)} received over ${transfer.transport.shortLabel}.';
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
