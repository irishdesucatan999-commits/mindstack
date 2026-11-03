import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(MindStackApp(prefs: prefs));
}

class MindStackApp extends StatefulWidget {
  const MindStackApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  State<MindStackApp> createState() => _MindStackAppState();
}

class _MindStackAppState extends State<MindStackApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final saved = widget.prefs.getInt('theme_mode');
    if (!mounted) return;
    setState(() {
      _themeMode = switch (saved) {
        1 => ThemeMode.light,
        2 => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    });
  }

  Future<void> _saveThemePreference() async {
    await widget.prefs.setInt(
      'theme_mode',
      switch (_themeMode) {
        ThemeMode.light => 1,
        ThemeMode.dark => 2,
        ThemeMode.system => 0,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindStack',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B7CFA),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C9BFF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101827),
      ),
      home: HomeScreen(
        prefs: widget.prefs,
        themeMode: _themeMode,
        onThemeChanged: (mode) {
          setState(() => _themeMode = mode);
          _saveThemePreference();
        },
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.prefs,
    required this.themeMode,
    required this.onThemeChanged,
  });

  final SharedPreferences prefs;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _notesKey = 'mindstack_notes';

  final TextEditingController _searchController = TextEditingController();
  final List<Color> _noteColors = const [
    Color(0xFFB8E7FF),
    Color(0xFFBFE8C5),
    Color(0xFFFFE6A7),
    Color(0xFFFFD7D7),
    Color(0xFFEAD8FF),
  ];

  List<Note> _notes = [];
  String _searchQuery = '';
  NotesSortOrder _sortOrder = NotesSortOrder.recent;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final raw = widget.prefs.getString(_notesKey);
    if (raw == null || raw.isEmpty) {
      setState(() {
        _notes = [
          Note(
            id: const Uuid().v4(),
            title: 'Welcome to MindStack',
            content:
                'Capture your quick ideas, reminders, and thoughtful notes here. Tap the + button to create your first entry.',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            colorIndex: 0,
          ),
        ];
      });
      await _saveNotes();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }

      final loaded = decoded
          .map<Note>((item) => Note.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      if (!mounted) return;
      setState(() => _notes = loaded);
    } catch (_) {
      if (!mounted) return;
      setState(() => _notes = []);
    }
  }

  Future<void> _saveNotes() async {
    final encoded = jsonEncode(_notes.map((note) => note.toJson()).toList());
    await widget.prefs.setString(_notesKey, encoded);
  }

  List<Note> get _filteredNotes {
    final query = _searchQuery.trim().toLowerCase();
    final notes = [..._notes];

    notes.sort((a, b) {
      switch (_sortOrder) {
        case NotesSortOrder.title:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case NotesSortOrder.recent:
          return b.updatedAt.compareTo(a.updatedAt);
      }
    });

    if (query.isEmpty) {
      return notes;
    }

    return notes
        .where(
          (note) =>
              note.title.toLowerCase().contains(query) ||
              note.content.toLowerCase().contains(query),
        )
        .toList();
  }

  Future<void> _openEditor({Note? note}) async {
    final result = await Navigator.push<Note>(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          note: note,
          noteColors: _noteColors,
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      final index = _notes.indexWhere((item) => item.id == result.id);
      if (index >= 0) {
        _notes[index] = result;
      } else {
        _notes.add(result);
      }
    });

    _saveNotes();
  }

  Future<void> _deleteNote(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _notes.removeWhere((note) => note.id == id);
    });
    await _saveNotes();
  }

  void _toggleTheme() {
    final nextMode = widget.themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    widget.onThemeChanged(nextMode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MindStack'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            onPressed: _toggleTheme,
            icon: Icon(
              widget.themeMode == ThemeMode.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search notes',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    PopupMenuButton<NotesSortOrder>(
                      tooltip: 'Sort notes',
                      onSelected: (value) => setState(() => _sortOrder = value),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: NotesSortOrder.recent,
                          child: Text('Recent'),
                        ),
                        const PopupMenuItem(
                          value: NotesSortOrder.title,
                          child: Text('Title'),
                        ),
                      ],
                      icon: const Icon(Icons.sort_rounded),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _filteredNotes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.sticky_note_2_outlined,
                              size: 56,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _notes.isEmpty
                                  ? 'No notes yet'
                                  : 'No notes match your search',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _notes.isEmpty
                                  ? 'Create your first note to get started.'
                                  : 'Try a different keyword or clear the query.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                      itemCount: _filteredNotes.length,
                      itemBuilder: (context, index) {
                        final note = _filteredNotes[index];
                        final color = _noteColors[note.colorIndex % _noteColors.length];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Card(
                            color: color.withValues(alpha: isDark ? 0.22 : 0.8),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _openEditor(note: note),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            note.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => _deleteNote(note.id),
                                          icon: const Icon(Icons.delete_outline_rounded),
                                          tooltip: 'Delete note',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      note.content,
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _formatDate(note.updatedAt),
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New note'),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}

enum NotesSortOrder { recent, title }

class Note {
  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.colorIndex,
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int colorIndex;

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? colorIndex,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'colorIndex': colorIndex,
      };

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String? ?? const Uuid().v4(),
      title: json['title'] as String? ?? 'Untitled',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      colorIndex: json['colorIndex'] as int? ?? 0,
    );
  }
}

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    this.note,
    required this.noteColors,
  });

  final Note? note;
  final List<Color> noteColors;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late int _selectedColorIndex;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _selectedColorIndex = widget.note?.colorIndex ?? 0;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final now = DateTime.now();

    if (title.isEmpty && content.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final savedNote = Note(
      id: widget.note?.id ?? const Uuid().v4(),
      title: title.isEmpty ? 'Untitled note' : title,
      content: content,
      createdAt: widget.note?.createdAt ?? now,
      updatedAt: now,
      colorIndex: _selectedColorIndex,
    );

    Navigator.pop(context, savedNote);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'New note' : 'Edit note'),
        actions: [
          TextButton.icon(
            onPressed: _saveNote,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose color',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.noteColors.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final selected = index == _selectedColorIndex;
                    final color = widget.noteColors[index];

                    return GestureDetector(
                      onTap: () => setState(() => _selectedColorIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 42,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? theme.colorScheme.primary
                                : (isDark
                                    ? Colors.white24
                                    : Colors.black12),
                            width: selected ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _titleController,
                style: theme.textTheme.headlineSmall,
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const Divider(),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'Write your note...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
