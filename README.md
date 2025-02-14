# WebView Container Application for Estre UI on Flutter

This project is reference of hybrid mobile application for PWA on Estre UI based service.

[Estre UI github](https://github.com/SoliEstre/EstreUI.js) - https://github.com/SoliEstre/EstreUI.js


## This reference project pre-implemented of
- Native level splash and flutter level splash screen
- Basic PWA support setting and implements
- Provide option to use InAppWebView (recommended) or WebViewWidget for main web view
- Common javascript handler method with pre-implemented for which using web view component
- Insert adapter codes on load page include common communication method on window.app.request()
- Ready for Edge to edge mode of Android 15. translucent system UI on Android/iOS with Estre UI
- Back navigation for Estre UI and prevented single trigger exits application by back navigation
- Estre UI Native Storage. it's access to app's shared preference through pre-implemented JS handler
- Popup browser(in app browser). when open link on blank target or called window.open()
- Receiving deep link and app link. but required additional settings for each platforms<br />
(on AndroidManifest and plist). Refer [this app_links library document](https://pub.dev/documentation/app_links/latest/)

<br />

Find **<-** or **vv** on codes of project for required or optional customizes your app

<br />

# Document index

- [Javascript handler](#Javascript%20handler)
- [Execute javascript for main web view](#Execute%20javascript%20for%20main%20web%20view)

<br />

# Common Javascript handler

- Flutter application side
```dart
late final Map<String, Future<dynamic> Function(List<dynamic>,
        {bool? isMainFrame, Uri? origin, Uri? from})> appRequestHandlers = {
    "handler_name": (args, {isMainFrame, origin, from}) async {
        return args[0] + args[2];
    },
    "handler_name2": (args, {isMainFrame, origin, from}) async {
        return {
            "bool": true,
            "int": 1234,
            "float": 123.456,
            "string": "asdf",
        };
        // do not return json code. it's fails.
        // return serizable object or primitive types.
        // or return quote esceped json.
    },
    "handler_name3": (args, {isMainFrame, origin, from}) async {
        return jsonEncode(args[0]).replaceAll('"', '\\"');
    },
};
```

- Estre UI on Web View
```javascript
let returns = await window.app.request("handler_name", 1, 2);
console.log(returns); // returns 3. of primitive type.

let returns = await window.app.request("handler_name2");
console.log(returns); // returns object.

let returns = await window.app.request("handler_name3", { data: "asdf" });
console.log(returns); // returns json code.
```

# Execute javascript for main web view

```dart
// Common method for which web view component
var returns = await executeJavascript('console.log("hello Estre"); true');
print(returns); // returns true

// Async function call for await response. only for InAppWebView
var returns = await iawvController!.callAsyncJavaScript(
    functionBody: 'return await estreUi.back()',
    arguments: { "string_argument_name": valueWhenRequired }
    );
print(returns); // returns true if processed Estre UI back request, else returns false
```