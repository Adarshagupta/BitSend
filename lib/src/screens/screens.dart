import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:solana/solana.dart' show isValidAddress;

import '../app/app.dart';
import '../app/theme.dart';
import '../models/app_models.dart';
import '../state/app_state.dart';
import '../widgets/app_widgets.dart';

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
      await state.initialize();
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
      child: const FadeSlideIn(delay: 0, child: _WelcomeHero()),
      bottom: ElevatedButton(
        onPressed: () {
          Navigator.of(
            context,
          ).pushReplacementNamed(AppRoutes.onboardingWallet);
        },
        child: const Text('Set up wallet'),
      ),
    );
  }
}

class WalletSetupScreen extends StatefulWidget {
  const WalletSetupScreen({super.key});

  @override
  State<WalletSetupScreen> createState() => _WalletSetupScreenState();
}

class _WalletSetupScreenState extends State<WalletSetupScreen> {
  final TextEditingController _phraseController = TextEditingController();
  String? _backupPath;

  @override
  void dispose() {
    _phraseController.dispose();
    super.dispose();
  }

  Future<void> _createWallet(BitsendAppState state) async {
    try {
      await state.createWallet();
      if (!mounted) {
        return;
      }
      setState(() {
        _backupPath = null;
      });
    } catch (error) {
      _showSnack(context, _messageFor(error));
    }
  }

  Future<void> _restoreWallet(BitsendAppState state) async {
    try {
      await state.restoreWallet(_phraseController.text);
      if (!mounted) {
        return;
      }
      setState(() {
        _backupPath = null;
      });
    } catch (error) {
      _showSnack(context, _messageFor(error));
    }
  }

  Future<void> _exportBackup(BitsendAppState state) async {
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
    await Clipboard.setData(ClipboardData(text: wallet.seedPhrase));
    if (!mounted) {
      return;
    }
    _showSnack(context, 'Recovery phrase copied.');
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
                      SelectableText(
                        wallet.seedPhrase,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
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
                        onPressed: state.working
                            ? null
                            : () => _createWallet(state),
                        child: const Text('Create new wallet'),
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
                        onPressed: state.working
                            ? null
                            : () => _restoreWallet(state),
                        child: const Text('Restore wallet'),
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
          : 'Send ${chain.shortLabel} on ${network.shortLabelFor(chain)}, or skip and fund it later from Home.',
      actions: <Widget>[
        IconButton(
          onPressed: () => _refresh(context, state),
          tooltip: 'Refresh balances',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
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
      label: '${chain.label} ${state.activeNetwork.shortLabelFor(chain)}',
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
      label: '${engine.label} · ${state.activeChain.label}',
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
        : !state.hasOfflineFunds && !state.hasOfflineReadyBlockhash
        ? 'Fund + refresh'
        : !state.hasOfflineFunds
        ? 'Fund offline wallet'
        : 'Refresh readiness';
    final String supportStatus = !state.hasWallet
        ? 'Set up wallet to start.'
        : usingBitGo && !state.hasInternet
        ? 'BitGo mode needs internet before submit.'
        : usingBitGo && !state.bitgoBackendIsLive
        ? 'BitGo backend is demo-only. Send will fall back to Local mode.'
        : usingBitGo
        ? 'BitGo wallet is ready for online submit.'
        : canSend
        ? 'Offline wallet is ready.'
        : !state.hasOfflineFunds && !state.hasOfflineReadyBlockhash
        ? 'Fund and refresh before send.'
        : !state.hasOfflineFunds
        ? 'Fund the offline wallet before send.'
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
      overlay: _switchingScope
          ? _ScopeSwitchOverlay(label: _switchingLabel)
          : null,
      showBack: false,
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
      title: 'Deposit ${chain.shortLabel}',
      subtitle: usingBitGo
          ? 'Share the BitGo-backed ${network.shortLabelFor(chain)} ${chain.shortLabel} address.'
          : 'Pick a wallet and share the ${network.shortLabelFor(chain)} ${chain.shortLabel} address.',
      actions: <Widget>[
        IconButton(
          onPressed: () async {
            try {
              await state.refreshWalletData();
            } catch (error) {
              if (!context.mounted) {
                return;
              }
              _showSnack(context, _messageFor(error));
            }
          },
          tooltip: 'Refresh balances',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
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
    _topUpController = TextEditingController(text: '0.100');
  }

  @override
  void dispose() {
    _topUpController.dispose();
    super.dispose();
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
    return BitsendPageScaffold(
      title: usingBitGo ? 'BitGo Wallet' : 'Offline Wallet',
      subtitle: usingBitGo
          ? 'BitGo mode is online-only. Manage the backend wallet here.'
          : 'Fund once. Refresh before handoff.',
      actions: <Widget>[
        IconButton(
          onPressed: state.refreshStatus,
          tooltip: 'Refresh balances',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
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
                  : 'If BitGo submit stays in demo mode or goes down, the app will switch to Local mode and use the offline wallet flow automatically.',
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
                    value: state.bitgoWallet?.address ?? 'Connect demo wallet',
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
                    onPressed: state.working ? null : state.connectBitGoDemo,
                    child: const Text('Refresh BitGo wallet'),
                  ),
                ],
              ),
            ),
          ] else ...<Widget>[
            _OfflineWalletScene(
              mainBalance: Formatters.asset(summary.balanceSol, chain),
              offlineBalance: Formatters.asset(
                summary.offlineBalanceSol,
                chain,
              ),
              spendableBalance: Formatters.asset(
                summary.offlineAvailableSol,
                chain,
              ),
              mainAddress: state.wallet?.displayAddress ?? 'Main unavailable',
              offlineAddress: summary.offlineWalletAddress == null
                  ? 'Offline unavailable'
                  : Formatters.shortAddress(summary.offlineWalletAddress!),
              readyForOffline: summary.readyForOffline,
              readinessAge: summary.blockhashAge == null
                  ? 'Refresh'
                  : Formatters.durationLabel(summary.blockhashAge),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Move ${chain.shortLabel}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _topUpController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Top up amount in ${chain.shortLabel}',
                      hintText: chain == ChainKind.solana ? '0.100' : '0.010',
                    ),
                  ),
                  if (state.working && state.statusMessage != null) ...<Widget>[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
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
                              state.statusMessage!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: state.working ? null : () => _topUp(state),
                    child: state.working
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
                    onPressed: state.working
                        ? null
                        : () => _refreshReadiness(state),
                    child: Text(
                      summary.readyForOffline
                          ? 'Refresh again'
                          : 'Refresh readiness',
                    ),
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
    final String displayReceiver = state.sendDraft.receiverLabel.isEmpty
        ? state.sendDraft.receiverAddress
        : state.sendDraft.receiverLabel;
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
    _resolvedReceiverLabel = state.sendDraft.receiverLabel.isEmpty
        ? null
        : state.sendDraft.receiverLabel;
    _resolvedReceiverAddress = state.sendDraft.receiverLabel.isEmpty
        ? null
        : state.sendDraft.receiverAddress;
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
    });
  }

  Future<void> _continue(BitsendAppState state) async {
    final String rawReceiver = _addressController.text.trim();
    String receiverAddress = rawReceiver;
    String receiverLabel = '';
    if (rawReceiver.isEmpty) {
      _showSnack(context, 'Receiver address is required.');
      return;
    }
    if (state.activeChain == ChainKind.ethereum &&
        !state.looksLikeEthereumEnsName(rawReceiver) &&
        !_isValidAddressForChain(rawReceiver, state.activeChain)) {
      _showSnack(context, 'Receiver address or ENS name is not valid.');
      return;
    }
    if (state.activeChain == ChainKind.ethereum &&
        state.looksLikeEthereumEnsName(rawReceiver)) {
      setState(() {
        _resolvingEns = true;
      });
      try {
        receiverAddress = await state.resolveEthereumEnsName(rawReceiver);
        receiverLabel = rawReceiver.toLowerCase();
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
      });
    }
    if (state.sendDraft.transport == TransportKind.hotspot) {
      state.updateReceiver(
        receiverAddress: receiverAddress,
        receiverLabel: receiverLabel,
        receiverEndpoint: _endpointController.text,
      );
    } else {
      state.updateReceiver(
        receiverAddress: receiverAddress,
        receiverLabel: receiverLabel,
        receiverPeripheralId: _selectedBleReceiverId ?? '',
        receiverPeripheralName: _selectedBleReceiverName ?? '',
      );
    }
    if (!state.sendDraft.hasReceiver) {
      _showSnack(
        context,
        state.activeWalletEngine == WalletEngine.bitgo
            ? 'Receiver address is required for BitGo mode.'
            : state.sendDraft.transport == TransportKind.hotspot
            ? 'Receiver address and endpoint are required.'
            : 'Receiver address and a discovered BLE device are required.',
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
    final ReceiverInvitePayload? invite = await Navigator.of(context)
        .push<ReceiverInvitePayload>(
          MaterialPageRoute<ReceiverInvitePayload>(
            builder: (_) => const _ReceiverQrScannerScreen(),
          ),
        );
    if (!mounted || invite == null) {
      return;
    }
    await _applyInvite(state, invite);
  }

  Future<void> _applyInvite(
    BitsendAppState state,
    ReceiverInvitePayload invite,
  ) async {
    await state.setActiveChain(invite.chain);
    await state.setActiveNetwork(invite.network);
    state.setSendTransport(invite.transport);
    if (invite.transport == TransportKind.hotspot) {
      state.updateReceiver(
        receiverAddress: invite.address,
        receiverEndpoint: invite.endpoint ?? '',
      );
    } else {
      state.updateReceiver(receiverAddress: invite.address);
    }
    setState(() {
      _addressController.text = invite.address;
      _endpointController.text = invite.endpoint ?? '';
      _selectedBleReceiverId = null;
      _selectedBleReceiverName = null;
      if (invite.transport == TransportKind.ble) {
        _selectedBleReceiverName = invite.displayAddress;
      }
    });
    if (invite.transport == TransportKind.ble) {
      await _scanBleReceivers(state, preferredAddress: invite.address);
    }
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final TransportKind transport = state.sendDraft.transport;
    final bool usingBitGo = state.activeWalletEngine == WalletEngine.bitgo;
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
              title: 'Demo backend detected',
              caption:
                  'Send will switch to Local mode automatically and continue with the offline wallet flow if BitGo is still in demo mode.',
              icon: Icons.info_outline_rounded,
            ),
            const SizedBox(height: 16),
          ],
          SegmentedButton<TransportKind>(
            segments: const <ButtonSegment<TransportKind>>[
              ButtonSegment<TransportKind>(
                value: TransportKind.hotspot,
                label: Text('Hotspot'),
                icon: Icon(Icons.wifi_tethering_rounded),
              ),
              ButtonSegment<TransportKind>(
                value: TransportKind.ble,
                label: Text('BLE'),
                icon: Icon(Icons.bluetooth_rounded),
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
            label: const Text('Scan receiver QR'),
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
                  decoration: InputDecoration(
                    labelText: state.activeChain == ChainKind.ethereum
                        ? 'Receiver address or ENS'
                        : 'Receiver address',
                    hintText: state.activeChain == ChainKind.ethereum
                        ? 'alice.eth or 0x...'
                        : state.activeChain.receiverHintFor(
                            state.activeNetwork,
                          ),
                  ),
                ),
                if (state.activeChain == ChainKind.ethereum) ...<Widget>[
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
                ],
                if (usingBitGo &&
                    transport == TransportKind.hotspot) ...<Widget>[
                  const SizedBox(height: 18),
                  const InlineBanner(
                    title: 'Endpoint not needed',
                    caption:
                        'In BitGo mode, hotspot QR is only used to prefill the receiver address. Submission happens online through the backend.',
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
    state.updateAmount(amount);
    if (!state.sendDraft.hasAmount) {
      _showSnack(context, 'Enter an amount greater than zero.');
      return;
    }
    final String? readinessMessage = _sendReadinessMessage(state);
    if (readinessMessage != null) {
      _showSnack(context, readinessMessage);
      return;
    }
    Navigator.of(context).pushNamed(AppRoutes.sendReview);
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final ChainKind chain = state.activeChain;
    final double amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final int baseUnits = chain.amountToBaseUnits(amount);
    final String? readinessMessage = _sendReadinessMessage(state);
    final bool autoRefreshOnSign =
        state.activeWalletEngine == WalletEngine.local &&
        state.hasOfflineFunds &&
        !state.hasOfflineReadyBlockhash &&
        state.hasInternet;
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
                  label: state.activeWalletEngine == WalletEngine.bitgo
                      ? 'BitGo wallet available'
                      : 'Offline wallet available',
                  value: Formatters.asset(
                    state.activeWalletEngine == WalletEngine.bitgo
                        ? state.mainBalanceSol
                        : state.offlineSpendableBalanceSol,
                    chain,
                  ),
                ),
                DetailRow(
                  label: state.activeWalletEngine == WalletEngine.bitgo
                      ? 'Source wallet'
                      : 'Offline wallet',
                  value: state.activeWalletEngine == WalletEngine.bitgo
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
                      : 'BLE receiver',
                  value: usingBitGo
                      ? draft.transport.label
                      : draft.transport == TransportKind.hotspot
                      ? draft.receiverEndpoint
                      : draft.receiverPeripheralName,
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
      bottom: ElevatedButton(
        onPressed: () {
          Navigator.of(context).pushNamed(AppRoutes.sendProgress);
        },
        child: Text(usingBitGo ? 'Submit with BitGo' : 'Sign and send'),
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
                  : 'The signed envelope is sent to the receiver over BLE.',
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

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final PendingTransfer? transfer = state.lastSentTransfer;
    _celebrate(transfer);
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
          : Row(
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
  String? _seenAnnouncement;
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
        state.announcementMessage != _seenAnnouncement) {
      _seenAnnouncement = state.announcementMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _showSnack(context, state.announcementMessage!);
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
        state.acknowledgeLastReceivedTransfer();
        Navigator.of(
          context,
        ).pushNamed(AppRoutes.receiveResult, arguments: transferId);
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
    final bool activeListener = transport == TransportKind.hotspot
        ? state.hotspotListenerRunning
        : state.bleListenerRunning;
    final ReceiverInvitePayload? invite = _receiverInvitePayload(
      state,
      transport,
      activeListener: activeListener && !usingBitGo,
    );
    return BitsendPageScaffold(
      title: 'Receive',
      subtitle: usingBitGo
          ? 'BitGo mode does not listen offline. Switch back to Local mode to receive over hotspot or BLE.'
          : 'Catch a signed handoff over local Wi-Fi or BLE.',
      actions: <Widget>[
        IconButton(
          onPressed: state.refreshStatus,
          tooltip: 'Refresh status',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
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
                  'Switch back to Local mode from the header to receive over hotspot or BLE.',
              icon: Icons.shield_outlined,
            ),
            const SizedBox(height: 16),
          ],
          _ReceiveStudioCard(
            scrollController: _scrollController,
            transport: transport,
            activeListener: activeListener && !usingBitGo,
            hasWallet: state.hasWallet,
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

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final PendingTransfer? transfer = widget.transferId == null
        ? state.lastReceivedTransfer
        : state.transferById(widget.transferId!);
    _celebrate(transfer);
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
          : Row(
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

Future<String> _captureReceiptImage(
  BuildContext context,
  GlobalKey boundaryKey,
  String transferId,
) async {
  final BuildContext? boundaryContext = boundaryKey.currentContext;
  if (boundaryContext == null) {
    throw StateError('Receipt is still preparing. Try again in a moment.');
  }
  final RenderRepaintBoundary boundary =
      boundaryContext.findRenderObject()! as RenderRepaintBoundary;
  final double pixelRatio = MediaQuery.devicePixelRatioOf(
    context,
  ).clamp(1.8, 3.0).toDouble();
  final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
  final ByteData? byteData = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  if (byteData == null) {
    throw StateError('Could not generate the receipt image.');
  }
  final Directory directory = await path_provider
      .getApplicationDocumentsDirectory();
  final String safeTransferId = transferId.replaceAll(
    RegExp(r'[^A-Za-z0-9_-]'),
    '_',
  );
  final File file = File(
    '${directory.path}/bitsend-receipt-$safeTransferId.png',
  );
  final Uint8List bytes = byteData.buffer.asUint8List();
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
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
      actions: <Widget>[
        IconButton(
          onPressed: () async {
            try {
              await state.refreshStatus();
            } catch (error) {
              if (!context.mounted) {
                return;
              }
              _showSnack(context, _messageFor(error));
            }
          },
          tooltip: 'Refresh status',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
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
  String? _backupPath;

  @override
  void initState() {
    super.initState();
    _rpcController = TextEditingController();
    _bitgoController = TextEditingController();
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
      await state.connectBitGoDemo();
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

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
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
                SelectableText(
                  state.wallet?.seedPhrase ?? 'Wallet not created yet.',
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
                      onPressed: state.wallet == null
                          ? null
                          : () async {
                              await Clipboard.setData(
                                ClipboardData(text: state.wallet!.seedPhrase),
                              );
                              if (!context.mounted) {
                                return;
                              }
                              _showSnack(context, 'Recovery phrase copied.');
                            },
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
                      child: const Text('Connect BitGo demo'),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'bitsend',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(letterSpacing: -0.4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Scope',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                  ),
                ],
              ),
              const Spacer(),
              Material(
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
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Text(
                            '${walletEngine.label} · ${chain.label} · ${network.shortLabelFor(chain)}',
                            key: ValueKey<String>(
                              '${walletEngine.name}:${chain.name}:${network.name}',
                            ),
                            style: Theme.of(context).textTheme.labelLarge,
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
                          ],
                          onChanged: _selectChain,
                        ),
                        const SizedBox(height: 12),
                        _ScopeToggleRow<WalletEngine>(
                          label: 'Wallet',
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
                          label: 'Network',
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
    required this.readinessAge,
  });

  final String mainBalance;
  final String offlineBalance;
  final String spendableBalance;
  final String mainAddress;
  final String offlineAddress;
  final bool readyForOffline;
  final String readinessAge;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Main to offline',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              _MiniCue(
                icon: readyForOffline
                    ? Icons.check_circle_outline_rounded
                    : Icons.update_rounded,
                label: readyForOffline ? 'Ready' : 'Refresh',
                active: readyForOffline,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _WalletBalanceNode(
                  title: 'Main',
                  value: mainBalance,
                  caption: mainAddress,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.emerald,
                  size: 26,
                ),
              ),
              Expanded(
                child: _WalletBalanceNode(
                  title: 'Offline',
                  value: offlineBalance,
                  caption: offlineAddress,
                  icon: Icons.lock_clock_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _ValueCue(
                icon: Icons.arrow_outward_rounded,
                label: 'Spendable',
                value: spendableBalance,
              ),
              _ValueCue(
                icon: Icons.bolt_rounded,
                label: 'Age',
                value: readinessAge,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletBalanceNode extends StatelessWidget {
  const _WalletBalanceNode({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
  });

  final String title;
  final String value;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.canvasTint.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: AppColors.ink, size: 22),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(caption, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ValueCue extends StatelessWidget {
  const _ValueCue({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: AppColors.slate),
          const SizedBox(width: 8),
          Text(
            '$label $value',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.ink),
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
                                ? (summary.bitgoWallet?.displayLabel ?? 'Demo')
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
  const _WelcomeHero();

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
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(38),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AppColors.heroStart,
                    Color(0xFF0F3128),
                    AppColors.heroEnd,
                  ],
                  stops: <double>[0, 0.54, 1],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.heroStart.withValues(alpha: 0.18),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: -28,
                    right: -18,
                    child: IgnorePointer(
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -42,
                    bottom: 82,
                    child: IgnorePointer(
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.amber.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 22 : 26,
                      compact ? 20 : 24,
                      compact ? 22 : 26,
                      compact ? 20 : 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const _WelcomeTonePill(
                          icon: Icons.wifi_protected_setup_rounded,
                          label: 'Offline-first payments',
                        ),
                        SizedBox(height: compact ? 18 : 20),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: Text(
                            'Send now. Settle later.',
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontSize: compact ? 33 : 38,
                              height: 0.98,
                              letterSpacing: -1.2,
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 10 : 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 470),
                          child: Text(
                            'Hand off a signed payment nearby. Either device can broadcast when it gets back online.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.78),
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 20 : 24),
                        Expanded(
                          child: _WelcomeTransferScene(compact: compact),
                        ),
                        SizedBox(height: compact ? 14 : 18),
                        _WelcomeFlowRibbon(compact: compact),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
  if (transport == TransportKind.hotspot &&
      (!activeListener || state.localEndpoint == null)) {
    return null;
  }
  return ReceiverInvitePayload(
    chain: state.activeChain,
    network: state.activeNetwork,
    transport: transport,
    address: wallet.address,
    displayAddress: wallet.displayAddress,
    endpoint: transport == TransportKind.hotspot ? state.localEndpoint : null,
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
        : transport == TransportKind.hotspot
        ? 'Open same-network receive'
        : 'Open Bluetooth receive';
    final String caption = !hasWallet
        ? 'Create or restore a wallet first.'
        : transport == TransportKind.hotspot
        ? activeListener
              ? 'Share the QR on the same Wi-Fi or hotspot. The sender fills your address and endpoint in one scan.'
              : 'Start when both phones share the same Wi-Fi or hotspot.'
        : activeListener
        ? 'Keep Bluetooth on and leave this screen open so nearby senders can discover this receiver.'
        : 'Start when Bluetooth is on and both phones are nearby.';
    final String helper = transport == TransportKind.hotspot
        ? (endpoint ?? 'Join a local Wi-Fi or hotspot first.')
        : 'bitsend BLE receiver';
    final bool showEndpointWarning =
        transport == TransportKind.hotspot && endpoint == null;

    return Semantics(
      container: true,
      label: 'Receive setup',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= 620;
          final Widget transportSwitch = SegmentedButton<TransportKind>(
            segments: const <ButtonSegment<TransportKind>>[
              ButtonSegment<TransportKind>(
                value: TransportKind.hotspot,
                label: Text('Hotspot'),
                icon: Icon(Icons.wifi_tethering_rounded),
              ),
              ButtonSegment<TransportKind>(
                value: TransportKind.ble,
                label: Text('BLE'),
                icon: Icon(Icons.bluetooth_rounded),
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
                          label: transport == TransportKind.hotspot
                              ? 'Endpoint'
                              : 'Signal',
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
                                    ClipboardData(text: invite!.toQrData()),
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  _showSnack(
                                    context,
                                    'Receiver QR payload copied.',
                                  );
                                },
                                icon: const Icon(Icons.copy_all_rounded),
                                label: const Text('Copy QR'),
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
        ? transport == TransportKind.hotspot
              ? activeListener
                    ? 'Waiting for the local endpoint.'
                    : 'Start hotspot receive to show the live QR.'
              : activeListener
              ? 'BLE is live. Nearby senders can detect this receiver.'
              : 'Start BLE receive to show the live QR.'
        : transport == TransportKind.hotspot
        ? 'Scan to fill address and endpoint.'
        : 'Scan to switch the sender into BLE.';

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
            QrImageView(
              data: invite!.toQrData(),
              version: QrVersions.auto,
              size: 184,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppColors.ink,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppColors.ink,
              ),
              semanticsLabel: 'Receiver QR code',
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
                    ? transport == TransportKind.hotspot
                          ? Icons.wifi_tethering_rounded
                          : Icons.bluetooth_searching_rounded
                    : Icons.account_balance_wallet_outlined,
                size: 44,
                color: hasWallet ? _transportTone(transport) : AppColors.slate,
              ),
            ),
          const SizedBox(height: 14),
          Text(
            activeListener ? 'Share QR' : 'Ready QR',
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

Color _transportTone(TransportKind transport) => switch (transport) {
  TransportKind.hotspot => AppColors.blue,
  TransportKind.ble => AppColors.emerald,
};

class _ReceiverQrScannerScreen extends StatefulWidget {
  const _ReceiverQrScannerScreen();

  @override
  State<_ReceiverQrScannerScreen> createState() =>
      _ReceiverQrScannerScreenState();
}

class _ReceiverQrScannerScreenState extends State<_ReceiverQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );
  bool _handled = false;
  String? _error;

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (_handled || capture.barcodes.isEmpty) {
      return;
    }
    final String? raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.trim().isEmpty) {
      return;
    }

    try {
      final ReceiverInvitePayload invite = ReceiverInvitePayload.fromQrData(
        raw,
      );
      _handled = true;
      await _controller.stop();
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
      });
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
      body: Stack(
        children: <Widget>[
          MobileScanner(
            controller: _controller,
            onDetect: (BarcodeCapture capture) {
              _handleCapture(capture);
            },
            onDetectError: (Object error, StackTrace stackTrace) {
              if (!mounted) {
                return;
              }
              setState(() {
                _error = _messageFor(error);
              });
            },
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
                          'Scan receiver QR',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Point the camera at the receiver QR to fill the address and transport.',
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
