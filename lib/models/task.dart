
enum Priority { low, medium, high }
enum TaskCategory { personal, work, study, other }

class Task {
  String title;
  bool isDone;
  Priority priority;
  DateTime dueDate;
  TaskCategory category;
  String? username; // Owner of the task

  Task({
    required this.title,
    required this.priority,
    required this.dueDate,
    this.isDone = false,
    this.category = TaskCategory.personal,
    this.username,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'isDone': isDone,
        'priority': priority.index,
        'dueDate': dueDate.toIso8601String(),
        'category': category.index,
        'username': username,
      };

  factory Task.fromMap(Map map) => Task(
        title: map['title'] ?? '',
        isDone: map['isDone'] ?? false,
        priority: Priority.values[map['priority'] ?? 0],
        dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : DateTime.now(),
        category: map['category'] != null 
            ? TaskCategory.values[map['category']] 
            : TaskCategory.personal,
        username: map['username'],
      );
}
