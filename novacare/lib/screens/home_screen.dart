import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/screens/auth/login_screen.dart';
import '/screens/ai_chat_screen.dart';
import '/screens/medical_records/medical_records_screen.dart'; // Make sure you have this screen!
import '/screens/settings/settings_screens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userName = '';
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    fetchUserName();
  }

  void fetchUserName() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('name')
          .eq('id', userId)
          .maybeSingle();

      setState(() {
        userName = response != null ? response['name'] ?? '' : '';
      });
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Screens for each tab index
  static const List<Widget> _widgetOptions = <Widget>[
    HomeContent(),          // Your current home content widget, defined below
    AiChatScreen(),         // Your AI Chat screen
    MedicalRecordsScreen(), // Medical records screen you have
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Welcome, ${userName.isNotEmpty ? userName : ''}!',
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') _logout();
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Text('Logout'),
                ),
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: Text('Settings'),
                ),
              ],
              child: CircleAvatar(
                backgroundColor: Colors.teal,
                child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: 'AI Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_shared),
            label: 'Medical Records',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// Extract your existing Home content into this widget for clarity
class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    const cardColor = Colors.white;
    const textColor = Colors.black87;
    const iconColor = Colors.teal;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const Text(
              '📌 Health Tips of the Moment',
              style: TextStyle(fontSize: 18, color: textColor),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: cardColor,
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          Icon(Icons.local_drink, size: 32, color: iconColor),
                          SizedBox(height: 8),
                          Text("Stay Hydrated",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, color: textColor)),
                          Text("Drink 8+ glasses of water daily.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Card(
                    color: cardColor,
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          Icon(Icons.medical_services, size: 32, color: iconColor),
                          SizedBox(height: 8),
                          Text("Visit Regularly",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, color: textColor)),
                          Text("Routine checkups help detect issues early.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text("Quick Access", style: TextStyle(fontSize: 18, color: textColor)),
            const SizedBox(height: 10),
            _quickAccessCard(
              icon: Icons.healing,
              title: "Symptom Checker",
              subtitle: "Let AI guide your next medical step.",
              onTap: () {
                // Switch tab to AI Chat on tap
                // Since this is inside HomeContent stateless widget,
                // we need a callback or use a method via context.
                // For now, use Navigator push:
                Navigator.pushNamed(context, '/ai_chat');
              },
            ),
            const SizedBox(height: 10),
            _quickAccessCard(
              icon: Icons.coronavirus,
              title: "COVID-19 Safety",
              subtitle: "Latest precautions and news updates.",
              onTap: () {
                Navigator.pushNamed(context, '/covid_info');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAccessCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Colors.teal.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(icon, color: Colors.teal),
          title: Text(title,
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle, style: const TextStyle(color: Colors.black54)),
        ),
      ),
    );
  }
}
