// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void openPermissionFixPage() {
  // Opens the index.html in a new tab
  html.window.open('index.html', '_blank');
}
