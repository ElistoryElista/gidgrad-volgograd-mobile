import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_view_tts/web_view_tts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GidgradScreen(),
    );
  }
}

class GidgradScreen extends StatelessWidget {
  const GidgradScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const GidgradWebview();
  }
}

class GidgradWebview extends StatefulWidget {
  const GidgradWebview({
    super.key,
  });

  @override
  State<GidgradWebview> createState() => _GidgradWebviewState();
}

enum GidgradStatus { initial, inProgress, success, failure }

class _GidgradWebviewState extends State<GidgradWebview> {
  final webViewKey = GlobalKey();

  InAppWebViewController? webViewController;
  InAppWebViewSettings settings = InAppWebViewSettings(
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    iframeAllow: "camera; microphone; geolocation",
    iframeAllowFullscreen: true,
  );

  PullToRefreshController? pullToRefreshController;
  String url = "";
  double progress = 0;
  // final urlController = TextEditingController();

  @override
  void initState() {
    super.initState();

    pullToRefreshController = kIsWeb
        ? null
        : PullToRefreshController(
            settings: PullToRefreshSettings(
              color: Colors.blue,
            ),
            onRefresh: () async {
              if (defaultTargetPlatform == TargetPlatform.android) {
                webViewController?.reload();
              } else if (defaultTargetPlatform == TargetPlatform.iOS) {
                webViewController?.loadUrl(
                  urlRequest: URLRequest(
                    url: await webViewController?.getUrl(),
                  ),
                );
              }
            },
          );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // canPop: controller.canGoBack(),
      child: Scaffold(
        body: SafeArea(
          child: InAppWebView(
            key: webViewKey,
            initialUrlRequest: URLRequest(
              url: WebUri("https://v.гидград.рф/"),
            ),
            initialSettings: settings,
            pullToRefreshController: pullToRefreshController,
            onWebViewCreated: (controller) => webViewController = controller,
            onLoadStart: (controller, url) async {
              await WebViewTTS.init(controller: controller);
              setState(() {
                this.url = url.toString();
                // urlController.text = this.url;
              });
            },
            onPermissionRequest: (controller, request) async {
              return PermissionResponse(
                resources: request.resources,
                action: PermissionResponseAction.GRANT,
              );
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              var uri = navigationAction.request.url!;

              if (![
                "http",
                "https",
                "file",
                "chrome",
                "data",
                "javascript",
                "about"
              ].contains(uri.scheme)) {
                // if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
                return NavigationActionPolicy.CANCEL;
                // }
              }

              return NavigationActionPolicy.ALLOW;
            },
            onLoadStop: (controller, url) async {
              pullToRefreshController?.endRefreshing();
              setState(() {
                this.url = url.toString();
                // urlController.text = this.url;
              });
            },
            onReceivedError: (controller, request, error) {
              pullToRefreshController?.endRefreshing();
            },
            onProgressChanged: (controller, progress) {
              if (progress == 100) {
                pullToRefreshController?.endRefreshing();
              }
              setState(() {
                this.progress = progress / 100;
                // urlController.text = url;
              });
            },
            onUpdateVisitedHistory: (controller, url, androidIsReload) {
              setState(() {
                this.url = url.toString();
                // urlController.text = this.url;
              });
            },
            onConsoleMessage: (controller, consoleMessage) {
              if (kDebugMode) {
                print(consoleMessage);
              }
            },
            onGeolocationPermissionsShowPrompt:
                onGeolocationPermissionsShowPrompt,
          ),
        ),
      ),
    );
  }

  Future<GeolocationPermissionShowPromptResponse?>
      onGeolocationPermissionsShowPrompt(
    InAppWebViewController controller,
    String origin,
  ) async {
    final isPermanentlyDenied = await Permission.location.isPermanentlyDenied;
    if (!isPermanentlyDenied) {
      final isGranted = await Permission.location.request().isGranted;
      return Future.value(
        GeolocationPermissionShowPromptResponse(
          origin: origin,
          allow: isGranted,
          retain: isGranted,
        ),
      );
    } else {
      final result = await showAdaptiveDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Необходимо предоставить доступ к местоположению'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                    'Для получения текущего местоположения необходимо предоставить доступ'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Отклонить'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Открыть настройки'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        ),
      );
      if (result == true) {
        await openAppSettings();
      }
      return Future.value(
        GeolocationPermissionShowPromptResponse(
          origin: origin,
          allow: false,
          retain: false,
        ),
      );
    }
  }
}
