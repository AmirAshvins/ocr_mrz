import 'package:camera_kit_plus/camera_kit_ocr_plus_view.dart';

/// A typedef for a function that builds the body of an API request
/// from a list of [OcrData] objects captured during the interval.
typedef OcrBodyBuilder = Map<String, dynamic> Function(List<OcrData> ocrDataList);

/// Configuration for making periodic API calls to an external service for MRZ recognition.
class OcrMrzApiConfig {
  /// The URL of the API endpoint to call.
  final String url;

  /// The headers to include in the HTTP request.
  final Map<String, String> headers;

  /// A function that takes a list of [OcrData] and returns a Map to be
  /// used as the JSON body of the request.
  final OcrBodyBuilder bodyBuilder;

  /// The interval at which to make the API calls.
  final Duration interval;

  /// Whether to capture and attach a photo to the API request.
  /// If true, the request will be sent as `multipart/form-data`.
  final bool attachPhoto;

  /// The quality of the attached JPEG photo (0-100). Defaults to 85.
  /// Only used if [attachPhoto] is true.
  final int photoQuality;

  /// The maximum width of the photo in pixels. The image will be resized
  /// proportionally if it's wider than this value.
  /// If null, the original width is used. Only used if [attachPhoto] is true.
  final int? photoMaxWidth;

  OcrMrzApiConfig({required this.url, required this.headers, required this.bodyBuilder, required this.interval, this.attachPhoto = false, this.photoQuality = 85, this.photoMaxWidth});
}
