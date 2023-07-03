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
**Danger** はCI/CD環境でコードレビューを機械的に実施してくれるツールで、 **Danger-Swift**[^1] はそれが Swift で書かれたものです。
設定ファイルとして `Dangerfile.swift` というスクリプトファイルにコードを記述していきます。

[^1]: https://github.com/danger/swift

iOSDC2022のパンフレットに **「CLIツールで始めるasync/await」** というタイトルで寄稿際、特に触れなかったのですが寄稿当時はSwift5.5〜5.6くらいの頃だったので、CLIツールで **async/await** を扱うためにはちょっとした制約がありました。また、同様の制約から **Danger-Swift** で **async/await** を扱うのは事実上不可能とされてきました。

風向きが変わったのはSwift 5.7からで、 **Danger-Swift** でも **async/await** を扱う展望が見えたため、本稿で解説します。

## Swift 5.6まで

簡単な例として、1秒待ってから `Hello, World!` と出力するだけのプログラムを考えてみます。
まず、実行可能なSwift Packageを作成し `main.swift` に以下の通り書いてみます。

```swift
import Foundation

try await Task.sleep(nanoseconds: 1_000_000_000)
print("Hello, World!")
```

しかし、これを実行しようとしてもトップレベルコードがConcurrencyに対応していないためビルドエラーが発生します。

```sh
/work/Sample# swift package init --type executable
(中略)
/work/Sample# swift run
/work/Sample/Sources/Sample/main.swift:3:11: error: 'async' call in a function that does not support concurrency
try await Task.sleep(nanoseconds: 1_000_000_000)
          ^
```

これを解決する手段として、エントリーポイントを `main.swift` の代わりに `@main` ディレクティブを使った型に置き換えます。

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

これを実行すると、無事実行して1秒後に `Hello, World!` が出力されました。

```sh
/work/Sample# swift run
Building for debugging...
Build complete! (0.13s)
Hello, World!
```

それでは、このコードをスクリプトファイルとして扱ってみましょう。  
一見問題がなさそうに見えますが、トップレベルコードでは `@main` が定義できない[^2]ためエラーになります。

[^2]: https://github.com/apple/swift/issues/55127

```sh
$ swift sample.swift 
sample.swift:3:1: error: 'main' attribute cannot be used in a module that contains top-level code
@main
^
sample.swift:1:1: note: top-level code defined in this source file
import Foundation
^
```

そのため、Swift 5.6まで `main.swift` やスクリプト上では `Task` を定義して `Task` の実行を `DispatchSemaphore` 等で待つといった本末転倒なワークアラウンドが必要でした。

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

## Swift 5.7 からのSwiftスクリプト
先述の通り、Swift 5.7からトップレベルコードでのConcurrencyサポート(**SE-0343**[^3])が実装されました。
これにより、 `Task` を介することなく直接 `await` が書けるようになりました。

[^3]: https://github.com/apple/swift-evolution/blob/main/proposals/0343-top-level-concurrency.md


```swift
import Foundation

try await Task.sleep(nanoseconds: 1_000_000_000)

print("Hello, World!")
```

## **Danger-Swift**について

**Danger**はCI/CD環境でコードレビューを機械的に実施してくれるツールで、**Danger-Swift**はその名の通り**Danger**がSwiftで書かれたものです。


TODO
```swift
let review = try await api.postReview(owner: owner, repository: repo_name, pullRequestNumber: prNumber, event: .approve)
let submitted = try await api.submitReview(owner: owner, repository: repo_name, pullRequestNumber: prNumber, reviewId: review.id, event: .approve)
print(submitted)
```