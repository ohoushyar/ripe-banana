import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../utils/color_name_detector.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  String? _errorMessage;
  String _detectedColorName = 'Tap on the camera view to detect color';
  Color? _detectedColor;
  bool _isProcessing = false;
  bool _isFrozen = false;
  Uint8List? _frozenImageBytes;
  img.Image? _frozenImage;
  Size? _frozenImageSize;
  
  // Zoom and pan state
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  double _baseScale = 1.0;
  Offset _baseOffset = Offset.zero;
  static const double _minScale = 1.0;
  static const double _maxScale = 5.0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      
      // Check if cameras are available
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = 'No camera available. Please use a device with a camera or enable camera in your emulator settings.';
            _isInitialized = false;
          });
        }
        return;
      }

      _controller = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize camera: $e\n\nIf you are using an emulator, make sure camera is enabled in the emulator settings.';
          _isInitialized = false;
        });
      }
    }
  }

  Future<void> _retryInitialize() async {
    setState(() {
      _errorMessage = null;
      _isInitialized = false;
    });
    await _initializeCamera();
  }

  Future<void> _freezeCamera() async {
    if (!_isInitialized || _controller == null || _isFrozen) return;

    try {
      // Take a picture to freeze
      final XFile image = await _controller!.takePicture();
      final imageBytes = await image.readAsBytes();
      final imageData = img.decodeImage(imageBytes);

      if (imageData != null && mounted) {
        setState(() {
          _isFrozen = true;
          _frozenImageBytes = imageBytes;
          _frozenImage = imageData;
          _frozenImageSize = Size(imageData.width.toDouble(), imageData.height.toDouble());
        });
      }
    } catch (e) {
      debugPrint('Error freezing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error freezing camera: $e')),
        );
      }
    }
  }

  void _unfreezeCamera() {
    if (mounted) {
      setState(() {
        _isFrozen = false;
        _frozenImageBytes = null;
        _frozenImage = null;
        _frozenImageSize = null;
        // Reset zoom when unfreezing
        _scale = 1.0;
        _offset = Offset.zero;
        _baseScale = 1.0;
        _baseOffset = Offset.zero;
      });
    }
  }

  void _resetZoom() {
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
      _baseScale = 1.0;
      _baseOffset = Offset.zero;
    });
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _scale;
    _baseOffset = _offset;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount == 1) {
      // Single finger drag (pan) - only allow if zoomed in
      if (_scale > 1.0) {
        setState(() {
          _offset = _baseOffset + details.focalPointDelta;
        });
      }
    } else if (details.pointerCount == 2) {
      // Two finger pinch (zoom)
      final newScale = (_baseScale * details.scale).clamp(_minScale, _maxScale);
      setState(() {
        _scale = newScale;
        // If zoomed out to 1.0, reset offset
        if (newScale == 1.0) {
          _offset = Offset.zero;
          _baseOffset = Offset.zero;
        }
      });
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _baseScale = _scale;
    _baseOffset = _offset;
  }

  Future<void> _onTapDown(TapDownDetails details) async {
    if (!_isInitialized || _isProcessing) return;
    if (!_isFrozen && _controller == null) return;

    // For frozen images, process immediately without showing loading
    if (_isFrozen && _frozenImage != null && _frozenImageSize != null) {
      _processFrozenImageTap(details);
      return;
    }

    // For live camera, show processing and take a picture
    setState(() {
      _isProcessing = true;
    });

    try {
      if (_controller != null) {
        // Take a new picture from camera
        final XFile image = await _controller!.takePicture();
        final imageBytes = await image.readAsBytes();
        final imageData = img.decodeImage(imageBytes);
        
        if (imageData != null) {
          _processImageTap(details, imageData, _controller!.value.previewSize!);
        } else {
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error detecting color: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _detectedColorName = 'Error detecting color';
        });
      }
    }
  }

  void _processFrozenImageTap(TapDownDetails details) {
    if (_frozenImage == null || _frozenImageSize == null) return;

    try {
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final Size containerSize = renderBox.size;
      Offset localPosition = renderBox.globalToLocal(details.globalPosition);
      
      // Account for zoom and pan transformations
      // The transform applies: scale around center, then translate
      // To reverse: subtract offset first, then reverse scale around center
      final double centerX = containerSize.width / 2;
      final double centerY = containerSize.height / 2;
      
      // Reverse translate
      final double afterTranslateX = localPosition.dx - _offset.dx;
      final double afterTranslateY = localPosition.dy - _offset.dy;
      
      // Reverse scale around center
      final double transformedX = (afterTranslateX - centerX) / _scale + centerX;
      final double transformedY = (afterTranslateY - centerY) / _scale + centerY;
      
      localPosition = Offset(transformedX, transformedY);
      
      // Calculate coordinates for frozen image with BoxFit.cover
      final double imageAspectRatio = _frozenImageSize!.width / _frozenImageSize!.height;
      final double containerAspectRatio = containerSize.width / containerSize.height;
      
      double displayedWidth, displayedHeight;
      double offsetX = 0, offsetY = 0;
      
      if (imageAspectRatio > containerAspectRatio) {
        displayedHeight = containerSize.height;
        displayedWidth = displayedHeight * imageAspectRatio;
        offsetX = (displayedWidth - containerSize.width) / 2;
      } else {
        displayedWidth = containerSize.width;
        displayedHeight = displayedWidth / imageAspectRatio;
        offsetY = (displayedHeight - containerSize.height) / 2;
      }
      
      final double adjustedX = localPosition.dx + offsetX;
      final double adjustedY = localPosition.dy + offsetY;
      final double scale = _frozenImageSize!.width / displayedWidth;
      
      final int x = (adjustedX * scale).round();
      final int y = (adjustedY * scale).round();
      final int clampedX = x.clamp(0, _frozenImage!.width - 1);
      final int clampedY = y.clamp(0, _frozenImage!.height - 1);

      final pixel = _frozenImage!.getPixel(clampedX, clampedY);
      final color = Color.fromRGBO(
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
        1.0,
      );
      final colorName = ColorNameDetector.getColorName(color);

      if (mounted) {
        setState(() {
          _detectedColor = color;
          _detectedColorName = colorName;
        });
      }
    } catch (e) {
      debugPrint('Error processing frozen image tap: $e');
    }
  }

  void _processImageTap(TapDownDetails details, img.Image imageData, Size previewSize) {
    try {
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final Size containerSize = renderBox.size;
      Offset localPosition = renderBox.globalToLocal(details.globalPosition);
      
      // Account for zoom and pan transformations
      // The transform applies: scale around center, then translate
      // To reverse: subtract offset first, then reverse scale around center
      final double centerX = containerSize.width / 2;
      final double centerY = containerSize.height / 2;
      
      // Reverse translate
      final double afterTranslateX = localPosition.dx - _offset.dx;
      final double afterTranslateY = localPosition.dy - _offset.dy;
      
      // Reverse scale around center
      final double transformedX = (afterTranslateX - centerX) / _scale + centerX;
      final double transformedY = (afterTranslateY - centerY) / _scale + centerY;
      
      localPosition = Offset(transformedX, transformedY);
      
      // Calculate scaling factors for live camera (accounting for possible rotation)
      // The preview size might be rotated relative to the screen
      final double scaleX = previewSize.height / containerSize.height;
      final double scaleY = previewSize.width / containerSize.width;
      
      final int x = (localPosition.dy * scaleX).round();
      final int y = (localPosition.dx * scaleY).round();
      final int clampedX = x.clamp(0, imageData.width - 1);
      final int clampedY = y.clamp(0, imageData.height - 1);

      final pixel = imageData.getPixel(clampedX, clampedY);
      final color = Color.fromRGBO(
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
        1.0,
      );
      final colorName = ColorNameDetector.getColorName(color);

      if (mounted) {
        setState(() {
          _detectedColor = color;
          _detectedColorName = colorName;
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('Error processing image tap: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _detectedColorName = 'Error detecting color';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show error screen if there's an error
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.camera_alt_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 24),
                Text(
                  'Camera Error',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _retryInitialize,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show loading screen while initializing
    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing camera...'),
            ],
          ),
        ),
      );
    }

    // Show camera preview
    return Scaffold(
      body: Stack(
        children: [
          // Camera preview or frozen image with zoom and pan
          GestureDetector(
            onTapDown: _onTapDown,
            onScaleStart: _handleScaleStart,
            onScaleUpdate: _handleScaleUpdate,
            onScaleEnd: _handleScaleEnd,
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: ClipRect(
                child: Transform(
                  transform: Matrix4.identity()
                    ..translate(_offset.dx, _offset.dy)
                    ..scale(_scale),
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: _isFrozen && _frozenImageBytes != null
                        ? Image.memory(
                            _frozenImageBytes!,
                            fit: BoxFit.cover,
                          )
                        : CameraPreview(_controller!),
                  ),
                ),
              ),
            ),
          ),
          // Freeze button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  onPressed: _isFrozen ? _unfreezeCamera : _freezeCamera,
                  backgroundColor: _isFrozen ? Colors.red : Colors.white.withOpacity(0.9),
                  child: Icon(
                    _isFrozen ? Icons.play_arrow : Icons.pause,
                    color: _isFrozen ? Colors.white : Colors.black87,
                  ),
                  tooltip: _isFrozen ? 'Unfreeze' : 'Freeze',
                ),
                // Reset zoom button (only show when zoomed)
                if (_scale > 1.0 || _offset != Offset.zero)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: _resetZoom,
                      backgroundColor: Colors.white.withOpacity(0.9),
                      child: const Icon(
                        Icons.zoom_out_map,
                        color: Colors.black87,
                      ),
                      tooltip: 'Reset zoom',
                    ),
                  ),
              ],
            ),
          ),
          // Frozen indicator
          if (_isFrozen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pause_circle,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Frozen',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Color name display
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_detectedColor != null)
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _detectedColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      margin: const EdgeInsets.only(bottom: 15),
                    ),
                  Text(
                    _detectedColorName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(2, 2),
                          blurRadius: 4,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_isProcessing)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    _isFrozen
                        ? 'Pinch to zoom • Tap to detect color'
                        : 'Pinch to zoom • Tap to detect color',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

