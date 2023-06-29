# Danger-Swiftでもasync/awaitがしたい！

<p align="right">
<strong>417.72KI (Twitter @417_72ki / GitHub: 417-72KI)</strong>
</p>

## はじめに
iOSDC2022のパンフレットに **「CLIツールで始めるasync/await」** というタイトルで寄稿させていただきました。寄稿当時はSwift5.5〜5.6くらいの頃だったので、CLIツールで **async/await** を扱うために`@main`ディレクティブを使ったエントリポイントを定義するか、`DispatchQueue`等を使って処理を待つ必要がありました。

その後、Swift 5.7でトップレベルコードでの **async/await** がサポートされるようになりました[^1]。その結果、`main.swift`で直接 **async/await** が書けるようになりました。それだけでなく、Swift Packageに属さないスクリプトファイルでも **async/await** が扱えるようになっています。

[^1]: https://github.com/apple/swift-evolution/blob/main/proposals/0343-top-level-concurrency.md

本記事では、Swift5.6と5.7でスクリプトファイルから **async/await** を使う方法を比較した後、Swiftで書くスクリプトの代表例として、**Danger-Swift**[^2]の設定ファイルとなる`Dangerfile.swift`で **async/await** を取り扱った事例をご紹介します。

[^2]: https://github.com/danger/swift

## スクリプトファイルにおける制約

簡単な例として以下のようなスクリプトを考えてみます。

```swift
#!/usr/env/swift

import Foundation

@main
struct Foo {
    static func main() async throws {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        print("Hello, World!")
    }
}
```

一見良さそうに見えますが、これはエラーになります。

```sh
$ swift sample.swift 
sample.swift:5:1: error: 'main' attribute cannot be used in a module that contains top-level code
@main
^
sample.swift:1:1: note: top-level code defined in this source file
#!/usr/env/swift
^
```

これはトップレベルコードでは `@main` が定義できないという仕様によるものです[^3]。

[^3]: 厳密には仕様ではなくバグの可能性もあり、一応[Issue](https://github.com/apple/swift/issues/55127)も上がっています。

## **Danger-Swift**について

**Danger**はCI/CD環境でコードレビューを機械的に実施してくれるツールで、**Danger-Swift**はその名の通り**Danger**がSwiftで書かれたものです。
