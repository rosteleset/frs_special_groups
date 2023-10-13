import 'dart:html' as html;

void onFrameClicked(String url) {
  html.window.open(url, '_blank');
}
