import 'package:flutter/material.dart';
import 'package:sonnet/auth_screen.dart';
import 'package:sonnet/home_screen.dart';
import 'package:sonnet/prompt_screen.dart';

class TogglePage extends StatefulWidget {
  const TogglePage({super.key});

  @override
  State<TogglePage> createState() => _TogglePageState();
}

class _TogglePageState extends State<TogglePage> {
  bool showAuthScreen = false;
  bool showPromptScreen = false;

  void toggleScreen() {
    setState(() {
      showAuthScreen = true;
      showPromptScreen = false;
    });
  }

  void showPrompt() {
    setState(() {
      showAuthScreen = false;
      showPromptScreen = true;
    });
  }

  void showHome() {
    setState(() {
      showAuthScreen = false;
      showPromptScreen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showAuthScreen) {
      return AuthScreen(showPromptScreen: showPrompt);
    } else if (showPromptScreen) {
      return PromptScreen(showHomeScreen: showHome);
    } else {
      return HomeScreen(showPromptScreen: toggleScreen);
    }
  }
}
