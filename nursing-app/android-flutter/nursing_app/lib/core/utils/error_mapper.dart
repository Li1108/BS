String normalizeErrorMessage(Object error, {String fallback = '请求失败'}) {
  final raw = error.toString().trim();
  if (raw.isEmpty) return fallback;

  final lowerRaw = raw.toLowerCase();
  if (lowerRaw.contains('connection timeout') ||
      lowerRaw.contains('timed out') ||
      lowerRaw.contains('socketexception')) {
    return '连接服务器超时，请确认后端服务已启动且 API 地址可访问';
  }
  if (lowerRaw.contains('failed host lookup') ||
      lowerRaw.contains('connection refused')) {
    return '无法连接服务器，请检查网络或 API_BASE_URL 配置';
  }

  if (raw.startsWith('Exception: ')) {
    final message = raw.substring('Exception: '.length).trim();
    return message.isEmpty ? fallback : message;
  }

  if (raw.startsWith('DioException')) {
    final parts = raw.split(':');
    if (parts.length > 1) {
      final message = parts.sublist(1).join(':').trim();
      if (message.isNotEmpty) return message;
    }
  }

  return raw;
}

String _messageByCode(int? code) {
  switch (code) {
    case 400:
    case 40001:
      return '请求参数错误';
    case 401:
    case 40100:
      return '未授权，请重新登录';
    case 403:
    case 40300:
      return '拒绝访问';
    case 404:
    case 40400:
      return '请求资源不存在';
    case 500:
    case 50000:
      return '服务器内部错误';
    default:
      return '请求失败';
  }
}

String normalizeApiErrorMessage({
  int? businessCode,
  int? statusCode,
  String? backendMessage,
  String? fallback,
}) {
  if (backendMessage != null && backendMessage.trim().isNotEmpty) {
    return backendMessage;
  }
  if (businessCode != null) {
    return _messageByCode(businessCode);
  }
  if (statusCode != null) {
    return _messageByCode(statusCode);
  }
  return fallback ?? '网络错误，请稍后重试';
}
