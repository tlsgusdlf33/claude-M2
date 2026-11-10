/* 자동 업데이트 (앱 안에서 게임 화면과 규칙만 교체) — tools/make-www.py 가 게임 HTML 맨 앞에 끼워 넣는다.
 * 어떤 파일로 시작할지는 tools/shell.html(앱의 index.html)이 고른다. 이 코드는 시작한 뒤의 일만 한다.
 *
 *  1. 시작하고 1.5초 뒤, 그리고 앱으로 돌아올 때(마지막 확인이 10분 넘었으면) 서버의 version.json 을 확인한다.
 *     지금 실행 중인 버전보다 높은 버전이 있으면 game.html 을 받아 저장해 둔다(localStorage).
 *  2. 받아 둔 버전은 다음 실행 때 자동으로 적용되고, 화면의 "지금 적용"(MMYG.apply)으로 바로 적용할 수도 있다.
 *  3. 게임이 정상으로 시작했다고 MMYG.ok()를 부르면 기록한다. 이 기록이 없으면 다음 실행 때 그 버전은 버려진다.
 *  인터넷이 없거나 서버가 응답하지 않으면 아무 일도 일어나지 않는다.
 *  앱 자체(광고, 결제, 권한 같은 네이티브 부분)는 이 방법으로 바뀌지 않는다. 그럴 때는 APK를 다시 설치해야 한다.
 */
(function () {
  var VER = __VERSION__;
  var BASES = __BASES__;
  var K = { html: 'mmyg-upd-html', ver: 'mmyg-upd-ver', good: 'mmyg-upd-good', bad: 'mmyg-upd-bad' };
  function g(k) { try { return window.localStorage.getItem(k); } catch (e) { return null; } }
  function s(k, v) { try { window.localStorage.setItem(k, v); } catch (e) {} }

  var M = window.MMYG = { version: VER, state: 'idle', onchange: null };
  function set(st) { M.state = st; try { if (M.onchange) M.onchange(st); } catch (e) {} }

  var cv = +g(K.ver) || 0;                      // 받아 둔 새 버전 (없으면 0)
  if (cv > VER && g(K.html)) set('ready');

  M.ok = function () { s(K.good, String(VER)); };
  M.apply = function () { window.location.reload(); };

  function getText(url) {
    return fetch(url, { cache: 'no-store' }).then(function (r) { if (!r.ok) throw new Error(r.status); return r.text(); });
  }
  function tryBase(i, manual) {
    if (i >= BASES.length) { set(manual ? 'offline' : 'idle'); return Promise.resolve(); }
    var base = BASES[i], t = Date.now();
    return getText(base + 'version.json?t=' + t).then(function (txt) {
      var info = JSON.parse(txt), n = +info.version || 0, have = Math.max(VER, cv), bad = +g(K.bad) || 0;
      if (n <= have || n === bad) { set(cv > VER ? 'ready' : 'latest'); return; }
      set('downloading');
      return getText(base + (info.file || 'game.html') + '?v=' + n).then(function (body) {
        var okDoc = body.length > 20000 && body.indexOf('name="mmyg-version" content="' + n + '"') > 0 && body.indexOf('showLogin();') > 0;
        if (!okDoc) throw new Error('bad update');
        s(K.html, body); s(K.ver, String(n)); cv = n;
        set('ready');
      });
    }).catch(function () { return tryBase(i + 1, manual); });
  }
  M.check = function (manual) {
    if (M.state === 'checking' || M.state === 'downloading') return Promise.resolve();
    if (M.state !== 'ready') set('checking');
    return tryBase(0, !!manual);
  };
  var lastCheck = 0;
  function auto() { lastCheck = Date.now(); M.check(false); }
  window.addEventListener('load', function () { setTimeout(auto, 1500); });
  document.addEventListener('visibilitychange', function () {
    if (!document.hidden && Date.now() - lastCheck > 600000) auto();
  });
})();
