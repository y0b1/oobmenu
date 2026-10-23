import 'dart:async';
import 'dart:math' as math;
import 'payment_qr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/menu_state.dart';
import 'order_client.dart';
import '../theme/transaction_theme.dart';
import '../theme/oob_typography.dart';
import '../widgets/footer_wordmark.dart';

Widget _largeBackButton(BuildContext context) => IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      icon: const Icon(Icons.arrow_back),
      iconSize: 48,
      constraints: const BoxConstraints.tightFor(width: 96, height: 96),
      onPressed: () => Navigator.maybePop(context),
    );

class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key, this.client});
  final OrderClient? client;
  @override
  Widget build(BuildContext context) => Theme(
      data: transactionTheme(Theme.of(context)),
      child: _OrderContent(client: client ?? OrderClient.instance));
}

class _OrderContent extends StatefulWidget {
  const _OrderContent({required this.client});
  final OrderClient client;
  @override
  State<_OrderContent> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<_OrderContent> {
  late final client = widget.client;
  String query = '';
  Timer? _paymentTimer;
  Object? _timedOrder;
  bool _returning = false;
  bool _qrScheduled = false;
  DialogRoute<void>? _qrRoute;

  @override
  void initState() {
    super.initState();
    client.addListener(_watchPayment);
    _watchPayment();
  }

  void _watchPayment() {
    _syncQrModal();
    if (client.order?['state'] != 'paid') {
      _paymentTimer?.cancel();
      _timedOrder = null;
      return;
    }
    final id = client.order?['id'];
    if (_timedOrder == id) return;
    _timedOrder = id;
    _paymentTimer?.cancel();
    _paymentTimer = Timer(const Duration(seconds: 5), _autoReturn);
  }

  void _syncQrModal() {
    if (_qrScheduled) return;
    _qrScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _qrScheduled = false;
      if (!mounted) return;
      final show = client.order?['state'] == 'awaiting_payment' &&
          client.order?['paymentChoice'] == 'qr';
      if (!show) {
        final route = _qrRoute;
        _qrRoute = null;
        if (route != null && route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
        return;
      }
      if (_qrRoute != null) return;
      final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Theme(
          data: transactionTheme(Theme.of(context)),
          child: PopScope(
              canPop: false,
              child: ListenableBuilder(
                listenable: client,
                builder: (context, _) {
                  final qrHeight =
                      math.min(440.0, MediaQuery.sizeOf(context).height * .48);
                  return Dialog(
                      child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const TransactionHeading('PAY WITH QR'),
                        const SizedBox(height: 16),
                        Text(
                            '${client.order?['number'] ?? ''} · ${centavos((client.order?['total'] ?? 0) as num)}',
                            style:
                                OobTypography.bodyBold.copyWith(fontSize: 22),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        SizedBox(
                            height: qrHeight,
                            width: qrHeight * 580 / 776,
                            child: const PaymentQrImage()),
                        const SizedBox(height: 16),
                        const Text('Awaiting payment',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        const Text(
                            'Scan the QR and keep this screen open. The cashier will confirm your payment.',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        if (client.error.isNotEmpty)
                          Text(client.error, textAlign: TextAlign.center),
                        SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                                onPressed: client.busy ||
                                        client.connection != 'Connected'
                                    ? null
                                    : _cancelOrder,
                                child: const Text('Cancel order'))),
                      ]),
                    ),
                  ));
                },
              )),
        ),
      );
      _qrRoute = route;
      Navigator.of(context).push(route).whenComplete(() {
        if (_qrRoute == route) _qrRoute = null;
      });
    });
  }

  void _autoReturn() {
    if (!mounted || client.order?['state'] != 'paid') return;
    if (client.busy || ModalRoute.of(context)?.isCurrent != true) {
      _paymentTimer = Timer(const Duration(seconds: 1), _autoReturn);
      return;
    }
    _startNewOrder();
  }

  Future<void> _startNewOrder() async {
    if (_returning || client.busy) return;
    _returning = true;
    _paymentTimer?.cancel();
    await client.startNewOrder();
    if (mounted && client.order == null && client.pending == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    _returning = false;
  }

  @override
  void dispose() {
    _paymentTimer?.cancel();
    client.removeListener(_watchPayment);
    super.dispose();
  }

  Future<void> add(Map<String, dynamic> product) async {
    final notes = TextEditingController();
    final selected = <String>{};
    var quantity = 1;
    final ok = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(builder: (context, update) {
              final unit = (product['price'] as int) +
                  client.modifiers
                      .where((m) => selected.contains(m['id']))
                      .fold<int>(0, (v, m) => v + (m['price'] as int));
              return AlertDialog(
                  title: Text(product['name'] as String),
                  content: SizedBox(
                      width: 440,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(product['description'] as String),
                        const SizedBox(height: 16),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                  onPressed: quantity > 1
                                      ? () => update(() => quantity--)
                                      : null,
                                  icon: const Icon(Icons.remove)),
                              Text('$quantity',
                                  style: const TextStyle(fontSize: 24)),
                              IconButton(
                                  onPressed: quantity < 99
                                      ? () => update(() => quantity++)
                                      : null,
                                  icon: const Icon(Icons.add))
                            ]),
                        for (final mod in client.modifiers.where((m) =>
                            (product['modifiers'] as List).contains(m['id'])))
                          CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                  '${mod['name']} (+${centavos(mod['price'] as num)})'),
                              value: selected.contains(mod['id']),
                              onChanged: (value) => update(() {
                                    final id = mod['id'] as String;
                                    if (value == true) {
                                      if (id == 'cold-whisk' ||
                                          id == 'traditional') {
                                        selected.removeAll(
                                            ['cold-whisk', 'traditional']);
                                      }
                                      selected.add(id);
                                    } else {
                                      selected.remove(id);
                                    }
                                  })),
                        const SizedBox(height: 16),
                        TextField(
                            controller: notes,
                            maxLength: 500,
                            maxLines: 3,
                            decoration: const InputDecoration(
                                labelText: 'Notes (optional)',
                                border: OutlineInputBorder())),
                        Text(centavos(unit * quantity),
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold)),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Back')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Add to order'))
                  ]);
            }));
    if (ok == true) {
      final unit = (product['price'] as int) +
          client.modifiers
              .where((m) => selected.contains(m['id']))
              .fold<int>(0, (v, m) => v + (m['price'] as int));
      await client.editCart([
        ...client.cart,
        {
          'id': product['id'],
          'name': product['name'],
          'quantity': quantity,
          'modifiers': selected.toList(),
          'notes': notes.text.trim(),
          'expectedUnitPrice': unit
        }
      ]);
    }
  }

  Future<void> _cancelOrder() async {
    final number = client.order?['number'];
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text('Cancel $number?'),
                content: const Text(
                    'Cancel this unpaid order so you can start again. The POS must confirm cancellation. An already-paid order cannot be cancelled here.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep order')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Cancel order'))
                ]));
    if (confirmed == true && mounted) await client.cancelOrder();
  }

  Widget status() {
    final order = client.order;
    final state = order?['state'];
    final heading = order == null
        ? 'Submitting'
        : {
            'awaiting_payment': 'Awaiting payment',
            'paid': 'Payment confirmed',
            'cancelled': 'Order cancelled'
          }[state]!;
    return ListView(padding: const EdgeInsets.all(32), children: [
      Icon(state == 'paid' ? Icons.check_circle_outline : Icons.receipt_long,
          size: 72),
      const SizedBox(height: 24),
      Text(heading,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
      if (order != null) ...[
        Text('${order['number']}',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 16),
        if (order['beeper'] != null) ...[
          Text('Beeper ${order['beeper']}',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          Text(
              order['fulfillment'] == 'completed'
                  ? 'Order collected'
                  : 'Your order is queued. Keep your beeper with you.',
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
        ],
        Text(centavos(order['total'] as num),
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 24),
        if (state == 'awaiting_payment') ...[
          OutlinedButton(
              onPressed: client.busy || client.connection != 'Connected'
                  ? null
                  : _cancelOrder,
              child: const Text('Cancel order')),
          const SizedBox(height: 24),
        ],
        for (final line in order['items'] as List)
          ListTile(
              title: Text('${line['quantity']} × ${line['name']}'),
              subtitle: Text([
                ...(line['modifiers'] as List).map((m) => m['name']),
                if (line['notes'] != '') line['notes']
              ].join(', ')),
              trailing: Text(centavos(line['total'] as num))),
        if (order['paymentChoice'] != null)
          Text(
              'Payment choice: ${order['paymentChoice'] == 'cash' ? 'Cash' : 'QR'}',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        if (state == 'awaiting_payment')
          Text(order['paymentChoice'] == 'cash'
              ? 'Your order is saved at the cashier. Please show your order number and pay with cash.'
              : order['paymentChoice'] == 'qr'
                  ? 'Your order is saved at the cashier. Scan the payment QR and show your order number. The cashier will confirm payment after checking the transfer.'
                  : 'Your order is saved at the cashier. Please show your order number. The cashier will confirm payment.'),
        if (state == 'cancelled' && order['reason'] != '')
          Text('Reason: ${order['reason']}'),
        if (state == 'paid' || state == 'cancelled')
          Padding(
              padding: const EdgeInsets.only(top: 32),
              child: FilledButton(
                  onPressed: client.busy ? null : _startNewOrder,
                  child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Start new order')))),
        const FooterWordmark(),
      ] else ...[
        const SizedBox(height: 24),
        const Text(
            'Waiting for the POS to confirm that your order is saved. A connection interruption will retry this same request, never a second order.'),
      ],
    ]);
  }

  bool choosingPayment = false;

  Future<void> choosePayment() async {
    if (choosingPayment ||
        client.busy ||
        client.locked ||
        client.connection != 'Connected' ||
        client.cart.isEmpty) {
      return;
    }
    choosingPayment = true;
    try {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('How would you like to pay?'),
          content: const Text(
              'Choose Cash or QR. Your choice will be sent to the cashier with your order.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back')),
            OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'cash'),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Cash')),
            FilledButton.icon(
                onPressed: () => Navigator.pop(context, 'qr'),
                icon: const Icon(Icons.qr_code),
                label: const Text('QR')),
          ],
        ),
      );
      if (choice != null && mounted) await client.submit(paymentChoice: choice);
    } finally {
      choosingPayment = false;
    }
  }

  Widget cart() => ListView(padding: const EdgeInsets.all(24), children: [
        const TransactionHeading('YOUR ORDER', subtitle: 'Review your drinks'),
        const SizedBox(height: 16),
        if (client.cart.isEmpty) const Text('Select a drink to begin.'),
        for (var index = 0; index < client.cart.length; index++)
          Builder(builder: (context) {
            final line = client.cart[index];
            return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${line['quantity']} × ${line['name']}'),
                subtitle: Text([
                  ...(line['modifiers'] as List).map((id) => client.modifiers
                      .firstWhere((m) => m['id'] == id,
                          orElse: () => {'name': id})['name']),
                  if (line['notes'] != '') line['notes']
                ].join(', ')),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(centavos((line['expectedUnitPrice'] as int) *
                      (line['quantity'] as int))),
                  IconButton(
                      tooltip: 'Remove item',
                      onPressed: client.busy
                          ? null
                          : () => client
                              .editCart([...client.cart]..removeAt(index)),
                      icon: const Icon(Icons.close))
                ]));
          }),
        const Divider(),
        Text(
            'Total ${centavos(client.cart.fold<int>(0, (v, l) => v + (l['quantity'] as int) * (l['expectedUnitPrice'] as int)))}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        FilledButton(
            onPressed: client.busy ||
                    client.connection != 'Connected' ||
                    client.cart.isEmpty
                ? null
                : choosePayment,
            child: const Padding(
                padding: EdgeInsets.all(16), child: Text('Submit order'))),
        const SizedBox(height: 16),
        const Text(
            'Payment is confirmed manually by the cashier. Prices are checked by the POS when you submit.'),
        if (client.connection != 'Connected')
          const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                  'Checkout is unavailable while disconnected. You can continue browsing and editing this order.')),
      ]);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: client,
      builder: (context, _) => Scaffold(
            appBar: AppBar(
                toolbarHeight: 96,
                leadingWidth: 96,
                leading: _largeBackButton(context),
                title: const Text('YOUR ORDER')),
            body: SafeArea(
                child: Column(children: [
              if (client.error.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(client.error,
                        style: const TextStyle(color: Color(0xFF9A3412)))),
              if (client.busy) const LinearProgressIndicator(),
              Expanded(
                  child: client.locked
                      ? status()
                      : LayoutBuilder(builder: (context, box) {
                          final picker = Column(children: [
                            const Padding(
                                padding: EdgeInsets.fromLTRB(32, 24, 32, 8),
                                child: TransactionHeading('OOB MENU',
                                    subtitle: 'Choose your drinks')),
                            Padding(
                                padding: const EdgeInsets.all(16),
                                child: TextField(
                                    decoration: const InputDecoration(
                                        labelText: 'Find a drink',
                                        prefixIcon: Icon(Icons.search)),
                                    onChanged: (value) =>
                                        setState(() => query = value))),
                            Expanded(
                                child: ListView(children: [
                              for (final p in client.products.where((p) =>
                                  (p['name'] as String)
                                      .toLowerCase()
                                      .contains(query.toLowerCase())))
                                ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 8),
                                    title: Text(p['name'] as String,
                                        style: OobTypography.bodyBold),
                                    subtitle: Text(p['description'] as String,
                                        style: OobTypography.italic),
                                    trailing: Text(centavos(p['price'] as num),
                                        style: OobTypography.price),
                                    onTap:
                                        client.busy || client.cart.length >= 50
                                            ? null
                                            : () => add(p)),
                              const FooterWordmark(),
                            ])),
                          ]);
                          if (box.maxWidth >= 850) {
                            return Row(children: [
                              Expanded(child: picker),
                              const VerticalDivider(width: 1),
                              Expanded(child: cart())
                            ]);
                          }
                          return Column(children: [
                            Expanded(child: picker),
                            const Divider(height: 1),
                            SizedBox(height: box.maxHeight * .45, child: cart())
                          ]);
                        })),
            ])),
          ));
}

class StaffConnectionButton extends ConsumerWidget {
  const StaffConnectionButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
      tooltip: 'Staff connection settings',
      iconSize: 48,
      constraints: const BoxConstraints.tightFor(width: 96, height: 96),
      icon: const Icon(Icons.settings_outlined),
      onPressed: () async {
        final password = TextEditingController();
        final allowed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('Staff connection settings'),
                    content: TextField(
                        controller: password,
                        obscureText: true,
                        decoration: const InputDecoration(
                            labelText: 'Existing menu admin password')),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Back')),
                      FilledButton(
                          onPressed: () async {
                            final accepted = await ref
                                .read(adminPasswordProvider.notifier)
                                .verify(password.text);
                            if (!context.mounted) return;
                            if (accepted) {
                              Navigator.pop(context, true);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Incorrect staff password')));
                            }
                          },
                          child: const Text('Continue'))
                    ]));
        if (allowed == true && context.mounted) {
          await Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => Theme(
                      data: transactionTheme(Theme.of(context)),
                      child: const MenuConnectionScreen())));
        }
      });
}

class MenuConnectionScreen extends StatefulWidget {
  const MenuConnectionScreen({super.key});
  @override
  State<MenuConnectionScreen> createState() => _MenuConnectionScreenState();
}

class _MenuConnectionScreenState extends State<MenuConnectionScreen> {
  final client = OrderClient.instance;
  late final address = TextEditingController(text: client.host);
  late final port = TextEditingController(text: '${client.port}');
  late final pin = TextEditingController(text: client.pin);
  final code = TextEditingController();
  String message = '';
  @override
  void dispose() {
    address.dispose();
    port.dispose();
    pin.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: client,
      builder: (context, _) => Scaffold(
          appBar: AppBar(
              toolbarHeight: 96,
              leadingWidth: 96,
              leading: _largeBackButton(context),
              title: const Text('Staff / Connection')),
          body: ListView(padding: const EdgeInsets.all(32), children: [
            Text(client.connection,
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
                'Connect Android Wi-Fi to the POS hotspot first. Copy the address and full certificate fingerprint directly from the POS Connection screen.'),
            const SizedBox(height: 24),
            TextField(
                controller: address,
                decoration: const InputDecoration(
                    labelText: 'POS IPv4 address',
                    hintText: 'Address displayed on the POS')),
            TextField(
                controller: port,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Port')),
            TextField(
                controller: pin,
                maxLines: 3,
                autocorrect: false,
                decoration: const InputDecoration(
                    labelText:
                        'Certificate SHA-256 fingerprint (64 characters)')),
            TextField(
                controller: code,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Pairing code (blank if already paired)')),
            const SizedBox(height: 24),
            FilledButton(
                onPressed: client.busy
                    ? null
                    : () async {
                        try {
                          await client.configure(
                              address.text,
                              int.tryParse(port.text) ?? 0,
                              pin.text,
                              code.text);
                          code.clear();
                          if (mounted) {
                            setState(() => message =
                                'Connected. Settings saved on this tablet.');
                          }
                        } catch (e) {
                          if (mounted) setState(() => message = '$e');
                        }
                      },
                child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Test connection and save'))),
            const SizedBox(height: 16),
            Text(message),
            const Text(
                'After an IP change, update the address and leave the code blank. Keep the same fingerprint and credentials to recover active orders. Never accept a fingerprint sent by an unknown network device.'),
          ])));
}
