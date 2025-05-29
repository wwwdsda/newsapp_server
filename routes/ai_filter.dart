import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:intl/intl.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

const mongoUri = 'mongodb://localhost:27017/dart_frog_newsapp';
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
  final id = context.request.uri.queryParameters['id'];
  final password = context.request.uri.queryParameters['password'];


  final db = await Db.create(mongoUri);
  await db.open();

  final user = await db.collection('users').findOne({
  'id': id,
  'password': password,
  });

  try {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final doc = await db.collection('news').findOne({'date': today});
    final keyword = (user?['키워드'] ?? []) as List<dynamic>;
    final newsAgency = (user?['뉴스사'] ?? []) as List<dynamic>;
    final newsSentiment = (user?['뉴스 성향'] ?? []) as List<dynamic>;
    final newsTopic = (user?['뉴스 주제'] ?? []) as List<dynamic>;

    if (doc == null) {
      return Response.json(
        statusCode: 404,
        body: {'error': '오늘 날짜의 뉴스 데이터가 없습니다.'},
        headers: _headers,
      );
    }

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
너는 객관적이고 전문적인 뉴스 필터링 모델이야.

아래 기준을 바탕으로, 객관적이고 사회적으로 중요한 뉴스 제목만 추려줘.
불필요한 감성 기사, 연예/가십성 기사, 홍보성 기사는 제외해.

뉴스 성향 필터링 기준
- 유지할 성향: 중도, 보수, 진보 (선택적 허용. 지금은 $newsSentiment)
- 성향이 명확히 확인되지 않으면 포함 보류가 아닌 포함 (기본적으로는 필터링하지 않음)

무조건 포함 키워드 (아래 단어 중 하나라도 포함되면 포함)
- 키워드 목록: $keyword
- 제목에 [속보], [단독]이 들어간 기사

포함 기준: 다음 중 하나라도 해당되면 포함
- 객관적 사실 기반 보도 (정책 발표, 통계, 사건)
- 새로운 혁신적인 기술 (AI, IT, 과학 등) 관련 정보
- 정부, 국회, 사법부 등 주요 기관의 변화 또는 결정
- 선거나 제도 변화에 관련된 정보
- 국내/해외에서 사회적 파장을 일으킨 논쟁
- 외교, 안보, 경제 등 국가 주요 정책
- 주식, 부동산, 금리 등 투자 관련 정보
- 국민 생활에 직접 영향을 미치는 정책 변화 (세금, 교육, 복지 등)
- 자연재해, 사고 등 긴급 속보
- 주요 국제 이슈 (전쟁, 정상회담, 외교 마찰 등)
- 유명 연예인 사건 사고
- 유명 게임 관련 뉴스
- 해외 유명 스포츠 관련 뉴스

제외 기준: 다음 중 하나라도 해당되면 제외
- 지나치게 감정적이거나 선정적인 표현이 포함된 기사
- 출처나 정보가 명확하지 않은 루머성 기사
- 광고/홍보성 기사 (상품 소개, 브랜드 홍보 등)

출력 형식
필터링된 "정상 뉴스 제목"만 한 줄씩 출력 (번호 없이)

입력 뉴스 제목 목록:
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

    await db.collection('news').replaceOne({'date': today}, doc);

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
