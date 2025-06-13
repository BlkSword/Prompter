import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// 主函数
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化本地通知
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // 创建通知渠道
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'battery_channel',
    'Battery Reminder',
    importance: Importance.high,
    enableVibration: true,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  runApp(BatteryReminderApp());
}

// 主体结构
class BatteryReminderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '充电守卫',
      theme: ThemeData(primarySwatch: Colors.deepOrange),
      home: BatteryMonitorPage(),
    );
  }
}

// 状态管理
class BatteryMonitorPage extends StatefulWidget {
  @override
  _BatteryMonitorPageState createState() => _BatteryMonitorPageState();
}

// 业务逻辑
class _BatteryMonitorPageState extends State<BatteryMonitorPage> {
  final Battery _battery = Battery();
  int _batteryLevel = 0;
  BatteryState _batteryState = BatteryState.discharging;
  bool _isSoundEnabled = false;
  bool _isNotificationEnabled = false;
  bool _hasNotified = false;

  String _batteryStateToString(BatteryState state) {
    switch (state) {
      case BatteryState.discharging:
        return '放电中';
      case BatteryState.charging:
        return '充电中';
      case BatteryState.full:
        return '满电';
      default:
        return '未知';
    }
  }

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  void _startMonitoring() async {
    // 获取初始电量
    _batteryLevel = await _battery.batteryLevel;
    setState(() {});

    // 监听电池状态变化
    _battery.onBatteryStateChanged.listen((BatteryState state) {
      setState(() {
        _batteryState = state;
      });
      _checkBatteryStatus();
    });

    // 使用定时器轮询获取电量变化
    const Duration pollingInterval = Duration(seconds: 10);
    Future.doWhile(() async {
      await Future.delayed(pollingInterval);
      final int newLevel = await _battery.batteryLevel;
      if (newLevel != _batteryLevel) {
        setState(() {
          _batteryLevel = newLevel;
        });
        _checkBatteryStatus();
      }
      return true; // 持续执行
    });
  }

  void _checkBatteryStatus() {
    // 当电量 >=100% 且处于充电状态时触发提醒
    if (_batteryLevel >= 100 &&
        (_batteryState == BatteryState.charging ||
            _batteryState == BatteryState.full)) {
      if (!_hasNotified) {
        if (_isSoundEnabled) {
          debugPrint("🔊 响铃提醒已触发");
        }
        if (_isNotificationEnabled) {
          _showNotification();
        }
        _hasNotified = true; // 防止重复提醒
      }
    } else {
      _hasNotified = false; // 电量下降后重置标志
    }
  }

  void _showNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'battery_channel',
      'Battery Reminder',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      '🔋 充电完成',
      '您的手机已充满，请拔掉充电器。',
      platformChannelSpecifics,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: Text('充电提醒工具')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '当前电量: $_batteryLevel%',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '充电状态: ${_batteryStateToString(_batteryState)}',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 20),

            // 响铃提醒开关带提示
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Switch(
                  value: _isSoundEnabled,
                  onChanged: (value) {
                    setState(() {
                      _isSoundEnabled = value;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(value ? '响铃提醒已开启' : '响铃提醒已关闭'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                Text('响铃提醒'),
              ],
            ),

            // 通知提醒开关带提示
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Switch(
                  value: _isNotificationEnabled,
                  onChanged: (value) {
                    setState(() {
                      _isNotificationEnabled = value;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(value ? '通知提醒已开启' : '通知提醒已关闭'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                Text('通知提醒'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
