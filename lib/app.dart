import 'package:flutter/material.dart';
import 'package:gov_agent/config/theme.dart';
import 'package:gov_agent/screens/home_screen.dart';

class GovAgentApp extends StatelessWidget {
  const GovAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GovAgent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
