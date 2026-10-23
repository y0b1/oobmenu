import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/menu_lock_settings.dart';
import '../theme/oob_colors.dart';
import '../theme/transaction_theme.dart';

/// Sits above the Navigator, including payment and owner dialogs. Locking never
/// clears the cart or interrupts authoritative POS synchronization.
class MenuLock extends StatefulWidget {
  const MenuLock({super.key, required this.child, required this.settings});
  final Widget child;
  final MenuLockSettings settings;
  @override
  State<MenuLock> createState() => _MenuLockState();
}

class _MenuLockState extends State<MenuLock> with WidgetsBindingObserver {
  final code = TextEditingController();
  Timer? idle;
  bool locked = true, busy = false;
  String error = '';
  int lockGeneration = 0;
  late final lockOverlay = OverlayEntry(builder: _content);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void activity() {
    if (locked) return;
    idle?.cancel();
    idle = Timer(const Duration(minutes: 5), lock);
  }

  void lock() {
    idle?.cancel();
    lockGeneration++;
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      locked = true;
      code.clear();
      error = '';
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      lock();
    }
  }

  Future<void> unlock() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    final generation = lockGeneration;
    try {
      final accepted = await widget.settings.unlock(code.text);
      if (!mounted || generation != lockGeneration) return;
      setState(() {
        locked = !accepted;
        error = accepted ? '' : 'Incorrect code. Try again.';
        code.clear();
      });
      if (accepted) {
        FocusManager.instance.primaryFocus?.unfocus();
        activity();
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    idle?.cancel();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    lockOverlay.markNeedsBuild();
    return Overlay(initialEntries: [lockOverlay]);
  }

  Widget _content(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => activity(),
        onPointerMove: (_) => activity(),
        onPointerSignal: (_) => activity(),
        child: Focus(
          onKeyEvent: (_, __) {
            activity();
            return KeyEventResult.ignored;
          },
          child: Stack(children: [
            ExcludeFocus(
                excluding: locked,
                child: IgnorePointer(ignoring: locked, child: widget.child)),
            if (locked)
              Positioned.fill(
                  child: BlockSemantics(
                      child: Theme(
                data: transactionTheme(Theme.of(context)),
                child: PopScope(
                    canPop: false,
                    child: Material(
                      color: OobColors.oobCream,
                      child: SafeArea(
                          child: Center(
                              child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: SizedBox(
                            width: 400,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const TransactionHeading('OOB MENU'),
                                  const SizedBox(height: 32),
                                  const Text('Enter code to continue',
                                      style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 24),
                                  TextField(
                                      controller: code,
                                      obscureText: true,
                                      enabled: !busy,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(4)
                                      ],
                                      decoration: const InputDecoration(
                                          labelText: '4-digit code'),
                                      onSubmitted: (_) => unlock()),
                                  if (error.isNotEmpty)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 16),
                                        child: Text(error)),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                      width: double.infinity,
                                      child: FilledButton(
                                          onPressed: busy ? null : unlock,
                                          child: const Text('Unlock menu'))),
                                ])),
                      ))),
                    )),
              ))),
          ]),
        ),
      );
}
