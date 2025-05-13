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



### 정상 기준:  
객관적 사실: 사건, 발표, 정책, 통계 기반 보도 (주관적 감정 최소화)
부정부패/권력 남용: 공직자 비리, 민주주의 훼손 등등
주요 국내/해외 사회적 논쟁: 국민적 관심, 큰 파장 이슈 등
국내/해외 정치 기관 변화: 정부, 국회, 사법부 주요 결정 과정
국내/해외 국가 중요 정책: 외교, 안보, 경제 (국가 미래 영향)
선거 핵심 정보: 제도 변화, 후보/정책 비교 (유권자 판단 필수)
주요 국내외 이슈: 경제, 정치, 사회 전반
투자 관련 정보: 주식, 부동산 등
긴급/안전 속보: 재난, 사고, 교통 통제 
제목에 [속보]/[단독] 포함
실생활 영향 정책: 세금, 교육, 복지, 의료 변화
사회적 파장 이슈: 대규모 시위, 운동, 재판 결과
주요 국제 뉴스: 전쟁, 외교, 경제 위기


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
