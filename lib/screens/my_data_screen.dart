import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../controllers/compression_controller.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class MyDataScreen extends StatefulWidget {
  const MyDataScreen({super.key});

  @override
  State<MyDataScreen> createState() => _MyDataScreenState();
}

class _MyDataScreenState extends State<MyDataScreen> {
  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final _api = Get.find<ApiService>();
  final _auth = Get.find<AuthController>();
  late final Worker _authWorker;

  List<ActiveCompressionSession> _sessions = [];
  bool _loadingSessions = true;
  String? _deletingSessionId;
  bool _deletingAll = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tryFetchSessions();
    _authWorker = everAll([
      _auth.isLoading,
      _auth.isAuthenticated,
    ], (_) => _tryFetchSessions());
  }

  @override
  void dispose() {
    _authWorker.dispose();
    super.dispose();
  }

  void _tryFetchSessions() {
    if (!mounted) return;
    if (_auth.isLoading.value || !_auth.isAuthenticated.value) {
      setState(() => _loadingSessions = false);
      return;
    }
    _fetchSessions();
  }

  Future<void> _fetchSessions() async {
    if (!_auth.isAuthenticated.value) return;
    setState(() {
      _loadingSessions = true;
      _error = null;
    });
    try {
      final response = await _api.getActiveSessions();
      if (!mounted) return;
      setState(() {
        _sessions = response.sessions;
        _loadingSessions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSessions = false;
        _error = 'Failed to load sessions. Please try again.';
      });
    }
  }

  String _formatDate(int? timestampSec) {
    if (timestampSec == null) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampSec * 1000);
    final date =
        '${_monthNames[dt.month - 1]} ${dt.day}, ${dt.year}';
    final time = TimeOfDay.fromDateTime(dt).format(context);
    return '$date, $time';
  }

  Future<void> _deleteSession(String sessionId) async {
    setState(() {
      _deletingSessionId = sessionId;
      _error = null;
    });
    try {
      await _api.deleteSession(sessionId);
      if (Get.isRegistered<CompressionController>()) {
        Get.find<CompressionController>().removeLocalFilesForSession(sessionId);
      }
      if (!mounted) return;
      setState(() {
        _sessions = _sessions.where((s) => s.sessionId != sessionId).toList();
        _deletingSessionId = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deletingSessionId = null;
        _error = 'Failed to delete session. Please try again.';
      });
    }
  }

  Future<void> _deleteAll() async {
    if (_sessions.isEmpty) return;
    final n = _sessions.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all sessions?'),
        content: Text(
          'Are you sure you want to delete all $n session${n > 1 ? 's' : ''}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _deletingAll = true;
      _error = null;
    });
    final ids = _sessions.map((s) => s.sessionId).toList();
    try {
      await Future.wait(ids.map(_api.deleteSession));
      if (Get.isRegistered<CompressionController>()) {
        final compression = Get.find<CompressionController>();
        for (final id in ids) {
          compression.removeLocalFilesForSession(id);
        }
      }
      if (!mounted) return;
      setState(() {
        _sessions = [];
        _deletingAll = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deletingAll = false;
        _error =
            'Failed to delete all sessions. Some sessions may have been deleted.';
      });
      await _fetchSessions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Data',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Obx(() {
        if (_auth.isLoading.value) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text(
                  'Loading...',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        if (!_auth.isAuthenticated.value) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Authentication Required',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Please log in to view your data.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _fetchSessions,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Text(
                      'Manage your active compression sessions',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (_sessions.isNotEmpty)
                    TextButton.icon(
                      onPressed: _deletingAll ? null : _deleteAll,
                      icon: _deletingAll
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.delete_outline, size: 20),
                      label: Text(_deletingAll ? 'Deleting...' : 'Delete All'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: AppColors.error,
                        disabledBackgroundColor: AppColors.error.withValues(
                          alpha: 0.5,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Material(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppColors.errorText,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          color: AppColors.error,
                          onPressed: () => setState(() => _error = null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (_loadingSessions)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text(
                        'Loading sessions...',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              else if (_sessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 88,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No Active Sessions',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "You don't have any active compression sessions.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._sessions.map(
                  (session) => _SessionCard(
                    session: session,
                    formatDate: _formatDate,
                    deleting: _deletingSessionId == session.sessionId,
                    onDelete: () => _deleteSession(session.sessionId),
                  ),
                ),
              const SizedBox(height: 24),
              _AboutSessionDataCard(),
            ],
          ),
        );
      }),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.formatDate,
    required this.deleting,
    required this.onDelete,
  });

  final ActiveCompressionSession session;
  final String Function(int?) formatDate;
  final bool deleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.picture_as_pdf_outlined,
                color: AppColors.primary,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.filename.isEmpty
                          ? 'Unknown File'
                          : session.filename,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Created',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatDate(session.createdAt),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Auto deletes at',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatDate(session.expiresAt),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: deleting ? null : onDelete,
                icon: deleting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : const Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: 'Delete session',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutSessionDataCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Session Data',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'All sessions automatically expire and are deleted after 2 hours. '
                  'You can manually delete sessions at any time.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
