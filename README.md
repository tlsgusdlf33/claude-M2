# 달빛 온실 (Moonlight Greenhouse)

안드로이드용 힐링 스테이지 클리어 게임. 손을 떼면 반딧불이 자동으로 새싹을 키우고, 누르고 끌면 물뿌리개로 직접 더 빨리 키웁니다. 스토리, 기획, 광고 수익화 검토는 `docs/DESIGN.md`에 있습니다.

| 경로 | 내용 |
|---|---|
| `docs/DESIGN.md` | 기획서 (스토리, 규칙, 광고, 광고 상점, 수익화 현실성) |
| `prototype/index.html` | 게임 본체 (단일 파일). 브라우저에서 바로 실행 가능 |
| `tools/sim.js` | 규칙을 화면 없이 돌려 밸런스를 확인하는 스크립트 |
| `tools/shell.html`, `tools/updater.js`, `tools/make-www.py` | 앱 시작 화면, 자동 업데이트 코드, 앱용 파일 생성기 |
| `android-app/`, `.github/workflows/` | APK 빌드(Capacitor)와 자동 업데이트 배포 |

## 실행
- 브라우저: `prototype/index.html`을 열기 (모바일 권장)
- 밸런스 시뮬레이션: `node tools/sim.js prototype/index.html`

## APK로 폰에 설치하기
1. 폰 브라우저에서 이 저장소의 Releases 페이지를 엽니다.
2. 가장 최근 릴리스의 `moonlight-debug.apk`를 내려받아 엽니다.
3. "출처를 알 수 없는 앱 설치"를 허용하라는 안내가 뜨면 해당 브라우저에 허용합니다.

처음 한 번만 설치하면 됩니다. 이후 `prototype/`을 고쳐 `main`에 올리면 설치된 앱이 켜질 때 새 게임 파일을 받아 갑니다(저장소가 공개일 때). 광고·권한 등 앱 껍데기를 바꾸면 APK를 다시 설치해야 합니다. 서명 키(`android-app/debug.keystore`)는 암호가 공개된 테스트용이므로 구글 플레이 출시용은 별도 키로 새로 만들어야 합니다.
