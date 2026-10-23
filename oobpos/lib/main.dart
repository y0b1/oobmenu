import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'operations.dart';
import 'reports.dart';
import 'theme/transaction_theme.dart';
import 'theme/oob_typography.dart';
import 'theme/oob_colors.dart';
import 'widgets/footer_wordmark.dart';

const bridge = MethodChannel('oob/pos');
String money(num amount) => '₱\u2009${(amount / 100).toStringAsFixed(2)}';
String timestamp(dynamic value) => value == null
    ? ''
    : DateTime.fromMillisecondsSinceEpoch(value as int)
        .toLocal()
        .toString()
        .split('.')
        .first;
void main() => runApp(const PosApp());

class PosApp extends StatelessWidget {
  const PosApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'OOB POS',
        debugShowCheckedModeBanner: false,
        theme: transactionTheme(
            ThemeData(useMaterial3: true, fontFamily: 'Mulish')),
        home: const CashierScreen(),
      );
}

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});
  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  Map<String, dynamic> status = {};
  Map<String, dynamic> operations = {};
  List<dynamic> orders = [];
  String search = '', error = '';
  bool hideCompleted = true;
  int? selected;
  bool connection = false, busy = false, refreshing = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (refreshing) return;
    refreshing = true;
    try {
      final s = jsonDecode((await bridge.invokeMethod<String>('status'))!);
      final h = jsonDecode((await bridge.invokeMethod<String>('history'))!);
      final o = jsonDecode((await bridge.invokeMethod<String>('operations'))!);
      if (mounted) {
        setState(() {
          status = Map<String, dynamic>.from(s);
          orders = h as List;
          operations = Map<String, dynamic>.from(o);
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      refreshing = false;
    }
  }

  Future<void> action(String method, [dynamic args]) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final response = await bridge.invokeMethod(method, args);
      if (mounted && method == 'export') {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$response')));
      }
      await refresh();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> cashierAction(String operation, Map<String, dynamic> args) =>
      action('cashier', jsonEncode({'operation': operation, ...args}));

  Map? get transactionShift =>
      (operations['transactionOperator'] ?? operations['activeShift']) as Map?;

  Future<void> decide(Map<String, dynamic> order, bool paid) async {
    final shift = transactionShift;
    if (shift == null) {
      setState(() => error = 'Start a cashier shift before processing orders.');
      return;
    }
    if (paid) {
      await paymentDialog(context, order, operations);
    } else {
      final reason = TextEditingController();
      final pin = TextEditingController();
      await operationDialog(context,
          title: 'Cancel unpaid order?',
          button: 'Cancel order',
          content: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${order['number']} · ${money(order['total'])}'),
                const SizedBox(height: 16),
                TextField(
                    controller: reason,
                    maxLength: 500,
                    decoration: const InputDecoration(
                        labelText: 'Cancellation reason (optional)')),
                if (operations['requirePin'] == true) pinField(pin),
              ]),
          submit: () => operate('cancel', {
                'id': order['id'],
                'shiftId': shift['id'],
                'reason': reason.text.trim(),
                'pin': pin.text
              }));
    }
    await refresh();
  }

  Future<void> review(Map<String, dynamic> order) async {
    final shift = transactionShift;
    await operationDialog(context,
        title: 'Recheck order verbally',
        button: 'Customer confirmed the order',
        content: (_) => Text(
            'Read back the items, quantities, modifiers and notes for ${order['number']} to the customer. Confirm the total of ${money(order['total'])} before checking payment.'),
        submit: () => operate('review',
            {'id': order['id'], 'shiftId': shift?['id'], 'confirmed': true}));
    await refresh();
  }

  Widget connectionScreen() =>
      ListView(padding: const EdgeInsets.all(24), children: [
        const TransactionHeading('CONNECTION',
            subtitle: 'Pair the customer menu'),
        const SizedBox(height: 16),
        const Text(
            'Enable this tablet’s Wi-Fi hotspot in Android Settings. Keep mobile data off. Connect the menu tablet to that hotspot.'),
        const SizedBox(height: 24),
        Text(
            status['running'] == true
                ? 'HTTPS service running'
                : 'Service stopped',
            style: const TextStyle(fontSize: 24)),
        if ('${status['error'] ?? ''}'.isNotEmpty)
          Text('${status['error']}', style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 16),
        Wrap(spacing: 16, runSpacing: 16, children: [
          FilledButton(
              onPressed: busy
                  ? null
                  : () => action(status['running'] == true ? 'stop' : 'start'),
              child: Text(status['running'] == true
                  ? 'Stop local service'
                  : 'Start local service')),
          OutlinedButton(
              onPressed: busy || status['running'] != true
                  ? null
                  : () => action('code'),
              child: const Text('Generate pairing code')),
        ]),
        const SizedBox(height: 24),
        const Text('Reachable interfaces (choose the hotspot address):'),
        for (final address in status['addresses'] as List? ?? [])
          SelectableText(
              '${address['address']}:${status['port']} (${address['interface']})',
              style: const TextStyle(fontSize: 22)),
        if ((status['addresses'] as List? ?? []).isEmpty)
          const Text(
              'No LAN address yet. Enable the hotspot, then wait a few seconds.'),
        const SizedBox(height: 24),
        Text(
            'Pairing code: ${status['code'] == '' || status['code'] == null ? 'Generate a new code' : status['code']}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const Text(
            'Single use, expires in 5 minutes. Five failed attempts lock pairing for 5 minutes.'),
        const SizedBox(height: 24),
        const Text(
            'TLS certificate SHA-256 fingerprint. Enter all 64 characters on the menu tablet; compare directly with this screen.'),
        SelectableText('${status['fingerprint'] ?? ''}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 20)),
        const SizedBox(height: 24),
        Text(status['connected'] == true
            ? 'Menu tablet connected (seen in the last 10 seconds)'
            : 'No menu tablet currently connected'),
        const SizedBox(height: 24),
        OutlinedButton(
            onPressed: busy
                ? null
                : () async {
                    final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                                title: const Text('Revoke menu credentials?'),
                                content: const Text(
                                    'All menu tablets will need to pair again. Complete active orders first; existing orders remain in history.'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Back')),
                                  FilledButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Revoke'))
                                ]));
                    if (ok == true) await action('revoke');
                  },
            child: const Text('Revoke paired menu devices')),
        const SizedBox(height: 16),
        OutlinedButton(
            onPressed: busy ? null : () => action('export'),
            child: const Text('Export order history to a local file')),
      ]);
  Widget details(Map<String, dynamic> order) =>
      ListView(padding: const EdgeInsets.all(24), children: [
        TransactionHeading('${order['number']}', subtitle: 'Order details'),
        const SizedBox(height: 24),
        Text(completed(order) ? 'Completed' : 'Uncompleted'),
        Text('Payment: ${label(order['state'] as String)}'),
        if (order['paymentChoice'] != null)
          Text(
              'Customer chose: ${order['paymentChoice'] == 'cash' ? 'Cash' : 'QR'}',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        if (order['beeper'] != null)
          Text('Beeper ${order['beeper']}',
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text('Submitted ${timestamp(order['submittedAt'])}'),
        const SizedBox(height: 24),
        for (final line in order['items'] as List)
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${line['quantity']} × ${line['name']}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(
                        '${money(line['unitPrice'] as num)} each · ${money(line['total'] as num)}'),
                    for (final mod in line['modifiers'] as List)
                      Text('${mod['name']} (+${money(mod['price'] as num)})'),
                    if (line['notes'] != '') Text('Notes: ${line['notes']}'),
                  ])),
        const Divider(),
        Text('Total ${money(order['total'] as num)}',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        if (order['state'] == 'awaiting_payment') ...[
          if (transactionShift == null)
            const Text('Start a cashier shift to process this order.'),
          if (order['reviewedShiftId'] != transactionShift?['id'] ||
              order['reviewedAt'] == null)
            FilledButton(
                onPressed: busy || transactionShift == null
                    ? null
                    : () => review(order),
                child: const Text('1. Recheck verbally with customer'))
          else ...[
            Text(
                'Verbally confirmed by ${order['reviewedBy']} at ${timestamp(order['reviewedAt'])}'),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: busy || transactionShift == null
                    ? null
                    : () => decide(order, true),
                child: const Text('2. Verify payment')),
          ],
          const SizedBox(height: 16),
          OutlinedButton(
              onPressed: busy ? null : () => decide(order, false),
              child: const Text('Cancel unpaid order')),
        ] else ...[
          Text(
              '${label(order['state'] as String)} by ${order['operator']}\n${timestamp(order['decisionAt'])}'),
          if (order['paymentMethod'] != null)
            Text('Payment: ${order['paymentMethod']['name']}'),
          if (order['paymentMethod']?['cash'] == true)
            Text(
                'Received ${money(order['tendered'])} · Change ${money(order['change'])}'),
          if (order['state'] == 'paid' && !completed(order)) ...[
            const SizedBox(height: 20),
            FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        await operationDialog(context,
                            title: 'Complete order?',
                            button: 'Complete and release beeper',
                            content: (_) => Text(
                                'Confirm ${order['number']} has been collected${order['beeper'] == null ? '' : ' and beeper ${order['beeper']} returned'}.'),
                            submit: () =>
                                operate('complete', {'id': order['id']}));
                        await refresh();
                      },
                child: const Text('Complete order')),
          ],
          if ('${order['reason'] ?? ''}'.isNotEmpty)
            Text('Reason: ${order['reason']}'),
          if ('${order['reference'] ?? ''}'.isNotEmpty)
            Text('Reference: ${order['reference']}'),
        ],
        const FooterWordmark(),
      ]);
  bool completed(Map order) =>
      order['fulfillment'] == 'completed' || order['state'] == 'cancelled';

  String label(String state) =>
      {
        'awaiting_payment': 'Awaiting payment',
        'paid': 'Paid',
        'queued': 'Queued',
        'cancelled': 'Cancelled'
      }[state] ??
      state;
  @override
  Widget build(BuildContext context) {
    final visible = orders
        .where((o) =>
            (!hideCompleted || !completed(o as Map)) &&
            (o['number'] as String)
                .toLowerCase()
                .contains(search.toLowerCase()))
        .toList();
    final matching = visible.where((o) => o['id'] == selected);
    final order = matching.isEmpty
        ? null
        : Map<String, dynamic>.from(matching.first as Map);
    final queue = Column(children: [
      Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
              decoration: const InputDecoration(
                  labelText: 'Search order number',
                  prefixIcon: Icon(Icons.search)),
              onChanged: (s) => setState(() => search = s))),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilterChip(
              label: Text("Don't show completed orders",
                  style: OobTypography.bodyBold.copyWith(
                      fontSize: 15,
                      color: hideCompleted
                          ? OobColors.oobWhite
                          : OobColors.oobNavy)),
              checkmarkColor: OobColors.oobWhite,
              selected: hideCompleted,
              onSelected: (value) => setState(() => hideCompleted = value))),
      const Padding(
          padding: EdgeInsets.all(16),
          child: TransactionHeading('ORDERS', subtitle: 'Oldest first')),
      Expanded(
          child: visible.isEmpty
              ? const Center(child: Text('No matching orders'))
              : ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final o = visible[index];
                    return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        selected: selected == o['id'],
                        title: Text(
                            '${o['number']}${o['beeper'] != null ? ' · Beeper ${o['beeper']}' : ''}',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${completed(o as Map) ? 'Completed' : 'Uncompleted'} · Payment: ${label(o['state'] as String)}\n${timestamp(o['submittedAt'])}${o['paymentChoice'] == null ? '' : '\nPayment choice: ${o['paymentChoice'] == 'cash' ? 'Cash' : 'QR'}'}'),
                        trailing: Text(money(o['total'] as num)),
                        onTap: () => setState(() => selected = o['id'] as int));
                  })),
    ]);
    return Scaffold(
        appBar: AppBar(
            toolbarHeight: 96,
            title: const Text('OOB / CASHIER'),
            actions: [
              if (operations['cashierTracking'] != false)
                IconButton(
                    tooltip: 'Cashier shifts',
                    iconSize: 48,
                    constraints:
                        const BoxConstraints.tightFor(width: 96, height: 96),
                    icon: const Icon(Icons.point_of_sale),
                    onPressed: () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => const OperationsScreen()));
                      await refresh();
                    }),
              IconButton(
                  tooltip: 'Owner settings',
                  iconSize: 48,
                  constraints:
                      const BoxConstraints.tightFor(width: 96, height: 96),
                  icon: const Icon(Icons.admin_panel_settings),
                  onPressed: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) =>
                                const OperationsScreen(owner: true)));
                    await refresh();
                  }),
              Center(
                  child: Text(status['running'] == true
                      ? (status['connected'] == true
                          ? 'Menu connected'
                          : 'Service on · menu offline')
                      : 'Service off')),
              IconButton(
                  tooltip: connection ? 'Orders' : 'Connection',
                  iconSize: 48,
                  constraints:
                      const BoxConstraints.tightFor(width: 96, height: 96),
                  onPressed: () => setState(() => connection = !connection),
                  icon: Icon(connection ? Icons.receipt_long : Icons.wifi)),
            ]),
        body: SafeArea(
            child: Column(children: [
          if (error.isNotEmpty)
            MaterialBanner(content: Text(error), actions: [
              TextButton(
                  onPressed: () => setState(() => error = ''),
                  child: const Text('Dismiss'))
            ]),
          if (busy) const LinearProgressIndicator(),
          if (operations['cashierTracking'] != false)
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(operations['activeShift'] == null
                        ? 'No active shift. Open Cashier shifts to count the lockbox.'
                        : 'Active cashier: ${operations['activeShift']['cashier']} · PIN ${operations['requirePin'] == true ? 'required' : 'off'}'))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Wrap(spacing: 16, runSpacing: 8, children: [
              FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Custom order'),
                  onPressed: busy
                      ? null
                      : () async {
                          final shift = transactionShift;
                          if (shift == null) {
                            setState(() => error =
                                'Start a cashier shift before creating a custom order.');
                            return;
                          }
                          final created =
                              await customOrderDialog(context, shift);
                          await refresh();
                          if (created != null && mounted) {
                            setState(() {
                              selected = created['id'] as int;
                              hideCompleted = true;
                              connection = false;
                            });
                          }
                        }),
              OutlinedButton.icon(
                  icon: const Icon(Icons.summarize_outlined),
                  label: const Text('Reports'),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const ReportsScreen()))),
            ]),
          ),
          Expanded(
              child: connection
                  ? connectionScreen()
                  : LayoutBuilder(builder: (context, constraints) {
                      if (constraints.maxWidth >= 800) {
                        return Row(children: [
                          Expanded(child: queue),
                          const VerticalDivider(width: 1),
                          Expanded(
                              child: order == null
                                  ? const Center(
                                      child: Text('Select an order to review'))
                                  : details(order))
                        ]);
                      }
                      return order == null
                          ? queue
                          : Column(children: [
                              TextButton.icon(
                                  onPressed: () =>
                                      setState(() => selected = null),
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('Back to orders')),
                              Expanded(child: details(order))
                            ]);
                    })),
        ])));
  }
}
