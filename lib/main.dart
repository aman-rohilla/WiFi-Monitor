// Author - Aman Rohilla @ rohilla.co.in


// ignore_for_file: unused_local_variable, unused_import, avoid_// print, prefer_typing_uninitialized_variables, empty_catches, prefer_const_constructors, unused_element, dead_code, unused_field, prefer_final_fields, sized_box_for_whitespace, avoid_unnecessary_containers, avoid_print, import_of_legacy_library_into_null_safe, prefer_interpolation_to_compose_strings, no_leading_underscores_for_local_identifiers, depend_on_referenced_packages, sort_child_properties_last, curly_braces_in_flow_control_structures, prefer_is_not_operator 

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:isolate';
import 'package:stream_channel/isolate_channel.dart';
import 'dart:io';
import 'package:dart_ipify/dart_ipify.dart';
import 'package:dns_client/dns_client.dart';
import 'package:string_validator/string_validator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:bordered_text/bordered_text.dart';
import 'package:flutter/services.dart';
import 'package:synchronized/synchronized.dart';
import 'package:ftpconnect/ftpConnect.dart';
import 'package:dart_ping/dart_ping.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

ConnectivityResult _connectionStatus = ConnectivityResult.none;
AppLifecycleState appLifecycleState = AppLifecycleState.detached;
bool textEnabled = false;

var padding;
double width = 0;
double height = 0;
double height1 = 0;
bool home=false;
double height2 = 0;
double height3 = 0;
int rows = 3;
double rowHeight = 0;

bool infinite = false;

String status = "Inactive";
String btnTxt = "Start";
String labTxt = 'WiFi Public Address';


final saveLock   = Lock();
final startLock  = Lock();
final toggleLock = Lock();

int delay = 60; //seconds
// int delay = 5;
String host = '';
String domain='';
SharedPreferences? prefs;

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

void onStart(ServiceInstance service) async {
  bool? infinite;

  ReceivePort rPort =  ReceivePort();
  IsolateChannel channel = IsolateChannel.connectReceive(rPort);
  Isolate isolate = await Isolate.spawn(isolateRun, rPort.sendPort, paused: true);

  Capability resumeCapability = isolate.pause(isolate.pauseCapability);
  Map <String, dynamic>? hostObj;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: 'Service Running',
      content: 'Monitoring',
    );
    service.invoke('update');
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('setHost').listen((event) {
    hostObj = event;
  });

  service.on('setInfinite').listen((data) {
    infinite = data?['infinite'];
  });

  service.on('stopService').listen((event) {
    isolate.kill(priority: Isolate.immediate);
    _connectivitySubscription?.cancel();
    service.stopSelf();
  });

  channel.stream.listen((data) {
    if(data != 'NoAction') {
      showToast(data);

      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 10,
          channelKey: 'channel',
          title: data
        )
      );
    }
    if(infinite != null && !infinite!) {
      service.invoke('setState');
      isolate.kill(priority: Isolate.immediate);
      service.stopSelf();
    } else {
      resumeCapability = isolate.pause(isolate.pauseCapability);
    }
  });

  final Connectivity _connectivity = Connectivity();
  final lock = Lock();

  _connectivitySubscription = _connectivity.onConnectivityChanged.listen((ConnectivityResult _connectionStatus) async {
    await lock.synchronized(() async {
      while(hostObj==null) {
        service.invoke('hostIsNull');
        await Future.delayed(Duration(microseconds: 100));
      }

      while(infinite==null) {
        service.invoke('infiniteIsNULL');
        await Future.delayed(Duration(microseconds: 100));
      }

      if(_connectionStatus != ConnectivityResult.mobile) {
        resumeCapability = isolate.pause(isolate.pauseCapability);
      } else if(hostObj != null) {
        channel.sink.add(jsonEncode(hostObj));
        isolate.resume(resumeCapability);
      }
    });
  });

}

bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    prefs = await SharedPreferences.getInstance();
    infinite = prefs?.getBool('infiniterunning')==true ? true : false;  
    host = prefs!.getString('server')!;
  } catch(e) {}
  if(host!='') {
    labTxt = host;
  }
  
  await initializeService();
  FlutterBackgroundService().invoke("setAsBackground");
  final service = FlutterBackgroundService();
  if(await service.isRunning()) {
    status = 'Monitoring';
    btnTxt = 'Stop';
  }

  FlutterBackgroundService().on('hostIsNull').listen((event) {
    FlutterBackgroundService().invoke('setHost', {'host' : host});
  });

  FlutterBackgroundService().on('infiniteIsNULL').listen((event) {
    FlutterBackgroundService().invoke('setInfinite', {'infinite' : infinite});
  });

  AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelGroupKey: 'channel_group',
        channelKey: 'channel',
        channelName: 'Notifications',
        channelDescription: 'Notification channel',
        defaultColor: Color.fromARGB(255, 26, 146, 120),
        playSound: true,
        vibrationPattern: mediumVibrationPattern,
        enableVibration: true,
        ledColor: Colors.green,
        enableLights: true,
        importance: NotificationImportance.High,
        defaultRingtoneType: DefaultRingtoneType.Notification,
      )
    ],
    channelGroups: [
      NotificationChannelGroup(
        channelGroupkey: 'channel_group',
        channelGroupName: 'Channel group'
      )
    ],
    // debug: true
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      title: 'WiFi Monitor',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Color.fromARGB(141, 50, 50, 50),
      ),
      home: const MyHomePage(title: 'WiFi Monitor'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver
{
  final controller = TextEditingController();
  FocusNode focusNode = FocusNode();

  @override
  void initState() {
    controller.text = labTxt;
    super.initState();
    home = true;

    WidgetsBinding.instance.addObserver(this);
    controller.addListener(() => setState(() {}));

    FlutterBackgroundService().on('setState').listen((event) async {
  
      if(appLifecycleState == AppLifecycleState.paused) {
        await Future.delayed(Duration(seconds: 5));
        if(appLifecycleState == AppLifecycleState.paused) {
          exit(0);
        } else {
        setState(() {
          status = 'Stopped';
          btnTxt = 'Restart';
        });
        }
      } else {
        setState(() {
          status = 'Stopped';
          btnTxt = 'Restart';
        });
      }
    });

    AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });

    AwesomeNotifications().actionStream.listen(
      (ReceivedNotification receivedNotification){
        Navigator.of(context).pushNamed(
          '/NotificationPage', // not implemented
          arguments: {
            'id': receivedNotification.id
          }
        );
      }
    );
    sleep(Duration(seconds: 2));

    setState(() {
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    focusNode.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    appLifecycleState = state;
  }

  void _wifi() async {
    if(startLock.locked) {
      return;
    }
    
    await startLock.synchronized(() async {

      if(host=='') { 
        showToast('Enter Valid WiFi Public Address');
        return ;
      }

      final service =  FlutterBackgroundService();
      if(!(await service.isRunning())) {
        await service.startService();
        service.invoke('setInfinite',{'infinite':infinite});
        setState(() {
          status = "Monitoring";
          btnTxt = "Stop";
        });
      } else {
        while(await FlutterBackgroundService().isRunning()) {
          service.invoke('stopService');
          await Future.delayed(Duration(microseconds: 100));
        }
        setState(() {
          status = "Stopped";
          btnTxt = "Restart";
        });
      }

      return ;
    });
  }


  @override
  Widget build(BuildContext context) {

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    width = MediaQuery.of(context).size.width;
    height = MediaQuery.of(context).size.height;

    padding = MediaQuery.of(context).viewPadding;
    height1 = height - padding.top - padding.bottom;
    height2 = height - padding.top;
    height3 = height - padding.top - kToolbarHeight;
    rowHeight = height3/rows;


    return GestureDetector(
      onTap: (() => FocusScope.of(context).unfocus()),
      child: WillPopScope(
        onWillPop: () async {
          return true;
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
          ),
          
          body: SingleChildScrollView(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.teal.withOpacity(0.7),
                    Colors.cyan.withOpacity(0.7),
                    Colors.pinkAccent.withOpacity(0.7),
                    Colors.redAccent.withOpacity(0.9),
                    Colors.orangeAccent.withOpacity(0.7),
                    Colors.greenAccent.withOpacity(0.7),
                    Color.fromARGB(255, 12, 134, 150).withOpacity(0.7),
                    // Color.fromARGB(255, 66, 170, 158),
                    // Color.fromARGB(255, 39, 120, 124),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft
                )
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[        
                  Container(
                    height: rowHeight,
          
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0,40,0,0),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              child: Image(
                                image: AssetImage('assets/icon.png'),
                                width: 80,
                              ),
                            ),
                            SizedBox(height: 30),                            
                            Flexible(child: buildText()),
                          ],
                        )
                      ),
                    ),
                  ),
          
                  Container(
                    height: rowHeight,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 40,),
                          BorderedText(
                            strokeWidth: 2,
                            child: Text(
                              status, // Status
                              style: TextStyle(
                                color: Colors.cyan, 
                                fontSize: 35, 
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1
                              ),
                              textAlign: TextAlign.center,                
                            ),
                          ),
                          SizedBox(height: 40,),
                          ElevatedButton(// Button
                            child: Text(btnTxt),
          
                            style: ButtonStyle(
                              shadowColor: MaterialStateProperty.all<Color>(Colors.pinkAccent.withOpacity(0.7),),
                              elevation: MaterialStateProperty.resolveWith<double>(
                                (Set<MaterialState> states) {
                                if (states.contains(MaterialState.pressed))
                                  return 20.0;
                                return 10.0;
                              }),
                              fixedSize: MaterialStateProperty.all<Size>(Size.fromWidth(200)),
                              foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                              backgroundColor: MaterialStateProperty.all<Color>(Colors.orange),
                              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                )
                              ),
                              padding: MaterialStateProperty.all<EdgeInsets>(EdgeInsets.symmetric(horizontal: 40, vertical: 10)), 
                              textStyle: MaterialStateProperty.all<TextStyle>(TextStyle( fontSize: 20, fontWeight: FontWeight.w900)),
                            ),
                            onPressed: _wifi,
                          ),
      
                        ],
                      ),
                    ),
          
                  ),
          
                  Container(
                    height: rowHeight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0,20,0,0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          
                          BorderedText(
                            strokeWidth: 0,
                            child: 
                              Text(
                              'Keep Running',
                              style: TextStyle(color: Color.fromARGB(255, 22, 74, 81), fontSize: 22, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                              
                            ),
                          ),
                          SizedBox(width: 7),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0,0,0,0),
                            child: buildSwitch(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),    
        ),
      ),
    );
  }
  
  Widget buildSwitch() => Transform.scale(
    scale: 1.3,
    child: Switch.adaptive(
      
      activeColor: Color.fromARGB(255, 11, 197, 20),
      activeTrackColor: Color.fromARGB(255, 10, 98, 55).withOpacity(0.6),
      inactiveThumbColor: Colors.pink,
      inactiveTrackColor: Color.fromARGB(255, 146, 4, 4).withOpacity(0.5),

      value: infinite,
      onChanged: (value) async {
        if(toggleLock.locked) {
          return;
        }

        await toggleLock.synchronized(() async {
          setState(() {
            infinite = value;
          });
          await prefs?.setBool('infiniterunning', infinite);
          final service = FlutterBackgroundService();
          if(await service.isRunning()) {
            service.invoke('setInfinite', {'infinite' : infinite});
          }
        });
      },
    ),
  );

  Widget buildText() => Padding(
    padding: const EdgeInsets.all(20.0),
    child: Theme(
      data: ThemeData(
        primaryColor: Colors.redAccent,
        primaryColorDark: Colors.red,
      ),

      child: TextField(
        controller: controller,
      
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
    
          fillColor: Colors.lightBlueAccent.withOpacity(0.3), 
          filled: true,
          labelStyle: TextStyle(
            color: Colors.white, 
            fontSize: 17
          ),
            suffixIcon  : IconButton(
                  icon: icon(!textEnabled),
                  onPressed: () async {
                    if(saveLock.locked) return;
                    await saveLock.synchronized(() async {
                      textEnabled = !textEnabled;
                      String oldHost = host;
                      if(!textEnabled) {
                        String text = controller.text.trim();

                        if(validateURL(text)) {
                          if(!text.startsWith('http://') 
                          && !text.startsWith('https://') 
                          && !text.startsWith('ftp://') 
                          && !text.startsWith('ftps://') 
                          && !text.startsWith('ping://') 
                          && text.contains('://') ) {
                            showToast('Only http/https/ftp/ftps/ping protocols supported');
                            controller.text = host;
                            return ;
                          }
                          host = extractHost(text);
                          controller.text = host;
                          await prefs?.setString('server', host);
                          if(host != oldHost && await FlutterBackgroundService().isRunning()) {
                            final service = FlutterBackgroundService();

                            while(await service.isRunning()) {
                              service.invoke('stopService');
                              await Future.delayed(Duration(microseconds: 100));
                            }
                            await service.startService();
                            service.invoke('setInfinite',{'infinite':infinite});  
                          }
                        } else if (controller.text == ''){
                          final service = FlutterBackgroundService();
                          bool run = false;
                          while(await FlutterBackgroundService().isRunning()) {
                            if(!run) {
                              run = true;
                            }
                            service.invoke('stopService');
                            await Future.delayed(Duration(microseconds: 100));
                          }
                          if(run) {
                            status = 'Stopped';
                            btnTxt = 'Restart';
                          }
                          controller.text = 'WiFi Public Address';
                          host = '';
                          await prefs?.setString('server', host);
                        } else {
                          if (host=='') { 
                            controller.text = 'WiFi Public Address';
                          } else {
                            controller.text = host;
                          }
                        }

                      } else if(controller.text == 'WiFi Public Address') {
                        controller.clear();
                      }
                      setState(() {});
                      }); 
                  },
                ),
          border: UnderlineInputBorder(),
        ),
        textInputAction: TextInputAction.done,
        // autofocus: true,
        readOnly: !textEnabled,
      ),
    ),
  );

  Widget buildIP() => Container(
    child: Text(
      host,
      style: TextStyle(color: Color.fromARGB(255, 22, 74, 81), fontSize: 22, fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,      
    ),
  );

  Icon icon(bool edit) {
    if(edit) {
      return Icon(Icons.edit, color: Colors.amberAccent,size: 25,);
    }
    return Icon(Icons.save, color: Colors.amberAccent, size: 25,);
  }
}


void showToast(String msg) {
  Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0
    );
}

bool validateURL(String text) {
  String temp = text;
  if(text.contains('://')) {
   temp = text.split('://')[1];
  }
  if(!isIP(temp) && !isURL(temp)) {
    showToast('Enter Valid WiFi Public Address');
    return false;
  }
  return true;
}

void isolateRun(SendPort sendPort) async {

  IsolateChannel channel = IsolateChannel.connectSend(sendPort);
  channel.stream.listen((data) async {
    Map<String, dynamic> json = jsonDecode(data);
    String wifiStatus = await wifi(json['host']);
    channel.sink.add(wifiStatus);
  });
}

Future<String> wifi (String host) async {
  HttpClient? client;
  FTPConnect? ftpConnect;
  if(!host.contains('://')) {
    host = 'http://' + host;
  }

  if(host.contains('ftp://') || host.contains('ftps://')) {
    var url = Uri.parse(host);
    int port = 21;
    if(url.hasPort) {
      port = url.port;
    }
    bool ssl = false;
    if(host.contains('ftps://')) {
      ssl = true;
    }

    ftpConnect = FTPConnect(url.host, port: port, isSecured: ssl, timeout: 3);
  } else if (host.contains('http://') || host.contains('https://')) {
    client = HttpClient();
    client.connectionTimeout = const Duration(seconds:5);
  }

  while(true) {
    try {
      var url = Uri.parse(host);
      var domain = url.host;

      var myIP, pubIP = domain;
      myIP = await Ipify.ipv4().timeout(Duration(seconds: 5));

      if(!isIP(pubIP)) {
        final dns = DnsOverHttps.google();
        final response = await dns.lookup(domain).timeout(Duration(seconds: 5));  
        var rdns = response.toSet();
        pubIP = rdns.elementAt(0).address.toString();
      }
      

      String msg = 'WiFi Restored';
      if(pubIP != myIP) {        
        if(host.contains('http://') || host.contains('https://')) {
          try {  
            var res = await client?.headUrl(url);
            await res?.close();
          } catch (e) {
            if(!(e is SocketException) || !e.toString().startsWith('SocketException: Connection refused (OS Error: Connection refused, errno = ')) {
              throw 'HTTPError';
            }
          }
        } else if(host.contains('ftp://') || host.contains('ftps://')) {
          try {  
            if(await ftpConnect!.connect()) {
              await ftpConnect.disconnect();
            }
          } catch (e) {
            await ftpConnect?.disconnect();
            if(e.toString() != 'FTPException: Timeout reached for Receiving response ! (Response: null)') {
              throw 'FTPError';
            }
          }
        } else if(! await ping(url.host)) {
          throw 'PingFailed';
        }

        try {
          ProcessResult process = Process.runSync('su', ['-c','svc data disable && svc wifi enable']);
          if(process.exitCode!=0) {
            msg = 'WiFi Available';
          }
        }
        catch(e) {
          msg = 'WiFi Available';
        }
        client?.close();
        return msg;
      }
      client?.close();
      return 'NoAction';
    } catch(e){
      await Future.delayed(Duration(seconds: delay));
    }
  }
}

String extractHost(String url) {
  if(!url.contains('://')) {
    url = 'http://' + url;
  }
  final uri = Uri.parse(url);
  String protocol = url.split('://')[0] + '://';
  String adrs = uri.host;
  if(uri.hasPort) {
    adrs = adrs + ':' + uri.port.toString();
  }
  if(protocol=='http://') {
    protocol = '';
  }
  return protocol + adrs;
}

Future<bool> ping(String host) async {
  try {
    int? count=0;
    final ping = Ping(host, count: 3);
    await ping.stream.listen((event) {
      count = event.summary?.received;
    }).asFuture();
    if(count!>=1) {
      return true;
    }
  } catch (e) {
    return false;
  }
  return false;
}