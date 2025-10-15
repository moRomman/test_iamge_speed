import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

void main() => runApp(const SimpleImageSpeedTestApp());

class SimpleImageSpeedTestApp extends StatelessWidget {
  const SimpleImageSpeedTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Speed Test',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      debugShowCheckedModeBanner: false,
      home: const ImageSpeedTestScreen(),
    );
  }
}

class ImageSpeedTestScreen extends StatefulWidget {
  const ImageSpeedTestScreen({super.key});

  @override
  State<ImageSpeedTestScreen> createState() => _ImageSpeedTestScreenState();
}

class _ImageSpeedTestScreenState extends State<ImageSpeedTestScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  bool _connected = true;
  String? _error;
  List<ImageResult> _results = [];

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final status = await Connectivity().checkConnectivity();
    setState(() => _connected = status != ConnectivityResult.none);
  }

  Future<void> _startTest() async {
    if (!_connected) {
      _showSnack('No internet connection');
      return;
    }

    final urls = _controller.text
        .split(RegExp(r'[,\n\s]+'))
        .where((u) => u.startsWith('http'))
        .toList();

    if (urls.isEmpty) {
      _showSnack('Enter valid image URLs');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _results = [];
    });

    try {
      final results = <ImageResult>[];
      for (final url in urls) {
        final res = await _testImage(url);
        results.add(res);
      }

      results.sort((a, b) => a.time.compareTo(b.time));

      setState(() {
        _results = results;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<ImageResult> _testImage(String url) async {
    final sw = Stopwatch()..start();
    try {
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      sw.stop();
      if (res.statusCode == 200) {
        return ImageResult(url, sw.elapsedMilliseconds, res.bodyBytes);
      } else {
        return ImageResult(url, 999999, null,
            error: 'Failed (${res.statusCode})');
      }
    } catch (e) {
      sw.stop();
      return ImageResult(url, 999999, null, error: e.toString());
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Load Speed Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Image URLs',
                hintText: 'Enter image URLs separated by comma or newline',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _startTest,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Start Test'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text('No results yet'))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final r = _results[i];
                        final isFastest = i == 0 && r.imageBytes != null;
                        return Card(
                          color:
                              isFastest ? Colors.green.shade50 : Colors.white,
                          child: ListTile(

                            title: Text(r.url,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                                r.error == null
                                    ? 'Load time: ${r.time} ms'
                                    : 'Error: ${r.error}',
                                style: TextStyle(
                                    color: r.error == null
                                        ? Colors.black
                                        : Colors.red)),
                            trailing: isFastest
                                ? const Icon(Icons.emoji_events,
                                    color: Colors.amber)
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ImageResult {
  final String url;
  final int time;
  final Uint8List? imageBytes;
  final String? error;

  ImageResult(this.url, this.time, this.imageBytes, {this.error});
}
