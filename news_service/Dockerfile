FROM dart:stable AS build

WORKDIR /app

# 의존성 복사 및 설치
COPY pubspec.* ./
RUN dart pub get

# 소스 코드 복사
COPY . .

# Dart Frog CLI 설치 및 빌드
RUN dart pub global activate dart_frog_cli
RUN dart pub global run dart_frog_cli:dart_frog build

# 서버 컴파일
RUN dart compile exe build/bin/server.dart -o build/bin/server

FROM scratch

COPY --from=build /runtime/ /
COPY --from=build /app/build/bin/server /app/bin/

CMD ["/app/bin/server"]
