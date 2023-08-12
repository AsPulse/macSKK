// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import SwiftUI

// これをObservableObjectにする?
// どうすればUserDefaultsとグローバル変数dictionaryのdictsと同期させる方法がまだよくわかってない
// @AppStorageを使う…?
final class DictSetting: ObservableObject, Identifiable {
    typealias ID = String
    @Published var filename: String
    @Published var enabled: Bool
    @Published var encoding: String.Encoding
    
    var id: String { filename }
    
    init(filename: String, enabled: Bool, encoding: String.Encoding) {
        self.filename = filename
        self.enabled = enabled
        self.encoding = encoding
    }

    init?(_ dictionary: [String: Any]) {
        guard let filename = dictionary["filename"] as? String else { return nil }
        self.filename = filename
        guard let enabled = dictionary["enabled"] as? Bool else { return nil }
        self.enabled = enabled
        guard let encoding = dictionary["encoding"] as? UInt else { return nil }
        self.encoding = String.Encoding(rawValue: encoding)
    }

    func encode() -> [String: Any] {
        ["filename": filename, "enabled": enabled, "encoding": encoding.rawValue]
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    /// CheckUpdaterで取得した最新のリリース。取得前はnil
    @Published var latestRelease: Release? = nil
    /// リリースの確認中かどうか
    @Published var fetchingRelease: Bool = false
    /// すべての利用可能なSKK辞書の設定
    @Published var fileDicts: [DictSetting] = []
    // 辞書ディレクトリ
    private let dictionariesDirectoryUrl: URL
    private var source: DispatchSourceFileSystemObject?
    private var cancellables = Set<AnyCancellable>()

    init(dictionariesDirectoryUrl: URL) throws {
        self.dictionariesDirectoryUrl = dictionariesDirectoryUrl
        // SKK-JISYO.Lのようにファイルの読み込みが遅いのでバックグラウンドで処理
        $fileDicts.receive(on: DispatchQueue.global()).filter({ !$0.isEmpty }).sink { dictSettings in
            dictSettings.forEach { dictSetting in
                if let dict = dictionary.fileDict(id: dictSetting.id) {
                    if dictSetting.enabled {
                        if dictSetting.encoding != dict.encoding {
                            // encodingを変えて読み込み直す
                            let fileURL = dictionariesDirectoryUrl.appendingPathComponent(dictSetting.filename)
                            do {
                                logger.log("\(dictSetting.filename)を読み込みます")
                                let fileDict = try FileDict(contentsOf: fileURL, encoding: dictSetting.encoding)
                                logger.log("\(dictSetting.filename)から \(fileDict.entries.count) エントリ読み込みました")
                                dictionary.replateDict(fileDict)
                            } catch {
                                logger.log("SKK辞書 \(dictSetting.filename) の読み込みに失敗しました: \(error)")
                            }
                        }
                    } else {
                        // dictをdictionaryから削除する
                        _ = dictionary.deleteDict(id: dictSetting.id)
                        logger.log("SKK辞書 \(dictSetting.filename) を無効化しました")
                    }
                } else if dictSetting.enabled {
                    // dictSettingsの設定でFileDictを読み込んでdictionaryに追加
                    let fileURL = dictionariesDirectoryUrl.appendingPathComponent(dictSetting.filename)
                    do {
                        logger.log("\(dictSetting.filename)を読み込みます")
                        let fileDict = try FileDict(contentsOf: fileURL, encoding: dictSetting.encoding)
                        dictionary.appendDict(fileDict)
                        logger.log("\(dictSetting.filename)から \(fileDict.entries.count) エントリ読み込みました")
                    } catch {
                        logger.log("SKK辞書 \(dictSetting.filename) の読み込みに失敗しました: \(error)")
                        // FIXME: dictSetting.enabledをfalseにしたほうがよい?
                        // FIXME: 環境設定の辞書設定画面で読み込みエラー理由が表示できるとよさそう
                    }
                }
            }
            // dictSettingsをUserDefaultsに永続化する
            UserDefaults.standard.set(self.fileDicts.map { $0.encode() }, forKey: "dictionaries")
        }
        .store(in: &cancellables)
    }

    // PreviewProvider用
    internal init(dictSettings: [DictSetting]) throws {
        dictionariesDirectoryUrl = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ).appendingPathComponent("Dictionaries")
        self.fileDicts = dictSettings
    }

    deinit {
        source?.cancel()
    }

    // fileDictsが設定されてから呼び出すこと。
    // じゃないとSKK-JISYO.Lのようなファイルが refreshDictionariesDirectoryでfileDictsにない辞書ディレクトリにあるファイルとして
    // enabled=falseでfileDictsに追加されてしまい、読み込みスキップされたというログがでてしまうため。
    // FIXME: 辞書設定が設定されたイベントをsinkして設定されたときに一回だけsetupEventsを実行する、とかのほうがよさそう。
    func setDictSettings(_ dictSettings: [DictSetting]) throws {
        self.fileDicts = dictSettings
        if !isTest() {
            try watchDictionariesDirectory()
            refreshDictionariesDirectory()
        }
    }

    /// 辞書ディレクトリを監視して変更があった場合にfileDictsを更新する
    /// DictSettingが変更されてないときは辞書ファイルの再読み込みは行なわない (需要があれば今後やるかも)
    func watchDictionariesDirectory() throws {
        // dictionaryDirectoryUrl直下のファイルを監視してfileDictsにないファイルがあればfileDictsに追加する
        let fileDescriptor = open(dictionariesDirectoryUrl.path(percentEncoded: true), O_EVTONLY)
        if fileDescriptor < 0 {
            logger.log("辞書ディレクトリのファイルディスクリプタ取得で失敗しました: code=\(fileDescriptor)")
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: [.write, .delete])
        source.setEventHandler {
            logger.log("辞書ディレクトリでファイルイベントが発生しました")
            self.refreshDictionariesDirectory()
        }
        source.setCancelHandler {
            logger.log("辞書ディレクトリの監視がキャンセルされました")
            source.cancel()
        }
        self.source = source
        source.activate()
    }

    /// 辞書ディレクトリを見て辞書設定と同期します。起動時とディレクトリのイベント時に実行します。
    /// - ディレクトリにあって辞書設定にないファイルができている場合は、enabled=false, encoding=euc-jpで辞書設定に追加し、UserDefaultsを更新する
    /// - ディレクトリになくて辞書設定にあるファイルができている場合は、読み込み辞書から設定を削除する? enabled=falseにする?
    func refreshDictionariesDirectory() {
        // 辞書ディレクトリ直下にあるファイル一覧をみていく。シンボリックリンク、サブディレクトリは探索しない。
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .nameKey]
        let enumerator = FileManager.default.enumerator(at: self.dictionariesDirectoryUrl,
                                                        includingPropertiesForKeys: Array(resourceKeys),
                                                        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        guard let enumerator else {
            logger.error("辞書フォルダのファイル一覧が取得できません")
            return
        }

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                  let isDirectory = resourceValues.isDirectory,
                  let filename = resourceValues.name
            else {
                continue
            }
            if isDirectory || filename == UserDict.userDictFilename {
                continue
            }
            if self.fileDicts.first(where: { $0.filename == filename }) == nil {
                // UserDefaultsの辞書設定に存在しないファイルが見つかったので辞書設定に無効化状態で追加
                logger.log("新しい辞書らしきファイル \(filename) がみつかりました")
                self.fileDicts.append(DictSetting(filename: filename, enabled: false, encoding: .japaneseEUC))
            }
        }
    }

    /**
     * リリースの確認を行う
     */
    func fetchReleases() async throws {
        fetchingRelease = true
        defer {
            fetchingRelease = false
        }
        latestRelease = try await LatestReleaseFetcher.shared.fetch()
    }
}
