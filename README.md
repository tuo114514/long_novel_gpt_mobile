# Long Novel GPT Mobile

AI小说加料工具 Android版

## 技术栈
- Flutter 3.22 + Dart 3.4
- Provider 状态管理
- sqflite 本地数据库
- dio 网络请求

## 功能
- 导入TXT小说，自动分章
- AI内容分析（8维度）
- 场景识别（46类）
- 按模板加料改写
- 原文/改文对比审阅
- 导出加料版TXT

## 编译
```bash
flutter pub get
flutter build apk --release
```

APK在 `build/app/outputs/flutter-apk/app-release.apk`
