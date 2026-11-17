# 随手抽签 iOS Demo

这是一个用于跑通 **Windows 开发 -> GitHub Actions 云编译 -> 自签安装到 iPhone** 的最小 Flutter 示例。

## 使用步骤
1. 在 GitHub 新建一个仓库（公开或私有均可）。
2. 将本目录代码推送到 GitHub 的 `main` 或 `master` 分支。
3. 打开 GitHub 仓库的 **Actions** 标签页，等待 `Build iOS IPA` 运行完成（约 3~5 分钟）。
4. 在运行结果页面底部的 **Artifacts** 中下载 `ios-picker-unsigned.zip` 并解压出 `.ipa` 文件。
5. 在 Windows 上使用 **Sideloadly**（插上数据线，输入个人 Apple ID）将该 `.ipa` 安装到你的 iPhone。
