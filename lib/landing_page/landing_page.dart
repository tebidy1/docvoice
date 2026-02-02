import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'components/sticky_navbar.dart';
import 'sections/hero_section.dart';
import 'sections/comparison_section.dart';
import 'sections/how_it_works_section.dart';
import 'sections/demo_section.dart';
import 'sections/mobile_showcase_section.dart';
import 'sections/features_section.dart';
import 'sections/platforms_section.dart';
import 'sections/security_section.dart';
import 'sections/final_cta_section.dart';
import 'sections/cinematic_slider_section.dart';
import 'sections/footer_section.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedNote AI',
      debugShowCheckedModeBanner: false,
      theme: MedTheme.darkTheme,
      
      // Force RTL and Arabic
      locale: const Locale('ar', 'AE'),
      supportedLocales: const [
        Locale('ar', 'AE'),
        Locale('en', 'US'),
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox(),
        );
      },
      home: const LandingHomeScaffold(),
    );
  }
}

class LandingHomeScaffold extends StatefulWidget {
  const LandingHomeScaffold({super.key});

  @override
  State<LandingHomeScaffold> createState() => _LandingHomeScaffoldState();
}

class _LandingHomeScaffoldState extends State<LandingHomeScaffold> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _demoKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToDemo() {
    if (_demoKey.currentContext != null) {
      Scrollable.ensureVisible(
        _demoKey.currentContext!, 
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MedColors.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                const SizedBox(height: 80), // Navbar Spacer
                
                HeroSection(
                  onTryLive: _scrollToDemo,
                  onSeeExample: _scrollToDemo,
                ),
                
                const HowItWorksSection(),
                
                const MobileShowcaseSection(),

                // ComparisonSection Removed per user request
                // const ComparisonSection(),

                const PlatformsSection(),
                const SecuritySection(),
                
                FinalCTASection(onStartNow: _scrollToDemo),
                
                const CinematicSliderSection(),

                const FooterSection(),
              ],
            ),
          ),
          
          // Sticky Navbar overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: StickyNavbar(scrollController: _scrollController),
          ),
        ],
      ),
    );
  }
}
