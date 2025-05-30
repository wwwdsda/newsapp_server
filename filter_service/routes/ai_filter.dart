import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:intl/intl.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../lib/globals.dart';

Future<Response> onRequest(RequestContext context) async {
  print('ai_filter 요청 도착: ${context.request.uri}');
  if (context.request.method == HttpMethod.options) {
    return Response(headers: headers);
  }
  final id = context.request.uri.queryParameters['id'];
  final password = context.request.uri.queryParameters['password'];

  Db? db;
  try {
    db = await Db.create(mongoUri);
    await db.open();

    final user = await db.collection('users').findOne({
      'id': id,
      'password': password,
    });

    if (user == null) {
      print('사용자 인증 실패: $id');
      return Response.json(
        statusCode: 401,
        body: {'success': false, 'message': '사용자 인증 실패'},
        headers: headers,
      );
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final doc = await db.collection('news').findOne({'date': today});

    if (doc == null) {
      print('오늘 날짜의 뉴스 데이터가 없습니다.');
      return Response.json(
        statusCode: 404,
        body: {'success': false, 'message': '오늘 날짜의 뉴스 데이터가 없습니다.'},
        headers: headers,
      );
    }

    final keyword = (user['키워드'] ?? []) as List<dynamic>;
    final newsAgency = (user['뉴스사'] ?? []) as List<dynamic>;
    final newsSentiment = (user['뉴스 성향'] ?? []) as List<dynamic>;
    final newsTopic = (user['뉴스 주제'] ?? []) as List<dynamic>;

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
- 유지할 성향: $newsSentiment
- 성향이 명확히 확인되지 않으면 포함 보류가 아닌 포함 (기본적으로는 필터링하지 않음)
- 진보가 선택되어 있으면 보수 뉴스는 필터, 그 반대도 똑같이. 하지만 둘 다 체크라면 다 필터하지 않는걸로

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
- 굳이 알 필요 없는 정치인의 개인적인 발언
- 이미 정상처리한 뉴스와 똑같은&비슷한 중복 뉴스

출력 형식
필터링된 "정상 뉴스 제목"만 한 줄씩 출력 (번호 없이)

정상뉴스1
정상뉴스2
정상뉴스3

입력 뉴스 제목 목록:
${titles.map((t) => '- $t').join('\n')}
''';

    final content = Content.text(prompt);
    final response = await model.generateContent([content]);

    print('Gemini 응답: ${response.text}');

    if (response.text == null) {
      throw Exception('Gemini 응답 없음');
    }

    final validTitles = response.text!
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'^\d+\.\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    print('필터링 결과: $validTitles');

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

    await db.close();

    return Response.json(
      statusCode: 200,
      body: {
        'success': true,
        'validTitles': validTitles,
        'message': '필터링 완료',
      },
      headers: headers,
    );
  } catch (e, st) {
    print('에러 발생: $e\n$st');
    db?.close();
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': e.toString(), 'stack': st.toString()},
      headers: headers,
    );
  }
}
