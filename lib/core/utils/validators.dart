/// Common validators used across the application.
///
/// Keep reusable form-validation logic here so that individual
/// screens do not need to duplicate the same validation code.
class AppValidators {
  AppValidators._();

  // ============================================================
  // REQUIRED FIELD
  // ============================================================

  static String? required(
    String? value,
    String fieldName,
  ) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return '$fieldName is required.';
    }

    return null;
  }

  // ============================================================
  // NAME
  // ============================================================

  static String? name(
    String? value, {
    String fieldName = 'Name',
  }) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return '$fieldName is required.';
    }

    if (text.length < 2) {
      return '$fieldName must contain at least 2 characters.';
    }

    if (text.length > 100) {
      return '$fieldName must not exceed 100 characters.';
    }

    return null;
  }

  // ============================================================
  // MOBILE NUMBER
  // ============================================================

  static String? mobile(
    String? value, {
    String fieldName = 'Mobile number',
  }) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return '$fieldName is required.';
    }

    final String normalized =
        text.replaceAll(RegExp(r'[\s\-()]'), '');

    final RegExp mobileRegex =
        RegExp(r'^(?:\+91|91)?[6-9]\d{9}$');

    if (!mobileRegex.hasMatch(normalized)) {
      return 'Enter a valid $fieldName.';
    }

    return null;
  }

  // ============================================================
  // OPTIONAL MOBILE NUMBER
  // ============================================================

  static String? optionalMobile(
    String? value, {
    String fieldName = 'Mobile number',
  }) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    return mobile(
      text,
      fieldName: fieldName,
    );
  }

  // ============================================================
  // EMAIL
  // ============================================================

  static String? email(
    String? value, {
    bool required = false,
  }) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return required
          ? 'Email is required.'
          : null;
    }

    final RegExp emailRegex = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailRegex.hasMatch(text)) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  // ============================================================
  // GST NUMBER
  // ============================================================

  static String? gst(
    String? value, {
    bool required = false,
  }) {
    final String text =
        value?.trim().toUpperCase() ?? '';

    if (text.isEmpty) {
      return required
          ? 'GST number is required.'
          : null;
    }

    final RegExp gstRegex = RegExp(
      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$',
    );

    if (!gstRegex.hasMatch(text)) {
      return 'Enter a valid GST number.';
    }

    return null;
  }

  // ============================================================
  // POSITIVE NUMBER
  // ============================================================

  static String? positiveNumber(
    String? value, {
    String fieldName = 'Value',
    bool required = true,
  }) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return required
          ? '$fieldName is required.'
          : null;
    }

    final double? number =
        double.tryParse(text);

    if (number == null) {
      return 'Enter a valid $fieldName.';
    }

    if (!number.isFinite) {
      return '$fieldName must be a finite number.';
    }

    if (number <= 0) {
      return '$fieldName must be greater than zero.';
    }

    return null;
  }

  // ============================================================
  // NON-NEGATIVE NUMBER
  // ============================================================

  static String? nonNegativeNumber(
    String? value, {
    String fieldName = 'Value',
    bool required = true,
  }) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return required
          ? '$fieldName is required.'
          : null;
    }

    final double? number =
        double.tryParse(text);

    if (number == null) {
      return 'Enter a valid $fieldName.';
    }

    if (!number.isFinite) {
      return '$fieldName must be a finite number.';
    }

    if (number < 0) {
      return '$fieldName cannot be negative.';
    }

    return null;
  }

  // ============================================================
  // INTEGER
  // ============================================================

  static String? integer(
    String? value, {
    String fieldName = 'Value',
    bool required = true,
  }) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return required
          ? '$fieldName is required.'
          : null;
    }

    final int? number =
        int.tryParse(text);

    if (number == null) {
      return 'Enter a valid $fieldName.';
    }

    return null;
  }

  // ============================================================
  // POSITIVE INTEGER
  // ============================================================

  static String? positiveInteger(
    String? value, {
    String fieldName = 'Value',
    bool required = true,
  }) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return required
          ? '$fieldName is required.'
          : null;
    }

    final int? number =
        int.tryParse(text);

    if (number == null) {
      return 'Enter a valid $fieldName.';
    }

    if (number <= 0) {
      return '$fieldName must be greater than zero.';
    }

    return null;
  }

  // ============================================================
  // MAX LENGTH
  // ============================================================

  static String? maxLength(
    String? value,
    int max, {
    String fieldName = 'Value',
  }) {
    final String text = value?.trim() ?? '';

    if (text.length > max) {
      return '$fieldName must not exceed $max characters.';
    }

    return null;
  }

  // ============================================================
  // MIN LENGTH
  // ============================================================

  static String? minLength(
    String? value,
    int min, {
    String fieldName = 'Value',
  }) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return '$fieldName is required.';
    }

    if (text.length < min) {
      return '$fieldName must contain at least $min characters.';
    }

    return null;
  }

  // ============================================================
  // URL
  // ============================================================

  static String? url(
    String? value, {
    bool required = false,
  }) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return required
          ? 'URL is required.'
          : null;
    }

    final Uri? uri = Uri.tryParse(text);

    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' &&
            uri.scheme != 'https')) {
      return 'Enter a valid URL.';
    }

    return null;
  }

  // ============================================================
  // MATCH VALUES
  // ============================================================

  static String? matches(
    String? value,
    String? otherValue, {
    String fieldName = 'Value',
    String otherFieldName = 'Value',
  }) {
    final String first =
        value?.trim() ?? '';

    final String second =
        otherValue?.trim() ?? '';

    if (first != second) {
      return '$fieldName does not match $otherFieldName.';
    }

    return null;
  }
}
