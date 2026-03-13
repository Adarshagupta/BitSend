import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      title: 'Send now. Settle later.',
      subtitle:
          'Sign a real devnet transfer, pass it over a local link, and broadcast it once either device is back online.',
      showBack: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _FeatureRow(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Wallet on each device',
                  caption: 'Create or restore a Solana devnet wallet locally.',
                ),
                SizedBox(height: 18),
                _FeatureRow(
                  icon: Icons.account_tree_rounded,
                  title: 'Derived offline wallet',
                  caption: 'A second wallet is derived for offline signing.',
                ),
                SizedBox(height: 18),
                _FeatureRow(
                  icon: Icons.swap_horiz_rounded,
                  title: 'Local handoff',
                  caption:
                      'Use hotspot HTTP or BLE to pass the signed transfer.',
                ),
                SizedBox(height: 18),
                _FeatureRow(
                  icon: Icons.cloud_upload_rounded,
                  title: 'Later settlement',
                  caption: 'Funds move on-chain only after a later broadcast.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const InlineBanner(
            title: 'Before you start',
            caption:
                'Finish setup online, fund the offline wallet, then use local handoff when internet drops.',
            icon: Icons.fact_check_rounded,
          ),
        ],
      ),
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
      Navigator.of(context).pushReplacementNamed(AppRoutes.onboardingFund);
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
      Navigator.of(context).pushReplacementNamed(AppRoutes.onboardingFund);
    } catch (error) {
      _showSnack(context, _messageFor(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    return BitsendPageScaffold(
      title: 'Set up this device',
      subtitle: 'Create a wallet or restore an existing one.',
      child: Column(
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
                  onPressed: state.working ? null : () => _createWallet(state),
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
                  onPressed: state.working ? null : () => _restoreWallet(state),
                  child: const Text('Restore wallet'),
                ),
              ],
            ),
          ),
          if (state.wallet != null) ...<Widget>[
            const SizedBox(height: 16),
            InlineBanner(
              title: 'Wallet ready',
              caption:
                  'Address ${state.wallet!.displayAddress}. Save the recovery phrase before you continue.',
              icon: Icons.verified_user_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

class FundWalletScreen extends StatelessWidget {
  const FundWalletScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final bool funded = state.hasEnoughFunding;
    return BitsendPageScaffold(
      title: 'Fund wallet',
      subtitle:
          'Add devnet SOL so setup can finish and the offline wallet can be topped up later.',
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
              children: <Widget>[
                MetricCard(
                  label: 'Device address',
                  value: state.wallet?.displayAddress ?? 'Wallet missing',
                  caption:
                      state.wallet?.address ??
                      'Create or restore a wallet first.',
                ),
                const SizedBox(height: 12),
                MetricCard(
                  label: 'Available balance',
                  value: Formatters.sol(state.mainBalanceSol),
                  caption: funded
                      ? 'Enough to continue.'
                      : 'Reach at least ${Formatters.sol(minimumFundingSol)} to continue.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InlineBanner(
            title: 'Minimum funding',
            caption:
                'Use an airdrop until the wallet clears the setup threshold.',
            icon: Icons.savings_rounded,
            action: TextButton(
              onPressed: () => _requestAirdrop(context, state),
              child: const Text('Airdrop'),
            ),
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
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _requestAirdrop(context, state),
            child: const Text('Request airdrop'),
          ),
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
    return BitsendPageScaffold(
      title: 'Offline wallet',
      subtitle:
          'A second wallet is derived automatically. Top it up from Home before any offline send.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionCard(
            child: Column(
              children: <Widget>[
                MetricCard(
                  label: 'Main wallet balance',
                  value: Formatters.sol(summary.balanceSol),
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
                  value: Formatters.sol(summary.offlineBalanceSol),
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

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final HomeStatus status = state.homeStatus;
    final WalletSummary summary = state.walletSummary;
    final List<PendingTransfer> recent = state.recentActivity();
    final bool canSend =
        state.hasWallet &&
        state.hasOfflineFunds &&
        state.hasOfflineReadyBlockhash;

    return BitsendPageScaffold(
      title: 'Home',
      actions: <Widget>[
        IconButton(
          onPressed: state.refreshStatus,
          tooltip: 'Refresh status',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      showBack: false,
      showHeader: false,
      primaryTab: BitsendPrimaryTab.home,
      onPrimaryTabSelected: (BitsendPrimaryTab tab) {
        _navigatePrimaryTab(context, tab);
      },
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
                label: 'Local link',
                active: status.hasLocalLink,
                icon: Icons.wifi_tethering_rounded,
              ),
              StatusRailChip(
                label: 'Devnet',
                active: status.hasDevnet,
                icon: Icons.cloud_done_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          FadeSlideIn(delay: 0, child: _DashboardHero(summary: summary)),
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: 40,
            child: _HomeSituationCard(
              hasOfflineFunds: state.hasOfflineFunds,
              hasReadyBlockhash: state.hasOfflineReadyBlockhash,
              hasLocalLink: status.hasLocalLink,
              canSend: canSend,
              onPrimary: () {
                Navigator.of(context).pushNamed(
                  canSend ? AppRoutes.sendTransport : AppRoutes.prepare,
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text('Actions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          Column(
            children: <Widget>[
              FadeSlideIn(
                delay: 100,
                child: ActionTile(
                  title: 'Deposit',
                  caption: 'Receive SOL',
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
                  title: 'Offline Wallet',
                  caption: 'Fund + refresh',
                  icon: Icons.account_balance_wallet_outlined,
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.prepare);
                  },
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                delay: 160,
                child: ActionTile(
                  title: 'Send',
                  caption: 'Handoff',
                  icon: Icons.send_rounded,
                  enabled: canSend,
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.sendTransport);
                  },
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                delay: 200,
                child: ActionTile(
                  title: 'Receive',
                  caption: 'Listen',
                  icon: Icons.call_received_rounded,
                  enabled: state.hasWallet,
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.receiveListen);
                  },
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                delay: 240,
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
    );
  }
}

enum _DepositTarget { main, offline }

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  _DepositTarget _target = _DepositTarget.main;

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
    final WalletProfile? targetWallet = _target == _DepositTarget.main
        ? state.wallet
        : state.offlineWallet;
    final String title = _target == _DepositTarget.main
        ? 'Main wallet'
        : 'Offline wallet';
    final String? fullAddress = targetWallet?.address;
    final String shortAddress = targetWallet?.displayAddress ?? 'Unavailable';
    final String balance = _target == _DepositTarget.main
        ? Formatters.sol(state.mainBalanceSol)
        : Formatters.sol(state.offlineBalanceSol);

    return BitsendPageScaffold(
      title: 'Deposit SOL',
      subtitle: 'Pick a wallet and share the address.',
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
          _DepositHero(
            title: title,
            shortAddress: shortAddress,
            balance: balance,
            statusLabel: _target == _DepositTarget.main
                ? 'Devnet'
                : state.hasOfflineReadyBlockhash
                ? 'Ready'
                : 'Needs refresh',
            statusIcon: _target == _DepositTarget.main
                ? Icons.cloud_done_rounded
                : state.hasOfflineReadyBlockhash
                ? Icons.check_circle_outline_rounded
                : Icons.update_rounded,
            statusActive:
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
                            : () => _requestAirdrop(state),
                        child: const Text('Airdrop'),
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
    return BitsendPageScaffold(
      title: 'Offline Wallet',
      subtitle: 'Fund once. Refresh before handoff.',
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
          _OfflineWalletScene(
            mainBalance: Formatters.sol(summary.balanceSol),
            offlineBalance: Formatters.sol(summary.offlineBalanceSol),
            spendableBalance: Formatters.sol(summary.offlineAvailableSol),
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
                Text('Move SOL', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                TextField(
                  controller: _topUpController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Top up amount in SOL',
                    hintText: '0.100',
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: state.working ? null : () => _topUp(state),
                  child: const Text('Top up offline wallet'),
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

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
    _endpointController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final BitsendAppState state = BitsendStateScope.of(context);
    _addressController.text = state.sendDraft.receiverAddress;
    _endpointController.text = state.sendDraft.receiverEndpoint;
    _selectedBleReceiverId = state.sendDraft.receiverPeripheralId.isEmpty
        ? null
        : state.sendDraft.receiverPeripheralId;
    _selectedBleReceiverName = state.sendDraft.receiverPeripheralName.isEmpty
        ? null
        : state.sendDraft.receiverPeripheralName;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _endpointController.dispose();
    super.dispose();
  }

  void _continue(BitsendAppState state) {
    if (state.sendDraft.transport == TransportKind.hotspot) {
      state.updateReceiver(
        receiverAddress: _addressController.text,
        receiverEndpoint: _endpointController.text,
      );
    } else {
      state.updateReceiver(
        receiverAddress: _addressController.text,
        receiverPeripheralId: _selectedBleReceiverId ?? '',
        receiverPeripheralName: _selectedBleReceiverName ?? '',
      );
    }
    if (!state.sendDraft.hasReceiver) {
      _showSnack(
        context,
        state.sendDraft.transport == TransportKind.hotspot
            ? 'Receiver address and endpoint are required.'
            : 'Receiver address and a discovered BLE device are required.',
      );
      return;
    }
    Navigator.of(context).pushNamed(AppRoutes.sendAmount);
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final TransportKind transport = state.sendDraft.transport;
    return BitsendPageScaffold(
      title: 'Choose receiver',
      subtitle: 'Pick the handoff method, then enter the receiver details.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
              });
            },
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
                  decoration: const InputDecoration(
                    labelText: 'Receiver address',
                    hintText: 'Receiver devnet address',
                  ),
                ),
                if (transport == TransportKind.hotspot) ...<Widget>[
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
                            : () async {
                                try {
                                  await state.scanBleReceivers();
                                } catch (error) {
                                  if (!context.mounted) {
                                    return;
                                  }
                                  _showSnack(context, _messageFor(error));
                                }
                              },
                        child: Text(
                          state.bleDiscovering ? 'Scanning...' : 'Scan',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (state.bleReceivers.isEmpty)
                    const InlineBanner(
                      title: 'No receiver selected',
                      caption:
                          'Open Receive on the other device, switch to BLE, then scan again.',
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
                                caption: item.subtitle,
                                selected: _selectedBleReceiverId == item.id,
                                onTap: () {
                                  setState(() {
                                    _selectedBleReceiverId = item.id;
                                    _selectedBleReceiverName = item.label;
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
        onPressed: () => _continue(state),
        child: const Text('Continue'),
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
    Navigator.of(context).pushNamed(AppRoutes.sendReview);
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final double amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final int lamports = (amount * 1000000000).round();
    return BitsendPageScaffold(
      title: 'Amount',
      subtitle: 'Enter the amount in SOL.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!state.hasOfflineReadyBlockhash)
            const InlineBanner(
              title: 'Refresh readiness first',
              caption:
                  'This flow signs from the offline wallet and needs a fresh blockhash.',
              icon: Icons.lock_clock_rounded,
            ),
          if (!state.hasOfflineReadyBlockhash) const SizedBox(height: 16),
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
                  decoration: const InputDecoration(
                    labelText: 'Amount in SOL',
                    hintText: '0.250',
                  ),
                  onChanged: (_) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 16),
                DetailRow(
                  label: 'Lamports',
                  value: Formatters.lamports(lamports),
                ),
                DetailRow(
                  label: 'Offline wallet available',
                  value: Formatters.sol(state.offlineSpendableBalanceSol),
                ),
                DetailRow(
                  label: 'Offline wallet',
                  value: state.offlineWallet?.displayAddress ?? 'Unavailable',
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: ElevatedButton(
        onPressed: state.hasOfflineReadyBlockhash && state.hasOfflineFunds
            ? () => _continue(state)
            : null,
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
      subtitle: 'Check the receiver, amount, and transport before signing.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const InlineBanner(
            title: 'When funds move',
            caption:
                'The receiver gets a signed transaction now. Settlement happens after broadcast.',
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              children: <Widget>[
                DetailRow(
                  label: 'Receiver',
                  value: Formatters.shortAddress(draft.receiverAddress),
                ),
                DetailRow(
                  label: 'Source wallet',
                  value:
                      state.offlineWallet?.displayAddress ??
                      'Offline wallet unavailable',
                ),
                DetailRow(
                  label: draft.transport == TransportKind.hotspot
                      ? 'Endpoint'
                      : 'BLE receiver',
                  value: draft.transport == TransportKind.hotspot
                      ? draft.receiverEndpoint
                      : draft.receiverPeripheralName,
                ),
                DetailRow(
                  label: 'Amount',
                  value: Formatters.sol(draft.amountSol),
                ),
                DetailRow(
                  label: 'Offline balance left',
                  value: Formatters.sol(
                    summary.offlineAvailableSol > draft.amountSol
                        ? summary.offlineAvailableSol - draft.amountSol
                        : 0,
                  ),
                ),
                DetailRow(
                  label: 'Blockhash age',
                  value: Formatters.durationLabel(summary.blockhashAge),
                ),
                DetailRow(label: 'Transport', value: draft.transport.label),
              ],
            ),
          ),
        ],
      ),
      bottom: ElevatedButton(
        onPressed: () {
          Navigator.of(context).pushNamed(AppRoutes.sendProgress);
        },
        child: const Text('Sign and send'),
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
    final List<_ProgressStep> steps = <_ProgressStep>[
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
          ? 'Signing locally and delivering over the selected link.'
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

class SendSuccessScreen extends StatelessWidget {
  const SendSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final PendingTransfer? transfer = state.lastSentTransfer;
    return BitsendPageScaffold(
      title: 'Delivered',
      subtitle:
          'The signed transfer was delivered and is waiting for broadcast.',
      child: transfer == null
          ? const EmptyStateCard(
              title: 'No transfer found',
              caption: 'Send a transfer first to see the delivery receipt.',
              icon: Icons.assignment_late_rounded,
            )
          : SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.emerald,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sent offline and queued for later settlement.',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  DetailRow(label: 'Transfer ID', value: transfer.transferId),
                  DetailRow(
                    label: 'Source wallet',
                    value: Formatters.shortAddress(transfer.senderAddress),
                  ),
                  DetailRow(label: 'Receiver', value: transfer.receiverAddress),
                  DetailRow(
                    label: 'Amount',
                    value: Formatters.sol(transfer.amountSol),
                  ),
                  DetailRow(
                    label: 'Transport',
                    value: transfer.transport.label,
                  ),
                  if (transfer.transactionSignature != null)
                    DetailRow(
                      label: 'Signature',
                      value: Formatters.shortAddress(
                        transfer.transactionSignature!,
                      ),
                    ),
                ],
              ),
            ),
      bottom: ElevatedButton(
        onPressed: () {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.pending,
            ModalRoute.withName(AppRoutes.home),
          );
        },
        child: const Text('Open pending'),
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
  String? _seenTransferId;
  String? _seenAnnouncement;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final BitsendAppState state = BitsendStateScope.of(context);
    if (!_started) {
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
      _seenTransferId = state.lastReceivedTransferId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushReplacementNamed(AppRoutes.receiveResult);
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
      _showSnack(context, _messageFor(error));
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
      _showSnack(context, _messageFor(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final TransportKind transport = state.receiveTransport;
    final bool activeListener = transport == TransportKind.hotspot
        ? state.hotspotListenerRunning
        : state.bleListenerRunning;
    return BitsendPageScaffold(
      title: 'Receive',
      subtitle: 'Listen on hotspot or BLE and store validated transfers.',
      actions: <Widget>[
        IconButton(
          onPressed: state.refreshStatus,
          tooltip: 'Refresh status',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
            onSelectionChanged: (Set<TransportKind> value) async {
              if (state.listenerRunning) {
                await state.stopReceiver();
              }
              state.setReceiveTransport(value.first);
            },
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              children: <Widget>[
                MetricCard(
                  label: 'Listener status',
                  value: activeListener ? 'Ready to receive' : 'Stopped',
                  caption: activeListener
                      ? (transport == TransportKind.hotspot
                            ? 'The local HTTP server is listening on port 8787.'
                            : 'The device is advertising the bitsend BLE service.')
                      : 'Tap start to accept transfers.',
                ),
                const SizedBox(height: 12),
                MetricCard(
                  label: 'Receiver address',
                  value: state.wallet?.displayAddress ?? 'Wallet missing',
                  caption: state.wallet?.address ?? 'Set up the wallet first.',
                ),
                const SizedBox(height: 12),
                MetricCard(
                  label: transport == TransportKind.hotspot
                      ? 'Local endpoint'
                      : 'BLE service',
                  value: transport == TransportKind.hotspot
                      ? (state.localEndpoint ?? 'No local IP available')
                      : 'bitsend BLE receiver',
                  caption: transport == TransportKind.hotspot
                      ? 'Share this with the sender.'
                      : 'Ask the sender to pick BLE and scan for this device.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InlineBanner(
            title: 'Validation',
            caption:
                'Only envelopes with matching signer, receiver, amount, and checksum are stored.',
            icon: Icons.rule_rounded,
          ),
        ],
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ElevatedButton(
            onPressed: () => _toggle(state),
            child: Text(activeListener ? 'Stop listener' : 'Start listener'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.pending);
            },
            child: const Text('Open pending'),
          ),
        ],
      ),
    );
  }
}

class ReceiveResultScreen extends StatelessWidget {
  const ReceiveResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final PendingTransfer? transfer = state.lastReceivedTransfer;
    return BitsendPageScaffold(
      title: 'Received',
      subtitle: 'The signed transfer was saved and is waiting for broadcast.',
      child: transfer == null
          ? const EmptyStateCard(
              title: 'No transfer stored yet',
              caption:
                  'Start listening and wait for the sender to deliver a transfer.',
              icon: Icons.inbox_rounded,
            )
          : SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.inventory_2_rounded,
                        color: AppColors.amber,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Received and queued for broadcast.',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  DetailRow(label: 'Transfer ID', value: transfer.transferId),
                  DetailRow(label: 'Sender', value: transfer.senderAddress),
                  DetailRow(
                    label: 'Amount',
                    value: Formatters.sol(transfer.amountSol),
                  ),
                  if (transfer.transactionSignature != null)
                    DetailRow(
                      label: 'Signature',
                      value: Formatters.shortAddress(
                        transfer.transactionSignature!,
                      ),
                    ),
                ],
              ),
            ),
      bottom: ElevatedButton(
        onPressed: () {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.pending,
            ModalRoute.withName(AppRoutes.home),
          );
        },
        child: const Text('Open pending'),
      ),
    );
  }
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
                DetailRow(label: 'Sender', value: transfer.senderAddress),
                DetailRow(label: 'Receiver', value: transfer.receiverAddress),
                DetailRow(
                  label: 'Amount',
                  value: Formatters.sol(transfer.amountSol),
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
        onRetry:
            transfer.isInbound &&
                (transfer.status == TransferStatus.broadcastFailed ||
                    transfer.status == TransferStatus.receivedPendingBroadcast)
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

  @override
  void initState() {
    super.initState();
    _rpcController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rpcController.text = BitsendStateScope.of(context).rpcEndpoint;
  }

  @override
  void dispose() {
    _rpcController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
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
                  decoration: const InputDecoration(
                    hintText: 'https://api.devnet.solana.com',
                  ),
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
                'Clearing local data removes the wallet, queue, cached blockhash, and saved RPC settings from this device.',
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

class _HomeSituationCard extends StatelessWidget {
  const _HomeSituationCard({
    required this.hasOfflineFunds,
    required this.hasReadyBlockhash,
    required this.hasLocalLink,
    required this.canSend,
    required this.onPrimary,
  });

  final bool hasOfflineFunds;
  final bool hasReadyBlockhash;
  final bool hasLocalLink;
  final bool canSend;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final String title = canSend
        ? 'Ready to send'
        : !hasOfflineFunds
        ? 'Fund offline wallet'
        : 'Refresh before send';

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              TextButton(
                onPressed: onPrimary,
                child: Text(canSend ? 'Send' : 'Open'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SituationFlow(
            hasOfflineFunds: hasOfflineFunds,
            hasReadyBlockhash: hasReadyBlockhash,
            canSend: canSend,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _MiniCue(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Offline',
                active: hasOfflineFunds,
              ),
              _MiniCue(
                icon: Icons.bolt_rounded,
                label: 'Ready',
                active: hasReadyBlockhash,
              ),
              _MiniCue(
                icon: Icons.wifi_tethering_rounded,
                label: 'Link',
                active: hasLocalLink,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SituationFlow extends StatelessWidget {
  const _SituationFlow({
    required this.hasOfflineFunds,
    required this.hasReadyBlockhash,
    required this.canSend,
  });

  final bool hasOfflineFunds;
  final bool hasReadyBlockhash;
  final bool canSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(
          child: _SituationNode(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Main',
            active: true,
          ),
        ),
        _FlowConnector(active: hasOfflineFunds),
        Expanded(
          child: _SituationNode(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Offline',
            active: hasOfflineFunds,
          ),
        ),
        _FlowConnector(active: hasReadyBlockhash),
        Expanded(
          child: _SituationNode(
            icon: Icons.send_rounded,
            label: 'Send',
            active: canSend,
          ),
        ),
      ],
    );
  }
}

class _SituationNode extends StatelessWidget {
  const _SituationNode({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: active
                ? AppColors.emeraldTint
                : Colors.white.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: active ? AppColors.emerald : AppColors.slate,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _FlowConnector extends StatelessWidget {
  const _FlowConnector({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 22),
        decoration: BoxDecoration(
          color: active ? AppColors.emerald : AppColors.line,
          borderRadius: BorderRadius.circular(999),
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
                          'Main',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white70,
                                letterSpacing: 0.7,
                              ),
                        ),
                        const Spacer(),
                        _HeroStatusChip(ready: summary.readyForOffline),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      Formatters.sol(summary.balanceSol),
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
                            label: 'Offline',
                            value: Formatters.sol(summary.offlineBalanceSol),
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                        ),
                        SizedBox(
                          width: statWidth,
                          child: _HeroMetric(
                            label: 'Spendable',
                            value: Formatters.sol(summary.offlineAvailableSol),
                            icon: Icons.arrow_outward_rounded,
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(
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
  const _HeroStatusChip({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    final Color textColor = ready ? Colors.white : AppColors.amberTint;
    return Semantics(
      label: 'Offline readiness',
      value: ready ? 'Ready' : 'Needs refresh',
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
              ready ? Icons.check_circle_outline_rounded : Icons.update_rounded,
              size: 14,
              color: textColor,
            ),
            const SizedBox(width: 5),
            Text(
              ready ? 'Ready' : 'Refresh',
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

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.caption,
  });

  final IconData icon;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      hint: caption,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.ink),
          ),
          const SizedBox(width: 14),
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
      value: '${Formatters.sol(transfer.amountSol)}, ${transfer.status.label}',
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
                  Formatters.sol(transfer.amountSol),
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
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String caption;
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
        transfer.status == TransferStatus.receivedPendingBroadcast
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
  if (text.startsWith('FormatException: ')) {
    return text.replaceFirst('FormatException: ', '');
  }
  return text;
}
