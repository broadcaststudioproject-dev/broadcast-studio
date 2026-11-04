// Copyright (c) 2026 Vinod Kumar Jannampally. All commercial and software rights reserved.
// Package: com.kingjvk.pocket_pcr

class NewsItem {
  int? id;
  String title;
  String content;
  String source;
  String category;
  String status; // New, Under Verification, Verified, Rejected, Ready for Production, Published
  String? mediaUrl;
  String date;

  NewsItem({
    this.id,
    required this.title,
    required this.content,
    required this.source,
    required this.category,
    required this.status,
    this.mediaUrl,
    required this.date,
  });

  // Database లోకి సేవ్ చేయడానికి Map గా మార్చడం
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'source': source,
      'category': category,
      'status': status,
      'mediaUrl': mediaUrl,
      'date': date,
    };
  }

  // Database నుండి డేటాను చదవడానికి
  factory NewsItem.fromMap(Map<String, dynamic> map) {
    return NewsItem(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      source: map['source'],
      category: map['category'],
      status: map['status'],
      mediaUrl: map['mediaUrl'],
      date: map['date'],
    );
  }
}
