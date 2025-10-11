import '../models/app_language.dart';

/// Service for managing app translations and localization
class LocalizationService {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  AppLanguage _currentLanguage = AppLanguage.english;

  AppLanguage get currentLanguage => _currentLanguage;

  void setLanguage(AppLanguage language) {
    _currentLanguage = language;
  }

  /// Get translated string by key
  String translate(String key, [Map<String, String>? params]) {
    String translation = _translations[_currentLanguage]?[key] ?? 
                        _translations[AppLanguage.english]?[key] ?? 
                        key;
    
    // Replace parameters if provided
    if (params != null) {
      params.forEach((key, value) {
        translation = translation.replaceAll('{$key}', value);
      });
    }
    
    return translation;
  }

  /// Shorthand for translate
  String t(String key, [Map<String, String>? params]) => translate(key, params);

  /// All translations organized by language and key
  static final Map<AppLanguage, Map<String, String>> _translations = {
    AppLanguage.english: {
      // Onboarding - Video Screen
      'onboarding_welcome': 'Welcome to\nAI Voice Notes',
      'onboarding_subtitle': 'Transform your voice into organized notes',
      'onboarding_sub_subtitle': 'Capture thoughts instantly with AI-powered intelligence',
      'onboarding_get_started': 'Get Started',
      'onboarding_continue': 'Continue',
      
      // Onboarding - Explanation Pages
      'onboarding_voice_title': 'Speak, Don\'t Type',
      'onboarding_voice_benefit_1': 'Capture thoughts 10x faster',
      'onboarding_voice_benefit_2': 'No more fighting autocorrect',
      'onboarding_voice_benefit_3': 'Your natural voice, perfectly transcribed',
      
      'onboarding_ai_title': 'Your Notes Organize Themselves',
      'onboarding_ai_benefit_1': 'AI creates perfect headlines',
      'onboarding_ai_benefit_2': 'Groups related thoughts automatically',
      'onboarding_ai_benefit_3': 'No folders, no manual sorting',
      
      'onboarding_speed_title': 'From Thought to Organized Note in Seconds',
      'onboarding_speed_benefit_1': 'Record → Transcribe → Organize',
      'onboarding_speed_benefit_2': 'All automatic, all instant',
      'onboarding_speed_benefit_3': 'Focus on ideas, not organization',
      
      // Onboarding - Theme Selector
      'onboarding_theme_title': 'Choose Your Style',
      'onboarding_theme_subtitle': 'Pick a theme that matches your vibe',
      
      // Onboarding - Questions
      'onboarding_question_1_title': 'Where did you\nhear about us?',
      'onboarding_question_1_option_1': 'Social Media',
      'onboarding_question_1_option_1_sub': 'Instagram, Twitter, TikTok',
      'onboarding_question_1_option_2': 'Friend or Colleague',
      'onboarding_question_1_option_2_sub': 'Personal recommendation',
      'onboarding_question_1_option_3': 'App Store',
      'onboarding_question_1_option_3_sub': 'Browsing or search',
      'onboarding_question_1_option_4': 'YouTube',
      'onboarding_question_1_option_4_sub': 'Review or tutorial',
      'onboarding_question_1_option_5': 'Reddit or Forum',
      'onboarding_question_1_option_5_sub': 'Community discussion',
      'onboarding_question_1_option_6': 'Google Search',
      'onboarding_question_1_option_6_sub': 'Looking for voice notes app',
      'onboarding_question_1_option_7': 'Other',
      'onboarding_question_1_option_7_sub': 'Other sources',
      
      'onboarding_question_2_title': 'What\'s your\nnote-taking style?',
      'onboarding_question_2_option_1': 'Quick Thoughts',
      'onboarding_question_2_option_1_sub': 'Brief notes on the go',
      'onboarding_question_2_option_2': 'Detailed Notes',
      'onboarding_question_2_option_2_sub': 'Comprehensive entries',
      'onboarding_question_2_option_3': 'Mixed',
      'onboarding_question_2_option_3_sub': 'Depends on the moment',
      
      'onboarding_question_3_title': 'When do you\ncapture ideas?',
      'onboarding_question_3_option_1': 'Throughout the Day',
      'onboarding_question_3_option_1_sub': 'As they come',
      'onboarding_question_3_option_2': 'Morning',
      'onboarding_question_3_option_2_sub': 'Start my day organized',
      'onboarding_question_3_option_3': 'Evening',
      'onboarding_question_3_option_3_sub': 'Reflect on my day',
      'onboarding_question_3_option_4': 'Spontaneous',
      'onboarding_question_3_option_4_sub': 'Random bursts of inspiration',
      
      'onboarding_question_4_title': 'How often do you\ntake notes?',
      'onboarding_question_4_option_1': 'Daily',
      'onboarding_question_4_option_1_sub': 'I\'m committed',
      'onboarding_question_4_option_2': 'Few times a week',
      'onboarding_question_4_option_2_sub': 'Regular user',
      'onboarding_question_4_option_3': 'Whenever inspiration strikes',
      'onboarding_question_4_option_3_sub': 'As needed',
      
      'onboarding_question_5_title': 'What will you use\nAI Voice Notes for?',
      'onboarding_question_5_option_1': 'Work & Productivity',
      'onboarding_question_5_option_1_sub': 'Meetings, tasks, ideas',
      'onboarding_question_5_option_2': 'Learning & Study',
      'onboarding_question_5_option_2_sub': 'Lectures, research, notes',
      'onboarding_question_5_option_3': 'Personal Journaling',
      'onboarding_question_5_option_3_sub': 'Thoughts, feelings, daily life',
      'onboarding_question_5_option_4': 'Creative Ideas',
      'onboarding_question_5_option_4_sub': 'Inspiration, projects',
      
      'onboarding_question_6_title': 'Choose your\ntranscription quality',
      'onboarding_question_6_subtitle': 'Optimized for {language}. You can change this later in settings',
      'onboarding_question_6_option_1': 'Fast & Efficient',
      'onboarding_question_6_option_1_sub': 'Good quality, quick processing',
      'onboarding_question_6_option_2': 'Balanced',
      'onboarding_question_6_option_2_sub': 'Recommended for most users',
      'onboarding_question_6_option_3': 'Maximum Accuracy',
      'onboarding_question_6_option_3_sub': 'Best quality, slower',
      
      'onboarding_question_7_title': 'Quick recording\nworkflow?',
      'onboarding_question_7_subtitle': 'Auto-close notes to record multiple entries faster',
      'onboarding_question_7_option_1': 'Yes, Auto-Close',
      'onboarding_question_7_option_1_sub': 'Close note after 2 seconds (faster workflow)',
      'onboarding_question_7_option_2': 'No, Keep Open',
      'onboarding_question_7_option_2_sub': 'I\'ll close notes manually (more control)',
      
      // Interstitial Screens
      'interstitial_privacy_title': 'Your Notes Stay Yours',
      'interstitial_privacy_message': 'All notes are stored securely on your device. Your privacy is our priority.',
      'interstitial_privacy_feature_1': 'End-to-End Encrypted',
      'interstitial_privacy_feature_2': 'Stored Locally Only',
      'interstitial_privacy_feature_3': 'Never Tracked or Sold',
      
      'interstitial_personalize_title': 'Almost There!',
      'interstitial_personalize_message': 'Just a few more questions to personalize your experience.',
      'interstitial_personalize_subtitle': 'Your perfect note-taking setup is just moments away',
      
      // Rating Screen
      'rating_title': 'Loving AI Voice Notes?',
      'rating_message': 'Your feedback helps us improve and reach more people who need better note-taking.',
      'rating_button': 'Rate Us ⭐',
      'rating_skip': 'Maybe Later',
      
      // Loading Screen
      'loading_title': 'Customizing Everything For You',
      'loading_task_1': 'Setting up your preferences',
      'loading_task_2': 'Optimizing voice recognition for {language}',
      'loading_task_3': 'Configuring AI assistant',
      'loading_task_4': 'Preparing your workspace',
      'loading_task_5': 'Almost ready...',
      
      // Completion Screen
      'completion_title': 'Welcome to Your New\nVoice Workflow',
      'completion_subtitle': 'Your thoughts, organized in seconds',
      'completion_cta': 'Start Recording',
      
      // Settings Screen
      'settings_language': 'Language',
      'settings_language_subtitle': 'App language and transcription',
      'settings_audio_quality': 'Audio Quality',
      'settings_theme': 'Theme',
      'settings_haptics': 'Haptic Feedback',
      'settings_background': 'Background Animation',
      'settings_note_view': 'Note View Style',
      'settings_auto_close': 'Auto-Close Notes',
      
      // Common
      'cancel': 'Cancel',
      'done': 'Done',
      'save': 'Save',
      'search': 'Search',
      'select_language': 'Select Language',
    },
    
    AppLanguage.spanish: {
      'onboarding_welcome': 'Bienvenido a\nAI Voice Notes',
      'onboarding_subtitle': 'Transforma tu voz en notas organizadas',
      'onboarding_sub_subtitle': 'Captura pensamientos al instante con inteligencia artificial',
      'onboarding_get_started': 'Comenzar',
      'onboarding_continue': 'Continuar',
      
      'onboarding_question_1_title': '¿Dónde nos\nconociste?',
      'onboarding_question_1_option_1': 'Redes Sociales',
      'onboarding_question_1_option_1_sub': 'Instagram, Twitter, etc.',
      'onboarding_question_1_option_2': 'Un Amigo',
      'onboarding_question_1_option_2_sub': 'Recomendación',
      'onboarding_question_1_option_3': 'App Store',
      'onboarding_question_1_option_3_sub': 'Navegando apps',
      'onboarding_question_1_option_4': 'Otro',
      'onboarding_question_1_option_4_sub': 'Otras fuentes',
      
      'onboarding_question_2_title': '¿Cuál es tu\nestilo de notas?',
      'onboarding_question_2_option_1': 'Pensamientos Rápidos',
      'onboarding_question_2_option_1_sub': 'Notas breves',
      'onboarding_question_2_option_2': 'Notas Detalladas',
      'onboarding_question_2_option_2_sub': 'Entradas completas',
      'onboarding_question_2_option_3': 'Mixto',
      'onboarding_question_2_option_3_sub': 'Depende del momento',
      
      'settings_language': 'Idioma',
      'settings_language_subtitle': 'Idioma de la app y transcripción',
      'cancel': 'Cancelar',
      'done': 'Hecho',
      'save': 'Guardar',
      'search': 'Buscar',
      'select_language': 'Seleccionar Idioma',
    },
    
    AppLanguage.french: {
      'onboarding_welcome': 'Bienvenue sur\nAI Voice Notes',
      'onboarding_subtitle': 'Transformez votre voix en notes organisées',
      'onboarding_sub_subtitle': 'Capturez vos pensées instantanément avec l\'IA',
      'onboarding_get_started': 'Commencer',
      'onboarding_continue': 'Continuer',
      
      'settings_language': 'Langue',
      'settings_language_subtitle': 'Langue de l\'app et transcription',
      'cancel': 'Annuler',
      'done': 'Terminé',
      'save': 'Sauvegarder',
      'search': 'Rechercher',
      'select_language': 'Sélectionner la Langue',
    },
    
    AppLanguage.german: {
      'onboarding_welcome': 'Willkommen bei\nAI Voice Notes',
      'onboarding_subtitle': 'Verwandeln Sie Ihre Stimme in organisierte Notizen',
      'onboarding_sub_subtitle': 'Erfassen Sie Gedanken sofort mit KI-Unterstützung',
      'onboarding_get_started': 'Loslegen',
      'onboarding_continue': 'Weiter',
      
      'settings_language': 'Sprache',
      'settings_language_subtitle': 'App-Sprache und Transkription',
      'cancel': 'Abbrechen',
      'done': 'Fertig',
      'save': 'Speichern',
      'search': 'Suchen',
      'select_language': 'Sprache Auswählen',
    },
    
    AppLanguage.italian: {
      'onboarding_welcome': 'Benvenuto su\nAI Voice Notes',
      'onboarding_subtitle': 'Trasforma la tua voce in note organizzate',
      'onboarding_sub_subtitle': 'Cattura i pensieri istantaneamente con l\'IA',
      'onboarding_get_started': 'Inizia',
      'onboarding_continue': 'Continua',
      
      'settings_language': 'Lingua',
      'settings_language_subtitle': 'Lingua dell\'app e trascrizione',
      'cancel': 'Annulla',
      'done': 'Fatto',
      'save': 'Salva',
      'search': 'Cerca',
      'select_language': 'Seleziona Lingua',
    },
    
    AppLanguage.portuguese: {
      'onboarding_welcome': 'Bem-vindo ao\nAI Voice Notes',
      'onboarding_subtitle': 'Transforme sua voz em notas organizadas',
      'onboarding_sub_subtitle': 'Capture pensamentos instantaneamente com IA',
      'onboarding_get_started': 'Começar',
      'onboarding_continue': 'Continuar',
      
      'settings_language': 'Idioma',
      'settings_language_subtitle': 'Idioma do app e transcrição',
      'cancel': 'Cancelar',
      'done': 'Concluído',
      'save': 'Salvar',
      'search': 'Pesquisar',
      'select_language': 'Selecionar Idioma',
    },
    
    AppLanguage.japanese: {
      'onboarding_welcome': 'AI Voice Notesへ\nようこそ',
      'onboarding_subtitle': '音声を整理されたメモに変換',
      'onboarding_sub_subtitle': 'AIで瞬時に思考をキャプチャ',
      'onboarding_get_started': '始める',
      'onboarding_continue': '続ける',
      
      'settings_language': '言語',
      'settings_language_subtitle': 'アプリ言語と文字起こし',
      'cancel': 'キャンセル',
      'done': '完了',
      'save': '保存',
      'search': '検索',
      'select_language': '言語を選択',
    },
    
    AppLanguage.chinese: {
      'onboarding_welcome': '欢迎使用\nAI Voice Notes',
      'onboarding_subtitle': '将您的声音转换为有序笔记',
      'onboarding_sub_subtitle': '通过AI即时捕捉想法',
      'onboarding_get_started': '开始',
      'onboarding_continue': '继续',
      
      'settings_language': '语言',
      'settings_language_subtitle': '应用语言和转录',
      'cancel': '取消',
      'done': '完成',
      'save': '保存',
      'search': '搜索',
      'select_language': '选择语言',
    },
    
    AppLanguage.korean: {
      'onboarding_welcome': 'AI Voice Notes에\n오신 것을 환영합니다',
      'onboarding_subtitle': '음성을 정리된 메모로 변환',
      'onboarding_sub_subtitle': 'AI로 즉시 생각 포착',
      'onboarding_get_started': '시작하기',
      'onboarding_continue': '계속',
      
      'settings_language': '언어',
      'settings_language_subtitle': '앱 언어 및 전사',
      'cancel': '취소',
      'done': '완료',
      'save': '저장',
      'search': '검색',
      'select_language': '언어 선택',
    },
    
    // Add basic translations for other languages (can be expanded later)
    AppLanguage.dutch: {
      'onboarding_welcome': 'Welkom bij\nAI Voice Notes',
      'onboarding_get_started': 'Begin',
      'settings_language': 'Taal',
      'cancel': 'Annuleren',
      'select_language': 'Selecteer Taal',
    },
    AppLanguage.russian: {
      'onboarding_welcome': 'Добро пожаловать в\nAI Voice Notes',
      'onboarding_get_started': 'Начать',
      'settings_language': 'Язык',
      'cancel': 'Отмена',
      'select_language': 'Выбрать Язык',
    },
    AppLanguage.arabic: {
      'onboarding_welcome': 'مرحباً بك في\nAI Voice Notes',
      'onboarding_get_started': 'ابدأ',
      'settings_language': 'اللغة',
      'cancel': 'إلغاء',
      'select_language': 'اختر اللغة',
    },
    AppLanguage.hindi: {
      'onboarding_welcome': 'AI Voice Notes में\nआपका स्वागत है',
      'onboarding_get_started': 'शुरू करें',
      'settings_language': 'भाषा',
      'cancel': 'रद्द करें',
      'select_language': 'भाषा चुनें',
    },
    AppLanguage.turkish: {
      'onboarding_welcome': 'AI Voice Notes\'a\nHoş Geldiniz',
      'onboarding_get_started': 'Başla',
      'settings_language': 'Dil',
      'cancel': 'İptal',
      'select_language': 'Dil Seç',
    },
    AppLanguage.polish: {
      'onboarding_welcome': 'Witaj w\nAI Voice Notes',
      'onboarding_get_started': 'Rozpocznij',
      'settings_language': 'Język',
      'cancel': 'Anuluj',
      'select_language': 'Wybierz Język',
    },
    AppLanguage.swedish: {
      'onboarding_welcome': 'Välkommen till\nAI Voice Notes',
      'onboarding_get_started': 'Börja',
      'settings_language': 'Språk',
      'cancel': 'Avbryt',
      'select_language': 'Välj Språk',
    },
    AppLanguage.norwegian: {
      'onboarding_welcome': 'Velkommen til\nAI Voice Notes',
      'onboarding_get_started': 'Start',
      'settings_language': 'Språk',
      'cancel': 'Avbryt',
      'select_language': 'Velg Språk',
    },
    AppLanguage.danish: {
      'onboarding_welcome': 'Velkommen til\nAI Voice Notes',
      'onboarding_get_started': 'Start',
      'settings_language': 'Sprog',
      'cancel': 'Annuller',
      'select_language': 'Vælg Sprog',
    },
    AppLanguage.finnish: {
      'onboarding_welcome': 'Tervetuloa\nAI Voice Notes',
      'onboarding_get_started': 'Aloita',
      'settings_language': 'Kieli',
      'cancel': 'Peruuta',
      'select_language': 'Valitse Kieli',
    },
  };
}

