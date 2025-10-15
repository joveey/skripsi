import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:flutter/services.dart';

void main() {
  runApp(const MushroomClassifierApp());
}

class MushroomClassifierApp extends StatelessWidget {
  const MushroomClassifierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Klasifikasi Jamur',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.green,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ============================================================
// SPLASH SCREEN
// ============================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF388E3C), Color(0xFF81C784)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.eco,
                size: 120,
                color: Colors.white,
              ),
              SizedBox(height: 20),
              Text(
                'Klasifikasi Jamur',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Deteksi Jamur Beracun & Aman',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: 40),
              CircularProgressIndicator(
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HOME SCREEN
// ============================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String _result = '';
  double _confidence = 0.0;
  bool _isLoading = false;
  Interpreter? _interpreter;
  List<String> _labels = [];

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  // Load Model TFLite dan Labels
  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/mushroom_classifier.tflite');
      
  // Load labels (use rootBundle so we don't use BuildContext across async gaps)
  final labelsData = await rootBundle.loadString('assets/labels.txt');
  _labels = labelsData.split('\n').where((label) => label.isNotEmpty).toList();

      debugPrint('✓ Model loaded successfully');
      debugPrint('✓ Labels: $_labels');
    } catch (e) {
      debugPrint('Error loading model: $e');
      if (!mounted) return;
      _showErrorDialog('Gagal memuat model. Pastikan file model tersedia.');
    }
  }

  // Preprocess Image
  List<List<List<List<double>>>> _preprocessImage(File imageFile) {
    // Read image
    img.Image? image = img.decodeImage(imageFile.readAsBytesSync());
    
    // Resize to 224x224
    img.Image resizedImage = img.copyResize(image!, width: 224, height: 224);
    
    // Normalize pixel values to [0, 1]
    // Access the underlying pixel data (Uint32List) and extract channels.
    List<List<List<List<double>>>> input = List.generate(
      1,
      (i) => List.generate(
        224,
        (y) => List.generate(
          224,
          (x) {
            // Get pixel value; depending on package:image version this may be an
            // int or a Pixel-like object with .toInt(). Use dynamic fallback.
            final rawPixel = resizedImage.getPixel(x, y);
            final int p = rawPixel is int ? rawPixel : (rawPixel as dynamic).toInt();
            final r = (p >> 16) & 0xFF;
            final g = (p >> 8) & 0xFF;
            final b = p & 0xFF;
            return [
              r / 255.0,
              g / 255.0,
              b / 255.0,
            ];
          },
        ),
      ),
    );
    
    return input;
  }

  // Klasifikasi Gambar
  Future<void> _classifyImage(File imageFile) async {
    if (_interpreter == null) {
      _showErrorDialog('Model belum dimuat');
      return;
    }

    setState(() {
      _isLoading = true;
      _result = '';
      _confidence = 0.0;
    });

    try {
      // Preprocess
      var input = _preprocessImage(imageFile);
      
      // Output buffer
      var output = List.filled(1 * 2, 0.0).reshape([1, 2]);
      
      // Run inference
      _interpreter!.run(input, output);
      
      // Get results
      double poisonousScore = output[0][0];
      double edibleScore = output[0][1];
      
      // Determine result
      int predictedClass = poisonousScore > edibleScore ? 0 : 1;
      double confidence = predictedClass == 0 ? poisonousScore : edibleScore;
      
      if (!mounted) return;
      setState(() {
        _result = _labels[predictedClass];
        _confidence = confidence * 100;
        _isLoading = false;
      });

      // Navigate to result screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            image: imageFile,
            result: _result,
            confidence: _confidence,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error during classification: $e');
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      _showErrorDialog('Terjadi kesalahan saat klasifikasi: $e');
    }
  }

  // Pick Image from Camera
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
        });
        await _classifyImage(_selectedImage!);
      }
    } catch (e) {
      _showErrorDialog('Gagal mengambil foto: $e');
    }
  }

  // Pick Image from Gallery
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        await _classifyImage(_selectedImage!);
      }
    } catch (e) {
      _showErrorDialog('Gagal memilih gambar: $e');
    }
  }

  // Show Error Dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Klasifikasi Jamur'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InfoScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Memproses gambar...'),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.eco,
                              size: 60,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Deteksi Jamur',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Identifikasi jamur beracun atau aman dikonsumsi',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Instructions
                    const Text(
                      'Cara Penggunaan:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildInstructionItem(
                      '1',
                      'Ambil foto jamur atau pilih dari galeri',
                    ),
                    _buildInstructionItem(
                      '2',
                      'Pastikan gambar jamur jelas dan terfokus',
                    ),
                    _buildInstructionItem(
                      '3',
                      'Aplikasi akan menganalisis dan memberikan hasil',
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Camera Button
                    ElevatedButton.icon(
                      onPressed: _pickImageFromCamera,
                      icon: const Icon(Icons.camera_alt, size: 28),
                      label: const Text(
                        'Ambil Foto',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                    ),
                    
                    const SizedBox(height: 15),
                    
                    // Gallery Button
                    OutlinedButton.icon(
                      onPressed: _pickImageFromGallery,
                      icon: const Icon(Icons.photo_library, size: 28),
                      label: const Text(
                        'Pilih dari Galeri',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Colors.green, width: 2),
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Warning Card
                    Card(
                      color: Colors.orange[50],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.orange[300]!, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange[700],
                              size: 30,
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                'Hasil identifikasi hanya sebagai referensi. Konsultasikan dengan ahli untuk memastikan keamanan konsumsi.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.orange[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInstructionItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                text,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// RESULT SCREEN
// ============================================================
class ResultScreen extends StatelessWidget {
  final File image;
  final String result;
  final double confidence;

  const ResultScreen({
    super.key,
    required this.image,
    required this.result,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    bool isPoisonous = result.toLowerCase().contains('poisonous') || 
                       result.toLowerCase().contains('beracun');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Klasifikasi'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Image Display
            Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[200],
              ),
              child: Image.file(
                image,
                fit: BoxFit.cover,
              ),
            ),
            
            // Result Card
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isPoisonous ? Colors.red[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isPoisonous ? Colors.red : Colors.green,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPoisonous ? Icons.dangerous : Icons.check_circle,
                          color: isPoisonous ? Colors.red : Colors.green,
                          size: 30,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isPoisonous ? 'BERACUN' : 'AMAN DIKONSUMSI',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isPoisonous ? Colors.red[900] : Colors.green[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Confidence
                  Text(
                    'Tingkat Keyakinan',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${confidence.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: confidence / 100,
                      minHeight: 15,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isPoisonous ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Warning/Info Card
                  Card(
                    color: isPoisonous ? Colors.red[50] : Colors.green[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            isPoisonous ? Icons.warning : Icons.info,
                            size: 50,
                            color: isPoisonous ? Colors.red : Colors.green,
                          ),
                          const SizedBox(height: 15),
                          Text(
                            isPoisonous 
                              ? 'Perhatian!'
                              : 'Informasi',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isPoisonous ? Colors.red[900] : Colors.green[900],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isPoisonous
                              ? 'Jamur ini terdeteksi sebagai jamur beracun. JANGAN dikonsumsi. Konsultasikan dengan ahli mikologi untuk konfirmasi.'
                              : 'Jamur ini terdeteksi aman untuk dikonsumsi. Namun tetap disarankan untuk berkonsultasi dengan ahli sebelum mengonsumsi.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Scan Lagi'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HomeScreen(),
                              ),
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.home),
                          label: const Text('Beranda'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// INFO SCREEN
// ============================================================
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informasi Aplikasi'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Icon(
                Icons.eco,
                size: 80,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 20),
            
            const Center(
              child: Text(
                'Aplikasi Klasifikasi Jamur',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            
            const Center(
              child: Text(
                'Versi 1.0.0',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            _buildInfoSection(
              'Tentang Aplikasi',
              'Aplikasi ini menggunakan teknologi Artificial Intelligence dengan Convolutional Neural Network (CNN) dan arsitektur MobileNetV2 untuk mengidentifikasi jamur beracun dan jamur yang aman dikonsumsi melalui analisis citra.',
            ),
            
            _buildInfoSection(
              'Cara Kerja',
              '1. Ambil foto jamur atau pilih dari galeri\n'
              '2. Sistem akan menganalisis citra menggunakan model CNN\n'
              '3. Hasil klasifikasi ditampilkan dengan tingkat keyakinan\n'
              '4. Sistem memberikan rekomendasi keamanan konsumsi',
            ),
            
            _buildInfoSection(
              'Disclaimer',
              'Hasil identifikasi aplikasi ini HANYA sebagai referensi awal. '
              'Untuk memastikan keamanan konsumsi jamur, WAJIB berkonsultasi '
              'dengan ahli mikologi atau pakar jamur. Pengembang tidak '
              'bertanggung jawab atas konsekuensi dari konsumsi jamur.',
            ),
            
            _buildInfoSection(
              'Teknologi',
              '• TensorFlow Lite\n'
              '• MobileNetV2\n'
              '• Flutter Framework\n'
              '• Convolutional Neural Network (CNN)',
            ),
            
            _buildInfoSection(
              'Pengembang',
              'Muhammad Jovi Syawal Difa\n'
              'Program Studi Sistem Informasi\n'
              'Universitas Nasional\n'
              'Tahun 2025',
            ),
            
            const SizedBox(height: 20),
            
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Kembali',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// (helpers removed — channel extraction performed inline to support different
// package:image versions.)