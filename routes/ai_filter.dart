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
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
    );

    final prompt = '''
너는 뉴스 필터링 전문가야.
주어진 뉴스 제목들을 바탕으로, 정상인 뉴스를 골라내야해.

출력 형식은 이렇게 : 
정상 제목1
정상 제목2 
정상 제목3

### 각각의 주제에서 제일 위에 기록해야하는, 무조건 봐야하는 뉴스:
- 공공안전, 재난, 긴급 속보 (지진, 태풍, 화재, 사고, 교통 통제 등), [속보]or[단독]이 제목에 포함
- 정부 정책 및 입법 변화 (세금, 교육, 복지, 의료 등 실생활에 직접 영향)
- 사회적 파장 큰 이슈 (대규모 시위, 사회 운동, 재판 결과 등)
- 주요 국제 뉴스 (전쟁, 외교, 글로벌 경제 위기 등)

### 정상 기준:
- 객관적인 사실을 전달(사건, 발표, 정책, 통계 등 정보 기반의 보도, 주관적 감정이 과도하게 들어가지 않음)
- 정제된 제목 (과장·선정적 표현 없음, 불필요한 감탄사, 욕설, 음란/비속어 없음)
- 사회 전반에 영향
- 경제/정치/사회 주요 이슈


### 필터 기준:
- 굳이 알 필요 없는 정치 뉴스
- 선정적/과장된 표현
- 광고성 내용
- 주제와 무관한 내용
- 중복(비슷한) 뉴스가 이미 있는 경우


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
