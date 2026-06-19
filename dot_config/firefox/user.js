// user.js — Firefox / Zen の about:config 設定をコード化したもの。
// 起動時に Firefox がこれを読み、prefs.js へ上書き適用する。
//   配置先: <profile>/user.js  (run_onchange_after_setup-firefox.sh が配置)
//   反映  : ブラウザを再起動すると有効になる。
//
// ここに書いた値が「正」。GUI で変更しても再起動でここの値に戻る。

/* ═══════════════════════════════════════════════════════════
   縦タブ / サイドバー  (Firefox 137+ のネイティブ機能)
   ═══════════════════════════════════════════════════════════ */
user_pref("sidebar.revamp", true);        // 新サイドバーUI
user_pref("sidebar.verticalTabs", true);  // タブを縦に
user_pref("sidebar.main.tools", "history,bookmarks");
user_pref("sidebar.visibility", "always-show");

/* ═══════════════════════════════════════════════════════════
   起動・UI
   ═══════════════════════════════════════════════════════════ */
user_pref("browser.startup.page", 1);            // 起動時にホームページ(=three.jsスタート画面)を表示
user_pref("browser.newtabpage.enabled", false);  // 新規タブは空白 (好みで true)
// ↑ browser.startup.homepage(自作スタート画面への file:// パス) は
//   プロファイルのパスがランダムなため run_onchange スクリプトが自動注入する。
user_pref("browser.uidensity", 2);               // 0=標準 1=タッチ 2=コンパクト
// userChrome.css / userContent.css を有効化 (UI 改造に必須)
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
// ダークテーマを強制 (ブラウザUIと、対応サイトの配色)
user_pref("layout.css.prefers-color-scheme.content-override", 0); // 0=dark 1=light 2=auto

/* ═══════════════════════════════════════════════════════════
   ダウンロード
   ═══════════════════════════════════════════════════════════ */
user_pref("browser.download.useDownloadDir", false); // 毎回保存先を確認

/* ═══════════════════════════════════════════════════════════
   テレメトリ / データ送信 — 全部切る
   ═══════════════════════════════════════════════════════════ */
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("toolkit.telemetry.newProfilePing.enabled", false);
user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);
user_pref("toolkit.telemetry.updatePing.enabled", false);
user_pref("toolkit.telemetry.bhrPing.enabled", false);
user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
user_pref("toolkit.telemetry.coverage.opt-out", true);
user_pref("toolkit.coverage.opt-out", true);
user_pref("toolkit.coverage.endpoint.base", "");
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("app.normandy.enabled", false);
user_pref("app.normandy.api_url", "");
user_pref("messaging-system.rsexperimentloader.enabled", false);
user_pref("browser.ping-centre.telemetry", false);
user_pref("browser.discovery.enabled", false);
// クラッシュレポート送信なし
user_pref("breakpad.reportURL", "");
user_pref("browser.tabs.crashReporting.sendReport", false);

/* ═══════════════════════════════════════════════════════════
   トラッキング防止 — Strict 相当
   ═══════════════════════════════════════════════════════════ */
user_pref("browser.contentblocking.category", "strict");
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.trackingprotection.emailtracking.enabled", true);
// Cookie を発行元ごとに隔離 (Total Cookie Protection)
user_pref("network.cookie.cookieBehavior", 5);
// グローバルプライバシーコントロール / Do Not Track を送る
user_pref("privacy.globalprivacycontrol.enabled", true);
// URL に付く ?fbclid= 等の追跡パラメータを除去
user_pref("privacy.query_stripping.enabled", true);
user_pref("privacy.query_stripping.enabled.pbmode", true);

/* ═══════════════════════════════════════════════════════════
   フィンガープリント対策
   ═══════════════════════════════════════════════════════════ */
// 軽量版(FPP)。サイトを壊しにくい。より厳格にしたいなら下の RFP を有効化。
user_pref("privacy.fingerprintingProtection", true);
// user_pref("privacy.resistFingerprinting", true); // ←最強だがレターボックス等の副作用あり

/* ═══════════════════════════════════════════════════════════
   ネットワーク系プライバシー (先読み・予測接続を止める)
   ═══════════════════════════════════════════════════════════ */
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.predictor.enabled", false);
user_pref("browser.urlbar.speculativeConnect.enabled", false);
user_pref("network.connectivity-service.enabled", false);
user_pref("geo.provider.network.url", "");
user_pref("browser.region.network.url", "");
user_pref("browser.region.update.enabled", false);

/* ═══════════════════════════════════════════════════════════
   URLバー / 検索 — キー入力を検索エンジンに送らない
   ═══════════════════════════════════════════════════════════ */
user_pref("browser.search.suggest.enabled", false);
user_pref("browser.urlbar.suggest.searches", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
user_pref("browser.urlbar.trimURLs", false); // 完全なURLを常に表示

/* ═══════════════════════════════════════════════════════════
   おすすめ / 広告 / Pocket を無効化
   ═══════════════════════════════════════════════════════════ */
user_pref("extensions.pocket.enabled", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("extensions.htmlaboutaddons.recommendations.enabled", false);
user_pref("browser.preferences.moreFromMozilla", false);
