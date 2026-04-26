// Location: lib/screens/system_protocols_screen.dart

import 'dart:io';
import 'dart:ui'; // 🔥 Needed for the Glassmorphism blur!
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart'; // 🔥 THE AI ENGINE

import '../widgets/doodle_background.dart';
import 'login_screen.dart';
import 'operator_profile_screen.dart';
import 'master_pin_setup_screen.dart'; 
import '../services/email_service.dart';
import 'otp_verification_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:screen_protector/screen_protector.dart'; // 🔥 NEEDED FOR STEALTH MODE

class SystemProtocolsScreen extends StatefulWidget {
  const SystemProtocolsScreen({super.key});

  @override
  State<SystemProtocolsScreen> createState() => _SystemProtocolsScreenState();
}

class _SystemProtocolsScreenState extends State<SystemProtocolsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  
  bool _biometricsEnabled = false;
  bool _stealthModeEnabled = false; 
  bool _isAppLockEnabled = false; 
  
  bool _isProcessing = false;
  bool _isLoadingSettings = true; 

  File? _profileImage; 

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final String userKey = 'operator_avatar_${user?.uid}'; 
    final imagePath = prefs.getString(userKey);
    
    setState(() {
      _biometricsEnabled = (prefs.getString('vaultAuthMethod') == 'Biometrics');
      _stealthModeEnabled = prefs.getBool('stealthMode') ?? false; 
      
      _isAppLockEnabled = prefs.containsKey('app_master_pin');
      
      if (imagePath != null && imagePath.isNotEmpty) {
        final file = File(imagePath);
        if (file.existsSync()) {
          _profileImage = file;
        } else {
          _profileImage = null;
        }
      } else {
        _profileImage = null;
      }
      
      _isLoadingSettings = false; 
    });
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const MasterPinSetupScreen()));
      _loadSettings(); 
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('app_master_pin');
      await prefs.remove('app_biometrics');
      setState(() => _isAppLockEnabled = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("App Startup Lock Disabled"), 
          backgroundColor: Colors.orange,
        ));
      }
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (_isProcessing) return; 
    setState(() => _isProcessing = true); 

    final prefs = await SharedPreferences.getInstance();
    setState(() => _biometricsEnabled = value);
    
    if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (value) {
      await prefs.setString('vaultAuthMethod', 'Biometrics');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Biometric Override Enabled"), backgroundColor: Colors.green, duration: Duration(milliseconds: 800)));
      }
    } else {
      await prefs.setString('vaultAuthMethod', 'Password');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reverted to PIN Security"), backgroundColor: Colors.orange, duration: Duration(milliseconds: 800)));
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isProcessing = false); 
  }

  Future<void> _toggleStealthMode(bool value) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final prefs = await SharedPreferences.getInstance();
    setState(() => _stealthModeEnabled = value);

    if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

    await prefs.setBool('stealthMode', value);

    // 🔥 THE ACTUAL STEALTH ACTIVATION LOGIC
    try {
      if (value) {
        await ScreenProtector.preventScreenshotOn(); 
        await ScreenProtector.protectDataLeakageWithColor(Colors.black); // Blacks out recent apps
      } else {
        await ScreenProtector.preventScreenshotOff();
        await ScreenProtector.protectDataLeakageWithColorOff();
      }
    } catch (e) {
      debugPrint("Stealth Mode Error: $e");
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(value ? "Stealth Mode Activated: Screen hidden" : "Stealth Mode Disabled: Screen visible"), 
        backgroundColor: value ? Colors.deepPurpleAccent : Colors.blueGrey, 
        duration: const Duration(milliseconds: 800)
      ));
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _resetSecretVaultPin() async {
    if (_isProcessing) return;
    
    final email = user?.email ?? "operator@fractalvault.com";

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D2137),
        title: const Text("RESET SECRET PIN?", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text(
          "To reset your Secret Vault PIN, a secure 6-digit code will be sent to your registered channel:\n\n$email\n\nProceed with transmission?", 
          style: const TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text("CANCEL", style: TextStyle(color: Colors.white54))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("SEND CODE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      )
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      try {
        final otpCode = await EmailService().dispatchPinResetOtp(email);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("✅ Code Dispatched: Check your inbox"), 
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ));

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpVerificationScreen(validOtp: otpCode),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("❌ Protocol Failure: $e"), 
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ));
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _terminateSession() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true); 
    await FirebaseAuth.instance.signOut(); 
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
    }
  }

  Future<void> _showOperatorProfile() async {
    if (_isProcessing) return;
    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500), 
        reverseTransitionDuration: const Duration(milliseconds: 350), 
        pageBuilder: (context, animation, secondaryAnimation) => const OperatorProfileScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final scaleCurve = CurvedAnimation(parent: animation, curve: Curves.fastLinearToSlowEaseIn, reverseCurve: Curves.easeOut);
          final fadeCurve = CurvedAnimation(parent: animation, curve: Curves.easeIn);
          return FadeTransition(opacity: fadeCurve, child: ScaleTransition(scale: Tween<double>(begin: 0.85, end: 1.0).animate(scaleCurve), child: child));
        },
      ),
    );
    if (mounted) _loadSettings(); 
  }

  // 🔥 THE FROSTED GLASS AI WINDOW
  void _showAIWindow(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SafeArea(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0), 
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.75, // 🔥 Made taller for chat
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D2137).withOpacity(0.75), 
                    border: Border(
                      top: BorderSide(color: const Color(0xFF90CAFF).withOpacity(0.8), width: 1.5),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.4, 
                          child: const CodeDoodleBackground(
                            icons: [Icons.smart_toy, Icons.memory, Icons.terminal, Icons.code, Icons.data_object, Icons.analytics],
                          ),
                        ),
                      ),
                      SystemAIWindow(onToggleStealth: _toggleStealthMode), // 👈 Gives AI the keys to the switch!
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    ImageProvider? avatarImage;
    if (_profileImage != null) {
      avatarImage = FileImage(_profileImage!); 
    } else if (user?.photoURL != null) {
      avatarImage = NetworkImage(user!.photoURL!); 
    }

    return Stack(
      children: [
        Container(
          height: double.infinity, width: double.infinity,
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [colors.primary, Colors.white], stops: const [0.2, 0.8])),
        ),
        
        const CodeDoodleBackground(icons: [Icons.settings, Icons.build, Icons.memory, Icons.tune, Icons.admin_panel_settings, Icons.developer_board]),
        
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20), 
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("SYSTEM PROTOCOLS", style: TextStyle(color: Color(0xFF90CAFF), fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                    
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D2137).withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF90CAFF).withOpacity(0.5)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.smart_toy, color: Color(0xFF90CAFF)),
                        onPressed: () => _showAIWindow(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              
              Expanded(
                child: _isLoadingSettings 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF90CAFF)))
                    : IgnorePointer(
                  ignoring: _isProcessing,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      InkWell(
                        onTap: _showOperatorProfile,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: const Color(0xFF0D2137), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF90CAFF).withOpacity(0.3))),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 30, backgroundColor: const Color(0xFF90CAFF).withOpacity(0.2), backgroundImage: avatarImage,
                                child: avatarImage == null ? const Icon(Icons.person, size: 35, color: Color(0xFF90CAFF)) : null,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("OPERATOR ID:", style: TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'Courier', letterSpacing: 1.5)),
                                    Text(user?.email ?? "Offline.Agent@vault.com", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      const Text("Clearance: MAXIMUM", style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontFamily: 'Courier', fontWeight: FontWeight.bold)),
                                    ]),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.white54),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      const Text("SECURITY CONFIGURATIONS", style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),

                      _buildSettingsTile(
                        icon: Icons.shield_moon,
                        title: "Master App Lock",
                        subtitle: _isAppLockEnabled ? "Startup Security Active" : "Unsecured - Direct Entry",
                        trailing: Switch(
                          value: _isAppLockEnabled,
                          onChanged: _toggleAppLock,
                          activeColor: const Color(0xFF90CAFF),
                          inactiveTrackColor: Colors.white10,
                        ),
                      ),

                      _buildSettingsTile(
                        icon: Icons.fingerprint,
                        title: "Biometric Authorization",
                        subtitle: "Use fingerprint/face to unlock Secret Vault",
                        trailing: Switch(
                          value: _biometricsEnabled,
                          onChanged: _toggleBiometrics,
                          activeColor: const Color(0xFF90CAFF),
                          inactiveTrackColor: Colors.white10,
                        ),
                      ),
                      
                      _buildSettingsTile(
                        icon: Icons.lock_reset,
                        title: "Reset Secret Vault PIN",
                        subtitle: "Forgot PIN? Send email verification",
                        trailing: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                        onTap: _resetSecretVaultPin, 
                      ),

                      _buildSettingsTile(
                        icon: Icons.visibility_off,
                        title: "Stealth Mode",
                        subtitle: "Hide app contents from recent apps screen",
                        trailing: Switch(
                          value: _stealthModeEnabled, 
                          onChanged: _toggleStealthMode, 
                          activeColor: const Color(0xFF90CAFF),
                          inactiveTrackColor: Colors.white10,
                        ),
                      ),

                      const SizedBox(height: 40),

                      InkWell(
                        onTap: _terminateSession,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent, width: 1.5)),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.power_settings_new, color: Colors.redAccent, size: 24),
                              SizedBox(width: 10),
                              Text("TERMINATE SESSION", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 100), 
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, required String subtitle, required Widget trailing, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: const Color(0xFF0D2137).withOpacity(0.6), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF90CAFF).withOpacity(0.2))),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(backgroundColor: const Color(0xFF90CAFF).withOpacity(0.2), child: Icon(icon, color: const Color(0xFF90CAFF), size: 22)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        trailing: trailing,
      ),
    );
  }
}

// =====================================================================
// 🔥 THE SYSTEM A.I. CHAT INTERFACE (WITH FUNCTION CALLING)
// =====================================================================
class SystemAIWindow extends StatefulWidget {
  final ValueChanged<bool> onToggleStealth; // 👈 AI's key to the physical UI

  const SystemAIWindow({super.key, required this.onToggleStealth});

  @override
  State<SystemAIWindow> createState() => _SystemAIWindowState();
}

class _SystemAIWindowState extends State<SystemAIWindow> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late final GenerativeModel _model;
  late final ChatSession _chatSession;
  
  bool _isLoading = false;
  final List<Map<String, String>> _messages = []; 

  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();
    _initializeAI();
  }

  void _initializeAI() {
    // 🛡️ 1. DEFINE THE AI'S ABILITIES (Tools)
    final aiTools = [
      Tool(functionDeclarations: [
        FunctionDeclaration(
          'set_stealth_mode',
          'Enables or disables the vault stealth mode. Use this when the operator asks to go dark, hide the app, or enable/disable stealth.',
          Schema(
            SchemaType.object,
            properties: {
              'enabled': Schema(SchemaType.boolean, description: 'True to enable stealth mode, false to disable.')
            },
            requiredProperties: ['enabled'],
          ),
        ),
        FunctionDeclaration(
          'check_node_health',
          'Pings the 5 decentralized network nodes to check their online status and quorum health.',
          Schema(SchemaType.object),
        )
      ]),
    ];

    // 🛡️ 2. SYSTEM INSTRUCTION
    final systemInstruction = Content.system(
      "You are the 'System A.I.', an elite cyber-guardian for the 'Fractal Vault'. "
      "Your operators are Ritankar and Tista. "
      "PRIME DIRECTIVES: "
      "1. You have access to system tools. Use them when requested. "
      "2. If a node or component is reported as OFFLINE, you are authorized to analyze the technical situation and provide expert hypotheses on potential causes (e.g., handshake timeouts, packet loss, or server-side maintenance). "
      "3. Always reassure the operator of the Vault's integrity if the Quorum is still stable. "
      "4. Keep your tone elite, tactical, and helpful."
    );

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      tools: aiTools, // 👈 INJECT THE TOOLS INTO THE BRAIN
      systemInstruction: systemInstruction,
    );

    _chatSession = _model.startChat();
    
    _messages.add({
      'role': 'ai',
      'text': "AI Core Online. System tools integrated. Awaiting command..."
    });
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    
    _chatController.clear();
    _scrollToBottom();

    try {
      final response = await _chatSession.sendMessage(Content.text(text));
      
      // 🧠 DID GEMINI DECIDE TO CALL A FUNCTION?
      if (response.functionCalls.isNotEmpty) {
        for (final call in response.functionCalls) {
          
          // ⚡ TRIGGER: STEALTH MODE
          if (call.name == 'set_stealth_mode') {
            final isEnabled = call.args['enabled'] as bool;
            
            // ACTUALLY FLIP THE SWITCH IN THE APP!
            widget.onToggleStealth(isEnabled);
            
            // Tell Gemini the mission was successful
            final funcResponse = await _chatSession.sendMessage(
              Content.functionResponse(call.name, {'status': 'SUCCESS', 'stealth_active': isEnabled})
            );
            
            setState(() {
              _messages.add({'role': 'ai', 'text': funcResponse.text ?? "Stealth Protocol Executed."});
            });
          }
          
          // ⚡ TRIGGER: NODE HEALTH DIAGNOSTIC
         // ⚡ TRIGGER: DYNAMIC 5-NODE DIAGNOSTIC
else if (call.name == 'check_node_health') {
  setState(() => _isLoading = true);

  // 🌐 Pull the Project ID from the environment
  final String supabaseId = dotenv.env['SUPABASE_PROJECT_ID'] ?? '';

  final results = await Future.wait([
    _pingNode("https://$supabaseId.supabase.co/rest/v1/"), // 🔥 Now Dynamic!
    _pingNode("https://cloud.appwrite.io/v1/health"),
    _pingNode("https://api.cloudinary.com/v1_1/health"),
    _pingNode("https://ik.imagekit.io/"), 
  ]);

  int onlineCount = results.where((e) => e).length + 1; 
  
  final liveData = {
    'Node_1_Supabase': results[0] ? 'ONLINE' : 'OFFLINE',
    'Node_2_Appwrite': results[1] ? 'ONLINE' : 'OFFLINE',
    'Node_3_Cloudinary': results[2] ? 'ONLINE' : 'OFFLINE',
    'Node_4_ImageKit': results[3] ? 'ONLINE' : 'OFFLINE',
    'Node_5_Local_Hardware': 'ONLINE',
    'Quorum_Status': onlineCount >= 3 ? 'STABLE' : 'CRITICAL',
    'Network_Efficiency': "${(onlineCount / 5 * 100).toInt()}%"
  };

  final funcResponse = await _chatSession.sendMessage(
    Content.functionResponse(call.name, liveData)
  );

  setState(() {
    _messages.add({'role': 'ai', 'text': funcResponse.text ?? "Diagnostic complete."});
  });
}
        }
      } 
      // 🧠 NORMAL TEXT RESPONSE
      else {
        setState(() {
          _messages.add({'role': 'ai', 'text': response.text ?? "Error: Null neural response."});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'ai', 'text': "SYSTEM ERROR: Neural link severed.\n$e"});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  // 🔥 PASTE IT HERE (Inside the _SystemAIWindowState class)
  Future<bool> _pingNode(String url) async {
  try {
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
    
    debugPrint("System Node Check [$url] returned: ${response.statusCode}");

    // 🛡️ THE SECURITY LOGIC: 
    // If the server responds with 200, 401 (Auth Error), or 404 (Not Found), 
    // it means the server is UP and active. 
    // We only fail if there is no response at all or a 500+ Server Error.
    return response.statusCode < 500; 
  } catch (e) {
    debugPrint("System Node Check [$url] failed: $e");
    return false; // This handles the SocketException (DNS failure)
  }
}
  


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy, color: Color(0xFF90CAFF), size: 28),
              const SizedBox(width: 12),
              const Text(
                "SYSTEM A.I.", 
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const Divider(color: Colors.white24, height: 20),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.only(bottom: 12, left: isUser ? 40 : 0, right: isUser ? 0 : 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF90CAFF).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                        bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                      ),
                      border: Border.all(color: isUser ? const Color(0xFF90CAFF).withOpacity(0.5) : Colors.white24),
                    ),
                    child: Text(msg['text']!, style: TextStyle(color: isUser ? Colors.white : const Color(0xFF90CAFF), fontFamily: isUser ? null : 'Courier')),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) const Align(alignment: Alignment.centerLeft, child: Text("Processing neural command...", style: TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'Courier'))),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFF071320).withOpacity(0.9), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF90CAFF).withOpacity(0.4))),
            child: Row(children: [
              Expanded(child: TextField(controller: _chatController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Enter system command...", hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16)))),
              Container(decoration: const BoxDecoration(color: Color(0xFF90CAFF), shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.send, color: Color(0xFF0D2137), size: 20), onPressed: _isLoading ? null : _sendMessage)),
            ]),
          ),
        ],
      ),
    );
  }
}