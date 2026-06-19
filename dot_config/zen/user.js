// Zen 固有の追加/上書き prefs。
//   共通prefsは dot_config/firefox/user.js を「正」として踏襲し、
//   配置スクリプトがそれを書き出した「後」にこのファイルを追記する
//   (= 後勝ちなので、ここに書いた値が共通設定を上書きする)。
//
// 共通側で済んでいるもの(Zenでもそのまま効く):
//   テレメトリ全停止 / トラッキングStrict / フィンガープリント対策 /
//   先読み停止 / 検索候補オフ / URL完全表示(trimURLs=false) など。

/* Firefoxネイティブのサイドバー縦タブ(revamp)はZenが独自機構(縦タブ/ワークスペース)
   を持つため不要。競合を避けて無効化する。 */
user_pref("sidebar.revamp", false);
user_pref("sidebar.verticalTabs", false);

/* ── URLバーの挙動 ──
   zen.urlbar.behavior は「普段の表示」と「Ctrl+Tの中央モーダル」を兼ねる1つのスイッチ:
     "floating-on-type" … 普段はコンパクト / Ctrl+Tで中央モーダル(Zen既定・好みの挙動)
     "normal"           … 普段は上部に固定表示 / Ctrl+Tは中央化しない(Firefox風)
   中央Ctrl+Tを残しつつ、普段のURLの見づらさは userChrome.css 側で文字を大きく/フル表示にして補う。 */
user_pref("zen.urlbar.behavior", "floating-on-type");
// ドメインのみ表示をやめ、フルURLを出す。
user_pref("zen.urlbar.show-domain-only-in-sidebar", false);
// 上部の単一ツールバー(横並び)。既定でtrueだが明示しておく。
user_pref("zen.view.use-single-toolbar", true);
// 起動時にコンパクトモードへ入らない(ツールバーを常時表示)。
user_pref("zen.view.compact.enable-at-startup", false);

/* この先、Zen独自UIの微調整は about:config で zen.* を確認して追記する。 */
