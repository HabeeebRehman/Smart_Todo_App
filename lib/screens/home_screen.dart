import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/task_tile.dart';
import 'login_screen.dart';

enum FilterStatus { all, pending, done }

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const HomeScreen({super.key, required this.onToggleTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Box box = Hive.box('tasks');
  String _searchQuery = '';
  TaskCategory? _selectedCategory;
  FilterStatus _filterStatus = FilterStatus.all;
  
  String get currentUser => AuthService().currentUser ?? '';

  List<Task> get tasks {
    final allTasks = box.values
        .map((e) => Task.fromMap(Map<String, dynamic>.from(e)))
        .where((t) => t.username == currentUser) // Filter by user
        .toList();

    return allTasks.where((task) {
      final matchesSearch = task.title.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == null || task.category == _selectedCategory;
      final matchesStatus = _filterStatus == FilterStatus.all ||
          (_filterStatus == FilterStatus.done && task.isDone) ||
          (_filterStatus == FilterStatus.pending && !task.isDone);

      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();
  }
  
  int get totalTasks => tasks.length;
  int get completedTasks => tasks.where((t) => t.isDone).length;

  void addTask(Task task) async {
    final key = await box.add(task.toMap());
    
    // Schedule notification
    await NotificationService().scheduleNotification(
      id: key,
      title: 'Task Reminder',
      body: 'Don\'t forget: ${task.title}',
      scheduledDate: task.dueDate,
    );
    
    setState(() {});
  }

  void updateTask(int key, Task task) {
    box.put(key, task.toMap());
    setState(() {});
  }

  void deleteTask(int key) async {
    await box.delete(key);
    await NotificationService().cancelNotification(key);
    setState(() {});
  }
  
  void _logout() async {
    await AuthService().logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen(onToggleTheme: widget.onToggleTheme)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayedTasks = tasks;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            _buildSummaryCard(theme),
            _buildSearchBar(theme),
            _buildFilterChips(),
            Expanded(
              child: displayedTasks.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: displayedTasks.length,
                      itemBuilder: (_, i) {
                        // We need to find the original index in the box to update/delete correctly
                        final allTasksMap = box.toMap(); // keys -> values
                        final filteredEntries = allTasksMap.entries.where((entry) {
                          final task = Task.fromMap(Map<String, dynamic>.from(entry.value));
                          if (task.username != currentUser) return false;
                          
                          final matchesSearch = task.title.toLowerCase().contains(_searchQuery.toLowerCase());
                          final matchesCategory = _selectedCategory == null || task.category == _selectedCategory;
                          final matchesStatus = _filterStatus == FilterStatus.all ||
                              (_filterStatus == FilterStatus.done && task.isDone) ||
                              (_filterStatus == FilterStatus.pending && !task.isDone);
                          return matchesSearch && matchesCategory && matchesStatus;
                        }).toList();
                        
                        final entry = filteredEntries[i];
                        final task = Task.fromMap(Map<String, dynamic>.from(entry.value));
                        final key = entry.key;

                        return TaskTile(
                          task: task,
                          onToggle: (v) {
                            task.isDone = v!;
                            box.put(key, task.toMap());
                            setState(() {});
                          },
                          onDelete: () => deleteTask(key),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTaskDialog(context),
        label: const Text('New Task'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $currentUser!',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Let\'s be productive today',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(theme.brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode),
                onPressed: widget.onToggleTheme,
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _logout,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    double progress = totalTasks == 0 ? 0 : completedTasks / totalTasks;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primaryColor, theme.primaryColor.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Progress',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '$completedTasks / $totalTasks tasks completed',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search tasks...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: theme.cardTheme.color,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('All', _filterStatus == FilterStatus.all, () {
            setState(() => _filterStatus = FilterStatus.all);
          }),
          const SizedBox(width: 8),
          _buildFilterChip('Pending', _filterStatus == FilterStatus.pending, () {
            setState(() => _filterStatus = FilterStatus.pending);
          }),
          const SizedBox(width: 8),
          _buildFilterChip('Done', _filterStatus == FilterStatus.done, () {
            setState(() => _filterStatus = FilterStatus.done);
          }),
          const VerticalDivider(width: 20),
           DropdownButton<TaskCategory?>(
            value: _selectedCategory,
            hint: const Text('Category'),
            underline: const SizedBox(),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Categories')),
              ...TaskCategory.values.map((c) => DropdownMenuItem(
                value: c,
                child: Text(c.name.toUpperCase()),
              ))
            ],
            onChanged: (v) => setState(() => _selectedCategory = v),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No tasks found',
            style: TextStyle(color: Colors.grey[500], fontSize: 18),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTaskDialog(BuildContext context) async {
    final titleCtrl = TextEditingController();
    Priority priority = Priority.low;
    TaskCategory category = TaskCategory.personal;
    DateTime date = DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'New Task',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'What needs to be done?',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Priority>(
                          value: priority,
                          isExpanded: true,
                          items: Priority.values.map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p.name.toUpperCase()),
                          )).toList(),
                          onChanged: (v) => setModalState(() => priority = v!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<TaskCategory>(
                          value: category,
                          isExpanded: true,
                          items: TaskCategory.values.map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.name.toUpperCase()),
                          )).toList(),
                          onChanged: (v) => setModalState(() => category = v!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null && context.mounted) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      setModalState(() {
                        date = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(DateFormat.yMMMd().add_jm().format(date)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (titleCtrl.text.isNotEmpty) {
                    addTask(Task(
                      title: titleCtrl.text,
                      priority: priority,
                      category: category,
                      dueDate: date,
                      username: currentUser, // Assign current user
                    ));
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Create Task'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
