import 'dart:convert';
import 'package:dart_frog/dart_frog.dart' as frog;
import 'package:puppeteer/puppeteer.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../lib/globals.dart';

Future<frog.Response> onRequest(frog.RequestContext context) async {
  if (context.request.method == frog.HttpMethod.options) {
    return frog.Response(headers: headers);
  }

  final body = await context.request.body();
  final data = jsonDecode(body);
  final title = data['title'] as String?;

  if (title == null || title.isEmpty) {
    return frog.Response.json(
      statusCode: 400,
      body: {'error': 'title 누락'},
      headers: headers,
    );
  }

  try {
    final model = GenerativeModel(
      model: 'gemini-2.0-flash', 
      apiKey: apiKey,
    );

final prompt = """
너는 뉴스 요약 전문가야. 아래 뉴스 제목에 해당하는 기사를 웹에서 찾아 내용을 읽고, 읽은 기사 내용을 바탕으로 한국어로 간결하게 요약해 줘.

- 요약 내용에는 **볼드체(**)나 `****`와 같은 마크다운 기호를 사용하지 마십시오.
- 요약문은 '~입니다.'와 같은 경어체로 작성해 주십시오.
- 최종 응답 시 요약 내용만 반환하며, '뉴스 요약:', '알겠습니다' 등 어떠한 부연 설명도 포함하지 마십시오.

제목: $title
""";
    final content = Content.text(prompt);

    final response = await model.generateContent([content]);
    final summary = response.text ?? '요약 실패';

    return frog.Response.json(
      body: {'summary': summary},
      headers: headers,
    );
  } catch (e, st) {
    return frog.Response.json(
      statusCode: 500,
      body: {'error': e.toString(), 'stack': st.toString()},
      headers: headers,
    );
  }
}