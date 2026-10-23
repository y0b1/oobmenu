import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart' show bridge, money;
import 'operations.dart';
import 'theme/transaction_theme.dart';
import 'theme/oob_colors.dart';
import 'theme/oob_typography.dart';
import 'widgets/footer_wordmark.dart';

String reportTime(dynamic value) =>
    DateTime.fromMillisecondsSinceEpoch(value as int, isUtc: true)
        .add(const Duration(hours: 8))
        .toString()
        .split('.')
        .first;

String localRequestId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
Future<Map<String, dynamic>> reportCall(String operation,
        [Map<String, dynamic> args = const {}]) async =>
    Map<String, dynamic>.from(jsonDecode((await bridge.invokeMethod<String>(
        'reports', jsonEncode({'operation': operation, ...args})))!));

Future<void> printDocument(BuildContext context, String type, int id) async {
  try {
    final result = await bridge.invokeMethod<String>(
        'printDocument', jsonEncode({'type': type, 'id': id}));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result ?? 'Print requested')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

Future<Map<String, dynamic>?> customOrderDialog(
    BuildContext context, Map shift) async {
  final name = TextEditingController();
  final price = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final notes = TextEditingController();
  final request = localRequestId();
  Map<String, dynamic>? pending;
  return operationDialog(context,
      title: 'Custom order',
      button: 'Create order',
      content: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
                'POS only. This item will not appear in the customer menu.'),
            const SizedBox(height: 16),
            TextField(
                controller: name,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Item name')),
            TextField(
                controller: quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity')),
            const SizedBox(height: 16),
            TextField(
                controller: price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Unit price (PHP)')),
            const SizedBox(height: 16),
            TextField(
                controller: notes,
                maxLength: 500,
                decoration:
                    const InputDecoration(labelText: 'Notes (optional)')),
            const Text(
                'After creation, verbally review the order and approve payment using the normal cashier flow.'),
          ]),
      submit: () async {
        final amount = parseMoney(price.text);
        final qty = int.tryParse(quantity.text);
        if (name.text.trim().isEmpty ||
            amount == null ||
            amount <= 0 ||
            qty == null ||
            qty < 1 ||
            qty > 99) {
          throw const FormatException(
              'Enter an item name, positive price and quantity from 1 to 99.');
        }
        final args = <String, dynamic>{
          'requestId': request,
          'shiftId': shift['id'],
          'name': name.text.trim(),
          'quantity': qty,
          'unitPrice': amount,
          'notes': notes.text.trim()
        };
        // Freeze retries if the native save succeeded but the response was lost.
        pending ??= args;
        if (jsonEncode(pending) != jsonEncode(args)) {
          throw const FormatException(
              'Retry with the original values, or check the order queue before creating another order.');
        }
        try {
          return await operate('customOrder', pending!);
        } on PlatformException catch (e) {
          if (e.code == 'POS') pending = null;
          rethrow;
        }
      });
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Map<String, dynamic> state = {}, report = {};
  String kind = 'daily', day = '', error = '';
  bool busy = false;
  @override
  void initState() {
    super.initState();
    run(() async {
      state = await reportCall('state');
      day = state['today'] as String;
      await loadSummary();
    });
  }

  Future<void> loadSummary() async {
    state = await reportCall('state');
    report = await reportCall('summary', {'kind': kind, 'day': day});
  }

  Future<void> run(Future<void> Function() task) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await task();
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String?> unlock() async {
    final password = TextEditingController();
    final value = await operationDialog(context,
        title: 'Owner authorization',
        button: 'Unlock',
        content: (_) => TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Owner password')),
        submit: () => operate('ownerLogin', {'password': password.text}));
    return value?['session'] as String?;
  }

  Future<void> chooseDate() async {
    final date = await showDatePicker(
        context: context,
        initialDate: DateTime.parse(day),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (date != null && mounted) {
      await run(() async {
        day = date.toIso8601String().substring(0, 10);
        await loadSummary();
      });
    }
  }

  Future<void> save(String type) async {
    if (type == 'Z') {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text('Close $day?'),
                  content: const Text(
                      'This saves the final Z-reading. Payment approvals and unpaid cancellations dated on or before this day will be blocked. This cannot be undone. Close after the last payment for the day.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Back')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Continue'))
                  ]));
      if (confirmed != true || !mounted) return;
    }
    await run(() async {
      String? session;
      if (type == 'Z') {
        session = await unlock();
        if (session == null) return;
      }
      final request = localRequestId();
      report = await reportCall('save', {
        'kind': type,
        'day': day,
        'requestId': request,
        if (session != null) 'session': session
      });
      state = await reportCall('state');
    });
  }

  Future<void> configureCutoff() async {
    await run(() async {
      final session = await unlock();
      if (session == null || !mounted) return;
      final config = state['autoCutoff'] as Map? ?? {};
      var enabled = config['enabled'] != false;
      var enforceSalesDay = config['enforceSalesDay'] != false;
      final parts = (config['time'] as String? ?? '20:30').split(':');
      var time =
          TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      final saved = await operationDialog(context,
          title: 'Automatic daily cutoff',
          button: 'Save cutoff',
          content: (update) =>
              Column(mainAxisSize: MainAxisSize.min, children: [
                SwitchListTile(
                    title: const Text('Enforce sales day'),
                    subtitle: const Text(
                        'Turn off temporarily for testing. Re-enable before live use. Saved Z-readings remain unchanged.'),
                    value: enforceSalesDay,
                    onChanged: (value) =>
                        update(() => enforceSalesDay = value)),
                SwitchListTile(
                    title: const Text('Enable automatic cutoff'),
                    value: enabled,
                    onChanged: (value) => update(() => enabled = value)),
                OutlinedButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text(time.format(context)),
                    onPressed: () async {
                      final chosen = await showTimePicker(
                          context: context, initialTime: time);
                      if (chosen != null && mounted) {
                        update(() => time = chosen);
                      }
                    }),
                const SizedBox(height: 16),
                const Text(
                    'Philippine time. Saves a final Z-reading and closes payments until midnight. Keep the POS service running. If it is off, missed cutoffs are saved when reopened. This does not count cash or close a cashier shift.'),
              ]),
          submit: () => reportCall('cutoff', {
                'session': session,
                'enabled': enabled,
                'enforceSalesDay': enforceSalesDay,
                'time':
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
              }));
      if (saved != null) await loadSummary();
    });
  }

  Future<void> profile() async {
    await run(() async {
      final session = await unlock();
      if (session == null || !mounted) return;
      final fields = <String, String>{
        'businessName': 'Registered business name',
        'tin': 'TIN',
        'address': 'Business address',
        'serialNumber': 'Machine serial number',
        'ptuNumber': 'PTU number',
        'posModel': 'Accredited POS model details',
        'accreditationNumber': 'Accreditation number',
        'minNumber': 'Machine identification number (MIN)'
      };
      final current = state['profile'] as Map? ?? {};
      final controllers = {
        for (final key in fields.keys)
          key: TextEditingController(text: current[key] as String? ?? '')
      };
      var status = current['taxStatus'] as String? ?? 'UNCONFIGURED';
      await operationDialog(context,
          title: 'Business and machine details',
          content: (update) =>
              Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                    'Enter the details from your actual registration. Saving them does not confer BIR accreditation. New sales keep a snapshot; earlier payment records remain unchanged.'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'VAT status'),
                    items: const [
                      DropdownMenuItem(
                          value: 'UNCONFIGURED', child: Text('Not configured')),
                      DropdownMenuItem(value: 'VAT', child: Text('VAT')),
                      DropdownMenuItem(value: 'NON-VAT', child: Text('Non-VAT'))
                    ],
                    onChanged: (v) => update(() => status = v!)),
                for (final field in fields.entries)
                  Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: TextField(
                          controller: controllers[field.key],
                          maxLength: 250,
                          decoration: InputDecoration(labelText: field.value))),
              ]),
          submit: () => reportCall('profile', {
                'session': session,
                'taxStatus': status,
                for (final field in controllers.entries)
                  field.key: field.value.text
              }));
      state = await reportCall('state');
    });
  }

  Widget amount(String label, dynamic value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(spacing: 24, runSpacing: 8, children: [
        Text(label),
        Text(money(value as num), style: OobTypography.bodyBold)
      ]));
  Widget group(String title, String key) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 32),
        TransactionHeading(title),
        const SizedBox(height: 16),
        for (final row in report[key] as List? ?? [])
          ListTile(
              title: Text(row['name'] as String),
              subtitle: Text('${row['count']} paid orders'),
              trailing: Text(money(row['total'] as num))),
      ]);
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            toolbarHeight: 96,
            leadingWidth: 96,
            leading: IconButton(
                iconSize: 48,
                constraints:
                    const BoxConstraints.tightFor(width: 96, height: 96),
                tooltip: 'Back',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back)),
            title: const Text('REPORTS')),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(32), children: [
          const TransactionHeading('SALES REPORTS',
              subtitle: 'Daily, weekly and monthly'),
          const SizedBox(height: 24),
          if (busy) const LinearProgressIndicator(),
          if (error.isNotEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(error)),
          if (state.isNotEmpty) ...[
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (final entry in {
                'daily': 'Daily',
                'weekly': 'Weekly',
                'monthly': 'Monthly'
              }.entries)
                ChoiceChip(
                    showCheckmark: false,
                    label: Text(entry.value,
                        style: OobTypography.bodyBold.copyWith(
                            fontSize: 16,
                            color: kind == entry.key
                                ? Colors.white
                                : OobColors.oobNavy)),
                    selected: kind == entry.key,
                    onSelected: busy
                        ? null
                        : (_) => run(() async {
                              kind = entry.key;
                              await loadSummary();
                            })),
              OutlinedButton.icon(
                  onPressed: busy ? null : chooseDate,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(day)),
              OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                            await loadSummary();
                          }),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh')),
            ]),
            const SizedBox(height: 16),
            const Text(
                'Philippine time. Weeks run Monday to Sunday. Sales count when payment is approved; cash received and change are not sales.'),
            const SizedBox(height: 24),
            Wrap(spacing: 12, runSpacing: 12, children: [
              FilledButton(
                  onPressed: busy ? null : () => save(kind),
                  child: const Text('Save summary')),
              OutlinedButton(
                  onPressed: busy ? null : () => save('X'),
                  child: const Text('Save X-reading')),
              OutlinedButton(
                  onPressed: busy ? null : () => save('Z'),
                  child: const Text('Close day: Z-reading')),
              OutlinedButton(
                  onPressed: busy ? null : profile,
                  child: const Text('Business details')),
              OutlinedButton.icon(
                  onPressed: busy ? null : configureCutoff,
                  icon: const Icon(Icons.schedule),
                  label: const Text('Automatic cutoff')),
            ]),
            const SizedBox(height: 16),
            Text(
                'Last closed day: ${(state['lastClosedDay'] as String).isEmpty ? 'None' : state['lastClosedDay']}'),
            if (state['autoCutoff'] is Map)
              Text(state['autoCutoff']['enforceSalesDay'] == false
                  ? 'Sales day paused for testing. Re-enable before live use.'
                  : state['autoCutoff']['enabled'] == true
                      ? 'Automatic cutoff: ${state['autoCutoff']['time']} daily (Philippine time)'
                      : 'Automatic cutoff: Off'),
            amount('Lifetime grand total', state['grandTotal']),
            Text(
                'Audit journal verified: ${state['audit']['entries']} entries'),
            const Text(
                'Keep regular exports outside the tablet. Operational reports and payment records are not yet BIR-accredited tax invoices.'),
          ],
          if (report.isNotEmpty) ...[
            const SizedBox(height: 32),
            TransactionHeading(
                '${report['kind'].toString().toUpperCase()} ${report['id'] == null ? 'PREVIEW' : '#${report['id']}'}',
                subtitle: '${report['start']} to ${report['end']}'),
            const SizedBox(height: 16),
            Text('Generated ${reportTime(report['generatedAt'])}'),
            Text('${report['count']} paid orders'),
            amount('Sales', report['total']),
            amount('Cash sales', report['cashSales']),
            amount('Other payments', report['otherSales']),
            Text(
                '${report['cancelledCount']} unpaid cancellations, excluded from sales'),
            amount('Grand total before period', report['previousGrandTotal']),
            amount('Grand total through period', report['periodGrandTotal']),
            if (report['id'] != null)
              FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () =>
                          printDocument(context, 'report', report['id'] as int),
                  icon: const Icon(Icons.print),
                  label: const Text('Save as PDF')),
            group('PAYMENT METHODS', 'methods'),
            group('CASHIERS', 'cashiers'),
            if (kind != 'daily') group('DAILY TOTALS', 'days'),
          ],
          const SizedBox(height: 32),
          const TransactionHeading('SAVED READINGS',
              subtitle: 'Original snapshots and reprints'),
          const SizedBox(height: 16),
          for (final saved in state['reports'] as List? ?? [])
            ListTile(
                title: Text(
                    '${saved['kind'].toString().toUpperCase()} #${saved['id']} · ${saved['start']} to ${saved['end']}'),
                subtitle: Text(
                    '${reportTime(saved['generatedAt'])} · ${money(saved['total'] as num)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: busy
                    ? null
                    : () => setState(() =>
                        report = Map<String, dynamic>.from(saved as Map))),
          const FooterWordmark(),
        ])),
      );
}
