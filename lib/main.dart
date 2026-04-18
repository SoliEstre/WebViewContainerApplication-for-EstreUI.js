import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
//import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
// import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:indent/indent.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:app_settings/app_settings.dart';
import 'package:app_links/app_links.dart';
import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:webview_flutter/webview_flutter.dart' as FSWV;
import 'package:webview_flutter_android/webview_flutter_android.dart'
    hide MixedContentMode;
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_install_referrer/flutter_install_referrer.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);

    // Check service worker feature support
    var swAvailable = await WebViewFeature.isFeatureSupported(
        WebViewFeature.SERVICE_WORKER_BASIC_USAGE);
    var swInterceptAvailable = await WebViewFeature.isFeatureSupported(
        WebViewFeature.SERVICE_WORKER_SHOULD_INTERCEPT_REQUEST);

    if (swAvailable && swInterceptAvailable) {
      ServiceWorkerController serviceWorkerController =
          ServiceWorkerController.instance();

      await serviceWorkerController.setServiceWorkerClient(ServiceWorkerClient(
        shouldInterceptRequest: (request) async {
          if (kDebugMode) print("Service Worker Request: ${request.url}");
          return null; // Allow default processing
        },
      ));

      var swAllowContentAccess = await WebViewFeature.isFeatureSupported(
          WebViewFeature.SERVICE_WORKER_CONTENT_ACCESS);
      var swAllowFileAccess = await WebViewFeature.isFeatureSupported(
          WebViewFeature.SERVICE_WORKER_FILE_ACCESS);
      var swBlockNetworkLoads = await WebViewFeature.isFeatureSupported(
          WebViewFeature.SERVICE_WORKER_BLOCK_NETWORK_LOADS);
      var swCacheMode = await WebViewFeature.isFeatureSupported(
          WebViewFeature.SERVICE_WORKER_CACHE_MODE);

      if (swAllowContentAccess)
        await ServiceWorkerController.setAllowContentAccess(true);
      if (swAllowFileAccess)
        await ServiceWorkerController.setAllowFileAccess(true);
      if (swBlockNetworkLoads)
        await ServiceWorkerController.setBlockNetworkLoads(false);
      if (swCacheMode)
        await ServiceWorkerController.setCacheMode(CacheMode.LOAD_NO_CACHE);
    }
  }

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

class WebviewErrorInfo {
  final String type;
  final String message;
  final int code;
  final String? description;

  WebviewErrorInfo({
    required this.type,
    required this.message,
    required this.code,
    this.description,
  });

  @override
  String toString() {
    return "$type [$code] $message\n$description";
  }
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
  bool isSharedPreferencesLoaded = false;

  final appLinks = AppLinks();
  late final StreamSubscription<Uri> appLinkListen;

  late final AppLifecycleListener _listener;
  AppLifecycleState? get state => SchedulerBinding.instance.lifecycleState;

  late final PackageInfo packageInfo;

  late final StreamSubscription<List<ConnectivityResult>> connectivity;

  late final FSWV.WebViewController? controller;
  late final FSWV.WebViewCookieManager? cookieMan;
  InAppWebViewController? iawvController;
  late final CookieManager? iawvCookieMan;
  // WebViewEnvironment? webViewEnvironment;
  late final InAppWebViewSettings settings = InAppWebViewSettings(
    isInspectable: kDebugMode,
    applicationNameForUserAgent: appInfoForUA,
    javaScriptEnabled: true,
    javaScriptCanOpenWindowsAutomatically: true,
    supportMultipleWindows: true,
    sharedCookiesEnabled: true,
    thirdPartyCookiesEnabled: true,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    // loadWithOverviewMode: true,
    // useWideViewPort: false,
    // initialScale: 0,
    textZoom: 100, // Fix text zoom to 100% to ignore system font size setting
    iframeAllow: "camera; microphone",
    iframeAllowFullscreen: true,
    disableDefaultErrorPage: true,
    limitsNavigationsToAppBoundDomains:
        false, // Allow cross-origin window access
    cacheMode: CacheMode.LOAD_NO_CACHE, //CacheMode.LOAD_DEFAULT,

    // Service worker activation settings
    allowFileAccessFromFileURLs: true,
    allowUniversalAccessFromFileURLs: true,
    // mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
    hardwareAcceleration: true,
    allowContentAccess: true,
    allowFileAccess: true,
    // cacheEnabled: true,
    // clearCache: false,

    // Additional settings for service worker support on Android
    domStorageEnabled: true,
    databaseEnabled: true,

    // Service worker support on iOS
    allowsLinkPreview: false,
    allowsBackForwardNavigationGestures: true,
    // useOnNavigationResponse: true,

    transparentBackground: false,
    rendererPriorityPolicy: RendererPriorityPolicy(
      rendererRequestedPriority: RendererPriority.RENDERER_PRIORITY_IMPORTANT,
      waivedWhenNotVisible: true,
    ),
    minimumZoomScale: 1,
  );
  PullToRefreshController? pullToRefreshController;

  // Switch for flutter_inappwebview / webview_flutter
  final isIAWV = true; //false//

  final BLANK = "about:blank";
  // vv To be setted specified scheme for calling this app's app link
  final SCHEME = "wvca4eui";
  // vv To be setted specified host for communication to your own API server
  final API_HOST = "estreui.mpsolutions.kr";
  // vv To be setted specified host for your own Estre UI PWA service. it must be fixed url location on main web view
  final SERVICE_HOST = "estreui.mpsolutions.kr";
  // vv To be setted specified host suffix for check url is own service when load popup browser
  final SERVICE_SUFFIX = "mpsolutions.kr";

  // String get rootUrl => "https://$SERVICE_HOST"; // <- Initial Estre UI site when url is index page
  String get rootUrl => "https://$SERVICE_HOST/serviceLoader.html";
  Uri get rootUri => Uri.parse(rootUrl);

  String appInfoForUA = "";
  // Be setted App name & version on initState for insert to user agent
  String uaSuffix = "";

  // vv Splash fade in duration. to be setted to splashFadeDuration as same
  final splashFadeInDuration = const Duration(milliseconds: 300);
  // vv Splash fade out duration
  final splashFadeOutDuration = const Duration(milliseconds: 500);
  // vv Initial(fade in) duration. set same value as splashFadeInDuration
  var splashFadeDuration = const Duration(milliseconds: 300);
  // vv Top web view loading bar fade in/out duration
  final loadingProgressFadeDuration = const Duration(milliseconds: 300);

  // Device info for provide to Estre UI application
  Map<String, dynamic>? rawDeviceInfo;
  final deviceInfo = DeviceInfoPlugin();
  AndroidDeviceInfo? androidDeviceInfo;
  IosDeviceInfo? iosDeviceInfo;
  DeviceCommonInfo? device;
  bool isIPhone = false;
  bool isIOS26 = false;

  MethodChannel methodChannel = const MethodChannel("app_default");

  AppLifecycleState _currentLifecycleState = AppLifecycleState.resumed;
  int _lastLifecycleChangeTime = 0;

  bool isInitialized = false;

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

  var needReloadOnResume = false;

  var onLoadMainWebview = false;

  double splashOpacity = 0.0;

  var loadingPercentage = 0;
  double loadingProgressBarOpacity = 0.0;

  var exitRequested = 0;

  bool _isInMultiWindowMode = false;

  bool isAppliedUserAgentForIPhone = false;

  String currentUrl = "";
  String? currentTitle;

  WebviewErrorInfo? onMainWebviewLoadError;

  int foregroundTerminationCount = 0;

  bool _isLoadedEstreUi = false;
  bool get isLoadedEstreUi => _isLoadedEstreUi;
  set isLoadedEstreUi(bool value) {
    _isLoadedEstreUi = value;

    // do something when Estre UI loaded
  }

  bool _isReadyEstreUiApp = false;
  bool get isReadyEstreUiApp => _isReadyEstreUiApp;
  set isReadyEstreUiApp(bool value) {
    _isReadyEstreUiApp = value;

    // do something when Estre UI App ready
  }

  bool? _isAppAutoStartEnabled;

  bool? _isAboDisabled;
  bool? _isAboManufacturerDisabled;

  bool? isFixedPortrait;
  bool? isSetFixedPortrait;

  // For notification processes
  Object? notiTriggeredByUser;
  Object? notiReceivedForeground;

  String? notiTriggeredByUserCallback;
  String? notiReceivedForegroundCallback;

  bool useAutoReloaderForTest = false; //true;//

  Future<bool> get wvCanGoBack =>
      (isIAWV ? iawvController?.canGoBack() : controller?.canGoBack()) ??
      Future.value(false);
  Future<bool> get wvCanGoForward =>
      (isIAWV ? iawvController?.canGoForward() : controller?.canGoForward()) ??
      Future.value(false);
  bool wvIsLoading = false;

  @override
  void initState() {
    super.initState();

    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (data != null && data.isNotEmpty) {
        // final uri = Uri.parse(data["custom_url"]);
        // processAppLinkReceived(uri);
      }

      final noti = event.notification;
      notiTriggeredByUser = {
        "id": noti.notificationId,
        "anid": noti.androidNotificationId,
        "title": noti.title,
        "body": noti.body,
        "url": noti.launchUrl,
        "largeIcon": noti.largeIcon,
        "bigPicture": noti.bigPicture,
        "attachments": noti.attachments,
        "sound": noti.sound,
        "data": data,
      };

      postNotiTriggeredByUser();
    });
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      final data = event.notification.additionalData;
      if (data != null && data.isNotEmpty) {
        // final uri = Uri.parse(data["custom_url"]);
        // processAppLinkReceived(uri);
      }

      event.preventDefault();

      final noti = event.notification;
      notiReceivedForeground = {
        "id": noti.notificationId,
        "anid": noti.androidNotificationId,
        "title": noti.title,
        "body": noti.body,
        "url": noti.launchUrl,
        "largeIcon": noti.largeIcon,
        "bigPicture": noti.bigPicture,
        "attachments": noti.attachments,
        "sound": noti.sound,
        "data": data,
      };

      postNotiReceivedForeground().then((allowed) {
        noti.display();
      });
    });

    // Enable verbose logging for debugging (remove in production)
    if (kDebugMode) OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    // Initialize with your OneSignal App ID
    OneSignal.initialize(
        "Enter_Your_OneSignal_App_ID_Here"); // <- To be changed your OneSignal App ID
    // Use this method to prompt for push notifications.
    // We recommend removing this method after testing and instead use In-App Messages to prompt for notification permission.
    // OneSignal.Notifications.requestPermission(false);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      // vv Set system bar icon brightness by your Estre UI app background color
      statusBarIconBrightness:
          Brightness.dark, //darkMode ? Brightness.light : Brightness.dark,
      systemNavigationBarIconBrightness:
          Brightness.dark, //darkMode ? Brightness.light : Brightness.dark,
      // ^^ set to dark when your site BG are lighten. set light or not.
      //    or implement custom dark mode toggle your self be with interoperated Estre UI site.
      // vv or adjust bar color to any you want half-transparency level.
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      // vv or set true bar contrast enforced for apply default half-transparency.
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
      // this options only be applied to Android devices.
      // default setting is matched be same as iOS system UI display style.
    ));

    // App link receiver. not recommended change this code.
    // for initial uri receive and process when started with app link.
    // custom implement is write in to processAppLinkReceived()
    appLinks.uriLinkStream.listen((uri) {
      if (isInit && (currentUrl.isEmpty || currentUrl == BLANK)) {
        initialUriReceived = true;
        initialUri = uri;
      } else {
        processAppLinkReceived(uri);
      }
    });

    // App lice cycle listener. insert implements for your app's needs
    _listener = AppLifecycleListener(onInactive: () {
      if (kDebugMode) print("AppLifecycleState.inactive");
    }, onHide: () {
      if (kDebugMode) print("AppLifecycleState.hide");
      if (!isInit && isIAWV) {
        iawvController?.clearFocus();
        if (defaultTargetPlatform == TargetPlatform.android)
          iawvController?.pause();
        WidgetsBinding.instance.addPostFrameCallback((_) async {});
      }
    }, onPause: () {
      if (kDebugMode) print("AppLifecycleState.pause");
      if (!isInit && isIAWV) {
        iawvController?.pauseTimers();
      }
    }, onDetach: () {
      if (kDebugMode) print("AppLifecycleState.detach");
    }, onRestart: () async {
      if (kDebugMode) print("AppLifecycleState.restart");
      if (!isInit && isIAWV) {
        if (iawvController != null) await setIawvUA();
        iawvController?.resumeTimers();
      }
    }, onShow: () {
      if (kDebugMode) print("AppLifecycleState.show");
      if (!isInit && isIAWV) {
        if (defaultTargetPlatform == TargetPlatform.android)
          iawvController?.resume();
        iawvController?.requestFocus();
        WidgetsBinding.instance.addPostFrameCallback((_) async {});
      }
    }, onResume: () async {
      if (kDebugMode) print("AppLifecycleState.resume");
      if (!isInit && (!await checkAliveWebview())) return;
      await releaseAndroidAppBatteryOptimizationDisabled();
    }, onExitRequested: () async {
      if (kDebugMode) print("AppLifecycleState.exitRequested");
      return AppExitResponse.exit;
    }, onStateChange: (state) {
      if (kDebugMode) print("AppLifecycleState changed: $state");
    });

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

      late FSWV.PlatformWebViewCookieManagerCreationParams cParams =
          const FSWV.PlatformWebViewCookieManagerCreationParams();
      late final FSWV.PlatformWebViewControllerCreationParams params;
      if (FSWV.WebViewPlatform.instance is WebKitWebViewPlatform) {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        );
        cParams = WebKitWebViewCookieManagerCreationParams
            .fromPlatformWebViewCookieManagerCreationParams(cParams);
      } else if (FSWV.WebViewPlatform.instance is AndroidWebViewPlatform) {
        params = AndroidWebViewControllerCreationParams();
        cParams = AndroidWebViewCookieManagerCreationParams
            .fromPlatformWebViewCookieManagerCreationParams(cParams);
      } else {
        params = const FSWV.PlatformWebViewControllerCreationParams();
      }
      cookieMan = FSWV.WebViewCookieManager.fromPlatformCreationParams(cParams);

      controller = FSWV.WebViewController.fromPlatformCreationParams(
          params); //WebViewController()
    }

    connectivity = Connectivity().onConnectivityChanged.listen((result) {
      currentConnections = result;

      checkInternetAvailable();
    });

    // Async initializes with application package info
    getPackageInfo(callback: (info) async {
      if (Platform.isAndroid) {
        final isMultiWindow =
            await methodChannel.invokeMethod('isInMultiWindowMode') ?? false;
        _onShiftMultiWindowMode(isMultiWindow, isInit: true);
      }

      final strIsFixedPortrait =
          sp.getString("isFixedPortrait") ?? "false"; //"auto";
      isFixedPortrait = strIsFixedPortrait == "auto"
          ? null
          : strIsFixedPortrait == "true"
              ? true
              : false;
      releaseFixedOrientationPortrait();

      sp = await SharedPreferences.getInstance();
      isSharedPreferencesLoaded = true;
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
          isIPhone = info.model == "iPhone";
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
          final versionBlocks = info.systemVersion.split(".");
          if (versionBlocks.isNotEmpty) {
            final major = int.tryParse(versionBlocks[0]) ?? 0;
            if (major == 26) setState(() => isIOS26 = true);
          }
        }
      } else {
        if (kDebugMode) print("Platform is ${Platform.operatingSystem}");
      }

      setState(() {
        appInfoForUA = "$APP_NAME/${info.version}";
        settings.applicationNameForUserAgent = appInfoForUA;
        uaSuffix = " $appInfoForUA";
      });
      await setIawvUA();

      WidgetsBinding.instance.addObserver(this);

      // Set environment for well receive push notification
      await releaseAndroidAppBatteryOptimizationDisabled(isInit: true);

      var installReferrer = await _getInstallReferrerUrl();
      if (installReferrer != null) {
        if (kDebugMode) print("Install referrer: $installReferrer");
        // final String url = installReferrer["referrerUrl"];
        // final params = Uri.splitQueryString(url);
        // final referrer = params["referrer"];
        // if (referrer != null &&
        //     referrer.startsWith("specified url")) {
        //   final uri = Uri.parse(referrer);
        //   if (uri.hasQuery) {
        //     initialUriReceived = true;
        //     initialUri = Uri.parse("$rootUrl?${uri.query}");
        //   }
        // }
      }
      final installReferrerApp = await InstallReferrer.referrer;
      if (kDebugMode) print("Install referrer: $installReferrerApp");

      if (isIAWV) {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          await InAppWebViewController.setWebContentsDebuggingEnabled(
              kDebugMode);
        }

        setIawvJsHandler();
      } else {
        if (controller!.platform is AndroidWebViewController) {
          AndroidWebViewController.enableDebugging(true);

          final androidController =
              (controller!.platform as AndroidWebViewController);

          await androidController.setMediaPlaybackRequiresUserGesture(false);

          await androidController.enableZoom(false);

          final androidCookieManager =
              (cookieMan!.platform as AndroidWebViewCookieManager);

          await androidCookieManager.setAcceptThirdPartyCookies(
              androidController, true);
        } else if (controller!.platform is WebKitWebViewController) {
          final webkitController =
              (controller!.platform as WebKitWebViewController);

          final webkitCookieManager =
              (cookieMan!.platform as WebKitWebViewCookieManager);
        }

        var ua = await controller!.getUserAgent();
        if (kDebugMode) print(ua);

        controller!
          ..setJavaScriptMode(FSWV.JavaScriptMode.unrestricted)
          ..setUserAgent(ua.toString() + uaSuffix)
          ..setNavigationDelegate(FSWV.NavigationDelegate(
            onNavigationRequest: (navigation) async {
              final isMainFrame = navigation.isMainFrame;
              final uri = Uri.parse(navigation.url);

              return await processNavigationRequest(uri, isMainFrame,
                      referrerUrl: currentUrl, rawUrl: navigation.url)
                  ? FSWV.NavigationDecision.prevent
                  : FSWV.NavigationDecision.navigate;
            },
            onUrlChange: (url) {
              if (url.url != null) currentUrl = url.url!;
            },
            onHttpError: (FSWV.HttpResponseError error) {
              String errorType = error.toString();
              String errorMessage = "";
              int errorCode = error.response?.statusCode ?? -99;
              if (errorCode == 400) {
                errorMessage = "Bad Request";
              } else if (errorCode == 401) {
                errorMessage = "Unauthorized";
              } else if (errorCode == 403) {
                errorMessage = "Forbidden";
              } else if (errorCode == 404) {
                errorMessage = "Not Found";
              } else if (errorCode == 408) {
                errorMessage = "Request Timeout";
              } else if (errorCode == 500) {
                errorMessage = "Internal Server Error";
              } else if (errorCode == 502) {
                errorMessage = "Bad Gateway";
              } else if (errorCode == 503) {
                errorMessage = "Service Unavailable";
              } else if (errorCode == 504) {
                errorMessage = "Gateway Timeout";
              } else if (errorCode < 0) {
                errorMessage = "Network Error";
              } else {
                errorMessage = "An unknown error has occurred";
              }

              var info = WebviewErrorInfo(
                  type: errorType, message: errorMessage, code: errorCode);

              onMainWebviewLoadError = info;

              // if (req != null && req.uri.toString().startsWith(rootUri.toString())) controller.loadRequest(rootUri);
            },
            onPageStarted: (url) {
              final uri = Uri.parse(url);
              final isServiceHost = uri.host.endsWith(SERVICE_HOST) == true;
              if (url.isNotEmpty && isServiceHost && uri.path == "/") {
                setState(() {
                  onMainWebviewLoadError = null;
                  onLoadMainWebview = true;
                  currentTitle = null;
                });
              }
              if (isInitialized) {
                beginPage(url, controller: controller);
              }
            },
            onProgress: (progress) async {
              if (currentTitle == null) {
                final title = await controller?.getTitle();
                if (title != null && title.isNotEmpty) {
                  setState(() {
                    currentTitle = title;
                  });
                  onTitleLoaded(title, controller: controller);
                }
              }

              if (isInitialized) {
                loadingPage(progress, controller: controller);
              }
            },
            onPageFinished: (url) {
              if (isInitialized) {
                completePage(url, controller: controller);
              }
            },
            onWebResourceError: (error) {
              if (error.errorType == FSWV.WebResourceErrorType.unknown &&
                  error.description.contains("WKErrorDomain")) {
                if (error.url != null) {
                  launchUrlString(error.url!);
                  return;
                }
              }
            },
          ))
          ..addJavaScriptChannel("App",
              onMessageReceived: (FSWV.JavaScriptMessage message) {
            final data = jsonDecode(message.message);
            if (kDebugMode)
              print("Received request from WebView: ${data.handleName}");

            processWebViewAppRequest(data);
          });
      }

      checkConnection();

      isInitialized = true;

      loadInitialUri();
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
                      child: Padding(
                          padding: MediaQuery.of(context).viewInsets,
                          child: Padding(
                              padding: EdgeInsets.zero,
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                        child: Stack(children: [
                                      !isIAWV
                                          ? FSWV.WebViewWidget(
                                              controller: controller!)
                                          : InAppWebView(
                                              initialUrlRequest: URLRequest(
                                                  url: WebUri(BLANK)),
                                              initialSettings: settings,
                                              pullToRefreshController:
                                                  pullToRefreshController,
                                              onWebViewCreated:
                                                  (InAppWebViewController
                                                      controller) async {
                                                setState(() {
                                                  iawvController = controller;
                                                });

                                                await setIawvUA();

                                                FlutterNativeSplash.remove();
                                              },
                                              shouldOverrideUrlLoading:
                                                  (controller,
                                                      navigationAction) async {
                                                final isMainFrame =
                                                    navigationAction
                                                        .isForMainFrame;
                                                final request =
                                                    navigationAction.request;

                                                final isDownload = navigationAction
                                                        .shouldPerformDownload ??
                                                    false;
                                                if (isDownload)
                                                  return NavigationActionPolicy
                                                      .DOWNLOAD;

                                                final uri = request.url;
                                                final url = uri?.rawValue ??
                                                    uri.toString();
                                                if (kDebugMode) {
                                                  print(
                                                      "mainWebview - url requested: $navigationAction");
                                                  print(
                                                      "raw url: ${uri?.rawValue}");
                                                }

                                                if (uri != null) {
                                                  if (url.isEmpty ||
                                                      (isInitialized &&
                                                          url == BLANK)) {
                                                    return NavigationActionPolicy
                                                        .CANCEL;
                                                  } else {
                                                    return await processNavigationRequest(
                                                            uri, isMainFrame,
                                                            navigationAction:
                                                                navigationAction,
                                                            referrerUrl: isMainFrame
                                                                ? currentUrl
                                                                : navigationAction
                                                                    .sourceFrame
                                                                    ?.request
                                                                    ?.url
                                                                    .toString(),
                                                            rawUrl:
                                                                uri.rawValue)
                                                        ? NavigationActionPolicy
                                                            .CANCEL
                                                        : NavigationActionPolicy
                                                            .ALLOW;
                                                  }
                                                }

                                                return NavigationActionPolicy
                                                    .ALLOW;
                                              },
                                              onUpdateVisitedHistory:
                                                  (controller, url,
                                                      androidIsReload) async {
                                                if (url != null) {
                                                  final urlString =
                                                      url.toString();
                                                  setState(() {
                                                    currentUrl = urlString;
                                                  });
                                                }
                                              },
                                              onPageCommitVisible:
                                                  (controller, url) async {
                                                // if (kDebugMode) print("mainWebview - page commit visible: $url");
                                              },
                                              onLoadStart: (controller, url) {
                                                // if (kDebugMode) print("mainWebview - load started: $url");

                                                setState(() {
                                                  wvIsLoading = true;
                                                });
                                                if (url != null) {
                                                  final isServiceHost = url.host
                                                          .endsWith(
                                                              SERVICE_HOST) ==
                                                      true;
                                                  if (isServiceHost &&
                                                      url.path == "/") {
                                                    setState(() {
                                                      onMainWebviewLoadError =
                                                          null;
                                                      onLoadMainWebview = true;
                                                    });
                                                  }
                                                }

                                                if (isInitialized) {
                                                  beginPage(url.toString(),
                                                      iawvController:
                                                          controller);
                                                }
                                              },
                                              onProgressChanged:
                                                  (controller, progress) {
                                                // if (kDebugMode) print("mainWebview - progress: $progress%");

                                                if (progress == 100) {
                                                  pullToRefreshController
                                                      ?.endRefreshing();
                                                  // completePage(currentUrl, iawvController: controller);
                                                } else {
                                                  // loadingPage(progress, iawvController: controller);
                                                }
                                                if (isInitialized) {
                                                  loadingPage(progress,
                                                      iawvController:
                                                          controller);
                                                }
                                              },
                                              onLoadStop: (controller, url) {
                                                // if (kDebugMode) print("mainWebview - load stopped: $url");

                                                pullToRefreshController
                                                    ?.endRefreshing();
                                                setState(() {
                                                  wvIsLoading = false;
                                                });
                                                if (isInitialized) {
                                                  completePage(url.toString(),
                                                      iawvController:
                                                          controller);
                                                }
                                              },
                                              onReceivedError:
                                                  (controller, request, error) {
                                                pullToRefreshController
                                                    ?.endRefreshing();
                                                if (kDebugMode)
                                                  print(
                                                      "Error occurred: $error");
                                                setState(() {
                                                  wvIsLoading = false;
                                                });
                                                if (request.isForMainFrame ==
                                                    true) {
                                                  var url = request.url;

                                                  if (url.host.endsWith(
                                                              SERVICE_HOST) ==
                                                          true &&
                                                      url.path == "/") {
                                                    String errorType =
                                                        error.type.toString();
                                                    String errorMessage = "";
                                                    int errorCode = -99;
                                                    if (error.type ==
                                                        WebResourceErrorType
                                                            .UNKNOWN) {
                                                      errorMessage =
                                                          "Unknown error occurred";
                                                      errorCode = -1;
                                                    } else if (error.type ==
                                                        WebResourceErrorType
                                                            .CANCELLED) {
                                                      errorMessage =
                                                          "Request was cancelled";
                                                      errorCode = -2;
                                                    } else if (error.type ==
                                                        WebResourceErrorType
                                                            .UNSUPPORTED_SCHEME) {
                                                      errorMessage =
                                                          "Unsupported scheme";
                                                      errorCode = -3;
                                                    } else if (error.type ==
                                                        WebResourceErrorType
                                                            .CANNOT_CONNECT_TO_HOST) {
                                                      errorMessage =
                                                          "Failed to connect to the server";
                                                      errorCode = -4;
                                                    } else if (error.type ==
                                                        WebResourceErrorType
                                                            .UNSAFE_RESOURCE) {
                                                      errorMessage =
                                                          "Unsafe resource";
                                                      errorCode = -5;
                                                    } else if (error.type ==
                                                        WebResourceErrorType
                                                            .NETWORK_CONNECTION_LOST) {
                                                      errorMessage =
                                                          "Network connection lost";
                                                      errorCode = -6;
                                                    } else if (error.type ==
                                                        WebResourceErrorType
                                                            .SECURE_CONNECTION_FAILED) {
                                                      errorMessage =
                                                          "Failed to establish a secure connection";
                                                      errorCode = -7;
                                                    } else if (error.type ==
                                                        WebResourceErrorType
                                                            .BAD_URL) {
                                                      errorMessage =
                                                          "Invalid URL";
                                                      errorCode = 400;
                                                    } else if (error.type ==
                                                        WebResourceErrorType
                                                            .FILE_NOT_FOUND) {
                                                      errorMessage =
                                                          "File not found";
                                                      errorCode = 404;
                                                    } else if (error.type ==
                                                        WebResourceErrorType
                                                            .TIMEOUT) {
                                                      errorMessage =
                                                          "Request timed out";
                                                      errorCode = 408;
                                                    }

                                                    var info = WebviewErrorInfo(
                                                        type: errorType,
                                                        message: errorMessage,
                                                        code: errorCode,
                                                        description:
                                                            error.description);

                                                    setState(() {
                                                      onMainWebviewLoadError =
                                                          info;
                                                    });
                                                  }
                                                }
                                              },
                                              onWebContentProcessDidTerminate:
                                                  (controller) async {
                                                if (kDebugMode)
                                                  print(
                                                      "Web content process did terminate");
                                                setState(() {
                                                  wvIsLoading = false;
                                                });
                                                await getIawvUserAgent();
                                                pullToRefreshController
                                                    ?.endRefreshing();
                                                setState(() {});
                                                if (_currentLifecycleState ==
                                                    AppLifecycleState
                                                        .detached) {
                                                  SystemNavigator.pop();
                                                } else if (_currentLifecycleState ==
                                                    AppLifecycleState.paused) {
                                                  SystemNavigator.pop();
                                                } else if (_currentLifecycleState ==
                                                    AppLifecycleState.hidden) {
                                                  if ((DateTime.now()
                                                              .millisecondsSinceEpoch -
                                                          _lastLifecycleChangeTime) >
                                                      5 * 60 * 1000) {
                                                    SystemNavigator.pop();
                                                  } else {
                                                    needReloadOnResume = true;
                                                  }
                                                } else if (_currentLifecycleState ==
                                                    AppLifecycleState
                                                        .inactive) {
                                                  if ((DateTime.now()
                                                              .millisecondsSinceEpoch -
                                                          _lastLifecycleChangeTime) >
                                                      20 * 60 * 1000) {
                                                    SystemNavigator.pop();
                                                  } else {
                                                    needReloadOnResume = true;
                                                  }
                                                } else {
                                                  setState(() {
                                                    foregroundTerminationCount++;
                                                  });
                                                  if (kDebugMode) {
                                                    var info = WebviewErrorInfo(
                                                        type:
                                                            "WebContentProcessDidTerminate",
                                                        message:
                                                            "The web content process was terminated by the system.",
                                                        code: -44,
                                                        description:
                                                            "onWebContentProcessDidTerminate");

                                                    setState(() {
                                                      onMainWebviewLoadError =
                                                          info;
                                                    });
                                                  } else {
                                                    if (isInit) {
                                                      while (!mounted) {
                                                        await Future.delayed(
                                                            const Duration(
                                                                milliseconds:
                                                                    100));
                                                      }
                                                      await controller.reload();
                                                    } else {
                                                      await controller.reload();
                                                    }
                                                  }
                                                }
                                              },
                                              onPermissionRequest:
                                                  (controller, request) async {
                                                return PermissionResponse(
                                                    resources:
                                                        request.resources,
                                                    action:
                                                        PermissionResponseAction
                                                            .GRANT);
                                              },
                                              onTitleChanged:
                                                  (controller, title) {
                                                if (isInitialized) {
                                                  onTitleLoaded(title,
                                                      iawvController:
                                                          controller);
                                                }
                                              },
                                              onConsoleMessage:
                                                  (controller, consoleMessage) {
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
                                              onCreateWindow: (controller,
                                                  createWindowAction) {
                                                final uri = createWindowAction
                                                    .request.url;
                                                // if (uri != null) {
                                                openPopupBrowser(
                                                    uri?.rawValue ??
                                                        uri?.toString() ??
                                                        "",
                                                    createWindowAction:
                                                        createWindowAction,
                                                    referrerController:
                                                        controller);
                                                return true;
                                                // }
                                                // return false;
                                              },
                                              onCloseWindow: (controller) {
                                                final navigator =
                                                    Navigator.of(context);
                                                if (navigator.canPop())
                                                  navigator.pop();
                                              },
                                            ),
                                      if (isIOS26)
                                        Positioned.fill(
                                            child: PointerInterceptor(
                                          intercepting:
                                              !_isTopOfNavigationStack,
                                          debug: kDebugMode,
                                          child: const SizedBox.expand(),
                                        ))
                                    ])),
                                  ])))),
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
                                            height: 100),
                                        // SvgPicture.asset("assets/images/EstreUI-bolder.svg", height: 100),
                                      ]))),
                        )
                      : onMainWebviewLoadError != null
                          ? Container(
                              color: Theme.of(context).canvasColor,
                              child: SizedBox(
                                  width: MediaQuery.of(context).size.width,
                                  height: MediaQuery.of(context).size.height,
                                  child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error,
                                            size: 150,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error),
                                        const SizedBox(height: 20),
                                        Text(
                                          "Failed to load the page.\n\nPlease check your internet connection or try again later.",
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge,
                                          textAlign: TextAlign.center,
                                        ),
                                        Text(
                                          "${onMainWebviewLoadError?.code}  ${onMainWebviewLoadError?.type}",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary),
                                        ),
                                        const SizedBox(height: 20),
                                        ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 10),
                                              textStyle: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black),
                                            ),
                                            onPressed: () {
                                              if (currentUrl == "" ||
                                                  currentUrl == BLANK) {
                                                loadInitialUri();
                                              } else if (isIAWV) {
                                                iawvController?.reload();
                                              } else {
                                                controller?.reload();
                                              }
                                            },
                                            child: const Text("Retry")),
                                      ])))
                          : SizedBox(width: double.infinity, height: 0),
                  SizedBox(
                      width: double.infinity,
                      height: MediaQuery.of(context).padding.top,
                      child: AnimatedOpacity(
                          curve: Curves.ease,
                          opacity:
                              loadingProgressBarOpacity, //loadingPercentage == 0 || loadingPercentage == 100 ? 0.0 : 1.0,//
                          duration: loadingProgressFadeDuration,
                          child: LinearProgressIndicator(
                            value: loadingPercentage / 100.0,
                            color: Theme.of(context).colorScheme.primary,
                          ))),
                ]))));
  }

  @override
  void activate() {
    super.activate();
    if (kDebugMode) print("WidgetsBindingObserver - activate");
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    releaseFixedOrientationPortrait();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Platform.isIOS) {
        Future.delayed(const Duration(milliseconds: 400), () {
          updateSafeAreaInsets(
              controller: controller, iawvController: iawvController);
        });
      } else {
        updateSafeAreaInsets(
            controller: controller, iawvController: iawvController);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        if (needReloadOnResume) {
          restartApp();
        }
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
    _minuteCheckTimer?.cancel();
    _listener.dispose();
    WidgetsBinding.instance.removeObserver(this);
    connectivity.cancel();

    super.dispose();
  }

  // App works interoperation
  void clearNavigationStack() {
    Navigator.of(context, rootNavigator: true)
        .popUntil((route) => route.isFirst);
  }

  void restartApp() {
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => EstreUiNativeExtensionApp()),
        (route) => false);
  }

  void onBackPressed(didPop, result) async {
    if (didPop) {
      return;
    }

    // final navigator = Navigator.of(context);

    // if (isFormalWebPages) {
    //   if (isIAWV) {
    //     if (await iawvController!.canGoBack()) {
    //       await iawvController!.goBack();
    //       return;
    //     }
    //   } else {
    //     if (await controller!.canGoBack()) {
    //       await controller!.goBack();
    //       return;
    //     }
    //   }
    //   var now = DateTime.now().millisecondsSinceEpoch;
    //   if (exitRequested < now - 2000) {
    //     exitRequested = now;
    //     Fluttertoast.showToast(msg: "To be finished this app by back navigation again");
    //   } else {
    //     SystemNavigator.pop();
    //   }
    // } else {
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
    // }
  }

  void insertAdapterCodes(
      {FSWV.WebViewController? controller,
      InAppWebViewController? iawvController}) {
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
        resuestSeq: 0,
        requests: [],
        
        getRequestSeq() {
          return ++this.resuestSeq;
        },
        
        issueRequestId(handlerName) {
          return handlerName + "#" + this.getRequestSeq() + "@" + Date.now() + "\$" + this.requests.length;
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
    if (kDebugMode) print(postCodes);

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
    "restart": (args, {isMainFrame, origin, from}) async {
      restartApp();
      return;
    },
    "clearNavigationStack": (args, {isMainFrame, origin, from}) async {
      clearNavigationStack();
      return;
    },

    "setFixedOrientationPortrait": (args, {isMainFrame, origin, from}) async {
      final bool? isFixed = args.isNotEmpty ? args[0] : null;
      setFixedOrientationPortrait(isFixed);
      return isFixedPortrait;
    },

    "onLoadedEstreUi": (args, {isMainFrame, origin, from}) async {
      setState(() {
        isLoadedEstreUi = true;
      });
      return isLoadedEstreUi;
    },
    "onReadyEstreUiApp": (args, {isMainFrame, origin, from}) async {
      setState(() {
        isReadyEstreUiApp = true;
      });
      return isReadyEstreUiApp;
    },

    "openAppSettings": (args, {isMainFrame, origin, from}) async {
      return await AppSettings.openAppSettings(type: AppSettingsType.settings);
    },

    "openSettingsPowerSavingExceptions": (args,
        {isMainFrame, origin, from}) async {
      if (Platform.isAndroid) {
        return await methodChannel
            .invokeMethod("openPowerSavingExceptionSettings");
        // } else if (Platform.isIOS) {
        //   return await launchUrlString("App-Prefs:");
      }
      return null;
    },

    "getAndroidBatteryOptimizationDisabled": (args,
        {isMainFrame, origin, from}) async {
      return _isAboDisabled;
    },
    "requestDisableAndroidBatteryOptimization": (args,
        {isMainFrame, origin, from}) async {
      if (Platform.isAndroid) {
        final result = await DisableBatteryOptimization
            .showDisableBatteryOptimizationSettings();
        releaseAndroidAppBatteryOptimizationDisabled();
        return result;
      }
      return null;
    },

    "getManufacturerBatteryOptimizationDisabled": (args,
        {isMainFrame, origin, from}) async {
      return _isAboManufacturerDisabled;
    },
    "requestDisableManufacturerBatteryOptimization": (args,
        {isMainFrame, origin, from}) async {
      if (Platform.isAndroid) {
        final result = await DisableBatteryOptimization
            .showDisableManufacturerBatteryOptimizationSettings(
                "Your device has additional battery optimization",
                "Follow the steps and disable the optimizations to allow smooth functioning of this app"); //"Your device has additional battery optimization", "Follow the steps and disable the optimizations to allow smooth functioning of this app");
        releaseAndroidAppBatteryOptimizationDisabled();
        return result;
      }
      return null;
    },

    "getAppAutoStartEnabled": (args, {isMainFrame, origin, from}) async {
      return _isAppAutoStartEnabled;
    },
    "requestEnableAppAutoStart": (args, {isMainFrame, origin, from}) async {
      if (Platform.isAndroid) {
        final result = await DisableBatteryOptimization.showEnableAutoStartSettings(
            "Activate Auto Start for the app",
            "Please follow the instructions to enable auto start for this app"); //"Enable Auto Start", "Follow the steps and enable the auto start of this app");
        releaseAndroidAppBatteryOptimizationDisabled();
        return result;
      }
      return null;
    },

    "openStoreForUpdate": (args, {isMainFrame, origin, from}) async {
      var url;
      if (Platform.isAndroid) {
        url =
            "https://play.google.com/store/apps/details?id={your.package.name}&hl={your_language_code}";
      } else if (Platform.isIOS) {
        url =
            "https://apps.apple.com/es/app/id{your_app_id}?l={your_language_code}";
      }
      return url != null
          ? await launchUrlString(url, mode: LaunchMode.externalApplication)
          : url;
    },

    "getOssid": (args, {isMainFrame, origin, from}) async {
      return OneSignal.User.pushSubscription.id;
    },
    "getOssidWhenAllowed": (args, {isMainFrame, origin, from}) async {
      return OneSignal.Notifications.permission
          ? OneSignal.User.pushSubscription.id
          : null;
    },
    "getPushToken": (args, {isMainFrame, origin, from}) async {
      return OneSignal.User.pushSubscription.token;
    },
    "getNotificationPermissionStatus": (args,
        {isMainFrame, origin, from}) async {
      return OneSignal.Notifications.permission;
    },
    "requestPermissionForNotification": (args,
        {isMainFrame, origin, from}) async {
      return await OneSignal.Notifications.requestPermission(
          (args.isNotEmpty ? args[0] : null) ?? false);
    },
    "isNotYetPromptedForNotification": (args,
        {isMainFrame, origin, from}) async {
      return await OneSignal.Notifications.canRequest();
    },
    "displayNotification": (args, {isMainFrame, origin, from}) async {
      final String? notificationId = args.isNotEmpty ? args[0] : null;
      if (notificationId != null)
        return OneSignal.Notifications.displayNotification(notificationId);
      return;
    },
    "removeNotification": (args, {isMainFrame, origin, from}) async {
      final int? notificationId = args.isNotEmpty ? args[0] : null;
      if (notificationId != null)
        return await OneSignal.Notifications.removeNotification(notificationId);
      return;
    },
    "clearEveryNotifications": (args, {isMainFrame, origin, from}) async {
      return await OneSignal.Notifications.clearAll();
    },

    "setLoginOss": (args, {isMainFrame, origin, from}) async {
      final String? externalId = args.isNotEmpty ? args[0] : null;
      if (externalId != null) return await OneSignal.login(externalId);
      return;
    },
    "getLoginIdOss": (args, {isMainFrame, origin, from}) async {
      return await OneSignal.User.getExternalId();
    },
    "setLogoutOss": (args, {isMainFrame, origin, from}) async {
      return await OneSignal.logout();
    },

    "setAliasOss": (args, {isMainFrame, origin, from}) async {
      final String? aliasName = args.isNotEmpty ? args[0] : null;
      if (aliasName != null) {
        final String? aliasValue = args.length > 1 ? args[1] : null;
        if (aliasValue != null) {
          return await OneSignal.User.addAlias(aliasName, aliasValue);
        }
      }
      return;
    },
    "setAliasesOss": (args, {isMainFrame, origin, from}) async {
      final aliases = args.isNotEmpty ? args[0] : null;
      if (aliases != null) return await OneSignal.User.addAliases(aliases);
      return;
    },
    "removeAliasOss": (args, {isMainFrame, origin, from}) async {
      final String? aliasName = args.isNotEmpty ? args[0] : null;
      if (aliasName != null) return await OneSignal.User.removeAlias(aliasName);
      return;
    },
    "removeAliasesOss": (args, {isMainFrame, origin, from}) async {
      final aliasNames = args.isNotEmpty ? args[0] : null;
      if (aliasNames != null)
        return await OneSignal.User.removeAliases(aliasNames);
      return;
    },

    "getOssOptedIn": (args, {isMainFrame, origin, from}) async {
      return OneSignal.User.pushSubscription.optedIn;
    },
    "setOssOptState": (args, {isMainFrame, origin, from}) async {
      final bool? state = args.isNotEmpty ? args[0] : null;
      if (state != null) {
        if (state)
          return await OneSignal.User.pushSubscription.optIn();
        else
          return await OneSignal.User.pushSubscription.optOut();
      }
      return;
    },

    "addTag": (args, {isMainFrame, origin, from}) async {
      final String? key = args.isNotEmpty ? args[0] : null;
      final String? value = args.length > 1 ? args[1] : null;
      if (key != null && value != null)
        return await OneSignal.User.addTagWithKey(key, value);
      return;
    },
    "addTags": (args, {isMainFrame, origin, from}) async {
      final tags = args.isNotEmpty ? args[0] : null;
      if (tags != null) return await OneSignal.User.addTags(tags);
      return;
    },
    "removeTag": (args, {isMainFrame, origin, from}) async {
      final String? key = args.isNotEmpty ? args[0] : null;
      if (key != null) return await OneSignal.User.removeTag(key);
      return;
    },
    "removeTags": (args, {isMainFrame, origin, from}) async {
      final tagNames = args.isNotEmpty ? args[0] : null;
      if (tagNames != null) return await OneSignal.User.removeTags(tagNames);
      return;
    },
    "getTags": (args, {isMainFrame, origin, from}) async {
      return await OneSignal.User.getTags();
    },

    "addNotificationItemUserTriggeredListener": (args,
        {isMainFrame, origin, from}) async {
      final String? callbackMethodString = args.isNotEmpty ? args[0] : null;

      if (callbackMethodString != null) {
        notiTriggeredByUserCallback = callbackMethodString;
        postNotiTriggeredByUser();
        return true;
      } else {
        return false;
      }
    },
    "addNotificationReceivedListenerWhenAppIsForeground": (args,
        {isMainFrame, origin, from}) async {
      final String? callbackMethodString = args.isNotEmpty ? args[0] : null;

      if (callbackMethodString != null) {
        notiReceivedForegroundCallback = callbackMethodString;
        postNotiReceivedForeground();
        return true;
      } else {
        return false;
      }
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
      if (args.isEmpty) return null;
      final String key = args[0];
      if (key.isNotEmpty) {
        String? def;
        if (args.length > 1) def = args[1];
        return sp.getString(key)?.replaceAll('"', '\\"') ?? def;
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
      final String? url = args.isNotEmpty ? args[0] : null;
      if (url != null && url.isNotEmpty) {
        final String initialTitle = args.length > 1 ? args[1] : "";
        final String? fixedTitle = args.length > 2 ? args[2] : null;
        final bool useSimpleFixedTitleBar =
            args.length > 3 && args[3] == false ? true : false;
        final bool hideToolbar =
            args.length > 3 && args[3] == true ? true : false;
        if (kDebugMode) print("Popup browser requested: $url");
        await openPopupBrowser(url,
            referrer: from,
            referrerOrigin: origin,
            referrerController: isIAWV ? iawvController : null,
            initialTitle: initialTitle,
            fixedTitle: fixedTitle,
            useSimpleFixedTitleBar: useSimpleFixedTitleBar,
            hideToolbar: hideToolbar);
        if (kDebugMode) print("Popup browser request has closed: $url");
        return true;
      } else {
        return false;
      }
    },

    "inAppBrowser": (args, {isMainFrame, origin, from}) async {
      final String? url = args.isNotEmpty ? args[0] : null;
      if (url != null && url.isNotEmpty) {
        if (kDebugMode) print("Open in app browser: $url");
        return await launchUrlString(url);
      }
      return null;
    },

    "externalBrowser": (args, {isMainFrame, origin, from}) async {
      final String? url = args.isNotEmpty ? args[0] : null;
      if (url != null && url.isNotEmpty) {
        if (kDebugMode) print("Open external browser: $url");
        return await launchUrlString(url, mode: LaunchMode.externalApplication);
      }
      return null;
    },

    "share": (args, {isMainFrame, origin, from}) async {
      final String? content = args.isNotEmpty ? args[0] : null;
      final String? title = args.length > 1 ? args[1] : null;
      final String? subject = args.length > 2 ? args[2] : null;
      if (content != null && content.isNotEmpty) {
        final mediaQuery = MediaQuery.of(context);
        final size = mediaQuery.size;
        final height = 40.0;
        return await SharePlus.instance.share(ShareParams(
          text: content,
          title: title,
          subject: subject,
          sharePositionOrigin:
              Rect.fromLTWH(0, size.height - height, size.width, height),
        ));
      }
      return null;
    },

    // vv For add new javascript handler
    // "": (args, { isMainFrame, origin, from }) async {
    //
    // },
  };

  void postNotiTriggeredByUser() {
    if (notiTriggeredByUser != null && notiTriggeredByUserCallback != null) {
      final json = jsonEscapedMS(notiTriggeredByUser);
      notiTriggeredByUser = null;
      executeJavascript("$notiTriggeredByUserCallback(`$json`)");
    }
  }

  Future<bool> postNotiReceivedForeground() async {
    if (notiReceivedForeground != null &&
        notiReceivedForegroundCallback != null) {
      final json = jsonEscapedMS(notiReceivedForeground);
      notiReceivedForeground = null;
      return await executeJavascript(
          "$notiReceivedForegroundCallback(`$json`)");
    } else
      return true;
  }

  // WebView initializing
  Future<String?> getIawvUserAgent() async {
    if (isIAWV) {
      var settings = await iawvController?.getSettings();
      String? ua = settings?.userAgent;
      if (kDebugMode) print("Current UA: $ua");
      String? defaultUa = await InAppWebViewController.getDefaultUserAgent();
      if (kDebugMode) print("Default UA: $defaultUa");
      return ua ?? defaultUa;
    }
    return null;
  }

  Future<void> setIawvUA(
      {InAppWebViewController? popupController,
      InAppWebViewSettings? popupSettings}) async {
    final isPopupBrowser = popupController != null;
    if ((isPopupBrowser && popupSettings != null) || isIAWV) {
      var isComplete = false;
      try {
        if (isPopupBrowser || iawvController != null) {
          final controller = isPopupBrowser ? popupController : iawvController!;
          final fallbackSettings = isPopupBrowser ? popupSettings! : settings;
          final newSettings =
              (await controller.getSettings()) ?? fallbackSettings;

          if (!Platform.isAndroid && appInfoForUA.isNotEmpty) {
            // Android is Crash by this block
            if (newSettings.applicationNameForUserAgent != appInfoForUA) {
              newSettings.applicationNameForUserAgent = appInfoForUA;
              await controller.setSettings(settings: newSettings);
            } else if (newSettings == fallbackSettings) {
              await controller.setSettings(settings: newSettings);
            }
          }

          var current = newSettings.userAgent ?? "";
          if (current.isEmpty) current = settings.userAgent ?? "";
          try {
            if (current.isEmpty)
              current =
                  (await executeJavascript("navigator.userAgent")) as String? ??
                      "";
          } on Exception catch (e) {
            // do nothing
          }
          if (current.isEmpty) current = await getDefaultUserAgent();

          if (uaSuffix.isNotEmpty && current.isNotEmpty) {
            if (kDebugMode) print("Current UA: $current");
            final isMobileAndIPhone = current.contains(" Mobile") && isIPhone;
            final isAppliedCustomUA = current.contains(uaSuffix);
            if (isMobileAndIPhone) {
              current = current.replaceAll(" Mobile",
                  ""); //.replaceFirst(RegExp(r"Mozilla/5.0 \(iPhone; .*/15E148"), "");
              if (current.contains("iPhone OS 18_6")) {
                final version =
                    iosDeviceInfo?.systemVersion.replaceAll('.', '_');
                if (version != null)
                  current = current.replaceFirst(
                      "iPhone OS 18_6", "iPhone OS $version");
              }
              if (kDebugMode) print("Removed Mobile from current UA: $current");
              isAppliedUserAgentForIPhone = true;
            }
            if (isAppliedCustomUA && !isMobileAndIPhone) {
              isComplete = true;
            } else {
              final ua = current + (isAppliedCustomUA ? "" : uaSuffix);
              newSettings.userAgent = ua;
              await controller.setSettings(settings: newSettings);
              isComplete = true;
              if (kDebugMode) print("UA updated: ${newSettings.userAgent}");
            }
          }
        }
      } on Exception catch (e) {
        if (kDebugMode) print("Exception on set UserAgent for IAWV: $e");
        // do nothing
      } on Error catch (e) {
        if (kDebugMode) print("Error on set UserAgent for IAWV: $e");
        // do nothing
      }
      if (!isComplete) {
        if (kDebugMode) print("Waiting retry for UserAgent for IAWV");
        Future.delayed(Duration(milliseconds: 1), () {
          if (kDebugMode) print("Begin retry for UserAgent for IAWV");
          setIawvUA(
              popupController: popupController, popupSettings: popupSettings);
        });
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
  Future<void> processAppLinkReceived(Uri uri, {String? rawUrl}) async {
    if (!await processNavigationRequest(uri, true, rawUrl: rawUrl)) {
      if (uri.host.endsWith(SERVICE_HOST)) {
        clearNavigationStack();
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
      {FSWV.WebViewController? controller,
      InAppWebViewController? iawvController}) {
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
      {FSWV.WebViewController? controller,
      InAppWebViewController? iawvController}) {
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
      {FSWV.WebViewController? controller,
      InAppWebViewController? iawvController}) {
    if (title != null && title.isNotEmpty && !Platform.isAndroid) {
      // Insert adapter codes
      insertAdapterCodes(
          controller: controller, iawvController: iawvController);

      // Provide screen area info
      updateSafeAreaInsets(
          controller: controller, iawvController: iawvController);
    }
  }

  void completePage(String url,
      {FSWV.WebViewController? controller,
      InAppWebViewController? iawvController}) {
    setState(() {
      loadingPercentage = 100;
      onLoadMainWebview = false;

      if (loadingProgressBarOpacity > 0.0) loadingProgressBarOpacity = 0.0;
      // if (isInit) splashOpacity = 0.0;
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
                  if (isIAWV) {
                    this.iawvController?.requestFocus();
                  }

                  if (initialUriReceived && !initialUriProcessed) {
                    initialUriProcessed = true;
                    if (initialUri != null) processAppLinkReceived(initialUri!);
                  }

                  if (useAutoReloaderForTest && kDebugMode) {
                    _minuteCheckTimer =
                        Timer.periodic(Duration(minutes: 1), (timer) {
                      final now = DateTime.now();
                      final onesDigit = now.minute %
                          10; // Get the ones digit of the current minute

                      if (onesDigit == 3 || onesDigit == 8) {
                        // Perform desired task
                        if (isIAWV) {
                          iawvController?.reload();
                        } else {
                          controller?.reload();
                        }
                      }
                    });
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

  Timer? _minuteCheckTimer;

  // WebView actions support
  Future<bool> processNavigationRequest(Uri uri, bool isMainFrame,
      {bool isPopupBrowser = false,
      NavigationAction? navigationAction,
      String? referrerUrl,
      String? rawUrl}) async {
    final uriString = rawUrl ?? uri.toString();
    if (kDebugMode)
      print(
          "Process navigation request - url: $uri, isMainFrame: $isMainFrame");
    final scheme = uri.scheme;
    final host = uri.host;

    if (!isInitialized && uriString == BLANK) {
      return false;
    }
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
      if (await canLaunchUrlString(uriString) &&
          await launchUrlString(uriString)) {
        // Launch the App
        // and cancel the request
        return true;
      } else if (await launchUrlString(uriString)) {
        // Fallback mode launch
        return true;
      } else if (await launchUri(uriString)) {
        return true;
      }
    }

    if (scheme == "http") {
      // if (kDebugMode) print("Not secured http request fallback to external browser: $uriString");
      // await launchUrlString(uriString, mode: LaunchMode.externalApplication);
      if (kDebugMode)
        print(
            "Not secured http request fallback to in app webview: $uriString");
      await launchUrlString(uriString);
      if (referrerUrl == "" || referrerUrl == "about:blank") {
        if (isPopupBrowser) {
          Navigator.of(context).pop();
        } else if (!isMainFrame) {
          await closePopupBrowserWhenOnTop();
        }
      }
      return true;
    } else if (isPopupBrowser) {
      if (kDebugMode)
        print(
            "processNavigationRequest - request in popup browser: $uriString, referrer: $referrerUrl");
      // do nothing = allow navigate
    } else if (isMainFrame) {
      if (host.endsWith(SERVICE_HOST)) {
        // do nothing = allow navigate
      } else {
        // prevent navigate for PWA service
        // vv *or open popup browser
        // openPopupBrowser(rawUrl ?? uri.toString(), navigationAction: navigationAction, referrerController: isIAWV ? iawvController : null);
        return true;
      }
    }

    if (kDebugMode) print("Allow navigate: $uriString");
    return false;
  }

  Future<bool> launchUri(String uri) async {
    String finalUrl = uri;
    if (Platform.isAndroid) {
      // if (uri.contains("package=kvp.jjy.MispAndroid320")) {
      //   return _callAppByIntentUrl(uri);
      // }

      // Android는 Native(Kotlin)로 URL을 전달해 Intent 처리 후 리턴
      try {
        await _convertIntentToAppUrl(finalUrl).then((value) async {
          finalUrl = value; // 앱이 설치되었을 경우
        });
        if (kDebugMode) print("Launching app url: $finalUrl");
        return await launchUrlString(finalUrl);
      } catch (e) {
        // URL 실행 불가 시, 앱 미설치로 판단하여 마켓 URL 실행
        finalUrl = await _convertIntentToMarketUrl(uri);
        return await launchUrlString(finalUrl);
      }
    } else if (Platform.isIOS) {
      return await launchUrlString(finalUrl);
    }
    return false;
  }

  Future<Map<String, dynamic>?> _getInstallReferrerUrl() async {
    try {
      final result = await methodChannel.invokeMethod('getInstallReferrer');
      if (result != null && result is Map) {
        // Map<Object?, Object?>를 Map<String, dynamic>으로 안전하게 변환
        return Map<String, dynamic>.from(result);
      }

      return null;
    } on PlatformException catch (e) {
      if (kDebugMode) print("Install Referrer Error: ${e.message}");
      return null;
    } catch (e) {
      print("Unexpected Error: $e");
      return null;
    }
  }

  Future<bool> _callAppByIntentUrl(String url) async {
    final result = await methodChannel
        .invokeMethod('callAppByIntentUrl', <String, Object>{'url': url});
    if (result != null && result is bool) {
      return result;
    }
    return false;
  }

  Future<String> _convertIntentToAppUrl(String text) async {
    return await methodChannel
        .invokeMethod('getAppUrl', <String, Object>{'url': text});
  }

  Future<String> _convertIntentToMarketUrl(String text) async {
    return await methodChannel
        .invokeMethod('getMarketUrl', <String, Object>{'url': text});
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
    try {
      if (isIAWV) {
        return await iawvController?.evaluateJavascript(source: codes);
      } else {
        return await controller?.runJavaScriptReturningResult(codes);
      }
    } catch (e) {
      if (kDebugMode) print("Error on executeJavascript: $e");
      return null;
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

  Future<void> releaseCacheMode(bool isInternetAvailable) async {
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

  Future<bool> checkAliveWebview({bool autoRestart = true}) async {
    bool isAlive = false;
    try {
      isAlive = (await executeJavascript("true")) == true;
    } catch (e) {
      // do nothing
    }

    if (!isAlive && autoRestart) {
      if (kDebugMode) print("WebView not alive, restart it");
      restartApp();
    }

    return isAlive;
  }

  bool get _isTopOfNavigationStack =>
      ModalRoute.of(context)?.isCurrent ?? false;

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
      {FSWV.WebViewController? controller,
      InAppWebViewController? iawvController}) {
    final mediaQuery = MediaQuery.of(context);
    final padding = mediaQuery.padding;

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

  checkInternetAvailable({String target = "google.com"}) async {
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
    if (isInitialized) {
      try {
        executeJavascript(
            'window.app.isOnline = $isOk; window.dispatchEvent(new Event("${isOk ? "online" : "offline"}"))');
        releaseCacheMode(isOk);
      } catch (e) {
        if (kDebugMode) print("Error on executeJavascript: $e");
      }
    }
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

  Future<String> getDefaultUserAgent() async {
    final defaultUA = await InAppWebViewController.getDefaultUserAgent();
    return defaultUA;
  }

  // for common utility
  String jsonEscaped(dynamic data) {
    return jsonEncode(data).replaceAll(r'`', r'\`').replaceAll(r'\', r'\\');
  }

  String jsonEscapedMS(dynamic data) {
    return jsonEncode(data)
        .trim()
        .replaceAll("\r\n", "\n")
        .replaceAll("\r", "\n")
        .replaceAll("\n", "\n")
        .replaceAll(r'`', r'\`')
        .replaceAll(r'\', r'\\');
  }

  // for application
  Future<void> releaseAndroidAppBatteryOptimizationDisabled(
      {bool isInit = false}) async {
    if (Platform.isAndroid) {
      if (isInit) {
        _isAppAutoStartEnabled =
            await DisableBatteryOptimization.isAutoStartEnabled;

        _isAboDisabled =
            await DisableBatteryOptimization.isBatteryOptimizationDisabled;
        _isAboManufacturerDisabled = await DisableBatteryOptimization
            .isManufacturerBatteryOptimizationDisabled;
      } else {
        bool? isAutoStartEnabled =
            await DisableBatteryOptimization.isAutoStartEnabled;
        bool? isBatteryOptimizationDisabled =
            await DisableBatteryOptimization.isBatteryOptimizationDisabled;
        bool? isManufacturerBatteryOptimizationDisabled =
            await DisableBatteryOptimization
                .isManufacturerBatteryOptimizationDisabled;
        setState(() {
          _isAppAutoStartEnabled = isAutoStartEnabled;

          _isAboDisabled = isBatteryOptimizationDisabled;
          _isAboManufacturerDisabled =
              isManufacturerBatteryOptimizationDisabled;
        });
      }
    }
  }

  bool _onShiftMultiWindowMode(bool isInMultiWindowMode,
      {bool isInit = false}) {
    final isOnShift = _isInMultiWindowMode != isInMultiWindowMode;

    if (kDebugMode)
      print(
          "MultiWindow mode check: isInMultiWindowMode=$isInMultiWindowMode, previous=$_isInMultiWindowMode, isOnShift=$isOnShift");

    if (isOnShift) {
      setState(() {
        _isInMultiWindowMode = isInMultiWindowMode;
        // if (!isInit) restartApp();
      });
    }

    return isOnShift;
  }

  void setFixedOrientationPortrait(bool? isFixed) {
    sp.setString("isFixedPortrait",
        isFixed == null ? "auto" : (isFixed ? "true" : "false"));
    setState(() {
      isFixedPortrait = isFixed;
      releaseFixedOrientationPortrait();
    });
  }

  Future<void> releaseFixedOrientationPortrait() async {
    bool setToFixed = false;
    final isAuto = isFixedPortrait == null;
    if (isAuto) {
      final mediaQuery = MediaQuery.of(context);
      final size = mediaQuery.size;
      final longSide = max(size.width, size.height);
      final shortSide = min(size.width, size.height);
      final screenRatio = longSide / shortSide;
      final isLong = screenRatio > (16 / 9);
      if (isLong) setToFixed = true;
    } else if (isFixedPortrait == true) {
      setToFixed = true;
    }

    if (setToFixed != isSetFixedPortrait) {
      if (kDebugMode) print("Set fixed orientation to portrait: $setToFixed");
      setState(() {
        isSetFixedPortrait = setToFixed;
      });
      final orientations = <DeviceOrientation>[];
      if (setToFixed) {
        orientations.addAll(
            [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      } else {
        orientations.addAll(DeviceOrientation.values);
      }
      await SystemChrome.setPreferredOrientations(orientations);
    }
  }

  // Popup webview for external service
  // Use instead Estre UI's popup browser when that page required cookie.
  Future<void> openPopupBrowser(
    String requestedUrl, {
    CreateWindowAction? createWindowAction,
    NavigationAction? navigationAction,
    Uri? referrer,
    Uri? referrerOrigin,
    InAppWebViewController? referrerController,
    String initialTitle = "",
    String? fixedTitle,
    bool useSimpleFixedTitleBar = false,
    bool hideToolbar = false,
  }) async {
    if (referrerController != null) {
      referrer ??= await referrerController.getUrl();
      referrerOrigin ??= await referrerController.getOriginalUrl();
    }
    Uri requestedUri = Uri.parse(requestedUrl);
    bool isEmptyCall = requestedUrl == "" || requestedUrl == "about:blank";
    bool isInitialized = !isEmptyCall;
    bool isOwnService = requestedUri.host.endsWith(SERVICE_SUFFIX);

    if (kDebugMode) print("openPopupBrowser - url: $requestedUrl");

    final mainWvSettings = await iawvController?.getSettings();
    String? userAgent;
    try {
      userAgent = (await executeJavascript("navigator.userAgent")) as String?;
    } on Exception catch (e) {
      // do nothing
    }
    if (userAgent == null || userAgent.isEmpty)
      userAgent = mainWvSettings?.userAgent;

    late final InAppWebViewController iawvCon;
    InAppWebViewSettings initialSettings = InAppWebViewSettings(
      isInspectable: kDebugMode,
      applicationNameForUserAgent: appInfoForUA,
      javaScriptEnabled: true,
      javaScriptCanOpenWindowsAutomatically: true,
      supportMultipleWindows: true,
      sharedCookiesEnabled: createWindowAction != null,
      thirdPartyCookiesEnabled: isOwnService,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      textZoom: 100, // Fix text zoom to 100% to ignore system font size setting
      // iframeAllow: "camera; microphone",
      iframeAllowFullscreen: true,
      cacheMode:
          isOwnService ? CacheMode.LOAD_DEFAULT : CacheMode.LOAD_NO_CACHE,

      // Settings to allow cross-origin window access
      limitsNavigationsToAppBoundDomains: true,
      allowUniversalAccessFromFileURLs: true,
      allowFileAccessFromFileURLs: true,
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

    String currentUrl = "";
    String titleText = initialTitle;
    bool onLoading = false;
    bool canGoBack = false;
    bool canGoForward = false;
    bool isShowingMenu = false;
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
                        child: Padding(
                            padding: MediaQuery.of(context).viewInsets,
                            child: Stack(children: [
                              SafeArea(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      hideToolbar
                                          ? Container()
                                          : SizedBox(
                                              height: controlBarHeight,
                                              child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children:
                                                      useSimpleFixedTitleBar
                                                          ? [
                                                              Container(
                                                                  width: Platform
                                                                          .isAndroid
                                                                      ? 10
                                                                      : 5),
                                                              IconButton(
                                                                  iconSize:
                                                                      iconSize,
                                                                  icon: Icon(Icons
                                                                      .arrow_back_ios),
                                                                  enableFeedback:
                                                                      canGoBack,
                                                                  onPressed:
                                                                      canGoBack
                                                                          ? () {
                                                                              iawvCon.goBack();
                                                                            }
                                                                          : null),
                                                              Expanded(
                                                                  child: Container(
                                                                      padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                                                                      child: DefaultTextStyle(
                                                                          style: TextStyle(color: Color(0xff222222), fontSize: 18, height: 1.2),
                                                                          child: Column(
                                                                            mainAxisAlignment:
                                                                                MainAxisAlignment.center,
                                                                            crossAxisAlignment:
                                                                                CrossAxisAlignment.center,
                                                                            children: [
                                                                              AutoSizeText(
                                                                                fixedTitle ?? "",
                                                                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                                                                                maxLines: 1,
                                                                                minFontSize: 12,
                                                                                overflow: TextOverflow.ellipsis,
                                                                              ),
                                                                            ],
                                                                          )))),
                                                              IconButton(
                                                                  iconSize:
                                                                      iconSize,
                                                                  icon: Icon(Icons
                                                                      .close),
                                                                  onPressed:
                                                                      () {
                                                                    Navigator.of(
                                                                            context)
                                                                        .pop();
                                                                  }),
                                                              Container(
                                                                  width: Platform
                                                                          .isAndroid
                                                                      ? 5
                                                                      : 0),
                                                            ]
                                                          : [
                                                              Container(
                                                                  width: Platform
                                                                          .isAndroid
                                                                      ? 10
                                                                      : 5),
                                                              // IconButton(iconSize: iconSize, icon: Icon(Icons.arrow_back_ios), enableFeedback: canGoBack, onPressed: canGoBack ? () { iawvCon.goBack(); } : null),
                                                              // IconButton(iconSize: iconSize, icon: Icon(Icons.arrow_forward_ios), enableFeedback: canGoForward, onPressed: canGoForward ? () { iawvCon.goForward(); }: null),
                                                              // IconButton(iconSize: iconSize, icon: Icon(Icons.home_outlined), onPressed: () { iawvCon.loadUrl(urlRequest: URLRequest(url: WebUri(requestedUrl))); }),
                                                              Expanded(
                                                                  child: Container(
                                                                      padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                                                                      child: DefaultTextStyle(
                                                                          style: TextStyle(color: Color(0xff222222), fontSize: 18, height: 1.2),
                                                                          child: Column(
                                                                            mainAxisAlignment:
                                                                                MainAxisAlignment.center,
                                                                            crossAxisAlignment:
                                                                                CrossAxisAlignment.start,
                                                                            children: [
                                                                              AutoSizeText(
                                                                                fixedTitle ?? titleText.replaceAll(RegExp(r"[\r\n]"), " "),
                                                                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                                                                                maxLines: 2,
                                                                                minFontSize: 12,
                                                                                overflow: TextOverflow.ellipsis,
                                                                              ),
                                                                            ],
                                                                          )))),
                                                              // IconButton(iconSize: iconSize, icon: Icon(onLoading ? Icons.cancel : Icons.refresh), onPressed: () { if (onLoading) { iawvCon.stopLoading(); } else { refresher(); } }),
                                                              IconButton(
                                                                  iconSize:
                                                                      iconSize,
                                                                  icon: Icon(Icons
                                                                      .arrow_back_ios),
                                                                  enableFeedback:
                                                                      canGoBack,
                                                                  onPressed:
                                                                      canGoBack
                                                                          ? () {
                                                                              iawvCon.goBack();
                                                                            }
                                                                          : null),
                                                              // GlobalKey declaration for dropdown menu
                                                              Builder(
                                                                builder:
                                                                    (context) {
                                                                  final GlobalKey
                                                                      menuKey =
                                                                      GlobalKey();
                                                                  return Container(
                                                                    key:
                                                                        menuKey,
                                                                    child:
                                                                        IconButton(
                                                                      iconSize:
                                                                          iconSize,
                                                                      icon: Icon(
                                                                          Icons
                                                                              .more_vert),
                                                                      onPressed:
                                                                          () async {
                                                                        final RenderBox
                                                                            button =
                                                                            menuKey.currentContext!.findRenderObject()
                                                                                as RenderBox;
                                                                        final RenderBox
                                                                            overlay =
                                                                            Overlay.of(context).context.findRenderObject()
                                                                                as RenderBox;
                                                                        final Offset
                                                                            position =
                                                                            button.localToGlobal(Offset.zero,
                                                                                ancestor: overlay);
                                                                        setState(() =>
                                                                            isShowingMenu =
                                                                                true);
                                                                        final selected =
                                                                            await showMenu(
                                                                          context:
                                                                              context,
                                                                          position:
                                                                              RelativeRect.fromLTRB(
                                                                            position.dx,
                                                                            position.dy +
                                                                                button.size.height,
                                                                            overlay.size.width -
                                                                                position.dx -
                                                                                button.size.width,
                                                                            overlay.size.height -
                                                                                position.dy -
                                                                                button.size.height,
                                                                          ),
                                                                          items: [
                                                                            PopupMenuItem(
                                                                              value: 'forward',
                                                                              child: canGoForward
                                                                                  ? ListTile(
                                                                                      leading: Icon(Icons.arrow_forward_ios),
                                                                                      title: Text("Go forward"),
                                                                                    )
                                                                                  : ListTile(
                                                                                      leading: Icon(Icons.arrow_forward_ios, color: Colors.grey),
                                                                                      title: Text("Go forward", style: TextStyle(color: Colors.grey)),
                                                                                    ),
                                                                            ),
                                                                            PopupMenuItem(
                                                                              value: 'reload',
                                                                              child: ListTile(
                                                                                leading: Icon(onLoading ? Icons.cancel : Icons.refresh),
                                                                                title: Text("Reload/Stop"),
                                                                              ),
                                                                            ),
                                                                            PopupMenuItem(
                                                                              value: 'home',
                                                                              child: ListTile(
                                                                                leading: Icon(Icons.home_outlined),
                                                                                title: Text("Go to first page"),
                                                                              ),
                                                                            ),
                                                                            PopupMenuItem(
                                                                              value: 'open',
                                                                              child: ListTile(
                                                                                leading: Icon(Icons.open_in_browser),
                                                                                title: Text("Open in app or browser"),
                                                                              ),
                                                                            ),
                                                                            PopupMenuItem(
                                                                              value: 'share',
                                                                              child: ListTile(
                                                                                leading: Icon(Icons.share),
                                                                                title: Text("Share"),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        );
                                                                        setState(() =>
                                                                            isShowingMenu =
                                                                                false);
                                                                        switch (
                                                                            selected) {
                                                                          case 'forward':
                                                                            if (canGoForward) {
                                                                              iawvCon.goForward();
                                                                            }
                                                                            break;
                                                                          case 'reload':
                                                                            if (onLoading) {
                                                                              iawvCon.stopLoading();
                                                                            } else {
                                                                              refresher();
                                                                            }
                                                                            break;
                                                                          case 'home':
                                                                            iawvCon.loadUrl(urlRequest: URLRequest(url: WebUri(requestedUrl)));
                                                                            iawvCon.clearHistory();
                                                                            break;
                                                                          case 'open':
                                                                            await launchUrlString(currentUrl,
                                                                                mode: LaunchMode.externalApplication);
                                                                            break;
                                                                          case 'share':
                                                                            final mediaQuery =
                                                                                MediaQuery.of(context);
                                                                            final size =
                                                                                mediaQuery.size;
                                                                            await SharePlus.instance.share(ShareParams(
                                                                              uri: Uri.parse(currentUrl),
                                                                              sharePositionOrigin: Rect.fromLTWH(size.width - (iconSize * 2), mediaQuery.viewInsets.top + controlBarHeight, iconSize, iconSize),
                                                                            ));
                                                                            break;
                                                                        }
                                                                      },
                                                                    ),
                                                                  );
                                                                },
                                                              ),
                                                              IconButton(
                                                                  iconSize:
                                                                      iconSize,
                                                                  icon: Icon(Icons
                                                                      .close),
                                                                  onPressed:
                                                                      () {
                                                                    Navigator.of(
                                                                            context)
                                                                        .pop();
                                                                  }),
                                                              Container(
                                                                  width: Platform
                                                                          .isAndroid
                                                                      ? 5
                                                                      : 0),
                                                            ]),
                                            ),
                                      Expanded(
                                          child: Stack(children: [
                                        InAppWebView(
                                          windowId:
                                              createWindowAction?.windowId,
                                          initialUrlRequest: createWindowAction
                                                  ?.request ??
                                              navigationAction?.request ??
                                              URLRequest(
                                                  url: WebUri(requestedUrl)),
                                          initialSettings: initialSettings,
                                          pullToRefreshController: ptrCon,
                                          onWebViewCreated: (con) async {
                                            iawvCon = con;
                                          },
                                          shouldOverrideUrlLoading: (controller,
                                              navigationAction) async {
                                            final isMainFrame =
                                                navigationAction.isForMainFrame;
                                            final request =
                                                navigationAction.request;

                                            final navigator =
                                                Navigator.of(context);

                                            final isDownload = navigationAction
                                                    .shouldPerformDownload ??
                                                false;
                                            if (isDownload) {
                                              if (navigationAction
                                                          .request.url !=
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
                                              final rawUrl = uri.rawValue;
                                              if (kDebugMode) {
                                                print(
                                                    "Referrer origin host: ${referrerOrigin?.host}, Popup browser requested host: ${requestedUri.host}, Navigate request host: ${uri.host}");
                                                print(
                                                    "PopupBrowser - raw url: ${uri.rawValue}");
                                              }
                                              if (referrerOrigin?.host
                                                      .endsWith(SERVICE_HOST) ==
                                                  true) {
                                                clearNavigationStack();
                                                processNavigationRequest(
                                                    uri, isMainFrame,
                                                    referrerUrl: currentUrl,
                                                    rawUrl: rawUrl);
                                                return NavigationActionPolicy
                                                    .CANCEL;
                                              }
                                              return await processNavigationRequest(
                                                      uri, isMainFrame,
                                                      isPopupBrowser: true,
                                                      referrerUrl: currentUrl,
                                                      rawUrl: rawUrl)
                                                  ? NavigationActionPolicy
                                                      .CANCEL
                                                  : NavigationActionPolicy
                                                      .ALLOW;
                                            }

                                            return NavigationActionPolicy.ALLOW;
                                          },
                                          onUpdateVisitedHistory: (controller,
                                              url, androidIsReload) async {
                                            final urlString = url.toString();
                                            if (kDebugMode)
                                              print(
                                                  "popupBrowser - changed url: $urlString");
                                            final host = url?.host ?? "";
                                            final isUpdateInitialUrl =
                                                !isInitialized &&
                                                    isEmptyCall &&
                                                    url != null &&
                                                    urlString != BLANK &&
                                                    host != "";

                                            if (isUpdateInitialUrl) {
                                              requestedUrl = urlString;
                                              requestedUri = url;
                                              isOwnService =
                                                  host.endsWith(SERVICE_SUFFIX);
                                            }
                                            setState(() {
                                              currentUrl = urlString;
                                              if (isUpdateInitialUrl) {
                                                isInitialized = true;
                                                if (kDebugMode)
                                                  print(
                                                      "Initial navigation received: $url");
                                                requestedUrl = urlString;
                                                requestedUri = url;
                                                isOwnService = host
                                                    .endsWith(SERVICE_SUFFIX);
                                              }
                                            });
                                            if (isUpdateInitialUrl) {
                                              final settings =
                                                  initialSettings; //(await controller.getSettings()) ?? initialSettings;
                                              if (settings
                                                      .applicationNameForUserAgent !=
                                                  appInfoForUA) {
                                                settings.applicationNameForUserAgent =
                                                    appInfoForUA;
                                              }
                                              var current =
                                                  settings.userAgent ?? "";
                                              if (current.isEmpty)
                                                current =
                                                    initialSettings.userAgent ??
                                                        "";
                                              try {
                                                if (current.isEmpty)
                                                  current =
                                                      (await executeJavascript(
                                                                  "navigator.userAgent"))
                                                              as String? ??
                                                          "";
                                              } on Exception catch (e) {
                                                // do nothing
                                              }
                                              if (current.isEmpty)
                                                current =
                                                    await getDefaultUserAgent();
                                              if (!current.contains(uaSuffix)) {
                                                final ua = current.isNotEmpty
                                                    ? current
                                                    : await InAppWebViewController
                                                        .getDefaultUserAgent();
                                                settings.userAgent =
                                                    ua + uaSuffix;
                                              }
                                              settings.thirdPartyCookiesEnabled =
                                                  isOwnService;
                                              settings.cacheMode = isOwnService
                                                  ? CacheMode.LOAD_DEFAULT
                                                  : CacheMode.LOAD_NO_CACHE;
                                              try {
                                                await controller.setSettings(
                                                    settings: settings);
                                              } catch (e) {
                                                if (kDebugMode)
                                                  print(
                                                      "Error on setSettings for popup browser: $e");
                                              }
                                            }
                                            () async {
                                              final cgb =
                                                  await controller.canGoBack();
                                              setState(() {
                                                canGoBack = cgb;
                                              });
                                            }();
                                            () async {
                                              final cgf = await controller
                                                  .canGoForward();
                                              setState(() {
                                                canGoForward = cgf;
                                              });
                                            }();
                                            setState(() {});
                                          },
                                          onPageCommitVisible:
                                              (controller, url) async {},
                                          onLoadStart: (controller, url) {
                                            setState(() {
                                              onLoading = true;
                                              loadingPct = 0;
                                            });
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
                                          },
                                          onReceivedError:
                                              (controller, request, error) {
                                            ptrCon.endRefreshing();
                                          },
                                          onWebContentProcessDidTerminate:
                                              (controller) async {
                                            if (kDebugMode)
                                              print(
                                                  "Web content process did terminate");
                                            ptrCon.endRefreshing();
                                            setState(() {
                                              onLoading = false;
                                              loadingPct = 0;
                                            });
                                            await controller.reload();
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
                                                action: PermissionResponseAction
                                                    .GRANT);
                                          },
                                          onCreateWindow: (controller,
                                              createWindowAction) async {
                                            final uri =
                                                createWindowAction.request.url;
                                            // if (uri != null) {
                                            openPopupBrowser(
                                                uri?.rawValue ??
                                                    uri?.toString() ??
                                                    "",
                                                createWindowAction:
                                                    createWindowAction,
                                                referrerController: controller);
                                            return true;
                                            // }
                                            // return false;
                                          },
                                          onCloseWindow: (controller) {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        if (isIOS26)
                                          Positioned.fill(
                                              child: PointerInterceptor(
                                            intercepting: isShowingMenu,
                                            debug: kDebugMode,
                                            child: const SizedBox.expand(),
                                          ))
                                      ])),
                                    ]),
                              ),
                              SizedBox(
                                  width: MediaQuery.of(context).size.width,
                                  height: MediaQuery.of(context).padding.top,
                                  child: AnimatedOpacity(
                                      curve: Curves.ease,
                                      opacity:
                                          loadingPct == 0 || loadingPct == 100
                                              ? 0.0
                                              : 1.0,
                                      duration: loadingProgressFadeDuration,
                                      child: LinearProgressIndicator(
                                          value: loadingPct / 100.0,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary))),
                            ])))));
          });
        });

    if (kDebugMode) print("Popup browser closed.");
  }
}
