---
title: Danger-Swiftでもasync/awaitがしたい！
author: '417.72KI (Twitter @417_72ki / GitHub: 417-72KI)'
papersize: a4
geometry: margin=20mm
header-includes: |
  <style>
    pre > code.sourceCode { white-space: pre-wrap; position: relative; }
    div.sourceCode code.swift { color: #000000; }
    code.swift span.at { color: #9B2393; font-weight: bold; } /* Attribute */
    code.swift span.kw { color: #9B2393; font-weight: bold; } /* Keyword */
    code.swift span.fu { color: #9B2393; font-weight: bold; } /* Function */
    code.swift span.cf { color: #9B2393; font-weight: bold; } /* ControlFlow */

    code.swift span.dv { color: #1c00cf; } /* DecVal */
    code.swift span.st { color: #c41a16; } /* String */
  </style>
---

## はじめに
iOSDC2022のパンフレットに **「CLIツールで始めるasync/await」** というタイトルで寄稿させていただきました。寄稿当時はSwift5.5〜5.6くらいの頃だったので、CLIツールで **async/await** を扱うために `@main` ディレクティブを使ったエントリポイントを定義するか、 `DispatchQueue` 等を使って処理を待つ必要がありました。

その後、Swift 5.7でトップレベルコードでの **async/await** がサポートされるようになりました[^1]。その結果、 `main.swift` で直接 **async/await** が書けるようになりました。それだけでなく、Swift Packageに属さないスクリプトファイルでも **async/await** が扱えるようになっています。

[^1]: https://github.com/apple/swift-evolution/blob/main/proposals/0343-top-level-concurrency.md

本記事では、Swift5.6と5.7でスクリプトファイルから **async/await** を使う方法を比較した後、Swiftで書くスクリプトの代表例として、**Danger-Swift**[^2]の設定ファイルとなる `Dangerfile.swift` で **async/await** を取り扱った事例をご紹介します。

[^2]: https://github.com/danger/swift

## Swift 5.6までのSwiftスクリプト

簡単な例として以下のようなスクリプトを考えてみます。

```swift
import Foundation

@main
struct Foo {
    static func main() async throws {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        print("Hello, World!")
    }
}
```

一見良さそうに見えますが、トップレベルコードでは `@main` が定義できない[^3]ためエラーになります。

[^3]: https://github.com/apple/swift/issues/55127

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
先述の通り、Swift 5.7からトップレベルコードでのConcurrencyサポート(**SE-0343**)が実装されました。
これにより、 `Task` を介することなく直接 `await` が書けるようになりました。

```swift
import Foundation

try await Task.sleep(nanoseconds: 1_000_000_000)

print("Hello, World!")
```

## **Danger-Swift**について

**Danger**はCI/CD環境でコードレビューを機械的に実施してくれるツールで、**Danger-Swift**はその名の通り**Danger**がSwiftで書かれたものです。
