class GeneratedOutput {
  String? title;
  String? content;
  
  // Custom constructor
  GeneratedOutput({this.title, this.content});
  
  // Convert from JSON
  factory GeneratedOutput.fromJson(Map<String, dynamic> json) {
    return GeneratedOutput(
      title: json['title'] as String?,
      content: json['content'] as String?,
    );
  }
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      if (title != null) 'title': title,
      if (content != null) 'content': content,
    };
  }
}
