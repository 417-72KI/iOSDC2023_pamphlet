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
**Danger**はCI/CD環境でコードレビューを機械的に実施してくれるツールで、**Danger-Swift**[^1] はそれが Swift で書かれたものです。
設定ファイルとして`Dangerfile.swift`というファイルにコードを記述していきます。

[^1]: https://github.com/danger/swift

iOSDC2022のパンフレットに **「CLIツールで始めるasync/await」** というタイトルで寄稿した際、特に触れなかったのですが当時はSwift5.5〜5.6くらいの頃だったので、CLIツールで**async/await**を扱うためにはちょっとした制約がありました。また、同様の制約から**Danger-Swift**で**async/await**を扱うのは事実上不可能とされてきました。

風向きが変わったのはSwift 5.7からで、**Danger-Swift**でも**async/await**を扱う展望が見えたため、本稿で解説します。

## **Danger-Swift**について

**Danger**はCI/CD環境でコードレビューを機械的に実施してくれるツールで、**Danger-Swift**はその名の通り**Danger**がSwiftで書かれたもの[^2]です。
詳細は省きますが`Dangerfile.swift`をスクリプトファイルとして実行する仕様になっています。

このスクリプトファイルについて触れる前に、CLIツールにおける**async/await**の取り扱いについて解説します。

[^2]: 正確には**Danger-JS**をSwiftでラップしたものになります

## CLIツールと**async/await**

### Swift 5.6まで

簡単な例として、「1秒待ってから`Hello, World!`と出力する」プログラムを考えてみます。
まず、実行可能なSwift Packageを作成し`main.swift`に以下の通り書いてみます。

```swift
import Foundation

try await Task.sleep(nanoseconds: 1_000_000_000)
print("Hello, World!")
```

しかし、これを実行しようとしてもトップレベルコードがConcurrencyに対応していないためビルドエラーが発生します。

```sh
/work/PackageSample$ swift package init --type executable
(中略)
/work/PackageSample$ swift run
/work/PackageSample/Sources/PackageSample/main.swift:3:11: error: 'async' call in a function that does not support concurrency
try await Task.sleep(nanoseconds: 1_000_000_000)
          ^
```

これを解決する手段として、エントリーポイントを`main.swift`の代わりに`@main`ディレクティブを使った型に置き換えます。
ここでは`main.swift`を消して`Foo.swift`を作成します。

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

このことから、スクリプトファイルは`main.swift`と同様の制約が存在することが分かります。

そして、Swift 5.6 までは`Task`を定義して`Task`の実行を`DispatchSemaphore`等で待つといった本末転倒なワークアラウンドが必要でした。

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

<br><br><br>

### Swift 5.7 以降
先述の通り、Swift 5.7からトップレベルコードでのConcurrencyサポート(**SE-0343**[^4])が実装されました。
これにより、`main.swift`やスクリプトでも`Task`を介することなく直接`await`が書けるようになりました。

[^4]: https://github.com/apple/swift-evolution/blob/main/proposals/0343-top-level-concurrency.md


```swift
import Foundation

try await Task.sleep(nanoseconds: 1_000_000_000)

print("Hello, World!")
```

## **Danger-Swift**と**async/await**

`Dangerfile.swift`で使う`Danger`の API にGitHub APIを扱う**octokit.swift**[^5] のAPIが含まれています。
Swift 5.7で**async/await**を使って呼び出せるようになったことで、 GitHub API を使ったバリデーションや PR の操作がしやすくなります。
例えば、「警告やエラーが無かったら自動でApproveする」といったことができるようになります。

[^5]: https://github.com/nerdishbynature/octokit.swift

※ 以下で書いている`postReview`や`submitReview`はPR[^6]を出している途中のものでまだ**octokit.swift**上でリリースされていません。
現状の**Danger-Swift**でもこれらのAPIは使用できない[^7]ため、将来的に実現できる理想のコードになります。

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
    let submitted = try await api.submitReview(
        owner: owner,
        repository: repository,
        pullRequestNumber: prNumber,
        reviewId: review.id,
        event: .approve
    )
    print(submitted)
}
```

APIの仕様上Approveをつけるために2つのAPIを叩く必要があるため、それだけでも**async/await**で直列に書けるメリットが分かるかと思います。

## 終わりに
