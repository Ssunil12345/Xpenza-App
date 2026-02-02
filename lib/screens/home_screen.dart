import 'package:expense_tracker/models/expense_model.dart';
import 'package:expense_tracker/screens/add_expense_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // --- STATE VARIABLES ---
  String _searchQuery = "";
  String _activeCategoryFilter = "All";
  DateTime _selectedMonth = DateTime.now();
  int _selectedYear = DateTime.now().year;

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- CATEGORY MANAGEMENT ---
  List<String> _getCategories() {
    final settingsBox = Hive.box('settings');
    final List<String> customCategories = List<String>.from(
      settingsBox.get('customCategories', defaultValue: <String>[]),
    );

    // Default categories (without "All" for filtering)
    final List<String> defaultCategories = [
      "Food",
      "Transport",
      "Shopping",
      "Bills",
    ];

    // Combine and remove duplicates using Set
    final Set<String> allCategoriesSet = {
      ...defaultCategories,
      ...customCategories,
    };

    // Return with "All" at the beginning for filter chips
    return ["All", ...allCategoriesSet.toList()];
  }

  // --- PDF EXPORT LOGIC ---
  Future<void> _exportToPDF(List<ExpenseModel> expenses) async {
    try {
      final pdf = pw.Document();
      final total = expenses.fold(0.0, (sum, item) => sum + item.amount);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  "Xpenza - Expense Report",
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                "Total: ₹${total.toStringAsFixed(2)}",
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  <String>['Date', 'Title', 'Category', 'Amount'],
                  ...expenses.map(
                    (e) => [
                      DateFormat('dd/MM/yyyy').format(e.date),
                      e.title,
                      e.category,
                      '₹${e.amount.toStringAsFixed(2)}',
                    ],
                  ),
                ],
              ),
            ];
          },
        ),
      );

      final bool result = await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Xpenza_Report_${DateFormat('MMM_yyyy').format(DateTime.now())}',
      );

      if (result && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("PDF Saved Successfully!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to save PDF"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- DATA LOGIC ---
  double _getBudget() {
    final settingsBox = Hive.box('settings');
    return settingsBox.get('monthlyLimit', defaultValue: 5000.0);
  }

  List<ExpenseModel> _getFilteredExpenses(List<ExpenseModel> allExpenses) {
    return allExpenses.where((e) {
      // Search filter
      final matchesSearch = e.title.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );

      // Category filter
      final matchesCategory =
          _activeCategoryFilter == "All" || e.category == _activeCategoryFilter;

      // Tab-based date filter
      bool matchesTab = true;
      final currentTab = _tabController.index;

      if (currentTab == 1) {
        // Today
        final now = DateTime.now();
        matchesTab =
            e.date.year == now.year &&
            e.date.month == now.month &&
            e.date.day == now.day;
      } else if (currentTab == 2) {
        // Monthly
        matchesTab =
            e.date.year == _selectedMonth.year &&
            e.date.month == _selectedMonth.month;
      } else if (currentTab == 3) {
        // Yearly
        matchesTab = e.date.year == _selectedYear;
      }

      return matchesSearch && matchesCategory && matchesTab;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<ExpenseModel>("expenses");
    final settingsBox = Hive.box('settings');

    final combinedListenable = Listenable.merge([
      box.listenable(),
      settingsBox.listenable(),
    ]);

    return AnimatedBuilder(
      animation: combinedListenable,
      builder: (context, _) {
        final allExpenses = box.values.toList().reversed.toList();
        final isDark = settingsBox.get('isDarkMode', defaultValue: false);

        final filteredExpenses = _getFilteredExpenses(allExpenses);

        final currentBudget = _getBudget();
        double totalSpent = filteredExpenses.fold(
          0.0,
          (sum, item) => sum + item.amount,
        );
        double remaining = currentBudget - totalSpent;
        double progress = (totalSpent / currentBudget).clamp(0.0, 1.0);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text(
              "Xpenza",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  controller: _tabController,
                  onTap: (index) => setState(() {}),
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3949AB), Color(0xFF5C6BC0)],
                    ),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: isDark
                      ? Colors.white70
                      : Colors.black54,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(text: "All"),
                    Tab(text: "Today"),
                    Tab(text: "Monthly"),
                    Tab(text: "Yearly"),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                ),
                onPressed: () => settingsBox.put('isDarkMode', !isDark),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded),
                onPressed: () => _exportToPDF(filteredExpenses),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => _showSettingsDialog(context),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(totalSpent, remaining, progress),
              ),

              // Month/Year Selector
              if (_tabController.index == 2 || _tabController.index == 3)
                SliverToBoxAdapter(child: _buildDateSelector(isDark)),

              if (filteredExpenses.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildChartSection(filteredExpenses, isDark),
                ),

              // Search Input
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: "Search transactions...",
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Colors.indigo,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = "");
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),

              // Category Filter
              SliverToBoxAdapter(
                child: _buildFilterRow(
                  _getCategories(),
                  _activeCategoryFilter,
                  (val) => setState(() => _activeCategoryFilter = val),
                  isDark,
                ),
              ),

              // Summary Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.indigo.withOpacity(0.1),
                          Colors.indigo.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.indigo.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Total Expenses",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${filteredExpenses.length} transactions",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "₹${totalSpent.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 15, 24, 16),
                  child: Text(
                    "Transaction History",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              filteredExpenses.isEmpty
                  ? _buildEmptyState(isDark)
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _ExpenseTile(
                            expense: filteredExpenses[index],
                            onTap: () => _showAddExpense(
                              context,
                              expense: filteredExpenses[index],
                            ),
                          ),
                          childCount: filteredExpenses.length,
                        ),
                      ),
                    ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddExpense(context),
            label: const Text(
              "Add Expense",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.add_rounded),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            elevation: 4,
          ),
        );
      },
    );
  }

  // --- HELPERS ---

  Widget _buildDateSelector(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: _tabController.index == 2
          ? _buildMonthSelector(isDark)
          : _buildYearSelector(isDark),
    );
  }

  Widget _buildMonthSelector(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () {
            setState(() {
              _selectedMonth = DateTime(
                _selectedMonth.year,
                _selectedMonth.month - 1,
              );
            });
          },
        ),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedMonth,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setState(() => _selectedMonth = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () {
            setState(() {
              _selectedMonth = DateTime(
                _selectedMonth.year,
                _selectedMonth.month + 1,
              );
            });
          },
        ),
      ],
    );
  }

  Widget _buildYearSelector(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () {
            setState(() => _selectedYear--);
          },
        ),
        InkWell(
          onTap: () async {
            final picked = await showDialog<int>(
              context: context,
              builder: (context) =>
                  _YearPickerDialog(initialYear: _selectedYear),
            );
            if (picked != null) {
              setState(() => _selectedYear = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  _selectedYear.toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () {
            setState(() => _selectedYear++);
          },
        ),
      ],
    );
  }

  Widget _buildFilterRow(
    List<String> items,
    String activeItem,
    Function(String) onSelect,
    bool isDark,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: items.map((item) {
          final isSelected = activeItem == item;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(item),
              selected: isSelected,
              onSelected: (val) => onSelect(item),
              selectedColor: Colors.indigo,
              backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide.none,
              elevation: isSelected ? 2 : 0,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeader(double spent, double remaining, double progress) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3949AB), Color(0xFF5C6BC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Remaining Balance",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${(progress * 100).toStringAsFixed(0)}%",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "₹${remaining.toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "of ₹${_getBudget().toStringAsFixed(0)} budget",
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              color: progress > 0.9 ? Colors.orangeAccent : Colors.white,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Spent: ₹${spent.toStringAsFixed(0)}",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                "Saved: ₹${remaining.toStringAsFixed(0)}",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(List<ExpenseModel> expenses, bool isDark) {
    Map<String, double> data = {};
    for (var e in expenses) {
      data[e.category] = (data[e.category] ?? 0) + e.amount;
    }

    Map<String, Color> catColors = {
      "Food": Colors.orangeAccent,
      "Transport": Colors.blueAccent,
      "Shopping": Colors.purpleAccent,
      "Bills": Colors.redAccent,
    };

    // Generate colors for custom categories
    final customCategories = data.keys.where((k) => !catColors.containsKey(k));
    final colors = [
      Colors.tealAccent,
      Colors.pinkAccent,
      Colors.cyanAccent,
      Colors.amberAccent,
      Colors.lightGreenAccent,
    ];
    int colorIndex = 0;
    for (var cat in customCategories) {
      catColors[cat] = colors[colorIndex % colors.length];
      colorIndex++;
    }

    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 35,
                sections: data.entries
                    .map(
                      (entry) => PieChartSectionData(
                        color: catColors[entry.key] ?? Colors.grey,
                        value: entry.value,
                        title: '',
                        radius: 18,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: data.entries
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: catColors[entry.key] ?? Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              "₹${entry.value.toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddExpense(BuildContext context, {ExpenseModel? expense}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseScreen(expense: expense),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const SettingsDialog());
  }

  Widget _buildEmptyState(bool isDark) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              "No expenses found",
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey[600],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Tap + to add your first expense",
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- EXPENSE TILE WIDGET ---
class _ExpenseTile extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback onTap;
  const _ExpenseTile({required this.expense, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Dismissible(
          key: Key(expense.hashCode.toString()),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.red, Colors.redAccent],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          onDismissed: (_) => expense.delete(),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey[200]!,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIcon(expense.category),
                    color: Colors.indigo,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${expense.category} • ${DateFormat("MMM d, yyyy").format(expense.date)}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  "-₹${expense.amount.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.redAccent,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String cat) {
    if (cat == "Food") return Icons.restaurant_rounded;
    if (cat == "Transport") return Icons.directions_car_rounded;
    if (cat == "Shopping") return Icons.shopping_bag_rounded;
    if (cat == "Bills") return Icons.receipt_long_rounded;
    return Icons.category_rounded;
  }
}

// --- YEAR PICKER DIALOG ---
class _YearPickerDialog extends StatelessWidget {
  final int initialYear;
  const _YearPickerDialog({required this.initialYear});

  @override
  Widget build(BuildContext context) {
    final years = List.generate(
      50,
      (index) => DateTime.now().year - 25 + index,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        height: 400,
        child: Column(
          children: [
            const Text(
              "Select Year",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: years.length,
                itemBuilder: (context, index) {
                  final year = years[index];
                  final isSelected = year == initialYear;
                  return ListTile(
                    title: Text(
                      year.toString(),
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? Colors.indigo : null,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: Colors.indigo.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () => Navigator.pop(context, year),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- SETTINGS DIALOG ---
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _budgetController;
  late TextEditingController _categoryController;

  @override
  void initState() {
    super.initState();
    final settingsBox = Hive.box('settings');
    final budget = settingsBox.get('monthlyLimit', defaultValue: 5000.0);
    _budgetController = TextEditingController(text: budget.toString());
    _categoryController = TextEditingController();
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _addCustomCategory() {
    final category = _categoryController.text.trim();
    if (category.isEmpty) return;

    final settingsBox = Hive.box('settings');
    final List<String> customCategories = List<String>.from(
      settingsBox.get('customCategories', defaultValue: []),
    );

    if (!customCategories.contains(category)) {
      customCategories.add(category);
      settingsBox.put('customCategories', customCategories);
      _categoryController.clear();
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Category '$category' added!"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _deleteCustomCategory(String category) {
    final settingsBox = Hive.box('settings');
    final List<String> customCategories = List<String>.from(
      settingsBox.get('customCategories', defaultValue: []),
    );

    customCategories.remove(category);
    settingsBox.put('customCategories', customCategories);
    setState(() {});
  }

  void _deleteAllExpenses() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear All Expenses?"),
        content: const Text(
          "This will permanently delete all your expense records. This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Hive.box<ExpenseModel>("expenses").clear();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("All expenses deleted!"),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text(
              "Delete All",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsBox = Hive.box('settings');
    final List<String> customCategories = List<String>.from(
      settingsBox.get('customCategories', defaultValue: []),
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Settings",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Monthly Budget
            const Text(
              "Monthly Budget",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: "₹ ",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 20),

            // Custom Categories
            const Text(
              "Custom Categories",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _categoryController,
                    decoration: InputDecoration(
                      hintText: "New category name",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addCustomCategory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // List of custom categories
            if (customCategories.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: customCategories.length,
                  itemBuilder: (context, index) {
                    final category = customCategories[index];
                    return ListTile(
                      title: Text(category),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _deleteCustomCategory(category),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),

            // Delete All Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _deleteAllExpenses,
                icon: const Icon(Icons.delete_sweep_rounded),
                label: const Text("Delete All Expenses"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final val = double.tryParse(_budgetController.text);
                    if (val != null) {
                      settingsBox.put('monthlyLimit', val);
                    }
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Save"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
