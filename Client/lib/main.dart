import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:xbt_client/home_page_content/sign.dart';
import 'package:xbt_client/home_page_content/user.dart';
import 'package:xbt_client/utils/constants.dart';
import 'package:xbt_client/utils/dio.dart';
import 'package:xbt_client/utils/local_json.dart';

// flutter build apk --release
// flutter build web --debug

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 绑定初始化
  dio.interceptors.add(interceptorsWrapper);
  await initBaseURL();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  static final RouteObserver<PageRoute> routeObserver =
      RouteObserver<PageRoute>();
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '学不通',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [FlutterSmartDialog.observer, routeObserver],
      builder: FlutterSmartDialog.init(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: '学不通'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int homepageIndex = 0;
  Map homepageMap = {
    0: const Sign(),
    1: const User(),
  };

  @override
  void initState() {
    super.initState();
    () async {
      var token = await prefs.getString('token');
      if (token == null) {
        await LocalJson.setItem('localUserList', []);
        await LocalJson.setItem('localCourses', []);
        await prefs.setString('token', ''); // 不解析json，prefs节约性能
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    dioContext ??= context;
    return Scaffold(
      body: homepageMap[homepageIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: '签到'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '用户'),
        ],
        elevation: 1,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        onTap: (value) {
          setState(() {
            homepageIndex = value;
          });
        },
        currentIndex: homepageIndex,
      ),
    );
  }
}
