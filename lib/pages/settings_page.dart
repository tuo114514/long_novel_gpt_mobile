import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/project_provider.dart';
import '../models/api_config.dart';
import '../services/api_service.dart';
import '../services/config_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _urlCtrl = TextEditingController(), _keyCtrl = TextEditingController();
  String _model = '', _templateName = '';
  double _temp = 0.7, _maxTokens = 4096;
  int _enhanceLevel = 2, _concurrency = 1;
  bool _autoRetry = true;
  List<Map<String, String>> _models = [];
  bool _loadingModels = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<ProjectProvider>();
    _urlCtrl.text = p.apiConfig.baseUrl;
    _keyCtrl.text = p.apiConfig.apiKey;
    _model = p.apiConfig.model;
    _temp = p.apiConfig.temperature;
    _maxTokens = p.apiConfig.maxTokens.toDouble();
    _enhanceLevel = p.apiConfig.defaultEnhanceLevel;
    _concurrency = p.apiConfig.concurrency;
    _autoRetry = p.apiConfig.autoRetry;
    _templateName = p.template?.name ?? '';
    _initModels();
  }

  Future<void> _initModels() async {
    final models = await ApiService().getCachedModels(_urlCtrl.text.trim());
    if (models.isNotEmpty && mounted) setState(() => _models = models);
  }

  Future<void> _fetchModels() async {
    setState(() => _loadingModels = true);
    try {
      _models = await ApiService().fetchModels(_urlCtrl.text.trim(), _keyCtrl.text.trim());
      if (_models.isNotEmpty && !_models.any((m) => m['id'] == _model)) _model = _models.first['id'] ?? _model;
    } catch (e) { _snack('获取失败: $e'); }
    setState(() => _loadingModels = false);
  }

  void _preset(String url, String model) { _urlCtrl.text = url; _model = model; ApiService().clearModelCache(url); _models = []; }

  Future<void> _importTemplate() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path == null) return;
      await context.read<ProjectProvider>().loadTemplate(path);
      setState(() => _templateName = context.read<ProjectProvider>().template?.name ?? '');
      _snack('模板加载成功: $_templateName');
    } catch (e) { _snack('模板加载失败: $e'); }
  }

  Future<void> _save() async {
    final config = ApiConfig(baseUrl: _urlCtrl.text.trim(), apiKey: _keyCtrl.text.trim(), model: _model, temperature: _temp, maxTokens: _maxTokens.toInt(), defaultEnhanceLevel: _enhanceLevel, concurrency: _concurrency, autoRetry: _autoRetry);
    await context.read<ProjectProvider>().saveConfig(config);
    _snack('设置已保存');
  }

  Future<void> _test() async {
    final config = ApiConfig(baseUrl: _urlCtrl.text.trim(), apiKey: _keyCtrl.text.trim(), model: _model);
    await ConfigService().saveConfig(config);
    final ok = await ApiService().testConnection();
    _snack(ok ? '连接成功 ✅' : '连接失败 ❌');
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  void dispose() { _urlCtrl.dispose(); _keyCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // ─── 模板 ───
        _sec('加料模板'),
        Card(child: ListTile(
          title: Text(_templateName.isNotEmpty ? _templateName : '未加载模板', style: TextStyle(fontWeight: FontWeight.w500, color: _templateName.isNotEmpty ? Colors.blue : Colors.grey)),
          subtitle: const Text('导入 GPT0625 JSON 格式模板'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (_templateName.isNotEmpty) IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () { context.read<ProjectProvider>().clearTemplate(); setState(() => _templateName = ''); }),
            FilledButton.tonal(onPressed: _importTemplate, child: const Text('导入')),
          ]),
        )),
        const SizedBox(height: 16),
        // ─── API ───
        _sec('API 配置'),
        Wrap(spacing: 8, children: [
          _presetBtn('硅基流动', () => _preset('https://api.siliconflow.cn/v1', 'deepseek-ai/DeepSeek-V4-Flash')),
          _presetBtn('DeepSeek', () => _preset('https://api.deepseek.com/v1', 'deepseek-chat')),
          _presetBtn('OpenAI', () => _preset('https://api.openai.com/v1', 'gpt-4o')),
        ]),
        const SizedBox(height: 8),
        TextFormField(controller: _urlCtrl, decoration: const InputDecoration(labelText: 'Base URL')),
        const SizedBox(height: 8),
        TextFormField(controller: _keyCtrl, decoration: const InputDecoration(labelText: 'API Key'), obscureText: true),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('模型: ${_displayModel(_model)}', style: const TextStyle(fontWeight: FontWeight.w500))),
          TextButton.icon(onPressed: _loadingModels ? null : _fetchModels, icon: _loadingModels ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh, size: 16), label: const Text('获取列表')),
        ]),
        if (_models.isNotEmpty) Container(height: 160, child: Card(child: Scrollbar(child: ListView(children: _models.map((m) => RadioListTile<String>(title: Text(m['display'] ?? m['id'] ?? '', style: const TextStyle(fontSize: 13)), subtitle: Text(m['id'] ?? '', style: const TextStyle(fontSize: 10)), value: m['id'] ?? '', groupValue: _model, onChanged: (v) => setState(() => _model = v ?? _model), dense: true, visualDensity: VisualDensity.compact)).toList()))))),
        const SizedBox(height: 8),
        _slider('Temperature', _temp, 0, 2),
        _slider('Max Tokens', _maxTokens, 1024, 16384),
        Row(children: [Expanded(child: OutlinedButton(onPressed: _test, child: const Text('测试连接'))), const SizedBox(width: 12), Expanded(child: FilledButton(onPressed: _save, child: const Text('保存设置')))]),
        const SizedBox(height: 24),
        // ─── 加料设置 ───
        _sec('加料设置'),
        Text('默认加料强度: $_enhanceLevel', style: const TextStyle(fontSize: 13)),
        Slider(value: _enhanceLevel.toDouble(), min: 1, max: 5, divisions: 4, onChanged: (v) => setState(() => _enhanceLevel = v.toInt())),
        Text('并发数: $_concurrency', style: const TextStyle(fontSize: 13)),
        Slider(value: _concurrency.toDouble(), min: 1, max: 3, divisions: 2, onChanged: (v) => setState(() => _concurrency = v.toInt())),
        SwitchListTile(title: const Text('错误自动重试'), value: _autoRetry, onChanged: (v) => setState(() => _autoRetry = v)),
      ]),
    );
  }

  Widget _sec(String t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)));
  Widget _presetBtn(String l, VoidCallback onTap) => ActionChip(label: Text(l, style: const TextStyle(fontSize: 12)), onPressed: onTap);

  Widget _slider(String label, double value, double min, double max) {
    return Row(children: [
      SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12))),
      Expanded(child: Slider(value: value, min: min, max: max, divisions: max > 100 ? 15 : 20, onChanged: (v) => setState(() {
        if (label.startsWith('T')) _temp = v; else _maxTokens = v;
      }))),
      SizedBox(width: 45, child: Text(value.toStringAsFixed(max > 10 ? 0 : 2), style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
    ]);
  }

  String _displayModel(String id) {
    final p = id.split('/');
    return p.length > 1 ? p.last : id;
  }
}
