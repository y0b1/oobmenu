import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart' show bridge, money, timestamp;
import 'theme/transaction_theme.dart';
import 'widgets/footer_wordmark.dart';

Future<Map<String, dynamic>> operate(
        String operation, Map<String, dynamic> args) async =>
    Map<String, dynamic>.from(jsonDecode((await bridge.invokeMethod<String>(
        'cashier', jsonEncode({'operation': operation, ...args})))!));

int? parseMoney(String value) {
  if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(value.trim())) return null;
  final parts = value.trim().split('.');
  return int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
}

Widget pinField(TextEditingController controller) => TextField(
      controller: controller,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4)
      ],
      decoration: const InputDecoration(labelText: 'Cashier PIN (4 digits)'),
    );

// Dialogs keep errors and entered values visible until the durable native operation succeeds.
Future<Map<String, dynamic>?> operationDialog(
  BuildContext context, {
  required String title,
  required Widget Function(StateSetter) content,
  required Future<Map<String, dynamic>> Function() submit,
  String button = 'Save',
}) =>
    showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        var busy = false;
        var error = '';
        return StatefulBuilder(
            builder: (context, update) => PopScope(
                  canPop: !busy,
                  child: AlertDialog(
                    title: Text(title),
                    content: SizedBox(
                        width: 460,
                        child: SingleChildScrollView(
                            child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            content(update),
                            if (error.isNotEmpty)
                              Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Text(error,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error))),
                            if (busy) const LinearProgressIndicator()
                          ],
                        ))),
                    actions: [
                      TextButton(
                          onPressed: busy ? null : () => Navigator.pop(context),
                          child: const Text('Back')),
                      FilledButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  update(() {
                                    busy = true;
                                    error = '';
                                  });
                                  try {
                                    final result = await submit();
                                    if (context.mounted) {
                                      Navigator.pop(context, result);
                                    }
                                  } catch (e) {
                                    update(() {
                                      error = e is PlatformException
                                          ? e.message ?? '$e'
                                          : '$e';
                                      busy = false;
                                    });
                                  }
                                },
                          child: Text(button))
                    ],
                  ),
                ));
      },
    );

Future<void> paymentDialog(BuildContext context, Map order, Map data) async {
  final shift = (data['transactionOperator'] ?? data['activeShift']) as Map?;
  if (shift == null) return;
  final methods =
      (data['methods'] as List).where((m) => m['enabled'] == true).toList();
  final matchingMethods = methods
      .where((m) => order['paymentChoice'] == 'cash'
          ? m['cash'] == true
          : order['paymentChoice'] == 'qr' && m['cash'] == false)
      .toList();
  String? methodId = matchingMethods.length == 1
      ? matchingMethods.single['id'] as String
      : null;
  final tender = TextEditingController();
  final reference = TextEditingController();
  final beeper = TextEditingController();
  final checked = await operationDialog(context,
      title: 'Verify payment', button: 'Continue', content: (update) {
    final matches = methods.where((m) => m['id'] == methodId);
    final cash = matches.isNotEmpty && matches.first['cash'] == true;
    final received = parseMoney(tender.text);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${order['number']} · ${money(order['total'])}',
              style:
                  const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          if (data['cashierTracking'] != false)
            Text('Cashier: ${shift['cashier']}'),
          if (order['paymentChoice'] != null)
            Text(
                'Customer chose: ${order['paymentChoice'] == 'cash' ? 'Cash' : 'QR'}. Change the method only if needed.'),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
              initialValue: methodId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Payment method'),
              items: [
                for (final m in methods)
                  DropdownMenuItem(
                      value: m['id'] as String,
                      child: Text(m['name'] as String))
              ],
              onChanged: (v) => update(() {
                    methodId = v;
                  })),
          const SizedBox(height: 16),
          if (cash) ...[
            TextField(
                controller: tender,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Cash received (₱)'),
                onChanged: (_) => update(() {})),
            if (received != null && received >= order['total'])
              Text('Change: ${money(received - order['total'])}'),
          ] else
            const Text(
                'Check the transfer on your separate payment device. This app records your decision and does not verify transfers.'),
          const SizedBox(height: 16),
          TextField(
              controller: reference,
              maxLength: 120,
              decoration: const InputDecoration(
                  labelText: 'Payment reference (optional)')),
          const SizedBox(height: 16),
          TextField(
              controller: beeper,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4)
              ],
              decoration:
                  const InputDecoration(labelText: 'Beeper number (1–9999)')),
        ]);
  }, submit: () async {
    if (methodId == null) {
      throw const FormatException('Select a payment method.');
    }
    if (!RegExp(r'^[1-9][0-9]{0,3}$').hasMatch(beeper.text)) {
      throw const FormatException('Enter a beeper number from 1 to 9999.');
    }
    final cash = methods.firstWhere((m) => m['id'] == methodId)['cash'] == true;
    final amount = cash ? parseMoney(tender.text) : order['total'] as int;
    if (amount == null || amount < order['total']) {
      throw const FormatException(
          'Enter enough cash to cover the exact total.');
    }
    return {
      'id': order['id'],
      'shiftId': shift['id'],
      'methodId': methodId,
      'tendered': amount,
      'reference': reference.text.trim(),
      'beeper': beeper.text
    };
  });
  if (checked == null || !context.mounted) return;
  final pin = TextEditingController();
  await operationDialog(context,
      title: 'Approve payment?',
      button: 'Approve payment and queue',
      content: (_) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${order['number']}\n${money(order['total'])}',
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold)),
                Text(
                    '${methods.firstWhere((m) => m['id'] == methodId)['name']} · Beeper ${checked['beeper']}'),
                Text('Approving cashier: ${shift['cashier']}'),
                const SizedBox(height: 20),
                if (data['requirePin'] == true)
                  pinField(pin)
                else
                  const Text('Ready to approve payment.'),
              ]),
      submit: () =>
          operate('approve', {...checked, 'verified': true, 'pin': pin.text}));
}

class OperationsScreen extends StatefulWidget {
  final bool owner;
  const OperationsScreen({super.key, this.owner = false});
  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  Map<String, dynamic> data = {};
  String session = '', error = '';
  bool busy = false;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    if (widget.owner) {
      bridge.invokeMethod('cashier', jsonEncode({'operation': 'ownerLock'}));
    }
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final d = jsonDecode((await bridge.invokeMethod<String>('operations'))!);
      if (mounted) setState(() => data = Map<String, dynamic>.from(d));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> unlock() async {
    final password = TextEditingController();
    final confirm = TextEditingController();
    final setup = data['ownerConfigured'] != true;
    final result = await operationDialog(context,
        title: setup ? 'Set up owner password' : 'Unlock owner settings',
        button: setup ? 'Create owner' : 'Unlock',
        content: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
              const Text(
                  'Owner access controls cashiers, payment methods and transaction PIN checks. Keep this password private.'),
              const SizedBox(height: 16),
              TextField(
                  controller: password,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                      labelText: 'Owner password (8+ characters)')),
              if (setup) ...[
                const SizedBox(height: 16),
                TextField(
                    controller: confirm,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Confirm owner password'))
              ],
            ]),
        submit: () {
          if (setup && password.text != confirm.text) {
            throw const FormatException('Passwords must match.');
          }
          return operate(
              setup ? 'ownerSetup' : 'ownerLogin', {'password': password.text});
        });
    if (result != null && mounted) {
      setState(() => session = result['session'] as String);
    }
    await refresh();
  }

  Future<void> edit(bool cashier, [Map? existing]) async {
    final name =
        TextEditingController(text: existing?['name'] as String? ?? '');
    final pin = TextEditingController();
    var cash = existing?['cash'] == true;
    var enabled = existing?['enabled'] != false;
    await operationDialog(context,
        title:
            '${existing == null ? 'Add' : 'Edit'} ${cashier ? 'cashier' : 'payment method'}',
        content: (update) => Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: name,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 16),
              if (cashier) ...[
                pinField(pin),
                if (existing != null)
                  const Text('Leave the PIN blank to keep the current PIN.')
              ] else
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: cash,
                    onChanged: (v) => update(() => cash = v),
                    title: const Text('Adds physical cash to lockbox'),
                    subtitle:
                        const Text('Keep off for GCash and bank transfers.')),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: enabled,
                  onChanged: (v) => update(() => enabled = v),
                  title: const Text('Enabled')),
            ]),
        submit: () => operate(cashier ? 'saveCashier' : 'saveMethod', {
              'session': session,
              if (existing != null) 'id': existing['id'],
              'name': name.text.trim(),
              'pin': pin.text,
              'cash': cash,
              'enabled': enabled
            }));
    await refresh();
  }

  Future<void> shift(bool close) async {
    final active = data['activeShift'] as Map?;
    final count = TextEditingController();
    final pin = TextEditingController();
    String? cashierId;
    final result = await operationDialog(context,
        title: close ? 'Close cashier shift' : 'Start cashier shift',
        button: close ? 'Record closing count' : 'Open shift',
        content: (update) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (close)
                    Text('Cashier: ${active!['cashier']}')
                  else
                    DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Cashier'),
                        isExpanded: true,
                        items: [
                          for (final c in data['cashiers'] as List? ?? [])
                            if (c['enabled'] == true)
                              DropdownMenuItem(
                                  value: c['id'] as String,
                                  child: Text(c['name'] as String))
                        ],
                        onChanged: (v) => update(() => cashierId = v)),
                  const SizedBox(height: 16),
                  const Text(
                      'Count the physical cash in the lockbox. Enter pesos including centavos.'),
                  const SizedBox(height: 16),
                  TextField(
                      controller: count,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: close
                              ? 'Closing cash count (₱)'
                              : 'Opening cash count (₱)')),
                  const SizedBox(height: 16),
                  pinField(pin),
                ]),
        submit: () {
          final amount = parseMoney(count.text);
          if (amount == null) {
            throw const FormatException(
                'Enter a valid cash count, for example 1500.50.');
          }
          return operate(close ? 'closeShift' : 'startShift', {
            'cashierId': cashierId,
            'shiftId': active?['id'],
            close ? 'closing' : 'opening': amount,
            'pin': pin.text
          });
        });
    await refresh();
    if (close && result != null && mounted) {
      await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
                  title: const Text('Shift closed'),
                  content: summary(result),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Done'))
                  ]));
    }
  }

  Widget summary(Map s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${s['cashier']}',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text('Opened ${timestamp(s['openedAt'])}'),
            Text('Opening count: ${money(s['opening'])}'),
            for (final m in s['methods'] as List? ?? [])
              Text(
                  '${m['name']}: ${money(m['total'])} (${m['count']} payments)'),
            Text('Cash sales: ${money(s['cashSales'] ?? 0)}'),
            Text('Expected lockbox cash: ${money(s['expected'])}'),
            if (s['closedAt'] != null) ...[
              Text('Closed ${timestamp(s['closedAt'])}'),
              Text('Closing count: ${money(s['closing'])}'),
              Text(
                  s['difference'] == 0
                      ? 'Balanced'
                      : s['difference'] < 0
                          ? 'Shortage: ${money(-(s['difference'] as num))}'
                          : 'Overage: ${money(s['difference'])}',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ]);
  @override
  Widget build(BuildContext context) {
    final active = data['activeShift'] as Map?;
    return Scaffold(
        appBar: AppBar(
            toolbarHeight: 96,
            leadingWidth: 96,
            leading: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              iconSize: 48,
              constraints: const BoxConstraints.tightFor(width: 96, height: 96),
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
            ),
            title: Text(widget.owner ? 'OWNER SETTINGS' : 'CASHIER SHIFTS')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          if (error.isNotEmpty) Text(error),
          if (data.isEmpty)
            const LinearProgressIndicator()
          else if (widget.owner) ...[
            if (session.isEmpty)
              FilledButton(
                  onPressed: unlock,
                  child: Text(data['ownerConfigured'] == true
                      ? 'Unlock owner settings'
                      : 'Set up owner password'))
            else ...[
              const Text(
                  'Owner access expires after 5 minutes. Close this screen to lock.'),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cashier tracking and shifts'),
                  subtitle: const Text(
                      'Turn off to use the POS without choosing a cashier or entering a transaction PIN. History is preserved. An already-open lockbox shift keeps accumulating cash sales.'),
                  value: data['cashierTracking'] != false,
                  onChanged: busy
                      ? null
                      : (value) async {
                          setState(() => busy = true);
                          try {
                            await operate('setCashierTracking',
                                {'session': session, 'enabled': value});
                            await refresh();
                          } catch (e) {
                            if (mounted) setState(() => error = '$e');
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        }),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: data['requirePin'] == true,
                  title: const Text('Require cashier PIN per transaction'),
                  subtitle: const Text(
                      'Applies to payment approval and cancellation. Shift counts always require a PIN.'),
                  onChanged: busy || data['cashierTracking'] == false
                      ? null
                      : (v) async {
                          setState(() => busy = true);
                          try {
                            await operate('setPinRequired',
                                {'session': session, 'enabled': v});
                            await refresh();
                          } catch (e) {
                            if (mounted) setState(() => error = '$e');
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        }),
              const Divider(),
              const TransactionHeading('CASHIERS', subtitle: 'Your team'),
              for (final c in data['cashiers'] as List)
                ListTile(
                    title: Text(c['name']),
                    subtitle: Text(c['enabled'] ? 'Enabled' : 'Disabled'),
                    trailing: const Icon(Icons.edit),
                    onTap: () => edit(true, c as Map)),
              OutlinedButton(
                  onPressed: () => edit(true),
                  child: const Text('Add cashier')),
              const SizedBox(height: 24),
              const TransactionHeading('PAYMENT METHODS',
                  subtitle: 'Cash and transfers'),
              for (final m in data['methods'] as List)
                ListTile(
                    title: Text(m['name']),
                    subtitle: Text(
                        '${m['cash'] ? 'Adds to lockbox' : 'Transfer / non-cash'} · ${m['enabled'] ? 'Enabled' : 'Disabled'}'),
                    trailing: const Icon(Icons.edit),
                    onTap: () => edit(false, m as Map)),
              OutlinedButton(
                  onPressed: () => edit(false),
                  child: const Text('Add payment method')),
              const SizedBox(height: 24),
              OutlinedButton(
                  onPressed: () async {
                    final password = TextEditingController();
                    final confirmation = TextEditingController();
                    final result = await operationDialog(context,
                        title: 'Change owner password',
                        content: (_) =>
                            Column(mainAxisSize: MainAxisSize.min, children: [
                              TextField(
                                  controller: password,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                      labelText:
                                          'New password (8+ characters)')),
                              const SizedBox(height: 16),
                              TextField(
                                  controller: confirmation,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                      labelText: 'Confirm new password')),
                            ]),
                        submit: () {
                          if (password.text != confirmation.text) {
                            throw const FormatException(
                                'Passwords must match.');
                          }
                          return operate('changeOwnerPassword',
                              {'session': session, 'password': password.text});
                        });
                    if (result != null && mounted) setState(() => session = '');
                  },
                  child: const Text('Change owner password')),
            ],
          ] else ...[
            if (data['ownerConfigured'] != true)
              const Text(
                  'Open Owner settings first to create the owner password and cashier accounts.'),
            if (active != null) ...[
              summary(active),
              const SizedBox(height: 20),
              FilledButton(
                  onPressed: () => shift(true),
                  child: const Text('Close shift and count cash'))
            ] else
              FilledButton(
                  onPressed: (data['cashiers'] as List)
                          .any((c) => c['enabled'] == true)
                      ? () => shift(false)
                      : null,
                  child: const Text('Start shift and count cash')),
            const SizedBox(height: 16),
            const Text(
                'One cashier at a time shares this lockbox. Close the current shift before handing over. Expected cash assumes no cash drops or expenses during the shift.'),
            const SizedBox(height: 24),
            const TransactionHeading('SHIFT HISTORY',
                subtitle: 'Cash counts and handovers'),
            for (final s in data['shifts'] as List)
              if (s['closedAt'] != null)
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: summary(s as Map))),
          ],
          const FooterWordmark(),
        ]));
  }
}
