import 'package:flutter/material.dart';
import 'package:myreader/presentation/pages/bookshelf/bookshelf_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 1;

  final List<Widget> _pages = [
    const ReadingTab(),
    const BookshelfTab(),
    const BookFriendsTab(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chrome_reader_mode_outlined),
            selectedIcon: Icon(Icons.chrome_reader_mode),
            label: '阅读',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: '书架',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: '书友',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我',
          ),
        ],
      ),
    );
  }
}

class ReadingTab extends StatelessWidget {
  const ReadingTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('阅读')),
      body: Center(
        child: Text('从书架中选择一本书开始阅读', style: TextStyle(color: Colors.grey[600])),
      ),
    );
  }
}

class BookshelfTab extends StatelessWidget {
  const BookshelfTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const BookshelfPage();
  }
}

class BookFriendsTab extends StatelessWidget {
  const BookFriendsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('书友')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '书友动态即将上线',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Icon(Icons.mail_outline, color: Colors.black54),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey.shade300,
                  child: const Text('Q', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '我也呢班打工仔',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    '+14',
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _profileCard(
              context,
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium, color: Color(0xFFF4B400)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '成为付费会员',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '立即开通 19 元/月',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: const [
                Expanded(
                  child: _SimpleStatCard(
                    title: '充值币',
                    value: '余额 0.00',
                    icon: Icons.monetization_on_outlined,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _SimpleStatCard(
                    title: '福利',
                    value: '0天 | 赠币0.00',
                    icon: Icons.card_giftcard,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _profileCard(
              context,
              child: Column(
                children: [
                  _rowMetric('读书排行榜', '第 2 名', '6 分钟中'),
                  const Divider(height: 18),
                  _rowMetric('阅读时长', '1935 小时 38 分钟', '本月 6 分钟'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.7,
              children: const [
                _SimpleStatCard(
                  title: '在读',
                  value: '累计 60 本',
                  icon: Icons.east,
                ),
                _SimpleStatCard(
                  title: '读完',
                  value: '累计 16 本',
                  icon: Icons.check_circle,
                ),
                _SimpleStatCard(
                  title: '笔记',
                  value: '累计 86 个',
                  icon: Icons.edit_note,
                ),
                _SimpleStatCard(
                  title: '订阅',
                  value: '已上架 1 本',
                  icon: Icons.notifications,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _profileCard(context, child: _rowMetric('书单', '1 个', '')),
            const SizedBox(height: 10),
            _profileCard(
              context,
              child: _rowMetric('关注', '12 人关注我', '我关注了 13 人'),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _profileCard(BuildContext context, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  static Widget _rowMetric(String title, String value, String sub) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
            ),
            if (sub.isNotEmpty)
              Text(
                sub,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
          ],
        ),
      ],
    );
  }
}

class _SimpleStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SimpleStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  value,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
