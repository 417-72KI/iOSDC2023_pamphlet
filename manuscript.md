# Danger-Swiftでもasync/awaitがしたい！

<p align="right">
<strong>417.72KI (Twitter @417_72ki / GitHub: 417-72KI)</strong>
</p>

<hr>

### はじめに
iOSDC2022のパンフレットに **「CLIツールで始めるasync/await」** というタイトルで寄稿させていただきました。寄稿当時はSwift5.5〜5.6くらいの頃だったので、CLIツールで **async/await** を扱うために`@main`ディレクティブを使ったエントリポイントを定義するか、`DispatchQueue`等を使って処理を待つ必要がありました。

その後、Swift 5.7でトップレベルコードでの **async/await** がサポートされるようになりました※1。その結果、`main.swift`で直接 **async/await** が書けるようになりました。それだけでなく、Swift Packageに属さないスクリプトファイルでも **async/await** が扱えるようになっています。

Swiftで書くスクリプトの代表例として、**Danger-Swift**の設定ファイルとなる`Dangerfile.swift`が挙げられます。
**Danger**はCI/CD環境でコードレビューを機械的に実施してくれるツールで、**Danger-Swift**はその名の通り**Danger**がSwiftで書かれたものです。
