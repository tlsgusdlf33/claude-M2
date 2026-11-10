#!/usr/bin/env python3
"""prototype/index.html 을 앱(WebView)용 완전한 HTML 문서로 감싸고, 자동 업데이트용 파일을 함께 만든다.

사용법:
  python3 tools/make-www.py prototype/index.html android-app/www [--version 202611100030] [--base https://사용자.github.io/저장소/]

만드는 파일 (출력 폴더):
  index.html    앱의 시작 화면 (tools/shell.html). 고정된 아주 작은 파일
  game.txt      앱에 넣는 게임 본체 (맨 앞에 업데이트 코드 포함). 일부러 .html 이 아닌 이름을 쓴다
                (Capacitor 가 .html 에는 자기 스크립트를 끼워 넣기 때문)
  game.html     game.txt 와 같은 내용. 서버에 올려서 앱이 내려받는다
  version.json  {"version": 숫자, "file": "game.html"}

프로토타입 파일은 아티팩트 게시용이라 <!doctype>, <html>, <head>, <body>가 없다.
스타일 블록까지를 head, 나머지를 body로 나눠 문서를 만든다.
"""
import argparse
import json
import os
import time

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("out")
ap.add_argument("--version", default=time.strftime("%Y%m%d%H%M%S", time.gmtime()))
ap.add_argument("--base", action="append", default=[])
a = ap.parse_args()

here = os.path.dirname(os.path.abspath(__file__))
upd = open(os.path.join(here, "updater.js"), encoding="utf-8").read()
upd = upd.replace("__VERSION__", str(int(a.version))).replace("__BASES__", json.dumps(a.base))

text = open(a.src, encoding="utf-8").read()
end = text.index("</style>") + len("</style>")
head, body = text[:end], text[end:]
doc = (
    '<!doctype html>\n<html lang="ko">\n<head>\n<meta charset="utf-8">\n'
    '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover,user-scalable=no">\n'
    '<meta name="mmyg-version" content="' + str(int(a.version)) + '">\n'
    "<script>\n" + upd + "\n</script>\n"
    + head
    + "\n<style>html{padding:env(safe-area-inset-top,0px) 0 env(safe-area-inset-bottom,0px)}"
    "html,body{margin:0;-webkit-tap-highlight-color:transparent;overscroll-behavior:none}"
    "body{-webkit-user-select:none;user-select:none}</style>\n</head>\n<body>"
    + body
    + "\n</body>\n</html>\n"
)
os.makedirs(a.out, exist_ok=True)
for name in ("game.txt", "game.html"):
    open(os.path.join(a.out, name), "w", encoding="utf-8").write(doc)
shell = open(os.path.join(here, "shell.html"), encoding="utf-8").read().replace("__VERSION__", str(int(a.version)))
open(os.path.join(a.out, "index.html"), "w", encoding="utf-8").write(shell)
open(os.path.join(a.out, "version.json"), "w", encoding="utf-8").write(
    json.dumps({"version": int(a.version), "file": "game.html"}) + "\n"
)
print("wrote", a.out, "version", a.version, len(doc), "chars")
