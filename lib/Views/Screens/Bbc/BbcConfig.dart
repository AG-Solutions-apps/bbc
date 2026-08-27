class BbcConfig {
  static const String apiBaseUrl = 'https://businessboosters.club/public/api';
  static const String imageBaseUrl = 'http://businessboosters.club/public/images/user_images/';
  static const String sliderImageBaseUrl = 'https://businessboosters.club/public/images/slider_images/';
  

  // Instructions & default fallback prompts
  static const String geminiSystemInstruction = 
      '\n\nWrite a highly warm, personalized, unique wish from "[Sender]" to "[Recipient]". '
      'Use natural formatting with paragraph breaks, include relevant emojis, and vary the wording so it is unique. '
      'Do not use markdown formatting, quotes, or asterisks (*).';

  static const String defaultBirthdayWish = 
      '🎂 Happy Birthday [Recipient]! 🎉🥳\n\n'
      'Wishing you a fantastic year ahead filled with success, happiness, and prosperity.\n\n'
      'Warm Regards,\n[Sender]';

  static const String defaultAnniversaryWish = 
      '💕 Happy Anniversary [Recipient]! 💑\n\n'
      'Wishing you both a lifetime of love, happiness, and togetherness.\n\n'
      'Warm Regards,\n[Sender]';

  // App update settings
  static const String latestAppVersion = '61.0.4'; 
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=com.bbc.agsolutions';
  static const List<String> updateFeatures = [
    'Ultra-fast scrolling experience',
    'AI-powered wishing message generator',
    'Frosted glassmorphism design layouts',
    'Enhanced security and account status checks'
  ];
}
