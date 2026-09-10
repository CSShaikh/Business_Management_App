import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:business_management_app/core/theme/app_theme.dart';
import 'package:business_management_app/firebase_options.dart';

import 'package:business_management_app/providers/business_provider.dart';
import 'package:business_management_app/providers/product_provider.dart';
import 'package:business_management_app/providers/customer_provider.dart';
import 'package:business_management_app/providers/supplier_provider.dart';
import 'package:business_management_app/providers/purchase_provider.dart';
import 'package:business_management_app/providers/sale_provider.dart';
import 'package:business_management_app/providers/payment_provider.dart';
import 'package:business_management_app/providers/expense_provider.dart';
import 'package:business_management_app/providers/ledger_provider.dart';
import 'package:business_management_app/providers/theme_provider.dart';

import 'package:business_management_app/screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const MyApp(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BusinessProvider>(
          create: (_) => BusinessProvider(),
        ),

        ChangeNotifierProvider<ProductProvider>(
          create: (_) => ProductProvider(),
        ),

        ChangeNotifierProvider<CustomerProvider>(
          create: (_) => CustomerProvider(),
        ),

        ChangeNotifierProvider<SupplierProvider>(
          create: (_) => SupplierProvider(),
        ),

        ChangeNotifierProvider<PurchaseProvider>(
          create: (_) => PurchaseProvider(),
        ),

        ChangeNotifierProvider<SaleProvider>(
          create: (_) => SaleProvider(),
        ),

        ChangeNotifierProvider<PaymentProvider>(
          create: (_) => PaymentProvider(),
        ),

        ChangeNotifierProvider<ExpenseProvider>(
          create: (_) => ExpenseProvider(),
        ),

        ChangeNotifierProvider<LedgerProvider>(
          create: (_) => LedgerProvider(),
        ),

        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
      ],
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (
        context,
        themeProvider,
        child,
      ) {
        return MaterialApp(
          title: 'Business Management App',

          debugShowCheckedModeBanner: false,

          theme: AppTheme.lightTheme,

          darkTheme: AppTheme.darkTheme,

          themeMode: themeProvider.themeMode,

          home: const SplashScreen(),
        );
      },
    );
  }
}
