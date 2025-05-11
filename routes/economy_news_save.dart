import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:intl/intl.dart';

const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
};

const mongoUri = 'mongodb://localhost:27017/dart_frog_newsapp';
const collectionName = 'news';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.options) {
    return Response(
      statusCode: HttpStatus.ok,
      headers: headers,
    );
  }

  Db? db;
  try {
    final rssUrl =
        'https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRGx6TVdZU0FtdHZHZ0pMVWlnQVAB?hl=ko&gl=KR&ceid=KR:ko';
    final response = await http.get(Uri.parse(rssUrl));
    if (response.statusCode != 200) {
      return Response.json(
        statusCode: 500,
        body: {'error': '뉴스 피드 요청 실패'},
        headers: headers,
      );
    }

    final document = xml.XmlDocument.parse(response.body);
    final items = document.findAllElements('item').take(10);

    // 날짜별, 분야별 뉴스 저장
    final Map<String, Map<String, List<Map<String, dynamic>>>> newsByDate = {};

    for (var item in items) {
      final title = item.findElements('title').single.text.trim();
      final link = item.findElements('link').single.text.trim();
      final pubDateStr = item.findElements('pubDate').single.text.trim();

      final pubDate = DateFormat('EEE, dd MMM yyyy HH:mm:ss', 'en_US')
          .parse(pubDateStr.replaceAll(' GMT', ''), true)
          .toLocal();

      final dateStr = DateFormat('yyyy-MM-dd').format(pubDate);
      final timeStr = DateFormat('HH:mm:ss').format(pubDate);

      final summary = link;

      final newsObj = {
        'title': title,
        'summary': summary,
        'time': timeStr,
        'isScrapped': 0,
        'isValid': false
      };

      newsByDate.putIfAbsent(dateStr, () => {});
      newsByDate[dateStr]!.putIfAbsent('경제', () => []);

      // 중복 제목 방지
      if (!newsByDate[dateStr]!['경제']!
          .any((n) => n['title'] == newsObj['title'])) {
        newsByDate[dateStr]!['경제']!.add(newsObj);
      }
    }

    // MongoDB 저장 (날짜별 1도큐먼트, 분야별 배열)
    db = await Db.create(mongoUri);
    await db.open();
    final collection = db.collection(collectionName);

    for (final date in newsByDate.keys) {
      final fields = newsByDate[date]!; // Map<String, List<Map>>
      final doc = {'date': date, ...fields}; // { "date": "2025-05-10", "한국": [...] }

      final exists = await collection.findOne({'date': date});
      if (exists == null) {
        await collection.insertOne(doc);
      } else {
        // 기존 도큐먼트의 분야별 뉴스 합치기 (중복 뉴스는 제목 기준으로 제외)
        final Map<String, dynamic> updatedDoc = Map<String, dynamic>.from(exists);
        fields.forEach((field, newsList) {
          updatedDoc.putIfAbsent(field, () => []);
          for (final news in newsList) {
            if (!(updatedDoc[field] as List)
                .any((n) => n['title'] == news['title'])) {
              (updatedDoc[field] as List).add(news);
            }
          }
        });
        await collection.replaceOne({'date': date}, updatedDoc);
      }
    }

    await db.close();

    return Response.json(
      statusCode: 200,
      body: {
        'success': true,
        'message': '뉴스 저장 완료',
      },
      headers: headers,
    );
  } catch (e, st) {
    db?.close();
    return Response.json(
      statusCode: 500,
      body: {'error': e.toString(), 'stack': st.toString()},
      headers: headers,
    );
  }
}
