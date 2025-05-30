import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../lib/globals.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.options) {
    return Response(
      statusCode: HttpStatus.ok,
      headers: headers,
    );
  }

  Db? db;
  try {
    final body = await context.request.body();

    if (body.isEmpty) {
      return Response.json(
        body: {'success': false, 'message': '요청 본문이 비어 있습니다'},
        statusCode: HttpStatus.badRequest,
        headers: headers,
      );
    }

    
    db = await Db.create(mongoUri);
    await db.open();
    final users = db.collection('users');
    

    final data = jsonDecode(body) as Map<String, dynamic>;
    final id = data['id'] as String? ?? '';
    final password = data['password'] as String? ?? '';

    if (id.isEmpty || password.isEmpty) {
      return Response.json(
        body: {'success': false, 'message': '아이디 또는 비밀번호가 비어 있습니다'},
        statusCode: HttpStatus.badRequest,
        headers: headers,
      );
    }
    
    final existingUser = await users.findOne(where.eq('id', id));

    if (existingUser != null && existingUser['password'] == password) {
      return Response.json(
        body: {
          'success': true,
          'message': '로그인 성공',
          'token': 'admin_token',
        },
        headers: headers,
      );
      
    }
    else{
      return Response.json(
        body: {'success': false, 'message': '잘못된 로그인 정보입니다'},
        statusCode: HttpStatus.unauthorized,
        headers: headers,
      );
      
    }
    
  } catch (e) {
    return Response.json(
      body: {'success': false, 'message': '서버 오류: ${e.toString()}'},
      statusCode: HttpStatus.internalServerError,
      headers: headers,
    );
  }
  finally {
      await db?.close();
    }
  
}