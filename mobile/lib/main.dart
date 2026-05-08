import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/data_service.dart';
import 'utils/constants.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/new_order_screen.dart';
import 'screens/today_orders_screen.dart';
import 'screens/receive_payment_screen.dart';
import 'screens/add_asset_screen.dart';
import 'screens/add_inventory_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/invoice_screen.dart';
import 'screens/sync_status_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/payments_list_screen.dart';
import 'screens/expenses_list_screen.dart';
import 'screens/inventory_list_screen.dart';
import 'screens/assets_list_screen.dart';
import 'screens/partner_balances_screen.dart';
import 'screens/add_capital_screen.dart';
import 'screens/add_spending_screen.dart';
import 'screens/add_partner_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.init();
  await AuthService.loadApiUrl();
  await DataService.init();
  runApp(const TailorApp());
}

class TailorApp extends StatelessWidget {
  const TailorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: 'Tailor App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: AppColors.primary,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            secondary: AppColors.secondary,
            surface: AppColors.background,
          ),
          scaffoldBackgroundColor: AppColors.background,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          cardTheme: CardTheme(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          fontFamily: 'Roboto',
          useMaterial3: true,
        ),
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/new-order': (context) => const NewOrderScreen(),
          '/today-orders': (context) => const TodayOrdersScreen(),
          '/receive-payment': (context) => const ReceivePaymentScreen(),
          '/add-asset': (context) => const AddAssetScreen(),
          '/add-inventory': (context) => const AddInventoryScreen(),
          '/payments': (context) => const PaymentsListScreen(),
          '/expenses': (context) => const ExpensesListScreen(),
          '/inventory': (context) => const InventoryListScreen(),
          '/assets': (context) => const AssetsListScreen(),
          '/sync-status': (context) => const SyncStatusScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/partner-balances': (context) => const PartnerBalancesScreen(),
          '/add-capital': (context) => const AddCapitalScreen(),
          '/add-spending': (context) => const AddSpendingScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/order-detail') {
            final orderId = settings.arguments as int;
            return MaterialPageRoute(
              builder: (_) => OrderDetailScreen(orderId: orderId),
            );
          }
          if (settings.name == '/invoice') {
            final orderId = settings.arguments as int;
            return MaterialPageRoute(
              builder: (_) => InvoiceScreen(orderId: orderId),
            );
          }
          return null;
        },
      ),
    );
  }
}
