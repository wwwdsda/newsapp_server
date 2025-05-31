4개의 마이크로서비스로 구성된 루트폴더
- auth_service (로그인, 회원가입 정보 관리)
- filter_service (ai filter를 사용하는 기능)
- news_service (뉴스 크롤링, 스크랩 뉴스 불러오기, 스크랩 뉴스 갱신)
- user_service (유저 설정 정보 관리 - 성향, 키워드, 뉴스 주제 불러오고 삭제 추가 기능)
도커 컴포스로 마이크로서비스와 몽고db를 동시에 관리중

newsapp_server/
├── auth_service/
│ ├── routes/
│ │ ├── login.dart # 유저 db에 로그인 정보 있는지 확인 후 결과 리턴
│ │ ├── register.dart # 유저 db에 계정 정보 있는지 확인 후 결과 리턴, db갱신
├── filter_service/ 
│ ├── routes/
│ │ ├── ai_filter. dart # 크롤링된 뉴스 프롬프트에 맞게 필터 후 db 갱신
│ │ ├── ai_summary.dart # 선택된 뉴스 읽고 요약본 작성 후 db 갱신
├── news_service/ 
│ ├── routes/
│ │ ├── news.dart # 날짜를 받고 해당하는 날짜의 뉴스들을 db에서 읽음
│ │ ├── scrap.dart # 뉴스 정보를 받고 해당하는 뉴스의 스크랩여부를 반전
│ │ ├── bring_scrap.dart # db에 저장된 스크랩뉴스들을 읽음
│ │ ├── ~~news_save.dart # 구글 뉴스 rss사이트에 가서 각각의 주제에 맞는 뉴스들을 읽어옴
├── user_service/ 
│ ├── routes/
│ │ ├── add_(bias, topic, keyword).dart # 전역변수에 있는 현재 유저의 db에 해당 성향, 주제, 키워드 추가
│ │ ├── delete_(bias, topic, keyword).dart # 현재 유저의 db에 해당 성향, 주제, 키워드 제거거
│ │ ├── save_(bias, topic).dart # db에 해당 성향, 토픽을 한번에 추가
│ │ ├── user_(biases, topic) , keyword # 현재 유저의 db에 있는 성향, 주제 키워드 읽어옴 
