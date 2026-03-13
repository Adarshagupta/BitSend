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
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Offline handoff now. Online settlement later.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                      ),
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                            ),
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
      title: 'Move a signed Solana payment before the internet returns.',
      subtitle:
          'bitsend signs a real devnet transfer locally, hands the signed payload to the receiver over a local link, and broadcasts it later when either device gets online.',
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
                  title: 'Local non-custodial wallet',
                  caption: 'Each device creates or restores its own Solana devnet keypair.',
                ),
                SizedBox(height: 18),
                _FeatureRow(
                  icon: Icons.account_tree_rounded,
                  title: 'Derived offline wallet',
                  caption: 'A second real account is derived from the same recovery phrase and can be topped up while online.',
                ),
                SizedBox(height: 18),
                _FeatureRow(
                  icon: Icons.swap_horiz_rounded,
                  title: 'Two real local transports',
                  caption: 'Hotspot HTTP is primary, and BLE is available as a real secondary handoff path.',
                ),
                SizedBox(height: 18),
                _FeatureRow(
                  icon: Icons.cloud_upload_rounded,
                  title: 'Delayed settlement',
                  caption: 'The signed offline-wallet transfer is only on-chain after the receiver or sender later broadcasts it.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const InlineBanner(
            title: 'Operational constraints',
            caption:
                'Wallet setup stays fully online. Offline mode starts only after you move funds into the derived offline wallet and hand off the signed transaction locally.',
            icon: Icons.fact_check_rounded,
          ),
        ],
      ),
      bottom: ElevatedButton(
        onPressed: () {
          Navigator.of(context).pushReplacementNamed(AppRoutes.onboardingWallet);
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
      title: 'Create or restore your device wallet',
      subtitle:
          'Both the sender and receiver use the same app. The role changes only by the action they pick next.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Create new wallet', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Generate a fresh local wallet for this device and continue to funding.',
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
                Text('Restore from phrase', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Paste the 12-word recovery phrase if you want to continue with an existing wallet on this device.',
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
                  'Active address ${state.wallet!.displayAddress}. Save the recovery phrase before moving to funding.',
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

  Future<void> _requestAirdrop(BuildContext context, BitsendAppState state) async {
    try {
      await state.requestAirdrop();
    } catch (error) {
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
      _showSnack(context, _messageFor(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final bool funded = state.hasEnoughFunding;
    return BitsendPageScaffold(
      title: 'Fund the device wallet',
      subtitle:
          'Fund the main wallet first. After onboarding, you can move part of this balance into the derived offline wallet for hotspot or BLE handoff.',
      actions: <Widget>[
        IconButton(
          onPressed: () => _refresh(context, state),
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
                  caption: state.wallet?.address ?? 'Create or restore a wallet first.',
                ),
                const SizedBox(height: 12),
                MetricCard(
                  label: 'Available balance',
                  value: Formatters.sol(state.mainBalanceSol),
                  caption: funded
                      ? 'Enough to finish setup and open the dashboard.'
                      : 'Reach at least ${Formatters.sol(minimumFundingSol)} before continuing.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InlineBanner(
            title: 'Funding rule',
            caption:
                'Continue unlocks only after the wallet has enough devnet SOL for a transfer amount plus some fee headroom.',
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
            child: const Text('Continue to home'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _requestAirdrop(context, state),
            child: const Text('Request devnet airdrop'),
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
      title: 'Offline wallet comes next',
      subtitle:
          'Main wallet setup is complete. From the dashboard, top up the derived offline wallet and refresh send readiness right before the local handoff.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionCard(
            child: Column(
              children: <Widget>[
                MetricCard(
                  label: 'Main wallet balance',
                  value: Formatters.sol(summary.balanceSol),
                  caption: 'Source balance for later offline-wallet top ups.',
                ),
                const SizedBox(height: 12),
                MetricCard(
                  label: 'Offline wallet',
                  value: summary.offlineWalletAddress == null
                      ? 'Unavailable'
                      : Formatters.shortAddress(summary.offlineWalletAddress!),
                  caption: 'Derived automatically from the same recovery phrase.',
                ),
                const SizedBox(height: 12),
                MetricCard(
                  label: 'Offline wallet balance',
                  value: Formatters.sol(summary.offlineBalanceSol),
                  caption: 'Move funds here from the dashboard before attempting an offline send.',
                ),
                const SizedBox(height: 12),
                MetricCard(
                  label: 'Local endpoint',
                  value: summary.localEndpoint ?? 'Not available yet',
                  caption:
                      'The receiver shares this endpoint while listening on the hotspot or local Wi-Fi.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InlineBanner(
            title: 'Permissions',
            caption: state.localPermissionsGranted
                ? 'Local network permissions are already granted.'
                : 'Location and nearby-device permissions are requested here because Android uses them for local transport.',
            icon: Icons.perm_device_information_rounded,
          ),
        ],
      ),
      bottom: ElevatedButton(
        onPressed: () {
          Navigator.of(context).pushReplacementNamed(AppRoutes.home);
        },
        child: const Text('Continue to home'),
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
    final bool canSend = state.hasWallet && state.hasOfflineFunds && state.hasOfflineReadyBlockhash;

    return BitsendPageScaffold(
      title: 'Home',
      subtitle:
          'The dashboard answers three things immediately: internet reachability, offline send readiness, and the next action to take.',
      actions: <Widget>[
        IconButton(
          onPressed: state.refreshStatus,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          onPressed: () {
            Navigator.of(context).pushNamed(AppRoutes.settings);
          },
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
      showBack: false,
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
          const SizedBox(height: 18),
          FadeSlideIn(
            delay: 0,
            child: _DashboardHero(summary: summary),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: 40,
            child: SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Readiness', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 14),
                  _ChecklistRow(
                    label: 'Wallet created',
                    complete: state.hasWallet,
                    caption: 'A local device wallet exists.',
                  ),
                  const SizedBox(height: 12),
                  _ChecklistRow(
                    label: 'Main wallet funded',
                    complete: state.hasEnoughFunding,
                    caption: 'Balance is above ${Formatters.sol(minimumFundingSol)}.',
                  ),
                  const SizedBox(height: 12),
                  _ChecklistRow(
                    label: 'Offline wallet funded',
                    complete: state.hasOfflineFunds,
                    caption: state.hasOfflineFunds
                        ? 'Funds are available to sign from the offline wallet.'
                        : 'Use Offline Wallet to move funds from the main wallet first.',
                  ),
                  const SizedBox(height: 12),
                  _ChecklistRow(
                    label: 'Send readiness refreshed',
                    complete: state.hasOfflineReadyBlockhash,
                    caption: state.hasOfflineReadyBlockhash
                        ? 'Fresh blockhash is cached.'
                        : 'Refresh readiness right before the offline handoff.',
                  ),
                ],
              ),
            ),
          ),
          if (!canSend) ...<Widget>[
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: 80,
              child: InlineBanner(
                title: 'Send is locked',
                caption: !state.hasOfflineFunds
                    ? 'Move funds into the offline wallet first.'
                    : 'Refresh send readiness before sending so the app has a fresh blockhash.',
                icon: Icons.lock_clock_rounded,
                action: TextButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.prepare);
                  },
                  child: const Text('Offline Wallet'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text('Actions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.98,
            children: <Widget>[
              FadeSlideIn(
                delay: 100,
                child: ActionTile(
                  title: 'Offline Wallet',
                  caption: 'Top up the derived offline wallet and refresh send readiness.',
                  icon: Icons.account_balance_wallet_outlined,
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.prepare);
                  },
                ),
              ),
              FadeSlideIn(
                delay: 140,
                child: ActionTile(
                  title: 'Send',
                  caption: 'Sign a real transfer and deliver it over hotspot or BLE.',
                  icon: Icons.send_rounded,
                  enabled: canSend,
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.sendTransport);
                  },
                ),
              ),
              FadeSlideIn(
                delay: 180,
                child: ActionTile(
                  title: 'Receive',
                  caption: 'Expose a hotspot or BLE listener and store inbound transfers.',
                  icon: Icons.call_received_rounded,
                  enabled: state.hasWallet,
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.receiveListen);
                  },
                ),
              ),
              FadeSlideIn(
                delay: 220,
                child: ActionTile(
                  title: 'Pending',
                  caption: 'Track offline handoffs, broadcasts, and confirmations.',
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
          Text('Recent activity', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          if (recent.isEmpty)
            const EmptyStateCard(
              title: 'No transfers yet',
              caption: 'Send or receive the first signed transfer to populate the queue.',
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
      subtitle:
          'This real Solana account is derived from the same recovery phrase. Top it up while online, then sign offline transfers from it later.',
      actions: <Widget>[
        IconButton(
          onPressed: state.refreshStatus,
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
                  label: 'Main wallet balance',
                  value: Formatters.sol(summary.balanceSol),
                  caption: state.wallet?.displayAddress ?? 'Main wallet missing.',
                ),
                const SizedBox(height: 12),
                MetricCard(
                  label: 'Offline wallet address',
                  value: summary.offlineWalletAddress == null
                      ? 'Unavailable'
                      : Formatters.shortAddress(summary.offlineWalletAddress!),
                  caption: summary.offlineWalletAddress ?? 'Derived from the same recovery phrase.',
                ),
                const SizedBox(height: 12),
                MetricCard(
                  label: 'Offline wallet balance',
                  value: Formatters.sol(summary.offlineBalanceSol),
                  caption:
                      'Available on-chain in the offline wallet before app-side reservations.',
                ),
                const SizedBox(height: 12),
                MetricCard(
                  label: 'Available to send',
                  value: Formatters.sol(summary.offlineAvailableSol),
                  caption: 'Pending offline handoffs are reserved from this amount.',
                ),
                const SizedBox(height: 12),
                MetricCard(
                  label: 'Send readiness',
                  value: summary.readyForOffline ? 'Fresh blockhash cached' : 'Needs refresh',
                  caption: summary.readyForOffline
                      ? 'Fetched ${Formatters.durationLabel(summary.blockhashAge)}.'
                      : 'Refresh this shortly before going offline.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Top up offline wallet', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'This sends a real on-chain transfer from the main wallet into the derived offline wallet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _topUpController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Top up amount in SOL',
                    hintText: '0.100',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: state.working ? null : () => _topUp(state),
                  child: const Text('Move funds to offline wallet'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InlineBanner(
            title: 'Operational note',
            caption:
                'Because the offline payment still uses a standard Solana transaction, refresh send readiness shortly before the judged handoff to minimize blockhash expiry risk.',
            icon: Icons.timelapse_rounded,
          ),
        ],
      ),
      bottom: ElevatedButton(
        onPressed: state.working ? null : () => _refreshReadiness(state),
        child: const Text('Refresh send readiness'),
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
      subtitle:
          'Choose the real transport you will use for the handoff, then enter the receiver address shown on the other device.',
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
                Text('Receiver address', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    hintText: 'Solana devnet address',
                  ),
                ),
                if (transport == TransportKind.hotspot) ...<Widget>[
                  const SizedBox(height: 18),
                  Text('Receiver endpoint', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _endpointController,
                    decoration: const InputDecoration(
                      hintText: '192.168.1.22:8787 or http://192.168.1.22:8787',
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
                        child: Text(state.bleDiscovering ? 'Scanning...' : 'Scan'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (state.bleReceivers.isEmpty)
                    const InlineBanner(
                      title: 'No BLE receiver selected',
                      caption:
                          'Ask the other device to switch Receive to BLE and start advertising, then scan again here.',
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
        child: const Text('Continue to amount'),
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
      title: 'Enter amount',
      subtitle:
          'Amount entry stays in SOL for readability, with the raw lamport value shown underneath for the signed offline-wallet transaction.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!state.hasOfflineReadyBlockhash)
            const InlineBanner(
              title: 'Refresh send readiness first',
              caption:
                  'This flow signs from the offline wallet. Refresh a fresh blockhash while online right before the offline exchange.',
              icon: Icons.lock_clock_rounded,
            ),
          if (!state.hasOfflineReadyBlockhash) const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
        subtitle: 'Receiver and amount are both required before signing.',
        child: const EmptyStateCard(
          title: 'Transfer not ready',
          caption: 'Go back and complete the receiver and amount steps first.',
          icon: Icons.assignment_late_rounded,
        ),
      );
    }

    return BitsendPageScaffold(
      title: 'Review transfer',
      subtitle:
          'This signs a real Solana devnet transfer from the derived offline wallet and sends the signed envelope over the local link.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const InlineBanner(
            title: 'Settlement timing',
            caption:
                'The receiver gets a signed transaction offline, but the actual deduction happens only after later broadcast.',
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              children: <Widget>[
                DetailRow(label: 'Receiver', value: Formatters.shortAddress(draft.receiverAddress)),
                DetailRow(
                  label: 'Source wallet',
                  value: state.offlineWallet?.displayAddress ?? 'Offline wallet unavailable',
                ),
                DetailRow(
                  label: draft.transport == TransportKind.hotspot ? 'Endpoint' : 'BLE receiver',
                  value: draft.transport == TransportKind.hotspot
                      ? draft.receiverEndpoint
                      : draft.receiverPeripheralName,
                ),
                DetailRow(label: 'Amount', value: Formatters.sol(draft.amountSol)),
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
                DetailRow(
                  label: 'Transport',
                  value: draft.transport.label,
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
        child: const Text('Sign and send offline'),
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
        title: 'Signing from offline wallet',
        caption: 'The derived offline wallet creates the Solana transfer locally.',
        complete: _stage > 0,
        current: _stage == 0,
      ),
      _ProgressStep(
        title: 'Sending offline',
        caption: transport == TransportKind.hotspot
            ? 'The signed envelope is posted to the receiver endpoint over the local network.'
            : 'The signed envelope is streamed over BLE to the receiver device.',
        complete: _stage > 1,
        current: _stage == 1,
      ),
      _ProgressStep(
        title: 'Delivered',
        caption: 'Receiver accepted the signed transfer and stored it.',
        complete: _stage > 1 && _error == null,
        current: _stage == 2,
      ),
    ];

    return BitsendPageScaffold(
      title: 'Sending transfer',
      subtitle: _error == null
          ? 'The sender signs first, then the app pushes the signed envelope across the selected local transport.'
          : 'Transport or validation failed before delivery.',
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
                      padding: EdgeInsets.only(bottom: entry.key == steps.length - 1 ? 0 : 16),
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
              child: Center(
                child: CircularProgressIndicator(),
              ),
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
                  child: const Text('Retry transfer'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Back to review'),
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
      title: 'Transfer delivered',
      subtitle:
          'The offline-wallet transaction was handed off offline and is now waiting for later broadcast.',
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
                      const Icon(Icons.check_circle_rounded, color: AppColors.emerald),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sent offline - awaiting internet for settlement.',
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
                  DetailRow(label: 'Amount', value: Formatters.sol(transfer.amountSol)),
                  DetailRow(label: 'Transport', value: transfer.transport.label),
                  if (transfer.transactionSignature != null)
                    DetailRow(
                      label: 'Signature',
                      value: Formatters.shortAddress(transfer.transactionSignature!),
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
        child: const Text('View pending'),
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
    if (state.announcementMessage != null && state.announcementMessage != _seenAnnouncement) {
      _seenAnnouncement = state.announcementMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _showSnack(context, state.announcementMessage!);
        state.clearAnnouncement();
      });
    }
    if (state.lastReceivedTransferId != null && state.lastReceivedTransferId != _seenTransferId) {
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
      subtitle:
          'This device can receive over hotspot HTTP or BLE, validate the signed transfer, and store it for later broadcast.',
      actions: <Widget>[
        IconButton(
          onPressed: state.refreshStatus,
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
                      : 'Tap start to accept incoming transfers.',
                ),
                const SizedBox(height: 12),
                MetricCard(
                  label: 'Receiver address',
                  value: state.wallet?.displayAddress ?? 'Wallet missing',
                  caption: state.wallet?.address ?? 'Set up the wallet first.',
                ),
                const SizedBox(height: 12),
                MetricCard(
                  label: transport == TransportKind.hotspot ? 'Local endpoint' : 'BLE service',
                  value: transport == TransportKind.hotspot
                      ? (state.localEndpoint ?? 'No local IP available')
                      : 'bitsend BLE receiver',
                  caption: transport == TransportKind.hotspot
                      ? 'Share this with the sender. They can enter it manually in the Send flow.'
                      : 'Ask the sender to pick BLE in Send and scan for this device.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InlineBanner(
            title: 'Validation rules',
            caption:
                'The receiver only stores envelopes whose signer, recipient, amount, and checksum all match the signed transaction bytes.',
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
            child: const Text('View pending queue'),
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
      title: 'Transfer received',
      subtitle: 'The inbound envelope has been validated locally and queued for broadcast.',
      child: transfer == null
          ? const EmptyStateCard(
              title: 'No transfer stored yet',
              caption: 'Start the listener and wait for the sender to post the signed envelope.',
              icon: Icons.inbox_rounded,
            )
          : SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.inventory_2_rounded, color: AppColors.amber),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Received incoming transfer - pending broadcast.',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  DetailRow(label: 'Transfer ID', value: transfer.transferId),
                  DetailRow(label: 'Sender', value: transfer.senderAddress),
                  DetailRow(label: 'Amount', value: Formatters.sol(transfer.amountSol)),
                  if (transfer.transactionSignature != null)
                    DetailRow(
                      label: 'Signature',
                      value: Formatters.shortAddress(transfer.transactionSignature!),
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
        child: const Text('View pending'),
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
      subtitle:
          'Outbound items show what was handed off offline. Inbound items show whether broadcast has started, failed, or confirmed.',
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
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
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
  const TransferDetailScreen({
    super.key,
    required this.transferId,
  });

  final String transferId;

  Future<void> _retry(BuildContext context, BitsendAppState state, PendingTransfer transfer) async {
    try {
      await state.retryBroadcast(transfer.transferId);
    } catch (error) {
      _showSnack(context, _messageFor(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final BitsendAppState state = BitsendStateScope.of(context);
    final PendingTransfer? transfer = state.transferById(transferId);
    if (transfer == null) {
      return const BitsendPageScaffold(
        title: 'Unknown transfer',
        subtitle: 'This transfer was not found in the local queue.',
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
      subtitle:
          'Everything the judges need is on one screen: timeline, transaction metadata, and the next available action.',
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
                        transfer.isInbound ? 'Inbound transfer' : 'Outbound transfer',
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
                DetailRow(label: 'Amount', value: Formatters.sol(transfer.amountSol)),
                DetailRow(label: 'Created', value: Formatters.dateTime(transfer.createdAt)),
                DetailRow(label: 'Updated', value: Formatters.dateTime(transfer.updatedAt)),
                if (transfer.remoteEndpoint != null)
                  DetailRow(label: 'Endpoint', value: transfer.remoteEndpoint!),
                if (transfer.transactionSignature != null)
                  DetailRow(label: 'Signature', value: transfer.transactionSignature!),
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
                        (MapEntry<int, TransferTimelineState> entry) => TimelineStepTile(
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
                  Text('Explorer', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Text(transfer.explorerUrl!, style: Theme.of(context).textTheme.bodyMedium),
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
        onRetry: transfer.isInbound &&
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
      subtitle:
          'Recovery phrase, permissions, RPC endpoint, and a hard reset of local queue data are kept here.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Recovery phrase', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  state.wallet?.seedPhrase ?? 'Wallet not created yet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  state.offlineWallet == null
                      ? 'Offline wallet unavailable.'
                      : 'Offline wallet ${state.offlineWallet!.displayAddress} is derived from this same recovery phrase.',
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
                Text('RPC endpoint', style: Theme.of(context).textTheme.titleLarge),
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
                  child: const Text('Save RPC endpoint'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Permissions', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  state.localPermissionsGranted
                      ? 'Local transport permissions granted.'
                      : 'Local transport permissions still need approval.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: state.requestLocalPermissions,
                  child: const Text('Request permissions'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const InlineBanner(
            title: 'Reset',
            caption:
                'Clearing local data removes the wallet, queue, cached blockhash, and saved RPC endpoint from this device.',
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

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.summary,
  });

  final WalletSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.heroStart, AppColors.heroEnd],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Main wallet balance',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            Formatters.sol(summary.balanceSol),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _HeroMetric(
                label: 'Offline wallet',
                value: Formatters.sol(summary.offlineBalanceSol),
              ),
              _HeroMetric(
                label: 'Available to send',
                value: Formatters.sol(summary.offlineAvailableSol),
              ),
              _HeroMetric(
                label: 'Readiness',
                value: summary.readyForOffline ? 'Ready' : 'Refresh',
              ),
              _HeroMetric(
                label: 'Endpoint',
                value: summary.localEndpoint == null ? 'Unavailable' : 'Shared in Receive',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.label,
    required this.complete,
    required this.caption,
  });

  final String label;
  final bool complete;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final Color color = complete ? AppColors.emerald : AppColors.amber;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          complete ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: color,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(caption, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
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
    return Row(
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
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({
    required this.transfer,
    required this.onTap,
  });

  final PendingTransfer transfer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.canvasWarm,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      transfer.isInbound ? 'Inbound transfer' : 'Outbound transfer',
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
    return Material(
      color: selected ? AppColors.emeraldTint : AppColors.canvasWarm,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? AppColors.emerald : AppColors.line,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.emerald : AppColors.mutedInk,
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
        ),
      ),
    );
  }
}

class _TransferDetailActions extends StatelessWidget {
  const _TransferDetailActions({
    required this.transfer,
    this.onRetry,
  });

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
  const _ProgressTile({
    required this.step,
  });

  final _ProgressStep step;

  @override
  Widget build(BuildContext context) {
    final Color color =
        step.complete || step.current ? AppColors.ink : AppColors.line;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 18,
          height: 18,
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
              Text(step.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(step.caption, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

String _messageFor(Object error) {
  final String text = error.toString();
  if (text.startsWith('FormatException: ')) {
    return text.replaceFirst('FormatException: ', '');
  }
  return text;
}
