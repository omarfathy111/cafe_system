import 'package:cafe_system/features/pos/ui/cashier_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'قهوة | إدارة الكافيه',
      locale: const Locale('ar'),
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Segoe UI',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF246B56)),
        scaffoldBackgroundColor: const Color(0xFFF7F5EF),
      ),
      initialRoute: CashierScreen.routeName,
      routes: {CashierScreen.routeName: (context) => const CashierScreen()},
    );
  }
}
