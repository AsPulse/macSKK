macSKK [![test](https://github.com/mtgto/macSKK/actions/workflows/test.yml/badge.svg)](https://github.com/mtgto/macSKK/actions/workflows/test.yml)
====
macSKKはmacOS用の[SKK](https://ja.wikipedia.org/wiki/SKK)方式の日本語入力システム (インプットメソッド) です。

macOS用のSKK方式の日本語入力システムにはすでに[AquaSKK](https://github.com/codefirst/aquaskk/)がありますが、いくつか独自の機能を作りたいと思い新たに開発しています。

macSKKを使用するには macOS 13.3 以降が必要です。
Universal Binaryでビルドしていますが、動作確認はApple Silicon環境でのみ行っています。

## 特徴

- 日本語入力システムはパスワードなどの機密情報を処理する可能性があるため安全性が求められるプログラムです。そのためmacSKKはmacOSのSandbox機構を使いネットワーク通信やファイルの読み書きに制限をかけることでセキュリティホールを攻撃されたときの被害を減らすように心掛けます。
- 不正なコードが含まれるリスクを避けるため、サードパーティによる外部ライブラリは使用していません。
- すべてをSwiftだけでコーディングしており、イベント処理にCombineを、UI部分にはSwiftUIを使用しています。
- 単語登録モードや送り仮名入力中などキー入力による状態変化管理が複雑なのでユニットテストを書いてエンバグのリスクを減らす努力をしています。

## 実装予定

しばらくはAquaSKKにはあるけどmacSKKにない機能を実装しつつ、徐々に独自機能を実装していこうと考えています。

- [x] 複数辞書を使用できるようにする
- [x] マイ辞書に保存しないプライベートモード
- [x] アプリごとに直接入力させるかどうかを設定できるようにする
  - ddskkを使っているときのGUI版Emacs.appなど
- [x] 過去の入力を使った入力補完
- [x] 数値変換
- [x] 送りありエントリのブロック形式
- [ ] Java AWT製アプリケーションで入力ができない問題のワークアラウンド対応 (JetBrain製品など)
- [ ] キー配列の設定 (Dvorakなど)

### 実装予定の独自機能

- [x] 自動更新確認
  - Network Outgoingが可能なXPCプロセスを作成し、GitHub Releasesから情報を定期的に取得して新しいバージョンが見つかったらNotification Centerに表示する
- [ ] iCloudにマイ辞書を保存して他環境と共有できるようにする
- [ ] マイ辞書の暗号化
  - 編集したい場合は生データでのエクスポート & インポートできるようにする

## インストール

2023年現在、Mac App Storeでは日本語入力システムを配布することができないため、[Appleのソフトウェア公証](https://support.apple.com/ja-jp/guide/security/sec3ad8e6e53/1/web/1)を受けたアプリケーションバイナリを[GitHub Releases](https://github.com/mtgto/macSKK/releases/latest)で配布しています。dmgファイルをダウンロードしマウントした中にあるpkgファイルからインストールしてください。

macSKKのインストール後に、システム設定→キーボード→入力ソースから「ひらがな (macSKK)」と「ABC (macSKK)」を追加してください。カタカナ、全角英数、半角カナは追加しなくても問題ありません。
もしインストール直後に表示されなかったり、バージョンアップしても反映されない場合はログアウト & ログインを試してみてください。

SKK辞書は `~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries` に配置してください。
その後、入力メニュー→環境設定を開き、辞書設定で使用する辞書を有効に切り替えてください。EUC-JPでないエンコーディングの場合はiボタンからエンコーディングを切り替えてください。

ユーザー辞書は `~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries/skk-jisyo.utf8` にUTF-8形式で保存されます。
ユーザー辞書はテキストエディタで更新可能です。別プロセスでユーザー辞書が更新された場合はmacSKKが自動で再読み込みを行います。

## 機能

### 単語登録

有効な辞書で有効な読みが見つからない場合、単語登録モードに移行します。

例として "あああ" で変換しようとしたが辞書になかった場合 `[登録：あああ]` のようなテキストが表示されます。

この状態でテキストを入力しEnterすることでユーザー辞書にその読みで登録されます。漢字変換も可能ですが単語登録モードで変換候補がない変換が行われた場合は入力されなかったと扱い、入れ子で単語登録モードには入れなくなっています。

AquaSKKと同様、単語登録モードでのみ `C-y` でクリップボードからペーストできます。通常のペースト `Cmd-v` はアクティブなアプリケーションに取られて利用できないため、特殊なキーバインドにしています。

単語登録をしない場合はEscキーや `C-g` でキャンセルしてください。

### 読みの補完

入力中、ユーザー辞書にある送りなし変換エントリから先頭が一致する変換履歴がある場合、入力テキストの下部に候補を表示します。タブキーを押すことで表示されているところまで入力が補完されます。

現在、補完の対象となるのはユーザー辞書の送りなしエントリだけです。

### 数値変換

辞書に "だい# /第#0/第#1/" のように、読みに"#"、変換候補に "#(数字)" を含むエントリは数値変換エントリです。

macSKKではタイプ0, 1, 2, 3, 8, 9に対応しています。
数値として使えるのは0以上2^63-1 (Int64.max) までです。

ユーザー辞書に追加される変換結果は "だい# /第#0/" のように実際の入力に使用した数値は含みません。

### プライベートモード

プライベートモードが有効なときは変換結果がユーザー辞書に反映されません。ユーザー辞書以外の辞書やプライベートモードを有効にする前のユーザー辞書の変換候補は参照されます。

プライベートモードの有効・無効は入力メニュー→プライベートモードから切り替えできます。

### 直接入力

直接入力を有効にしたアプリケーションでは、日本語変換処理を行いません。独自でIME機能を持つEmacs.appなどで使用することを想定しています。

直接入力の有効・無効の切り替えは、切り替えたいアプリケーションが最前面のときに入力メニュー→"(アプリ名)で直接入力"から行えます。
また有効になっているアプリケーションのリストは設定→直接入力から確認できます。

直接入力を有効にしたアプリケーションはBundle Identifier単位で記録しているため、アプリケーションを移動させても設定は無効になりません。また特殊なGUIアプリケーションはBundle Identifierをもたないため直接入力を設定できません (Android StudioのAndroidエミュレータとか)。

### ユーザー辞書の自動保存

ユーザー辞書が更新された場合、一定期間おきにファイル書き出しが行われます。またmacSKKプロセスが正常終了する際にファイル書き出しが終わっていない更新がある場合はファイル書き出しを行ってから終了します。
もし即座にファイル書き出ししたい場合は入力メニューから"ユーザー辞書を今すぐ保存"を選んでください。

Command + Option + Escからの強制終了では保存されないので注意してください。

### バージョンの自動チェック

macSKKは現在開発中のアプリケーションです。そのため安定していない可能性が高いです。
なるべく不具合が修正された最新バージョンを使っていただきたいため、定期的に新しいバージョンがないかをチェックして見つかった場合は通知センターで通知します。

新規バージョンの確認はGitHubのReleasesページのAtom情報を取得して行います。
バージョンチェックは12時間おきにバックグラウンドで実行されます。

macSKKアプリ自体はApp Sandboxでインターネット通信ができないように設定しているため、GitHubのReleaseページの取得はmacSKKからXPCを介して外部プロセスで行います。

## アンインストール

現在アンインストールする手順は用意していないためお手数ですが手動でお願いします。
今後、dmg内にアンインストーラを同梱予定です。

手動で行うには、システム設定→キーボード→入力ソースから「ひらがな (macSKK)」「ABC (macSKK)」を削除後、以下のファイルを削除してください。

- `~/Library/Input Methods/macSKK.app`
- `~/Library/Containers/net.mtgto.inputmethod.macSKK`

## FAQ

### Q. Visual Studio Code (vscode) で `C-j` を押すと行末が削除されてしまいます

A. `C-j` がVisual Studio Codeのキーボードショートカット設定の `editor.action.joinLines` にデフォルトでは割り当てられていると思われます。`Cmd-K Cmd-S` から `editor.action.joinLines` で検索し、キーバインドを削除するなり変更するなりしてみてください。

### Q. Wezterm で `C-j` を押すと改行されてしまいます

A. [macos_forward_to_ime_modifier_mask](https://wezfurlong.org/wezterm/config/lua/config/macos_forward_to_ime_modifier_mask.html) に `CTRL` を追加することでIMEに `C-j` が渡されてひらがなモードに切り替えできるようになります。 `SHIFT` も入れておかないと漢字変換開始できなくなります。

## 開発

Xcodeでビルドし、 `~/Library/Input Methods` に `macSKK.app` を配置してからシステム設定→キーボード→入力ソースで `ひらがな (macSKK)` などを追加してください。

### バージョンアップ

`X.Y.Z` 形式のバージョン (MARKETING_VERSION) とビルド番号 (CURRENT_PROJECT_VERSION) の更新が必要です。

#### ビルド番号

メジャー、マイナー、パッチ、どのバージョンアップでも1ずつインクリメントしてください。
Xcodeから手動でやってもいいし、`agvtool`でもいいです。

```console
agvtool next-version
```

#### MARKETING_VERSIONの更新

`Info.plist`に`CFBundleShortVersionString`で管理するのではなくpbxprojに`MARKETING_VERSION`で管理する形式だと`agvtool next-marketing-version` が使えないみたいなのでXcodeで手動で変えてください。

### リリース

- CHANGELOGを記述
- バージョンアップ
- `make clean && make release`
- GitHubのReleaseを作成、dmgとdSYMsをアップロード、CHANGELOGをコピペ

## ライセンス

macSKKはGNU一般公衆ライセンスv3またはそれ移行のバージョンの条項の元で配布されるフリー・ソフトウェアです。

詳細は `LICENSE` を参照してください。
