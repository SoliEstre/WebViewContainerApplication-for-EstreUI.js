import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:indent/indent.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:app_links/app_links.dart';
import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  runApp(const EstreUiNativeExtensionApp());
}

class EstreUiNativeExtensionApp extends StatelessWidget {
  const EstreUiNativeExtensionApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Estre UI', // <- To be changed your application name
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue
                .shade300), // <- To be change your app's primary point color
        canvasColor:
            Colors.white, // <- To be change your app's background color
        useMaterial3: true,
      ),
      home: const MainWebView(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DeviceCommonInfo {
  final bool isPhysical;

  final String id;
  final String os;
  final String osVersion;
  final String vendor;
  final String brand;
  final String? kind;
  final String model;
  final String? modelName;

  DeviceCommonInfo({
    required this.isPhysical,
    required this.id,
    required this.os,
    required this.osVersion,
    required this.vendor,
    required this.brand,
    this.kind,
    required this.model,
    this.modelName,
  });

  Map<String, dynamic> forJson() => {
        "isPhysical": isPhysical,
        "id": id,
        "os": os,
        "osVersion": osVersion,
        "vendor": vendor,
        "brand": brand,
        "kind": kind,
        "model": model,
        "modelName": modelName,
      };
}

class MainWebView extends StatefulWidget {
  const MainWebView({super.key});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  @override
  State<MainWebView> createState() => _MainWebViewState();
}

class _MainWebViewState extends State<MainWebView> with WidgetsBindingObserver {
  // vv To be change to own application name
  final APP_NAME = "WVCA4EUI";

  late final SharedPreferences sp;

  final appLinks = AppLinks();
  late final StreamSubscription<Uri> appLinkListen;

  late final AppLifecycleListener _listener;
  AppLifecycleState? get state => SchedulerBinding.instance.lifecycleState;

  late final PackageInfo packageInfo;
  late final StreamSubscription<List<ConnectivityResult>> connectivity;
  late final WebViewController? controller;
  late final WebViewCookieManager? cookieMan;
  late final InAppWebViewController? iawvController;
  late final CookieManager? iawvCookieMan;
  // WebViewEnvironment? webViewEnvironment;
  InAppWebViewSettings settings = InAppWebViewSettings(
    isInspectable: kDebugMode,
    applicationNameForUserAgent:
        "WVCA4EUI_Flutter", // Recommended to not change this. Application name & version info is be assigned on initState()
    javaScriptEnabled: true,
    javaScriptCanOpenWindowsAutomatically: true,
    supportMultipleWindows: true,
    // sharedCookiesEnabled: true,
    // thirdPartyCookiesEnabled: true,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    iframeAllow: "camera; microphone",
    iframeAllowFullscreen: true,
    disableDefaultErrorPage: true,
    limitsNavigationsToAppBoundDomains: true,
    cacheMode: CacheMode.LOAD_DEFAULT,
  );
  PullToRefreshController? pullToRefreshController;

  // Switch for flutter_inappwebview / webview_flutter
  final isIAWV = true; //false//

  // vv To be setted specified scheme for calling this app's app link
  final SCHEME = "wvca4eui";
  // vv To be setted specified host for communication to your own API server
  final API_HOST = "estreui.mpsolutions.co.kr";
  // vv To be setted specified host for your own Estre UI PWA service. it must be fixed url location on main web view
  final SERVICE_HOST = "estreui.mpsolutions.co.kr";
  // vv To be setted specified host suffix for check url is own service when load popup browser
  final SERVICE_SUFFIX = "mpsolutions.co.kr";

  String get rootUrl => "https://$SERVICE_HOST";
  Uri get rootUri => Uri.parse(rootUrl);

  // Be setted App name & version on initState for insert to user agent
  String uaPrefix = "";

  final splashFadeInDuration = const Duration(
      milliseconds:
          300); // <- Splash fade in duration. to be setted to splashFadeDuration as same
  final splashFadeOutDuration =
      const Duration(milliseconds: 500); // <- Splash fade out duration
  var splashFadeDuration = const Duration(
      milliseconds:
          300); // <- Initial(fade in) duration. set same value as splashFadeInDuration
  final loadingProgressFadeDuration = const Duration(
      milliseconds: 300); // <- Top web view loading bar fade in/out duration

  // Device info for provide to Estre UI application
  Map<String, dynamic>? rawDeviceInfo;
  final deviceInfo = DeviceInfoPlugin();
  AndroidDeviceInfo? androidDeviceInfo;
  IosDeviceInfo? iosDeviceInfo;
  DeviceCommonInfo? device;

  // Safe area inset property for covered viewport on main web view
  Map<String, double> safeAreaInsets = {
    'top': 0.0,
    'left': 0.0,
    'bottom': 0.0,
    'right': 0.0,
  };

  // Conectivity state property
  List<ConnectivityResult> currentConnections = [];
  bool get isOnline => currentConnections.isNotEmpty;
  bool isInternetAvailable = true;

  // Property for process on start with app link
  var initialUriReceived = false;
  var initialUriProcessed = false;
  Uri? initialUri;

  // State properties
  var isInit = true;

  double splashOpacity = 0.0;

  var loadingPercentage = 0;
  double loadingProgressBarOpacity = 0.0;

  var exitRequested = 0;

  String currentUrl = "";

  @override
  void initState() {
    super.initState();

    // App link receiver. not recommended change this code.
    // for initial uri receive and process when started with app link.
    // custom implement is write in to processAppLinkReceived()
    appLinks.uriLinkStream.listen((uri) {
      if (!initialUriReceived) {
        initialUriReceived = true;
        initialUri = uri;
      } else {
        processAppLinkReceived(uri);
      }
    });

    // App lice cycle listener. insert implements for your app's needs
    _listener = AppLifecycleListener(
        onInactive: () {},
        onHide: () {
          if (!isInit && isIAWV) {
            iawvController?.clearFocus();
            if (defaultTargetPlatform == TargetPlatform.android)
              iawvController?.pause();
            iawvController?.pauseTimers();
            WidgetsBinding.instance.addPostFrameCallback((_) async {});
          }
        },
        onPause: () {},
        onDetach: () {},
        onRestart: () {},
        onShow: () {
          if (!isInit && isIAWV) {
            if (defaultTargetPlatform == TargetPlatform.android)
              iawvController?.resume();
            iawvController?.resumeTimers();
            iawvController?.requestFocus();
            WidgetsBinding.instance.addPostFrameCallback((_) async {});
          }
        },
        onResume: () {},
        onExitRequested: () async {
          return AppExitResponse.exit;
        },
        onStateChange: (state) {});

    if (isIAWV) {
      controller = null;
      cookieMan = null;

      iawvCookieMan = CookieManager.instance();

      InAppWebViewController.setJavaScriptBridgeName("App");

      // PTR controller for main web view. it necessary when failed load Estre UI.
      pullToRefreshController = kIsWeb ||
              ![TargetPlatform.iOS, TargetPlatform.android]
                  .contains(defaultTargetPlatform)
          ? null
          : PullToRefreshController(
              settings: PullToRefreshSettings(
                color: Theme.of(context).primaryColor,
              ),
              onRefresh: () async {
                await refreshWebView();
              },
            );
    } else {
      iawvController = null;
      iawvCookieMan = null;

      late PlatformWebViewCookieManagerCreationParams cParams =
          const PlatformWebViewCookieManagerCreationParams();
      late final PlatformWebViewControllerCreationParams params;
      if (WebViewPlatform.instance is WebKitWebViewPlatform) {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        );
        cParams = WebKitWebViewCookieManagerCreationParams
            .fromPlatformWebViewCookieManagerCreationParams(cParams);
      } else if (WebViewPlatform.instance is AndroidWebViewPlatform) {
        params = AndroidWebViewControllerCreationParams();
        cParams = AndroidWebViewCookieManagerCreationParams
            .fromPlatformWebViewCookieManagerCreationParams(cParams);
      } else {
        params = const PlatformWebViewControllerCreationParams();
      }
      cookieMan = WebViewCookieManager.fromPlatformCreationParams(cParams);

      controller = WebViewController.fromPlatformCreationParams(
          params); //WebViewController()
    }

    connectivity = Connectivity().onConnectivityChanged.listen((result) {
      currentConnections = result;

      checkInternetAvailable();
    });

    // Async initializes with application package info
    getPackageInfo(callback: (info) async {
      sp = await SharedPreferences.getInstance();

      uaPrefix = "$APP_NAME/${info.version} ";
      await setIawvUA();

      WidgetsBinding.instance.addObserver(this);

      if (Platform.isAndroid) {
        if (kDebugMode) print("Platform is Android");
        androidDeviceInfo = await deviceInfo.androidInfo;
        final deviceId = await AndroidId().getId() ?? "unknown";

        if (androidDeviceInfo != null) {
          final info = androidDeviceInfo!;
          rawDeviceInfo = info.data;
          if (kDebugMode)
            print("Detected Android device info\n${jsonEncode(rawDeviceInfo)}");
          device = DeviceCommonInfo(
            isPhysical: info.isPhysicalDevice,
            id: deviceId,
            os: "Android",
            osVersion: info.version.release,
            vendor: info.manufacturer,
            brand: info.brand,
            model: info.model,
          );
        }
      } else if (Platform.isIOS) {
        if (kDebugMode) print("Platform is iOS");
        iosDeviceInfo = await deviceInfo.iosInfo;
        final deviceId = iosDeviceInfo?.identifierForVendor ?? "unknown";

        if (iosDeviceInfo != null) {
          final info = iosDeviceInfo!;
          rawDeviceInfo = info.data;
          if (kDebugMode)
            print("Detected iOS device info\n${jsonEncode(rawDeviceInfo)}");
          device = DeviceCommonInfo(
            isPhysical: info.isPhysicalDevice,
            id: deviceId,
            os: info.isiOSAppOnMac ? "macOS" : info.systemName,
            osVersion: info.systemVersion,
            vendor: "Apple",
            brand: info.name,
            kind: info.model,
            model: info.utsname.machine,
            modelName: info.modelName,
          );
        }
      } else {
        if (kDebugMode) print("Platform is ${Platform.operatingSystem}");
      }

      if (isIAWV) {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          await InAppWebViewController.setWebContentsDebuggingEnabled(
              kDebugMode);
        }
      } else {
        if (controller!.platform is AndroidWebViewController) {
          AndroidWebViewController.enableDebugging(true);

          final androidController =
              (controller!.platform as AndroidWebViewController);

          androidController.setMediaPlaybackRequiresUserGesture(false);

          final androidCookieManager =
              (cookieMan!.platform as AndroidWebViewCookieManager);

          androidCookieManager.setAcceptThirdPartyCookies(
              androidController, true);
        } else if (controller!.platform is WebKitWebViewController) {
          // final webkitController = (controller!.platform as WebKitWebViewController);

          // final webkitCookieManager = (cookieMan!.platform as WebKitWebViewCookieManager);
        }

        var ua = await controller!.getUserAgent();
        if (kDebugMode) print(ua);

        controller!
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setUserAgent(uaPrefix + ua.toString())
          ..setNavigationDelegate(NavigationDelegate(
            onNavigationRequest: (navigation) async {
              final isMainFrame = navigation.isMainFrame;
              final uri = Uri.parse(navigation.url);

              return await processNavigationRequest(uri, isMainFrame)
                  ? NavigationDecision.prevent
                  : NavigationDecision.navigate;
            },
            onUrlChange: (url) {
              if (url.url != null) currentUrl = url.url!;
            },
            onHttpError: (error) {
              // final req = error.request;
            },
            onPageStarted: (url) {
              beginPage(url, controller: controller);
            },
            onProgress: (progress) {
              loadingPage(progress, controller: controller);
            },
            onPageFinished: (url) {
              () async {
                onTitleLoaded(await controller?.getTitle(),
                    controller: controller);
              }();
              completePage(url, controller: controller);
            },
          ))
          ..addJavaScriptChannel("App",
              onMessageReceived: (JavaScriptMessage message) {
            final data = jsonDecode(message.message);
            if (kDebugMode)
              print("Received request from WebView: ${data.handleName}");

            processWebViewAppRequest(data);
          });

        loadInitialUri();

        // <- Write your async initial processes

        FlutterNativeSplash.remove();
      }

      checkConnection();

      if (isIAWV) {
        setIawvJsHandler();
        loadInitialUri();
      }

      // <- Write your initial processes
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: onBackPressed,
        child: Container(
            color: Theme.of(context).canvasColor,
            child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: Stack(children: [
                  SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: !isIAWV
                          ? WebViewWidget(controller: controller!)
                          : InAppWebView(
                              initialUrlRequest:
                                  URLRequest(url: WebUri(rootUrl)),
                              initialSettings: settings,
                              pullToRefreshController: pullToRefreshController,
                              onWebViewCreated:
                                  (InAppWebViewController controller) {
                                iawvController = controller;

                                FlutterNativeSplash.remove();

                                setIawvUA();

                                setIawvJsHandler();
                              },
                              shouldOverrideUrlLoading:
                                  (controller, navigationAction) async {
                                final isMainFrame =
                                    navigationAction.isForMainFrame;
                                final request = navigationAction.request;

                                final isDownload =
                                    navigationAction.shouldPerformDownload ??
                                        false;
                                if (isDownload)
                                  return NavigationActionPolicy.DOWNLOAD;

                                final uri = request.url;
                                if (uri != null) {
                                  return await processNavigationRequest(
                                          uri, isMainFrame,
                                          navigationAction: navigationAction)
                                      ? NavigationActionPolicy.CANCEL
                                      : NavigationActionPolicy.ALLOW;
                                }

                                return NavigationActionPolicy.ALLOW;
                              },
                              onLoadStart: (controller, url) {
                                beginPage(url.toString(),
                                    iawvController: controller);
                              },
                              onProgressChanged: (controller, progress) {
                                if (progress == 100) {
                                  pullToRefreshController?.endRefreshing();
                                  // completePage(currentUrl, iawvController: controller);
                                } else {
                                  // loadingPage(progress, iawvController: controller);
                                }
                                loadingPage(progress,
                                    iawvController: controller);
                              },
                              onLoadStop: (controller, url) {
                                pullToRefreshController?.endRefreshing();
                                completePage(url.toString(),
                                    iawvController: controller);
                              },
                              onReceivedError: (controller, request, error) {
                                pullToRefreshController?.endRefreshing();
                              },
                              onPermissionRequest: (controller, request) async {
                                return PermissionResponse(
                                    resources: request.resources,
                                    action: PermissionResponseAction.GRANT);
                              },
                              onUpdateVisitedHistory:
                                  (controller, url, androidIsReload) {
                                setState(() {
                                  currentUrl = url.toString();
                                });
                              },
                              onTitleChanged: (controller, title) {
                                onTitleLoaded(title,
                                    iawvController: controller);
                              },
                              onConsoleMessage: (controller, consoleMessage) {
                                if (kDebugMode) {
                                  // print(consoleMessage);
                                }
                              },
                              onWindowFocus: (controller) {
                                // controller.evaluateJavascript(source: 'window.dispatchEvent(new Event("focus"));');
                              },
                              onWindowBlur: (controller) {
                                // controller.evaluateJavascript(source: 'window.dispatchEvent(new Event("blur"));');
                              },
                              onCreateWindow: (controller, createWindowAction) {
                                final uri = createWindowAction.request.url;
                                // if (uri != null) {
                                openPopupBrowser(uri?.toString() ?? "",
                                    createWindowAction: createWindowAction,
                                    referrerController: controller);
                                return true;
                                // }
                                // return false;
                              },
                              onCloseWindow: (controller) {
                                final navigator = Navigator.of(context);
                                if (navigator.canPop()) navigator.pop();
                              },
                            )),
                  isInit
                      ? AnimatedOpacity(
                          // splash
                          curve: Curves.ease,
                          opacity: splashOpacity,
                          duration: splashFadeDuration,
                          child: Container(
                              color: Theme.of(context).canvasColor,
                              child: SizedBox(
                                  width: double.infinity,
                                  height: double.infinity,
                                  child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                            "assets/images/EstreUI-bolder-512x512.png",
                                            height: 150),
                                      ]))),
                        )
                      : SizedBox(width: double.infinity, height: 0),
                  SizedBox(
                      width: double.infinity,
                      height: MediaQuery.of(context).padding.top,
                      child: AnimatedOpacity(
                          curve: Curves.ease,
                          opacity: loadingProgressBarOpacity,
                          duration: loadingProgressFadeDuration,
                          child: LinearProgressIndicator(
                              value: loadingPercentage / 100.0,
                              color: Theme.of(context).colorScheme.primary))),
                ]))));
  }

  @override
  void activate() {
    super.activate();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateSafeAreaInsets(
          controller: controller, iawvController: iawvController);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
        break;
      case AppLifecycleState.paused:
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    _listener.dispose();
    WidgetsBinding.instance.removeObserver(this);
    connectivity.cancel();

    super.dispose();
  }

  // App works interoperation
  void onBackPressed(didPop, result) async {
    if (didPop) {
      return;
    }

    final returns =
        isIAWV ? await processBackForEstreUi() : await processBackWebView();
    if (returns) {
      //do nothing
    } else {
      var now = DateTime.now().millisecondsSinceEpoch;
      if (exitRequested < now - 2000) {
        exitRequested = now;
        final codes =
            'note?.("To be finished this app by back navigation again")';
        if (isIAWV) {
          await iawvController!.evaluateJavascript(source: codes);
        } else {
          await controller!.runJavaScript(codes);
        }
      } else {
        SystemNavigator.pop();
      }
    }
  }

  void insertAdapterCodes(
      {WebViewController? controller, InAppWebViewController? iawvController}) {
    final preCodes = (isIAWV
            ? '''
      // iawv pre
      // <- To be implements for your application

    '''
                .trimMargin()
            : '''
      // wv pre
      // <- To be implements for your application
      
    '''
                .trimMargin()) +
        '''
      // common
      // <- To be implements for your application

      console.log("Pre adapter code launched finely");
    '''
            .trimMargin();
    if (kDebugMode) print(preCodes);
    controller?.runJavaScript(preCodes);
    iawvController?.evaluateJavascript(source: preCodes);

    // Common JS handler implementation. not recommended edit this codes
    final commonCodes = '''
      window.app = {
        requests: [],
        
        issueRequestId(handlerName) {
          return handlerName + "#" + this.requests.length + "@" + Date.now();
        },
        
        registerRequest(handlerName, resolve, reject) {
          const requestId = this.issueRequestId(handlerName);
          this.requests[requestId] = { resolve, reject };
          return requestId;
        },
      
        returnResult(requestId, returns, isReject = false) {
          const promise = this.requests[requestId];
          if (promise != null) {
            delete this.requests[requestId];
            if (isReject) promise.reject(new TypeError(requestId.split("#")[0] + " is not a function"));
            else try {
              promise.resolve(JSON.parse(returns));
            } catch (ex) {
              console.error(ex);
              promise.resolve(returns);
            }
          }
        },
        
        isOnline: true,
      };

    '''
            .trimMargin() +
        (isIAWV
            ? '''
      window.app.request = function (handlerName, ...args) {
        return new Promise((resolve, reject) => {
          const requestId = this.registerRequest(handlerName, resolve, reject);
          App.callHandler(handlerName, requestId, ...args);
        });
      };
            
    '''
                .trimMargin()
            : '''
      window.app.request = function (handlerName, ...args) {
        return new Promise((resolve, reject) => {
          const requestId = this.registerRequest(handlerName, resolve, reject);
          App.postMessage(JSON.stringify({ handlerName, requestId, args }));
        });
      };
      console.log("Common adapter code launched finely");
      console.log(window.app);
        
    '''
                .trimMargin());
    if (kDebugMode) print(commonCodes);
    controller?.runJavaScript(commonCodes);
    iawvController?.evaluateJavascript(source: commonCodes);

    final postCodes = (isIAWV
            ? '''
      // iawv post
      // <- To be implements for your application
      
    '''
                .trimMargin()
            : '''
      // wv post
      // <- To be implements for your application
        
    '''
                .trimMargin()) +
        '''
      // common
      // <- To be implements for your application
      
      console.log("Post adapter code launched finely");
    '''
            .trimMargin();
    if (kDebugMode) {
      print(postCodes);
      print(
          "device id: ${device?.id}, os version: ${device?.osVersion}, app version: ${packageInfo.version}");
    }
    controller?.runJavaScript(postCodes);
    iawvController?.evaluateJavascript(source: postCodes);
  }

  // Javascript handlers
  late final Map<
      String,
      Future<dynamic> Function(List<dynamic>,
          {bool? isMainFrame, Uri? origin, Uri? from})> appRequestHandlers = {
    "clearCache": (args, {isMainFrame, origin, from}) async {
      await clearCacheWebView();
    },
    "refresh": (args, {isMainFrame, origin, from}) async {
      await refreshWebView();
    },
    "test": (args, {isMainFrame, origin, from}) async {
      return "it's works!";
    },
    "rawDeviceInfo": (args, {isMainFrame, origin, from}) async {
      return rawDeviceInfo;
    },
    "deviceInfo": (args, {isMainFrame, origin, from}) async {
      return device?.forJson();
    },
    "appInfo": (args, {isMainFrame, origin, from}) async {
      // return packageInfo;
      return {
        "name": packageInfo.appName,
        "version": packageInfo.version,
        "versionCode": packageInfo.buildNumber,
        "packageName": packageInfo.packageName,
        // "buildSign": packageInfo.buildSignature,
        "installedBy": packageInfo.installerStore,
      };
    },

    "getLengthOfNativeStorage": (args, {isMainFrame, origin, from}) async {
      return sp.getKeys().length;
    },
    "getFromNativeStorageAt": (args, {isMainFrame, origin, from}) async {
      final int? index = args[0];
      if (index != null) {
        try {
          final key = sp.getKeys().elementAt(index);
          return sp.getString(key)?.replaceAll('"', '\\"');
        } on RangeError catch (_) {
          // do nothing
        }
      }
      return null;
    },
    "getFromNativeStorage": (args, {isMainFrame, origin, from}) async {
      try {
        final String key = args[0];
        if (key.isNotEmpty) {
          String? def;
          try {
            def = args[1];
          } on RangeError catch (_) {
            // do nothing
          }
          return sp.getString(key)?.replaceAll('"', '\\"') ?? def;
        }
      } on RangeError catch (_) {
        // do nothing
      }
      return null;
    },
    "setToNativeStorage": (args, {isMainFrame, origin, from}) async {
      try {
        final String key = args[0];
        String? value;
        try {
          value = args[1];
        } on RangeError catch (_) {
          // do nothing
        }
        if (key.isNotEmpty) {
          if (value == null) {
            await sp.remove(key);
          } else {
            return await sp.setString(key, value);
          }
        }
      } on RangeError catch (_) {
        // do nothing
      }
      return null;
    },
    "removeFromNativeStorage": (args, {isMainFrame, origin, from}) async {
      try {
        final String key = args[0];
        if (key.isNotEmpty) {
          return await sp.remove(key);
        }
      } on RangeError catch (_) {
        // do nothing
      }
      return null;
    },
    "clearNativeStorage": (args, {isMainFrame, origin, from}) async {
      return await sp.clear();
    },

    "popupBrowser": (args, {isMainFrame, origin, from}) async {
      final String? url = args[0];
      if (url != null && url.isNotEmpty)
        openPopupBrowser(url,
            referrer: from,
            referrerOrigin: origin,
            referrerController: isIAWV ? iawvController : null);
    },
    // vv For add new javascript handler
    // "": (args, { isMainFrame, origin, from }) async {
    //
    // },
  };

  // WebView initializing
  Future<void> setIawvUA({InAppWebViewController? popupController}) async {
    if (isIAWV || popupController != null) {
      try {
        var isComplete = false;
        if (uaPrefix.isNotEmpty) {
          final settings =
              await (popupController ?? iawvController!).getSettings() ??
                  this.settings;
          final current = settings.userAgent ?? "";
          if (kDebugMode) print("Current UA: $current");
          if (current.contains(uaPrefix)) {
            isComplete = true;
          } else {
            final ua = current.isNotEmpty
                ? current
                : await InAppWebViewController.getDefaultUserAgent();
            settings.userAgent = uaPrefix + ua;
            (popupController ?? iawvController!)
                .setSettings(settings: settings);
            isComplete = true;
            if (kDebugMode) print("UA updated: ${settings.userAgent}");
          }
        }
        if (!isComplete) {
          if (kDebugMode) print("Waiting retry for UserAgent for IAWV");
          Future.delayed(Duration(milliseconds: 100), () {
            if (kDebugMode) print("Begin retry for UserAgent for IAWV");
            setIawvUA(popupController: popupController);
          });
        }
      } on Exception catch (e) {
        if (kDebugMode) print("Exception on set UserAgent for IAWV: $e");
        // do nothing
      } on Error catch (e) {
        if (kDebugMode) print("Error on set UserAgent for IAWV: $e");
        // do nothing
      }
    }
  }

  void setIawvJsHandler() {
    try {
      if (iawvController != null && appRequestHandlers.isNotEmpty) {
        for (final name in appRequestHandlers.keys) {
          iawvController!.addJavaScriptHandler(
              handlerName: name,
              callback: (JavaScriptHandlerFunctionData data) {
                if (kDebugMode) {
                  print("Received request from InAppWebView: $name");
                }
                processInAppWebViewAppRequest(name, data);
              });
        }
      }
    } on Exception catch (_) {
      // do nothing
    }
  }

  // common initialize
  void loadInitialUri() {
    if (initialUriReceived && initialUri != null) {
      final Uri uri = initialUri!;
      if (uri.host.endsWith(SERVICE_HOST)) {
        initialUriProcessed = true;
        if (isIAWV) {
          iawvController!
              .loadUrl(urlRequest: URLRequest(url: WebUri(uri.toString())));
        } else {
          controller!.loadRequest(uri);
        }
      }
    }

    if (!initialUriProcessed) {
      if (isIAWV) {
        // do nothing
      } else {
        controller!.loadRequest(rootUri);
      }
    }
  }

  // Deep link and App link receives
  Future<void> processAppLinkReceived(Uri uri) async {
    if (!await processNavigationRequest(uri, true)) {
      if (uri.host.endsWith(SERVICE_HOST)) {
        if (isIAWV) {
          iawvController?.loadUrl(
              urlRequest: URLRequest(url: WebUri(uri.toString())));
        } else {
          controller?.loadRequest(uri);
        }
      }
    }
  }

  // Process common WebView works
  void beginPage(String url,
      {WebViewController? controller, InAppWebViewController? iawvController}) {
    currentUrl = url;

    if (Platform.isAndroid) {
      // Insert adapter codes
      insertAdapterCodes(
          controller: controller, iawvController: iawvController);

      // Provide screen area info
      updateSafeAreaInsets(
          controller: controller, iawvController: iawvController);
    }

    // For loading bar
    setState(() {
      loadingPercentage = 0;
      if (loadingProgressBarOpacity > 0.0) loadingProgressBarOpacity = 0.0;
    });
  }

  void loadingPage(int progress,
      {WebViewController? controller, InAppWebViewController? iawvController}) {
    setState(() {
      loadingPercentage = progress;
      if (progress == 100) {
        if (loadingProgressBarOpacity > 0.0) loadingProgressBarOpacity = 0.0;
      } else {
        if (loadingProgressBarOpacity < 1.0) loadingProgressBarOpacity = 1.0;
      }
      if (isInit && splashOpacity == 0.0) {
        splashFadeDuration = splashFadeInDuration;
        splashOpacity = 1.0;
      }
    });
  }

  void onTitleLoaded(String? title,
      {WebViewController? controller, InAppWebViewController? iawvController}) {
    if (!Platform.isAndroid) {
      // Insert adapter codes
      insertAdapterCodes(
          controller: controller, iawvController: iawvController);

      // Provide screen area info
      updateSafeAreaInsets(
          controller: controller, iawvController: iawvController);
    }
  }

  void completePage(String url,
      {WebViewController? controller, InAppWebViewController? iawvController}) {
    setState(() {
      loadingPercentage = 100;

      if (loadingProgressBarOpacity > 0.0) loadingProgressBarOpacity = 0.0;
      if (isInit) {
        if (splashOpacity > 0.0) {
          splashFadeDuration = splashFadeOutDuration;
          splashOpacity = 0.0;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (isInit) {
            await Future.delayed(splashFadeOutDuration);
            if (isInit) {
              setState(() {
                if (isInit) {
                  isInit = false;
                  this.iawvController?.requestFocus();

                  if (initialUriReceived && !initialUriProcessed) {
                    initialUriProcessed = true;
                    if (initialUri != null) processAppLinkReceived(initialUri!);
                  }
                }
              });
            }
          }
        });
      } else {
        iawvController?.requestFocus();
      }
    });
  }

  // WebView actions support
  Future<bool> processNavigationRequest(Uri uri, bool isMainFrame,
      {bool isPopupBrowser = false, NavigationAction? navigationAction}) async {
    if (kDebugMode)
      print(
          "Process navigation request - url: $uri, isMainFrame: $isMainFrame");
    final scheme = uri.scheme;
    final host = uri.host;

    if (uri.scheme == SCHEME) {
      // <- To do implement when received app link own app link scheme
      return true;
    } else if (![
      "http",
      "https",
      "file",
      "chrome",
      "data",
      "javascript",
      "about",
    ].contains(scheme)) {
      if (await canLaunchUrl(uri)) {
        // Launch the App
        await launchUrl(uri);
        // and cancel the request
        return true;
      } else {
        // Fallback mode launch
        final result = await launchUrl(uri);
        if (result) return true;
      }
    }

    if (isPopupBrowser) {
      // do nothing = allow navigate
    } else if (isMainFrame) {
      if (host.endsWith(SERVICE_HOST)) {
        // do nothing = allow navigate
      } else {
        // prevent navigate for PWA service
        // vv *or open popup browser
        // openPopupBrowser(uri.toString(), navigationAction: navigationAction, referrerController: isIAWV ? iawvController : null);
        return true;
      }
    }

    return false;
  }

  Future<bool> processBackWebView() async {
    if (isIAWV) {
      if (await iawvController!.canGoBack()) {
        await iawvController!.goBack();
        return true;
      }
    } else {
      if (await controller!.canGoBack()) {
        await controller!.goBack();
        return true;
      }
    }
    return false;
  }

  Future<dynamic> executeJavascript(String codes) async {
    if (isIAWV) {
      return await iawvController?.evaluateJavascript(source: codes);
    } else {
      return await controller?.runJavaScriptReturningResult(codes);
    }
  }

  Future<void> refreshWebView() async {
    if (isIAWV) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        iawvController?.reload();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        iawvController?.loadUrl(
            urlRequest: URLRequest(url: await iawvController?.getUrl()));
      }
    } else {
      await controller?.reload();
    }
  }

  Future<void> clearCacheWebView() async {
    if (isIAWV) {
      await InAppWebViewController.clearAllCache();
    } else {
      await controller?.clearCache();
    }
    if (kDebugMode) print("Cleared WebView Cache!");
  }

  releaseCacheMode(bool isInternetAvailable) async {
    if (isIAWV) {
      var settings = await iawvController?.getSettings();
      if (settings != null) {
        var changeTo = isInternetAvailable
            ? CacheMode.LOAD_DEFAULT
            : CacheMode.LOAD_CACHE_ELSE_NETWORK;
        if (settings.cacheMode != changeTo) {
          settings.cacheMode = changeTo;
          iawvController?.setSettings(settings: settings);
        }
      }
    } else {}
  }

  // Estre UI supports
  Future<dynamic> closePopupBrowserWhenOnTop() async {
    return executeJavascript("closePopupBrowserWhenOnTop?.()");
  }

  Future<bool> processBackForEstreUi() async {
    if (isIAWV) {
      final returns = await iawvController!.callAsyncJavaScript(
          functionBody: 'return await estreUi?.back?.() ?? false');
      if (kDebugMode) print(returns);
      if ((returns?.value as bool?) == true) return true;
    } else {
      final returns = await controller!.runJavaScriptReturningResult(
          'await estreUi?.back?.() ?? false'); //Async method not returning - alternative implementation needed
      if (kDebugMode) print(returns);
      if ((returns as bool?) == true) return true;
    }
    return false;
  }

  Future<void> processWebViewAppRequest(String data) async {
    final request = jsonDecode(data);
    if (kDebugMode)
      print("Received request process from WebView: ${request.handlerName}");

    String? originUrl = await controller?.currentUrl();
    Uri? origin = originUrl != null ? Uri.parse(originUrl) : null;
    await processAppRequest(
        request.handlerName, request.requestId, request.args,
        origin: origin, from: origin);
  }

  void processInAppWebViewAppRequest(
      String handlerName, JavaScriptHandlerFunctionData data) {
    if (kDebugMode)
      print("Received request process from InAppWebView: $handlerName");
    List<dynamic> args = data.args;
    String requestId = args.removeAt(0);

    processAppRequest(handlerName, requestId, args,
        isMainFrame: data.isMainFrame,
        origin: data.origin,
        from: data.requestUrl);
  }

  Future<void> processAppRequest(
      String handlerName, String requestId, List<dynamic> args,
      {bool? isMainFrame, Uri? origin, Uri? from}) async {
    if (kDebugMode)
      print(
          "Requested process: $handlerName, requestId: $requestId, args: $args");

    String codes;
    if (appRequestHandlers[handlerName] != null) {
      final returns = await appRequestHandlers[handlerName]!(args,
          isMainFrame: isMainFrame, origin: origin, from: from);
      if (kDebugMode) print("Request handler returns: $returns");

      codes =
          '''window.app.returnResult("$requestId", `${jsonEncode(returns)}`)''';
    } else {
      if (kDebugMode) print("Request handler not exist: $handlerName");

      codes = 'window.app.returnResult("$requestId", null, true)';
    }

    if (kDebugMode) print("Feedback response codes: \n$codes");
    if (isIAWV) {
      iawvController?.evaluateJavascript(source: codes);
    } else {
      controller?.runJavaScript(codes);
    }
  }

  // WebView supports
  void updateSafeAreaInsets(
      {WebViewController? controller, InAppWebViewController? iawvController}) {
    final padding = MediaQuery.of(context).padding;
    setState(() {
      safeAreaInsets = {
        'top': padding.top,
        'left': padding.left,
        'bottom': padding.bottom,
        'right': padding.right,
      };
    });

    final codes = '''
      window.safeAreaInsets = $safeAreaInsets;
      window.dispatchEvent(new Event("safeAreaInsetsChanged"));
    '''
        .trimMargin();
    controller?.runJavaScript(codes);
    iawvController?.evaluateJavascript(source: codes);
  }

  Future<List<ConnectivityResult>> checkConnection(
      {Function(List<ConnectivityResult>)? callback}) async {
    List<ConnectivityResult> current = await Connectivity().checkConnectivity();
    currentConnections = current;
    callback?.call(current);
    return current;
  }

  checkInternetAvailable({String target = "google.co.kr"}) async {
    isInternetAvailable = false;
    bool isOk = true;
    try {
      final result = await InternetAddress.lookup(target);
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        isOk = false;
      }
    } on SocketException catch (_) {
      isOk = false;
    }
    setState(() {
      isInternetAvailable = isOk;
    });
    executeJavascript(
        'window.app.isOnline = $isOk; window.dispatchEvent(new Event("${isOk ? "online" : "offline"}"))');
    releaseCacheMode(isOk);
    return isOk;
  }

  whenInternetAvailable(
      {String target = "google.co.kr",
      Duration retryTerm = const Duration(seconds: 3),
      Function? callback}) async {
    while (!await checkInternetAvailable(target: target)) {
      await Future.delayed(retryTerm);
    }
    callback?.call();
  }

  Future<bool> checkOnline({Function(bool)? callback}) async {
    // await checkConnection();
    final isFine = isOnline && await checkInternetAvailable();
    callback?.call(isFine);
    return isFine;
  }

  Future<PackageInfo> getPackageInfo({Function(PackageInfo)? callback}) async {
    packageInfo = await PackageInfo.fromPlatform();
    callback?.call(packageInfo);
    return packageInfo;
  }

  // Popup webview for external service
  // Use instead Estre UI's popup browser when that page required cookie.
  openPopupBrowser(
    String requestedUrl, {
    CreateWindowAction? createWindowAction,
    NavigationAction? navigationAction,
    Uri? referrer,
    Uri? referrerOrigin,
    InAppWebViewController? referrerController,
    String initialTitle = "",
    String? fixedTitle,
  }) async {
    if (referrerController != null) {
      referrer ??= await referrerController.getUrl();
      referrerOrigin ??= await referrerController.getOriginalUrl();
    }
    Uri requestedUri = Uri.parse(requestedUrl);
    bool isOwnService = requestedUri.host.endsWith(SERVICE_SUFFIX);

    late final InAppWebViewController iawvCon;
    InAppWebViewSettings initialSettings = InAppWebViewSettings(
      isInspectable: kDebugMode,
      applicationNameForUserAgent: "$APP_NAME/${packageInfo.version}",
      javaScriptEnabled: true,
      javaScriptCanOpenWindowsAutomatically: true,
      supportMultipleWindows: true,
      // sharedCookiesEnabled: true,
      // thirdPartyCookiesEnabled: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      // iframeAllow: "camera; microphone",
      iframeAllowFullscreen: true,
      cacheMode:
          isOwnService ? CacheMode.LOAD_DEFAULT : CacheMode.LOAD_NO_CACHE,
    );

    Future<void> refresher() async {
      if (defaultTargetPlatform == TargetPlatform.android) {
        iawvCon.reload();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        iawvCon.loadUrl(urlRequest: URLRequest(url: await iawvCon.getUrl()));
      }
    }

    Future<void> insertAdapterCodes() async {
      await iawvCon.evaluateJavascript(
          source: '''
        // common

      '''
              .trimMargin());
    }

    late final PullToRefreshController ptrCon = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: Theme.of(context).primaryColor,
      ),
      onRefresh: refresher,
    );

    String titleText = initialTitle;
    bool onLoading = false;
    bool canGoBack = false;
    bool canGoForward = false;
    int loadingPct = 0;
    double controlBarHeight = 48;
    double iconSize = (controlBarHeight * 7 / 12).toInt().toDouble();

    await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) async {
                  if (didPop) {
                    return;
                  }

                  final navigator = Navigator.of(context);
                  if (await iawvCon.canGoBack()) {
                    iawvCon.goBack();
                  } else {
                    navigator.pop();
                  }
                },
                child: Container(
                    color: Theme.of(context).canvasColor,
                    child: SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height,
                        child: Stack(children: [
                          SafeArea(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    height: controlBarHeight,
                                    child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Container(
                                              width:
                                                  Platform.isAndroid ? 10 : 5),
                                          IconButton(
                                              iconSize: iconSize,
                                              icon: Icon(Icons.arrow_back_ios),
                                              enableFeedback: canGoBack,
                                              onPressed: () {
                                                iawvCon.goBack();
                                              }),
                                          IconButton(
                                              iconSize: iconSize,
                                              icon:
                                                  Icon(Icons.arrow_forward_ios),
                                              enableFeedback: canGoForward,
                                              onPressed: () {
                                                iawvCon.goForward();
                                              }),
                                          IconButton(
                                              iconSize: iconSize,
                                              icon: Icon(Icons.home_outlined),
                                              onPressed: () {
                                                iawvCon.loadUrl(
                                                    urlRequest: URLRequest(
                                                        url: WebUri(
                                                            requestedUrl)));
                                              }),
                                          Expanded(
                                              child: Container(
                                                  padding: EdgeInsets.fromLTRB(
                                                      10, 5, 10, 5),
                                                  child: DefaultTextStyle(
                                                      style: TextStyle(
                                                          color:
                                                              Color(0xff222222),
                                                          fontSize: 18,
                                                          height: 1.2),
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                              fixedTitle ??
                                                                  titleText.replaceAll(
                                                                      RegExp(
                                                                          r"[\r\n]"),
                                                                      " "),
                                                              style: TextStyle(
                                                                  fontSize: 20,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700)),
                                                        ],
                                                      )))),
                                          IconButton(
                                              iconSize: iconSize,
                                              icon: Icon(onLoading
                                                  ? Icons.cancel
                                                  : Icons.refresh),
                                              onPressed: () {
                                                if (onLoading)
                                                  iawvCon.stopLoading();
                                                refresher();
                                              }),
                                          IconButton(
                                              iconSize: iconSize,
                                              icon: Icon(Icons.close),
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              }),
                                          Container(
                                              width:
                                                  Platform.isAndroid ? 5 : 0),
                                        ]),
                                  ),
                                  Expanded(
                                    child: InAppWebView(
                                      windowId: createWindowAction?.windowId,
                                      initialUrlRequest: createWindowAction
                                              ?.request ??
                                          navigationAction?.request ??
                                          URLRequest(url: WebUri(requestedUrl)),
                                      initialSettings: initialSettings,
                                      pullToRefreshController: ptrCon,
                                      onWebViewCreated: (con) {
                                        iawvCon = con;
                                        //setIawvUA(popupController: con);
                                      },
                                      shouldOverrideUrlLoading:
                                          (controller, navigationAction) async {
                                        final isMainFrame =
                                            navigationAction.isForMainFrame;
                                        final request =
                                            navigationAction.request;

                                        final navigator = Navigator.of(context);

                                        final isDownload = navigationAction
                                                .shouldPerformDownload ??
                                            false;
                                        if (isDownload) {
                                          if (navigationAction.request.url !=
                                                  null &&
                                              requestedUrl.isEmpty) {
                                            Future.delayed(
                                                Duration(milliseconds: 100),
                                                () {
                                              navigator.pop();
                                            });
                                          }
                                          return NavigationActionPolicy
                                              .DOWNLOAD;
                                        }

                                        final uri = request.url;
                                        if (uri != null) {
                                          if (kDebugMode)
                                            print(
                                                "Referrer origin host: ${referrerOrigin?.host}, Popup browse requested host: ${requestedUri.host}, Navigate request host: ${uri.host}");
                                          return await processNavigationRequest(
                                                  uri, isMainFrame,
                                                  isPopupBrowser: true)
                                              ? NavigationActionPolicy.CANCEL
                                              : NavigationActionPolicy.ALLOW;
                                        }

                                        return NavigationActionPolicy.ALLOW;
                                      },
                                      onUpdateVisitedHistory:
                                          (controller, url, androidIsReload) {
                                        () async {
                                          final cgb =
                                              await controller.canGoBack();
                                          setState(() {
                                            canGoBack = cgb;
                                          });
                                        }();
                                        () async {
                                          final cgf =
                                              await controller.canGoForward();
                                          setState(() {
                                            canGoForward = cgf;
                                          });
                                        }();
                                        setState(() {});
                                      },
                                      onLoadStart: (controller, url) {
                                        setState(() {
                                          if (url != null &&
                                              url.toString() != "about:blank" &&
                                              requestedUrl.isEmpty) {
                                            if (kDebugMode)
                                              print(
                                                  "Initial navigation received: $url");
                                            requestedUrl = url.toString();
                                            requestedUri = url;

                                            final isCacheAllowed = isOwnService;
                                            isOwnService = requestedUri.host
                                                .endsWith(SERVICE_SUFFIX);
                                            final isAllowedNew = isOwnService;
                                            if (isAllowedNew !=
                                                isCacheAllowed) {
                                              () async {
                                                final settings =
                                                    await controller
                                                            .getSettings() ??
                                                        initialSettings;
                                                settings.cacheMode =
                                                    isAllowedNew
                                                        ? CacheMode.LOAD_DEFAULT
                                                        : CacheMode
                                                            .LOAD_NO_CACHE;
                                                controller.setSettings(
                                                    settings: settings);
                                              }();
                                            }
                                          }
                                          onLoading = true;
                                          loadingPct = 0;
                                        });
                                        insertAdapterCodes();
                                      },
                                      onProgressChanged:
                                          (controller, progress) {
                                        if (progress == 100) {
                                          ptrCon.endRefreshing();
                                        } else {}
                                        setState(() {
                                          loadingPct = progress;
                                        });
                                      },
                                      onLoadStop: (controller, url) {
                                        ptrCon.endRefreshing();
                                        setState(() {
                                          onLoading = false;
                                          loadingPct = 0;
                                        });
                                        insertAdapterCodes();
                                      },
                                      onReceivedError:
                                          (controller, request, error) {
                                        ptrCon.endRefreshing();
                                      },
                                      onTitleChanged: (controller, title) {
                                        setState(() {
                                          titleText = title ?? initialTitle;
                                        });
                                      },
                                      onPermissionRequest:
                                          (controller, request) async {
                                        return PermissionResponse(
                                            resources: request.resources,
                                            action:
                                                PermissionResponseAction.GRANT);
                                      },
                                      onCreateWindow: (controller,
                                          createWindowAction) async {
                                        final uri =
                                            createWindowAction.request.url;
                                        openPopupBrowser(uri?.toString() ?? "",
                                            createWindowAction:
                                                createWindowAction,
                                            referrerController: controller);
                                        return true;
                                      },
                                      onCloseWindow: (controller) {
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ),
                                ]),
                          ),
                          SizedBox(
                              width: MediaQuery.of(context).size.width,
                              height: MediaQuery.of(context).padding.top,
                              child: AnimatedOpacity(
                                  curve: Curves.ease,
                                  opacity: loadingPct == 0 || loadingPct == 100
                                      ? 0.0
                                      : 1.0,
                                  duration: loadingProgressFadeDuration,
                                  child: LinearProgressIndicator(
                                      value: loadingPct / 100.0,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary))),
                        ]))));
          });
        });
  }
}
