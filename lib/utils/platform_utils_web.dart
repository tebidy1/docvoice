import 'dart:html' as html;

void downloadFile(String url, String filename) {
  html.AnchorElement(href: url)
    ..setAttribute("download", filename)
    ..click();
}
