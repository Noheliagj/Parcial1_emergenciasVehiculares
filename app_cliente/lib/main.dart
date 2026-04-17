import 'package:flutter/material.dart';
import 'theme.dart';
import 'pages/login_page.dart';

void main() => runApp(const TallerProApp());

class TallerProApp extends StatelessWidget {
  const TallerProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TallerPro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const LoginPage(),
    );
  }
}