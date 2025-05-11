import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:intl/intl.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

const mongoUri = 'mongodb://localhost:27017/dart_frog_newsapp';
const collectionName = 'news';
const apiKey = 'AIzaSyCQ9ZL2HCI0zuc0_6oFtqDaaDATc3M7B50';

final _headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.options) {
    return Response(headers: _headers);
  }

  final db = await Db.create(mongoUri);
  await db.open();

  try {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final doc = await db.collection(collectionName).findOne({'date': today});
    if (doc == null) {
      return Response.json(
        statusCode: 404,
        body: {'error': '오늘 날짜의 뉴스 데이터가 없습니다.'},
        headers: _headers,
      );
    }

    // 모든 분야(예: '경제')에서 title만 추출
    final List<Map<String, dynamic>> allNews = [];
    for (final key in doc.keys) {
      if (key == '_id' || key == 'date') continue;
      final List<dynamic> newsList = doc[key];
      allNews.addAll(newsList.cast<Map<String, dynamic>>());
    }

    final titles = allNews.map((n) => n['title'] as String).toList();

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );

    final prompt = '''
너는 뉴스 필터링 전문가야.
주어진 뉴스 제목들을 바탕으로, 정상인 뉴스를 골라내야해.

출력 형식은 이렇게 : 
정상 제목1
정상 제목2 
정상 제목3


### 정상 기준:
- 정부/공공기관/대기업 관련
- 사회 전반에 영향
- 경제/정치/사회 주요 이슈
- 속보/단독 포함

### 필터 기준:
- 선정적/과장된 표현
- 광고성 내용
- 주제와 무관한 내용


뉴스 제목:
${titles.map((t) => '- $t').join('\n')}
''';

    final content = Content.text(prompt);
    final response = await model.generateContent([content]);

    if (response.text == null) {
      throw Exception('Gemini 응답 없음');
    }

final validTitles = response.text!
    .split('\n')
    .map((line) => line.replaceAll(RegExp(r'^\d+\.\s*'), '').trim())
    .where((line) => line.isNotEmpty)
    .toList();

    for (final key in doc.keys) {
      if (key == '_id' || key == 'date') continue;
      final List<dynamic> updatedNews = (doc[key] as List).map((news) {
        final map = Map<String, dynamic>.from(news);
        if (validTitles.contains(map['title'])) {
          map['isValid'] = true;
        }
        return map;
      }).toList();
      doc[key] = updatedNews;
    }

    await db.collection(collectionName).replaceOne({'date': today}, doc);

    return Response.json(
      statusCode: 200,
      headers: _headers,
    );
  } catch (e, st) {
    return Response.json(
      statusCode: 500,
      body: {'error': e.toString(), 'stack': st.toString()},
      headers: _headers,
    );
  } finally {
    await db.close();
  }
}
