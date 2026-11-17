@AGENTS.md

## graphify

- 평소 코드 질문은 grep·Read 로 찾는다. `graphify-out/` 그래프는 전체 구조 점검(의존 방향, 여러 파일에 반복되는 코드), 문서와 코드가 어긋난 곳 찾기, 여러 파일을 거치는 흐름 추적에만 `graphify query`·`path`·`explain` 으로 쓴다.
- 그래프에는 문자열·숫자 값이 없다. 설정 키·하드코딩 상수는 grep 으로 찾는다.
- 그래프는 이 맥에만 있다. 코드가 바뀌었으면 쓰기 전에 `graphify update .` 로 갱신한다.
