import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'dart:async';

class MobileShowcaseSection extends StatefulWidget {
  const MobileShowcaseSection({super.key});

  @override
  State<MobileShowcaseSection> createState() => _MobileShowcaseSectionState();
}

class _MobileShowcaseSectionState extends State<MobileShowcaseSection> with TickerProviderStateMixin {
  int _currentStep = 0;
  Timer? _timer;
  
  // Animation controller for the Final Screen Scroll
  late AnimationController _scrollController;

  final List<Map<String, dynamic>> _steps = [
    {
      "title": "سجّل في أي وقت",
      "desc": "افتح التطبيق واضغط زر التسجيل. لا داعي للقلق حول الضوضاء أو اللهجة.",
      "icon": Icons.mic,
      "duration": 6500, // Longer for recording demo
    },
    {
      "title": "دقّق النص طبياً",
      "desc": "شاهد النص يتحول فوراً بذكاء يتعرف على الأدوية والمصطلحات المعقدة.",
      "icon": Icons.text_fields,
      "duration": 4000,
    },
    {
      "title": "اختر القالب",
      "desc": "SOAP، تحويل، أو تقرير خروج. بلمسة واحدة.",
      "icon": Icons.dashboard_customize,
      "duration": 4500, // Selection animation on chips
    },
    {
      "title": "نسخ للنظام",
      "desc": "الملاحظة النهائية منسقة وجاهزة. انسخها والصقها في نظام المستشفى.",
      "icon": Icons.copy_all,
      "duration": 6000, 
    },
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _scheduleNextStep();
  }

  void _scheduleNextStep() {
    final duration = _steps[_currentStep]['duration'] as int;
    _timer = Timer(Duration(milliseconds: duration), () {
      if (mounted) {
        setState(() {
          _currentStep = (_currentStep + 1) % _steps.length;
        });
        
        // Reset/Start animations based on step
        if (_currentStep == 3) {
           _scrollController.forward(from: 0);
        }
        
        _scheduleNextStep();
      }
    });
  }

  void _manualSelect(int index) {
    _timer?.cancel(); 
    setState(() => _currentStep = index);
    if (index == 3) _scrollController.forward(from: 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
// ... (rest of build methods)




  
  // Re-write _buildAnimatedTemplateCard to be simpler and cleaner with Animate
  Widget _buildSimpleTemplateCard(String title, bool isSelected) {
     // ... (Keep old helper if needed or replace)
     return Container(); 
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 24),
      color: MedColors.background, 
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 900;
              if (isMobile) {
                return Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 48),
                    _buildPhoneFrame(),
                    const SizedBox(height: 48),
                    _buildStepsList(),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 5, child: _buildPhoneFrame()),
                  const SizedBox(width: 80),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 48),
                        _buildStepsList(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: MedColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: MedColors.primary.withOpacity(0.2)),
              ),
              child: const Text("تطبيق الجوال", style: TextStyle(color: MedColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          "عيادتك في جيبك...\nفي كل وقت.",
          style: GoogleFonts.cairo(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "سواء كنت في جولة في المستشفى أو في العيادة، DocVoice معك لتدوين الملاحظات لحظة بلحظة.",
          style: TextStyle(color: MedColors.textMuted, fontSize: 18, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildStepsList() {
    return Column(
      children: List.generate(_steps.length, (index) {
        final isActive = _currentStep == index;
        final step = _steps[index];
        return InkWell(
          onTap: () => _manualSelect(index),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isActive ? MedColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isActive ? MedColors.primary.withOpacity(0.5) : Colors.transparent),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isActive ? MedColors.primary : MedColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(step['icon'] as IconData, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step['title'] as String,
                        style: TextStyle(
                          color: isActive ? Colors.white : MedColors.textMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(height: 8),
                        Text(
                          step['desc'] as String,
                          style: TextStyle(color: MedColors.textMuted.withOpacity(0.8), fontSize: 14),
                        ).animate().fadeIn().slideY(begin: -0.2, end: 0)
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPhoneFrame() {
    return Center(
      child: Container(
        width: 320, // Slightly wider for better Inbox look
        height: 640,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(48),
          border: Border.all(color: const Color(0xFF2A2A2A), width: 8),
          boxShadow: [
             BoxShadow(color: MedColors.primary.withOpacity(0.3), blurRadius: 80, offset: const Offset(0, 20)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Stack(
            children: [
              // Screen Content
              Positioned.fill(
                child: Directionality(
                  textDirection: TextDirection.ltr, // Force LTR for English App Mockup
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    child: KeyedSubtree(
                      key: ValueKey(_currentStep),
                      child: _buildScreenContent(_currentStep),
                    ),
                  ),
                ),
              ),
              
              // Dynamic Island
              Positioned(
                top: 12, left: 0, right: 0,
                child: Center(
                  child: Container(
                    width: 100, height: 28,
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              // Home Indicator
              Positioned(
                bottom: 8, left: 110, right: 110,
                child: Container(height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScreenContent(int stepIndex) {
    switch (stepIndex) {
      case 0: return _buildRecordScreen();
      case 1: return _buildEditScreen(showSelection: false);
      case 2: return _buildEditScreen(showSelection: true); 
      case 3: return _buildFinalResultScreen();
      default: return Container(color: Colors.black);
    }
  }

  // 1. INBOX / RECORD SCREEN (Based on Uploaded Image)
  Widget _buildRecordScreen() {
    return Container(
      color: const Color(0xFF111111), // Dark Inbox BG
      child: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 50),
              // App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Inbox", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Color(0xFF222222), shape: BoxShape.circle), child: const Icon(Icons.person, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Filter Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text("Today", style: TextStyle(color: MedColors.primary, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 20),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // List Mockup
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildInboxCard("Draft Note", "21-year old male, high fever...", "10:03", MedColors.warning),
                    _buildInboxCard("Sick Leave", "Recommendation for 3 days...", "09:58", MedColors.error),
                    _buildInboxCard("Draft Note", "Follow up visit, diabetes...", "Yesterday", MedColors.primary),
                  ],
                ),
              ),
            ],
          ),
          
          // Bottom Navigation Curve
          Positioned(
             bottom: 0, left: 0, right: 0,
             child: Container(
               height: 80,
               decoration: const BoxDecoration(
                 color: Color(0xFF1A1A1A),
                 borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
               ),
               child: const Row(
                 mainAxisAlignment: MainAxisAlignment.spaceAround,
                 children: [
                    Icon(Icons.inbox, color: MedColors.primary),
                    SizedBox(width: 40), // Gap for FAB
                    Icon(Icons.settings, color: Colors.grey),
                 ],
               ),
             ),
          ),

          // FAB (Mic) with Animation
          Positioned(
            bottom: 30, left: 0, right: 0,
            child: Center(
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF222222), // Dark outer ring
                  shape: BoxShape.circle,
                  boxShadow: [
                     BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 56, height: 56,
                    decoration: const BoxDecoration(
                      color: MedColors.error, // Red for Mic
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic, color: Colors.white, size: 28),
                  ).animate(
                    onPlay: (c) => c.repeat(reverse: true),
                  ).scale(begin: const Offset(1,1), end: const Offset(1.2, 1.2), duration: 800.ms)
                   .boxShadow(begin: const BoxShadow(color: Colors.transparent), end: BoxShadow(color: MedColors.error.withOpacity(0.6), blurRadius: 20, spreadRadius: 10)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInboxCard(String title, String preview, String time, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: iconColor.withOpacity(0.2), shape: BoxShape.circle), child: Icon(Icons.edit_note, color: iconColor, size: 16)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              const Icon(Icons.copy, color: Colors.grey, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(preview, style: const TextStyle(color: Colors.grey, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const Spacer(),
              const Text("Draft", style: TextStyle(color: MedColors.warning, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEditScreen({bool showSelection = false}) {
    return Container(
      color: const Color(0xFF111111),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 50),
          const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
             Icon(Icons.arrow_back, color: Colors.white),
             Text("Review", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
             Icon(Icons.check, color: MedColors.primary),
          ]),
          const SizedBox(height: 20),
          RichText(
            text: const TextSpan(
              style: TextStyle(color: Colors.white, fontSize: 18, height: 1.6),
              children: [
                TextSpan(text: "Pt presents with "),
                TextSpan(text: "severe migraine", style: TextStyle(backgroundColor: Color(0xFF263238), fontWeight: FontWeight.bold)),
                TextSpan(text: " started 3 days ago. Associated with "),
                TextSpan(text: "photophobia", style: TextStyle(backgroundColor: Color(0xFF263238))),
                TextSpan(text: ". Vitals are stable."),
              ]
            ),
          ),
          const Spacer(),
          // Suggestion Chips with Selection Simulation
          Wrap(spacing: 8, children: [
             _buildFakeChip("Migraine", isSelected: false),
             _buildFakeChip("Neurology", isSelected: false),
             _buildFakeChip("SOAP Note", isSelected: showSelection, delay: 1000.ms),
          ]),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFakeChip(String label, {bool isSelected = false, Duration delay = Duration.zero}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
    )
    .animate(target: isSelected ? 1 : 0)
    .tint(color: MedColors.primary, delay: delay, duration: 300.ms) // Animate to blue
    .boxShadow(begin: const BoxShadow(color: Colors.transparent), end: BoxShadow(color: MedColors.primary.withOpacity(0.5), blurRadius: 10))
    .scale(begin: const Offset(1,1), end: const Offset(1.05, 1.05), delay: delay, duration: 200.ms);
  }

  Widget _buildFinalResultScreen() {
    return Container(
      color: const Color(0xFF111111),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
           const SizedBox(height: 50),
           const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
             Icon(Icons.close, color: Colors.white),
             Text("Final Note", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
             Icon(Icons.share, color: MedColors.primary),
          ]),
          const SizedBox(height: 20),
          // Scrolling content
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, // White paper look
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedBuilder(
                animation: _scrollController,
                builder: (context, child) {
                  return SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(), // Auto-scroll only
                    controller: ScrollController(initialScrollOffset: _scrollController.value * 200), // Simulate scroll
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("SOAP NOTE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                        Divider(height: 20),
                        Text("SUBJECTIVE:", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text("Patient is a 21yo male presenting with severe migraine...", style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.5)),
                        SizedBox(height: 10),
                        Text("OBJECTIVE:", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text("Vitals stable. BP 120/80. No focal deficit.", style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.5)),
                        SizedBox(height: 10),
                        Text("ASSESSMENT:", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text("Acute Migraine without Aura.", style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.5)),
                        SizedBox(height: 10),
                        Text("PLAN:", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text("1. Ibuprofen 400mg.\n2. Rest in dark room.\n3. Follow up if worsens.", style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.5)),
                        SizedBox(height: 40), // Extra space for scroll effect
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: MedColors.success, borderRadius: BorderRadius.circular(30)),
            child: const Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Icon(Icons.copy, color: Colors.white, size: 20),
                 SizedBox(width: 8),
                 Text("Copy to System", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
               ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}


