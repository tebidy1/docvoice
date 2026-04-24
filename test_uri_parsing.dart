void main() {
  final urlStr = 'wss://host.com/path?encoding=audio/raw;rate=16000&model=WHISPER';
  final uri = Uri.parse(urlStr);
  print('Parsed: \${uri.toString()}');
}

