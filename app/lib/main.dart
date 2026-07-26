import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/cart_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/billing/billing_screen.dart';
import 'services/connectivity_service.dart';
import 'services/local_db_service.dart';
import 'services/receipt_printer.dart';

const _supabaseUrl = 'https://xawpxbhglzhaibmcpwho.supabase.co';
const _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhhd3B4YmhnbHpoYWlibWNwd2hvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcxMTA4MTMsImV4cCI6MjA5MjY4NjgxM30.rin8K6vTWF_L-gCJKw1dyf0Vm2RoDvxcMSKSnClWy9E';

final _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );
  final currentUser = Supabase.instance.client.auth.currentUser;
  if (currentUser != null) {
    await LocalDbService.initForUser(currentUser.id);
  }
  await ConnectivityService.instance.init();
  // Pre-warm PDF fonts so the first print has no delay.
  ReceiptPrinter.preWarm();
  // Fire-and-forget: app opens immediately with local data, cloud pull happens in background
  if (currentUser != null) {
    ConnectivityService.instance.pullFromCloud();
  }
  runApp(const BillCatApp());
}

class BillCatApp extends StatefulWidget {
  const BillCatApp({super.key});

  @override
  State<BillCatApp> createState() => _BillCatAppState();
}

class _BillCatAppState extends State<BillCatApp> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _handleIncomingLinks();
  }

  void _handleIncomingLinks() {
    _appLinks.uriLinkStream.listen((uri) {
      if (uri.fragment.contains('type=recovery') ||
          uri.queryParameters['type'] == 'recovery') {
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
          (route) => false,
        );
      }
    });

    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      if (data.event == AuthChangeEvent.signedIn && user != null) {
        // `signedIn` also fires on token refresh / session restore for the SAME
        // user — clearing then would wipe local data that hasn't synced yet.
        // Only wipe when a genuinely different account signs in.
        final switchingAccount = LocalDbService.currentUserId != null &&
            LocalDbService.currentUserId != user.id;
        await LocalDbService.initForUser(user.id);
        if (switchingAccount) {
          await LocalDbService.clearAll();
        }
        await ConnectivityService.instance.pullFromCloud();

        final provider = user.appMetadata['provider'] as String?;
        if (provider == 'google') {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const BillingScreen()),
            (route) => false,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        title: 'BillCat',
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF1A3A5F),
          useMaterial3: true,
          scrollbarTheme: ScrollbarThemeData(
            thickness: WidgetStateProperty.all(4),
            radius: const Radius.circular(4),
            thumbColor: WidgetStateProperty.all(const Color(0xFFCBD5E1)),
            trackColor: WidgetStateProperty.all(Colors.transparent),
            trackBorderColor: WidgetStateProperty.all(Colors.transparent),
            crossAxisMargin: 2,
            mainAxisMargin: 4,
          ),
        ),
        home: Supabase.instance.client.auth.currentUser != null
            ? const BillingScreen()
            : const LoginScreen(),
      ),
    );
  }
}
