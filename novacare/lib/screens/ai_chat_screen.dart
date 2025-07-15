import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/supabase_service.dart';
// import '../models/chat_conversation.dart';
import 'chat_history_screen.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiChatScreen extends StatefulWidget {
  static const routeName = '/ai_chat';

  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  final FocusNode _textFieldFocus = FocusNode();
  final SupabaseService _supabaseService = SupabaseService();
  bool _isBotTyping = false;
  late AnimationController _typingAnimationController;

  final String apiUrl = 'http://172.20.10.7:8000/webhook';
  final String symptomsUrl = 'http://172.20.10.7:8000/symptoms';

  // Chat saving state
  String? _currentConversationId;
  bool _isChatSaved = false;
  bool _isSavingChat = false;

  // State management
  bool isStartPhase = true;
  bool isSymptomPhase = false;
  bool isLoading = false;
  List<String> availableSymptoms = [];
  List<String> selectedSymptoms = [];
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _addWelcomeMessage();

    // Listen for text changes to enable/disable send button
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _textFieldFocus.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add({
        'role': 'bot',
        'text':
            'Hello! I\'m your AI medical assistant. I\'ll help you understand your symptoms and provide preliminary guidance. Please note that this is not a substitute for professional medical advice.',
        'timestamp': DateTime.now(),
        'type': 'start',
      });
    });
  }

  Future<void> fetchSymptoms() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse(symptomsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          availableSymptoms = List<String>.from(data);
          isStartPhase = false;
          isSymptomPhase = true;
          isLoading = false;
        });

        // Add a bot message to guide the user
        _addBotMessage(
            'Please select all symptoms you\'re experiencing from the list below. You can select multiple symptoms.');
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage =
            'Unable to load symptoms. Please check your connection and try again.';
        isLoading = false;
      });
      debugPrint("Error fetching symptoms: $e");
    }
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add({
        'role': 'bot',
        'text': text,
        'timestamp': DateTime.now(),
      });
    });
    _scrollToBottom();
  }

  void _toggleSymptom(String symptom) {
    setState(() {
      if (selectedSymptoms.contains(symptom)) {
        selectedSymptoms.remove(symptom);
      } else {
        selectedSymptoms.add(symptom);
      }
    });
    HapticFeedback.selectionClick();
  }

  void _sendSymptoms() {
    if (selectedSymptoms.isEmpty) {
      _addBotMessage('Please select at least one symptom before proceeding.');
      return;
    }

    final message = 'My symptoms are: ${selectedSymptoms.join(', ')}';
    _sendMessage(message);

    setState(() {
      selectedSymptoms.clear();
      isSymptomPhase = false;
    });
  }

  void _skipSymptomSelection() {
    setState(() {
      isSymptomPhase = false;
    });
    _addBotMessage(
        'No problem! You can describe your symptoms in your own words. How can I help you today?');
  }

  Future<String> sendToBackend(String userMessage) async {
    try {
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'queryResult': {
                'queryText': userMessage,
              }
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['fulfillmentText'] ??
            'I apologize, but I couldn\'t process your request properly. Could you please rephrase your question?';
      } else {
        return 'I\'m experiencing some technical difficulties. Please try again in a moment.';
      }
    } catch (e) {
      debugPrint('Backend error: $e');
      return 'I\'m temporarily unavailable. Please check your internet connection and try again.';
    }
  }

  void _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    HapticFeedback.lightImpact();

    final userMessage = {
      'role': 'user',
      'text': message.trim(),
      'timestamp': DateTime.now(),
    };

    setState(() {
      _messages.add(userMessage);
      _isBotTyping = true;
    });

    _controller.clear();
    _scrollToBottom();

    // Log the activity
    try {
      await _supabaseService.logActivity(
        'ai_chat',
        'Asked: "${message.trim().length > 50 ? '${message.trim().substring(0, 50)}...' : message.trim()}"',
      );
    } catch (e) {
      // Silently handle logging errors
      debugPrint('Error logging activity: $e');
    }

    try {
      String botResponse = await sendToBackend(message);

      await Future.delayed(
          const Duration(milliseconds: 500)); // Simulate thinking time

      setState(() {
        _messages.add({
          'role': 'bot',
          'text': botResponse,
          'timestamp': DateTime.now(),
        });
        _isBotTyping = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'bot',
          'text':
              'I apologize for the inconvenience. There was an error processing your request. Please try again.',
          'timestamp': DateTime.now(),
        });
        _isBotTyping = false;
      });
    }

    _scrollToBottom();
  }

  // Chat saving methods
  Future<void> _saveChatConversation() async {
    if (_messages.isEmpty) return;

    setState(() {
      _isSavingChat = true;
    });

    try {
      // Filter out welcome/start messages for saving
      final messagesToSave =
          _messages.where((msg) => msg['type'] != 'start').toList();

      if (messagesToSave.isNotEmpty) {
        await _supabaseService.saveChatConversation(
          messagesToSave,
          conversationId: _currentConversationId,
        );

        setState(() {
          _isChatSaved = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chat conversation saved successfully!'),
              backgroundColor: Colors.teal,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save chat: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      debugPrint('Error saving chat: $e');
    } finally {
      setState(() {
        _isSavingChat = false;
      });
    }
  }

  Future<void> _showSaveChatDialog() async {
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.save_rounded, color: Colors.teal),
            SizedBox(width: 12),
            Text('Save Chat'),
          ],
        ),
        content: const Text(
          'Would you like to save this conversation? You can access it later from your chat history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Save Chat'),
          ),
        ],
      ),
    );

    if (shouldSave == true) {
      await _saveChatConversation();
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _currentConversationId = null;
      _isChatSaved = false;
      isStartPhase = true;
      isSymptomPhase = false;
      selectedSymptoms.clear();
    });
    _addWelcomeMessage();
  }

  Future<void> _showClearChatDialog() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.refresh_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Clear Chat'),
          ],
        ),
        content: const Text(
          'Are you sure you want to clear this conversation? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Clear Chat'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      _clearChat();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildStartButton() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading symptoms...'),
              ],
            )
          else if (errorMessage != null)
            Column(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: fetchSymptoms,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            )
          else
            ElevatedButton.icon(
              onPressed: fetchSymptoms,
              icon: const Icon(Icons.medical_services),
              label: const Text('Start Symptom Check'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSymptomSelector() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6, // Constrain height
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Fixed at top
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.checklist, color: Colors.teal),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Select your symptoms:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: _skipSymptomSelection,
                  child: const Text('Skip'),
                ),
              ],
            ),
          ),

          // Scrollable symptoms area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableSymptoms.map((symptom) {
                  final selected = selectedSymptoms.contains(symptom);
                  return FilterChip(
                    label: Text(symptom),
                    selected: selected,
                    onSelected: (_) => _toggleSymptom(symptom),
                    selectedColor: Colors.teal.shade100,
                    checkmarkColor: Colors.teal.shade700,
                    backgroundColor: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: selected
                            ? Colors.teal.shade300
                            : Colors.transparent,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Footer - Fixed at bottom
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Column(
              children: [
                if (selectedSymptoms.isNotEmpty) ...[
                  Text(
                    '${selectedSymptoms.length} sympt${selectedSymptoms.length == 1 ? '' : 's'} selected',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (selectedSymptoms.isNotEmpty)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                selectedSymptoms.clear();
                              });
                            },
                            icon: const Icon(Icons.clear, size: 18),
                            label: const Text('Clear All'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade300,
                              foregroundColor: Colors.grey.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: selectedSymptoms.isNotEmpty ? 8 : 0,
                        ),
                        child: ElevatedButton.icon(
                          onPressed: selectedSymptoms.isNotEmpty
                              ? _sendSymptoms
                              : null,
                          icon: const Icon(Icons.send, size: 18),
                          label: Text(selectedSymptoms.isEmpty
                              ? 'Select symptoms'
                              : 'Continue (${selectedSymptoms.length})'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedSymptoms.isNotEmpty
                                ? Colors.teal
                                : Colors.grey.shade300,
                            foregroundColor: selectedSymptoms.isNotEmpty
                                ? Colors.white
                                : Colors.grey.shade500,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 80, top: 8, bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...List.generate(3, (index) {
              return AnimatedContainer(
                duration: Duration(milliseconds: 300 + (index * 100)),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 8,
                width: 8,
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(
                    ((_typingAnimationController.value + (index * 0.3)) % 1.0) >
                            0.5
                        ? 0.8
                        : 0.3,
                  ),
                  shape: BoxShape.circle,
                ),
              );
            }),
            const SizedBox(width: 12),
            Text(
              'AI is analyzing...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg, int index) {
    if (msg['type'] == 'start') {
      return Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.teal.shade100),
        ),
        child: Column(
          children: [
            Text(
              msg['text'],
              style: TextStyle(
                color: Colors.teal.shade800,
                fontSize: 15,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildStartButton(),
          ],
        ),
      );
    }

    final isUser = msg['role'] == 'user';
    final timestamp = msg['timestamp'] as DateTime;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOut,
      margin: EdgeInsets.only(
        left: isUser ? 80 : 16,
        right: isUser ? 16 : 80,
        top: 4,
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: isUser
                  ? LinearGradient(
                      colors: [Colors.teal.shade600, Colors.teal.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isUser ? null : Colors.grey.shade100,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isUser ? 20 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isUser ? 0.1 : 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              msg['text'],
              style: TextStyle(
                color: isUser ? Colors.white : Colors.grey.shade800,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTime(timestamp),
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildInputArea() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _textFieldFocus,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sendMessage,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Describe your symptoms or ask a question...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _controller.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear, size: 20),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: !_isBotTyping && _controller.text.trim().isNotEmpty
                    ? () => _sendMessage(_controller.text)
                    : null,
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(14),
                  backgroundColor: _controller.text.trim().isNotEmpty
                      ? Colors.teal
                      : Colors.grey.shade300,
                ),
                child: Icon(
                  Icons.send,
                  color: _controller.text.trim().isNotEmpty
                      ? Colors.white
                      : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "AI Medical Assistant",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Save chat button
          if (_messages.length > 1 && !_isChatSaved)
            IconButton(
              onPressed: _isSavingChat ? null : _showSaveChatDialog,
              icon: _isSavingChat
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.teal,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              tooltip: 'Save Chat',
            ),

          // Chat saved indicator
          if (_isChatSaved)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 20,
              ),
            ),

          // Clear chat button
          if (_messages.length > 1)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'clear') {
                  _showClearChatDialog();
                } else if (value == 'save') {
                  _showSaveChatDialog();
                } else if (value == 'history') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatHistoryScreen(),
                    ),
                  );
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'history',
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, size: 20),
                      SizedBox(width: 12),
                      Text('Chat History'),
                    ],
                  ),
                ),
                if (!_isChatSaved)
                  const PopupMenuItem<String>(
                    value: 'save',
                    child: Row(
                      children: [
                        Icon(Icons.save_rounded, size: 20),
                        SizedBox(width: 12),
                        Text('Save Chat'),
                      ],
                    ),
                  ),
                const PopupMenuItem<String>(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, size: 20),
                      SizedBox(width: 12),
                      Text('Clear Chat'),
                    ],
                  ),
                ),
              ],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'Chat Options',
            ),
        ],
      ),
      body: Column(
        children: [
          if (isSymptomPhase) _buildSymptomSelector(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 16, bottom: 20),
              itemCount: _messages.length + (_isBotTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isBotTyping && index == _messages.length) {
                  return _buildTypingIndicator();
                }
                return _buildMessage(_messages[index], index);
              },
            ),
          ),
          if (!isSymptomPhase) _buildInputArea(),
        ],
      ),
    );
  }
}
