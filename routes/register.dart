import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.options) {
    return Response(
      statusCode: HttpStatus.ok,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
      },
    );
  }

  final headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
  };

  if (context.request.method == HttpMethod.post) {
    Db? db;
    try {
      db = await Db.create('mongodb://localhost:27017/dart_frog_newsapp');
      await db.open();
      final users = db.collection('users');

      final body = await context.request.body();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final name = data['이름'] as String?;
      final id = data['아이디'] as String?;
      final password = data['비밀번호'] as String?;

      if (name == null || id == null || password == null) {
        return Response.json(
          statusCode: HttpStatus.badRequest,
          body: {'message': '이름, 아이디, 비밀번호를 모두 제공해주세요.'},
          headers: headers,
        );
      }

      final existingUser = await users.findOne(where.eq('id', id));
      if (existingUser != null) {
        return Response.json(
          statusCode: HttpStatus.conflict,
          body: {'message': '이미 사용 중인 아이디입니다.'},
          headers: headers,
        );
      }

      await users.insert({
        'id': id,
        'name': name,
        'password': password,
        '키워드': data['키워드'] ?? [],
        '뉴스사': data['뉴스사'] ?? [],
        '뉴스 성향': data['뉴스 성향'] ?? [],
        '뉴스 주제': data['뉴스 주제'] ?? ['국내 정치, 해외, 경제'],
      });

      return Response.json(
        statusCode: HttpStatus.created,
        body: {'message': '계정이 성공적으로 생성되었습니다.'},
        headers: headers,
      );
    } catch (e) {
      return Response.json(
        statusCode: HttpStatus.internalServerError,
        body: {'message': '서버 오류: ${e.toString()}'},
        headers: headers,
      );
    } finally {
      await db?.close();
    }
  } else {
    return Response(
      statusCode: HttpStatus.methodNotAllowed,
      headers: headers,
    );
  }
}
