---
title: Danger-Swiftでもasync/awaitがしたい！
author: '417.72KI (Twitter @417_72ki / GitHub: 417-72KI)'
papersize: a4
geometry: margin=20mm
header-includes: |
  <style>
    div.sourceCode { background-color: #ffffff; }
    pre.sourceCode:before { border: 1px solid #2a211c; content: " "; position: absolute; z-index: -1; }
    pre.sourceCode { border: 1px solid #2a211c; }
    pre code.sourceCode { white-space: pre-wrap; position: relative; }

    div.sourceCode code.swift { color: #000000; }
    code.swift span.at { color: #9b2393; font-weight: bold; } /* Attribute */
    code.swift span.kw { color: #9b2393; font-weight: bold; } /* Keyword */
    code.swift span.fu { color: #9b2393; font-weight: bold; } /* Function */
    code.swift span.cf { color: #9b2393; font-weight: bold; } /* ControlFlow */

    code.swift span.dv { color: #1c00cf; } /* DecVal */
    code.swift span.st { color: #c41a16; } /* String */

    div.sourceCode pre.sh { background-color: #000000; }
    div.sourceCode code.bash { color: #28fe14; }
    code.bash span.kw { color: #28fe14; font-weight: bold; }
    code.bash span.er { color: #28fe14; font-weight: bold; }
  </style>
---

## はじめに
iOSDC 2022のパンフレットに **「CLIツールで始めるasync/await」** というタイトルで寄稿しました。その際は特に触れなかったのですが、当時はSwift5.5〜5.6くらいの頃だったので、トップレベルコードでasync/awaitを直接扱えないという制約がありました。また、同様の制約からDanger-Swift[^1] でasync/awaitを扱うのは事実上不可能とされてきました。

[^1]: https://github.com/danger/swift

風向きが変わったのはSwift 5.7からで、 Danger-Swiftでもasync/awaitを扱う展望が見えたため、本稿で解説します。

## エントリーポイントとトップレベルコード
プログラムが実行される際最初に呼び出される部分をエントリーポイントと呼び、Swiftにおいては `main.swift` や `@main` ディレクティブが付いた型の `static func main()` 等がそれに該当します。
また `main.swift` やSwiftスクリプトには処理を直接記述でき、これをトップレベルコードと呼びます。

## Danger-Swift について

DangerはCI/CD環境でコードレビューを機械的に実施してくれるツールです。元々Rubyで書かれていましたが、それをSwiftで移植した[^2]のがDanger-Swiftです。
詳細は省きますが`Dangerfile.swift`をスクリプトファイルとして実行する仕様になっています。

このスクリプトファイルでasync/awaitを取り扱うために、まずは前提としてCLIツールにおけるasync/awaitの取り扱いについて解説します。

[^2]: 正確にはJavaScriptで書かれたDanger-JSをSwiftでラップしたものになります

## CLIツールと async/await 

### Swift 5.6まで

簡単な例として、「1秒待ってから`Hello, World!`と出力する」プログラムを考えてみます。
まず、実行可能なSwift Packageを作成し`main.swift`に以下の通り書いてみます。

```swift
import Foundation

try await Task.sleep(nanoseconds: 1_000_000_000)
print("Hello, World!")
```

しかし、これを実行しようとしてもトップレベルコードがasync/awaitに対応していないためビルドエラーが発生します。

```sh
/work/PackageSample$ swift package init --type executable
(中略)
/work/PackageSample$ swift run
/work/PackageSample/Sources/PackageSample/main.swift:3:11: error: 'async' call in a function that does not support concurrency
try await Task.sleep(nanoseconds: 1_000_000_000)
          ^
```

これを解決する手段として、エントリーポイントを`main.swift`の代わりに`@main`ディレクティブを使った型に置き換えます。
ここでは`main.swift`を消して`Foo.swift`を作成します。その際、 `main()` に `async` を付与することでasync/awaitに対応させることができます。

```swift
import Foundation

@main
enum Foo {
    static func main() async throws {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        print("Hello, World!")
    }
}
```

これを実行すると、無事実行して1秒後に`Hello, World!`が出力されました。

```sh
/work/PackageSample$ swift run
Building for debugging...
Build complete! (0.13s)
Hello, World!
```

それでは、このコードを単体のスクリプトファイルとして扱ってみましょう。

```sh
$ swift Sources/PackageSample/Foo.swift
Sources/PackageSample/Foo.swift:3:1: error: 'main' attribute cannot be used in a module that contains top-level code
@main
^
Sources/PackageSample/Foo.swift:1:1: note: top-level code defined in this source file
import Foundation
^
Sources/PackageSample/Foo.swift:1:1: note: pass '-parse-as-library' to compiler invocation if this is intentional
import Foundation
^
```

トップレベルコードでは`@main`が定義できない[^3]というエラーになってしまいました。

[^3]: https://github.com/apple/swift/issues/55127

<!-- textlint-disable ja-technical-writing/no-doubled-joshi -->
このことから、スクリプトファイルは`main.swift`と同様の制約が存在することが分かります。
<!-- textlint-enable ja-technical-writing/no-doubled-joshi -->

そして、Swift 5.6までは`Task`を定義して`Task`の実行を`DispatchSemaphore`等で待つといった本末転倒なワークアラウンドが必要でした。

```swift
import Foundation

let semaphore = DispatchSemaphore(value: 0)
Task {
    try await Task.sleep(nanoseconds: 1_000_000_000)

    print("Hello, World!")

    semaphore.signal()
}
semaphore.wait()
```

### Swift 5.7 以降
先述の通り、Swift 5.7からトップレベルコードでのConcurrencyサポート(**SE-0343**[^4])が実装されました。
これにより、`main.swift`やスクリプトでも`Task`を介することなく直接`await`が書けるようになりました。

[^4]: https://github.com/apple/swift-evolution/blob/main/proposals/0343-top-level-concurrency.md


```swift
import Foundation

try await Task.sleep(nanoseconds: 1_000_000_000)

print("Hello, World!")
```

## Danger-Swift と async/await
さて、本題となるDanger-Swiftについてですがここまで読めばもう`Dangerfile.swift`でasync/awaitを扱う方法について解説する必要はもはや無いと言っても過言ではありません。  
では、`Dangerfile.swift`でasync/awaitが扱えると何が嬉しいのでしょうか？

実は`Dangerfile.swift`で使うDangerのAPIにGitHub APIを扱う**Octokit.swift**[^5] のAPIが含まれており、`Dangerfile.swift`から直接GitHub APIを呼び出すことができました。
しかし、Swift 5.6までは前述の通りasync/awaitを直接扱うことができなかったため、`DispatchSemaphore`等によるワークアラウンドが必須でした。

Swift 5.7でasync/awaitを使って呼び出せるようになったことで、 GitHub APIを使ったバリデーションやPRの操作がシンプルに書けるようになりました。

[^5]: https://github.com/nerdishbynature/octokit.swift

以下に「警告やエラーが無かったら自動でApproveする」例を記載しています。

※ このコードで呼び出している`postReview`や`submitReview`はPR[^6]を出している途中のものでまだOctokit.swift上でリリースされていません。
現状のDanger-SwiftでもこれらのAPIは使用できない[^7]ため、将来的に実現できるであろうコードを紹介します。

[^6]: https://github.com/nerdishbynature/octokit.swift/pull/171
[^7]: 7/4現在

```swift
import Danger

let danger = Danger()

SwiftLint.lint(inline: true)

(中略)

if (danger.warnings + danger.fails).isEmpty {
    let api = danger.github.api
    // Reviewを開始する
    let review = try await api.postReview(
        owner: owner, 
        repository: repository, 
        pullRequestNumber: prNumber, 
        event: .approve
    )
    // Reviewを完了する
    try await api.submitReview(
        owner: owner,
        repository: repository,
        pullRequestNumber: prNumber,
        reviewId: review.id,
        event: .approve
    )
}
```

APIの仕様上Approveをつけるために2つのAPIを叩く必要があるため、それだけでもasync/awaitで直列に書けるメリットが分かるはずです。

## 終わりに
トップレベルコードでasync/awaitが扱えるようになったことで、Danger-Swiftをもっとリッチに扱える環境が整いました。
今回はDanger-Swiftに内蔵しているOctokit.swiftのAPIを使う例で書いていますが`URLSession`を使った通常の通信処理もasync/awaitで扱えるため、JIRA・Trello・Notion等のツールと連携してPRの状態を管理するといったことも簡単にできるようになるでしょう。

これを機にDanger-Swiftを使った事例が増えてコミュニティがもっと活発になってくれれば幸いです。
