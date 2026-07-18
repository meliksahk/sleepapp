/**
 * Admin panel sözlükleri.
 *
 * **Neden çerez tabanlı, neden URL'de `[locale]` YOK:** admin bir İÇ ARAÇ — SEO,
 * paylaşılabilir çok-dilli URL, arama motoru indekslemesi gerekmiyor. `[locale]`
 * segment refactor'ü tüm route'ları, linkleri ve testleri değiştirirdi; kazancı
 * sıfır, riski yüksek olurdu. Dil çerezde tutulur, layout okur, sağlayıcı dağıtır.
 *
 * **Neden tek dosyada tipli sözlük:** anahtar seti TypeScript'te sabitlenir →
 * EN'de olup TR'de olmayan bir anahtar DERLEME HATASI verir. Mobilde bu güvenceyi
 * ayrı bir parity testi sağlıyordu; burada tip sistemi bedavaya veriyor.
 *
 * **Sunucu mu istemci mi:** metinlerin çoğu SUNUCU bileşenlerinde yaşıyor ve
 * `useT()` bir hook — orada çağrılamaz. Sunucuda desen `getLocale()` + `translate()`,
 * istemcide `useT()`. Bileşenleri `'use client'`a çevirip hook kullanmak, sırf çeviri
 * için JS bütçesini şişirirdi (ör. users sayfası bilinçli olarak sıfır client JS).
 */
export const dictionaries = {
  tr: {
    'nav.dashboard': 'Pano',
    'nav.campaigns': 'Kampanyalar',
    'nav.security': 'Güvenlik',
    'nav.content': 'İçerik',
    'nav.users': 'Kullanıcılar',
    'nav.analytics': 'Analitik',
    'nav.flags': 'Bayraklar',

    'meta.title': 'NOCTA Yönetim',
    'meta.description': 'NOCTA yönetim paneli',

    'common.admin': 'Yönetim',
    'common.logout': 'Çıkış',
    'common.loggingOut': 'Çıkılıyor…',
    'common.saving': 'Kaydediliyor…',
    'common.saved': 'Kaydedildi.',
    'common.password': 'Parola',

    'login.subtitle': 'Yönetim paneli',
    'login.email': 'E-posta',
    'login.password': 'Parola',
    'login.totpCode': 'Doğrulama kodu',
    'login.submit': 'Giriş yap',
    'login.submitting': 'Giriş yapılıyor…',
    'login.errorRate': 'Çok fazla deneme yapıldı. Bir dakika bekleyip tekrar deneyin.',
    'login.errorTotpRequired': 'Doğrulama uygulamanızdaki 6 haneli kodu girin.',
    'login.errorTotpInvalid': 'Kod hatalı veya süresi doldu. Yeni kodu deneyin.',
    'login.errorCredentials': 'E-posta veya parola hatalı.',
    'login.errorUnreachable': 'Sunucuya ulaşılamadı.',
    'login.errorGeneric': 'Giriş yapılamadı. Lütfen tekrar deneyin.',

    'lang.label': 'Dil',
    'lang.tr': 'Türkçe',
    'lang.en': 'English',

    'dashboard.title': 'Genel bakış',
    'dashboard.subtitle': 'Canlı rakamlar. Henüz ölçülemeyenler aşağıda açıkça belirtilmiştir.',
    'dashboard.published': 'Yayında',
    'dashboard.publishedHint': 'kullanıcıların gördüğü',
    'dashboard.draft': 'Taslak',
    'dashboard.draftHint': 'yayınlanmamış',
    'dashboard.waitlist': 'Bekleme listesi',
    'dashboard.waitlistHint': 'ön-lansman kaydı',
    'dashboard.pushAudience': 'Push kitlesi',
    'dashboard.pushAudienceHint': 'kampanyayla ulaşılabilir',
    'dashboard.shareRate': 'Kart paylaşım oranı',
    'dashboard.shareRateNoData': 'henüz test tamamlanmadı',
    'dashboard.shareRatePeople': '{shared}/{completed} kişi',
    'dashboard.trialToPaid': 'Deneme→ücretli',
    'dashboard.trialToPaidHint': "ödeme F6'da",
    'dashboard.soundscapes': 'Soundscapes',
    'dashboard.soundscapeCounts': '{total} kayıt · {scheduled} planlı',
    'dashboard.manageContent': 'İçeriği yönet',
    'dashboard.recentActivity': 'Son etkinlik',
    'dashboard.notMeasured': 'Henüz ölçülmeyenler',
    'dashboard.notMeasuredBody':
      'D7 retention kohort analizi gerektiriyor (A3). Deneme→ücretli ödeme entegrasyonuna bağlı (F6).',

    'audit.empty': 'Henüz etkinlik yok',
    'audit.colWho': 'Kim',
    'audit.colWhat': 'Ne yaptı',
    'audit.colTarget': 'Neye',
    'audit.colWhen': 'Ne zaman',
    'audit.soundscapeCreate': 'oluşturdu',
    'audit.soundscapeUpdate': 'güncelledi',
    'audit.soundscapePublish': 'yayınladı',
    'audit.soundscapeUnpublish': 'yayından kaldırdı',
    'audit.soundscapeRecipe': 'ses tarifini değiştirdi',

    'status.draft': 'Taslak',
    'status.scheduled': 'Planlandı',
    'status.published': 'Yayında',

    'content.title': 'Soundscapes',
    'content.subtitle': 'Taslak ve planlı kayıtlar dahil. Yayınlamak için ses tarifi gerekir.',
    'content.newDraft': 'Yeni taslak',
    'content.backToList': 'Soundscapes',
    'content.empty': 'Henüz soundscape yok',
    'content.colTitle': 'Başlık',
    'content.colSlug': 'Slug',
    'content.colStatus': 'Durum',
    'content.colAffinity': 'Uyku kimliği',
    'content.colVersion': 'Sürüm',
    'content.colAction': 'Eylem',
    'content.publish': 'Yayınla',
    'content.unpublish': 'Yayından kaldır',
    'content.fieldSlug': 'Slug',
    'content.fieldTitleEn': 'Başlık (EN)',
    'content.fieldAffinity': 'Uyku kimlikleri (virgülle)',
    'content.placeholderSlug': 'deep-ocean-drift',
    'content.placeholderTitle': 'Deep Ocean Drift',
    'content.placeholderAffinity': 'deep-ocean, night-owl',
    'content.createSubmit': 'Taslak oluştur',
    'content.created': 'Taslak oluşturuldu: {slug}',
    'content.metaHeading': 'Bilgiler',
    'content.metaSubmit': 'Bilgileri kaydet',
    'content.recipeHeading': 'Ses tarifi',
    'content.recipeNoPermission': 'Tarifi düzenlemek için editör yetkisi gerekir.',
    'content.noLayers': 'Katman yok — bu kayıt yayınlanamaz. En az bir katman ekleyin.',
    'content.layerName': 'Katman adı',
    'content.layerType': 'Tür',
    'content.layerGain': 'Kazanç ({gain})',
    'content.layerRemove': 'Sil',
    'content.layerAdd': 'Katman ekle',
    'content.recipeSubmit': 'Tarifi kaydet',
    'content.recipeSaved': 'Tarif kaydedildi.',
    'content.errorSlugTaken': 'Bu slug zaten kullanımda. Başka bir slug deneyin.',
    'content.errorEmptyRecipe':
      'Ses tarifi boş — yayınlanamaz. Önce sesi tanımlayın (tarif editörü henüz yok).',
    'content.errorNotFound': 'Kayıt bulunamadı. Liste güncel olmayabilir.',
    'content.errorEmptyTitle': 'Başlık boş olamaz.',
    'content.errorInvalidSlug':
      'Slug yalnızca küçük harf, rakam ve tire içerebilir (ör. deep-ocean-drift).',
    'content.errorForbidden': 'Bu işlem için yetkiniz yok.',
    'content.errorBadInput': 'Girdiler geçersiz. Slug ve başlığı kontrol edin.',
    'content.errorGeneric': 'Kaydedilemedi. Lütfen tekrar deneyin.',
    'content.errorLayersUnreadable': 'Katmanlar okunamadı. Sayfayı yenileyip tekrar deneyin.',

    'users.title': 'Kullanıcılar',
    'users.subtitle': 'E-posta veya kullanıcı kimliğiyle ara (destek senaryosu).',
    'users.noPermission': 'Bu bölüm için yetkiniz yok (owner veya support gerekir).',
    'users.searchLabel': 'Kullanıcı ara',
    'users.searchPlaceholder': 'e-posta veya id…',
    'users.searchSubmit': 'Ara',
    'users.minChars': 'Aramak için en az 2 karakter girin.',
    'users.empty': 'Eşleşen kullanıcı yok.',
    'users.colEmail': 'E-posta',
    'users.colKind': 'Tür',
    'users.colCreated': 'Oluşturma',
    'users.colId': 'Kimlik',

    'flags.title': 'Özellik bayrakları',
    'flags.subtitle': 'Rollout görünürlüğü — hangi özellik kime açık.',
    'flags.canEdit': 'Owner olarak düzenleyebilirsiniz.',
    'flags.readOnly': 'Düzenleme yalnızca owner.',
    'flags.formHeading': 'Flag oluştur / değiştir',
    'flags.empty': 'Tanımlı feature flag yok.',
    'flags.colKey': 'Anahtar',
    'flags.colStatus': 'Durum',
    'flags.colTargeting': 'Hedefleme',
    'flags.on': 'Açık',
    'flags.off': 'Kapalı',
    'flags.fieldKey': 'Anahtar (küçük-harf-kebab, ör. smart-alarm)',
    'flags.fieldStatus': 'Durum',
    'flags.fieldRollout': 'Rollout % (boş = herkes)',
    'flags.fieldPlatforms': 'Platformlar (virgülle, boş = hepsi)',
    'flags.fieldMinVersion': 'Asgari sürüm (boş = yok)',
    'flags.placeholderKey': 'smart-alarm',
    'flags.placeholderRollout': 'ör. 25',
    'flags.placeholderPlatforms': 'ios, android',
    'flags.placeholderVersion': '1.4.0',
    'flags.submit': 'Flag kaydet',
    'flags.savedKey': '“{key}” kaydedildi.',
    'flags.rolloutAll': 'tüm kullanıcılar',
    'flags.rolloutPercent': '{percent} kullanıcı',
    'flags.rolloutPlatforms': 'yalnızca {platforms}',
    'flags.rolloutMinVersion': 'sürüm ≥ {version}',
    'flags.errorKeyInvalid':
      'Anahtar geçersiz — yalnızca küçük harf, rakam ve tire (ör. smart-alarm).',
    'flags.errorForbidden': 'Bu işlem için yetkiniz yok (yalnızca owner flag düzenler).',
    'flags.errorInvalid': 'Girdiler geçersiz: yüzde 0-100 arası, sürüm 1.4.0 gibi olmalı.',
    'flags.errorGeneric': 'Kaydedilemedi. Lütfen tekrar deneyin.',

    'campaign.title': 'Push kampanyaları',
    'campaign.subtitle': "Push token'ı olan kullanıcılara bildirim gönder.",
    'campaign.subtitleNoPermission': 'Gönderme yetkisi yalnızca owner rolündedir.',
    'campaign.noPermission': 'Kampanya göndermek için owner yetkisi gerekir.',
    'campaign.fieldTitle': 'Başlık',
    'campaign.fieldBody': 'Mesaj',
    'campaign.fieldPlatform': 'Hedef',
    'campaign.platformAll': 'Tüm push kullanıcıları',
    'campaign.platformIos': 'Yalnızca iOS',
    'campaign.platformAndroid': 'Yalnızca Android',
    'campaign.placeholderTitle': 'Yeni haftalık soundscape',
    'campaign.placeholderBody': 'Bu haftanın ritüel sesi yayında.',
    'campaign.reachNote':
      'Gönderim seçili segmentteki tüm kullanıcılara ulaşır (bildirimleri kapatanlar hariç).',
    'campaign.submit': 'Kampanyayı gönder',
    'campaign.submitting': 'Gönderiliyor…',
    'campaign.queued':
      'Kuyruğa alındı: {recipients} kullanıcı segmentte, {queued} teslim işi sıraya kondu. Teslim arka planda yapılıyor.',
    'campaign.errorForbidden': 'Bu işlem için yetkiniz yok (yalnızca owner kampanya gönderir).',
    'campaign.errorInvalid':
      'Girdiler geçersiz: başlık/gövde boş olamaz, platform ios veya android.',
    'campaign.errorGeneric': 'Kampanya gönderilemedi. Lütfen tekrar deneyin.',

    'security.title': 'Hesap güvenliği',
    'security.subtitle': 'İki adımlı doğrulama, parolanız ele geçse bile hesabınızı korur.',
    'security.twoStep': 'İki adımlı doğrulama',
    'security.badgeEnabled': 'Etkin',
    'security.badgePending': 'Kurulum tamamlanmadı',
    'security.badgeOff': 'Kapalı',
    'security.enabledBody': 'Her girişte doğrulama uygulamanızdaki kod istenir.',
    'security.recoveryWarning':
      "Giriş yapmışken 2FA'yı aşağıdan sıfırlayıp yeni cihaza taşıyabilirsiniz; ancak çıkış yapmışken doğrulama uygulamanızı kaybederseniz giriş yapamazsınız — kurulum anahtarını güvenli bir yerde saklayın.",
    'security.rotateHeading': 'Yeni cihaza taşı / sıfırla',
    'security.setupStart': 'İki adımlı doğrulamayı kur',
    'security.preparing': 'Hazırlanıyor…',
    'security.step1':
      'Doğrulama uygulamanızda (Google Authenticator, 1Password, Aegis…) yeni hesap ekleyin.',
    'security.step2': 'Aşağıdaki kodu okutun veya anahtarı elle girin.',
    'security.step3': 'Uygulamanın ürettiği 6 haneli kodu yazıp onaylayın.',
    'security.setupKeyLabel': 'Kurulum anahtarı (elle giriş için)',
    'security.codeLabel': 'Uygulamadaki 6 haneli kod',
    'security.verifying': 'Doğrulanıyor…',
    'security.enable': 'Etkinleştir',
    'security.enabledDone':
      'İki adımlı doğrulama etkinleştirildi. Bundan sonra her girişte uygulamanızdaki kod istenecek.',
    'security.resetHint':
      'Yeni bir cihaza geçmek için parolanızla sıfırlayın; ardından baştan kurabilirsiniz.',
    'security.resetting': 'Sıfırlanıyor…',
    'security.resetSubmit': 'İki adımlı doğrulamayı sıfırla',
    'security.resetDone':
      'İki adımlı doğrulama sıfırlandı. Sayfayı yenileyip yeni cihazınızda yeniden kurabilirsiniz.',
    'security.errorCodeFormat': 'Kod 6 haneli olmalı.',
    'security.errorPasswordRequired': 'Parola gerekli.',
    'security.errorAlreadyEnabled': 'Bu hesapta iki adımlı doğrulama zaten etkin.',
    'security.errorAlreadyEnabledShort': 'İki adımlı doğrulama zaten etkin.',
    'security.errorSession': 'Oturumunuz sona ermiş. Yeniden giriş yapın.',
    'security.errorRate': 'Çok fazla deneme yapıldı. Bir dakika bekleyin.',
    'security.errorEnrollGeneric': 'Kurulum başlatılamadı. Lütfen tekrar deneyin.',
    'security.errorInvalidPassword': 'Parola hatalı.',
    'security.errorResetGeneric': 'Sıfırlanamadı. Lütfen tekrar deneyin.',
    'security.errorCodeInvalid': 'Kod hatalı veya süresi doldu. Uygulamadaki yeni kodu girin.',
    'security.errorConfirmGeneric': 'Kod doğrulanamadı. Lütfen tekrar deneyin.',
  },
  en: {
    'nav.dashboard': 'Dashboard',
    'nav.campaigns': 'Campaigns',
    'nav.security': 'Security',
    'nav.content': 'Content',
    'nav.users': 'Users',
    'nav.analytics': 'Analytics',
    'nav.flags': 'Flags',

    'meta.title': 'NOCTA Admin',
    'meta.description': 'NOCTA admin panel',

    'common.admin': 'Admin',
    'common.logout': 'Sign out',
    'common.loggingOut': 'Signing out…',
    'common.saving': 'Saving…',
    'common.saved': 'Saved.',
    'common.password': 'Password',

    'login.subtitle': 'Admin panel',
    'login.email': 'Email',
    'login.password': 'Password',
    'login.totpCode': 'Verification code',
    'login.submit': 'Sign in',
    'login.submitting': 'Signing in…',
    'login.errorRate': 'Too many attempts. Wait a minute and try again.',
    'login.errorTotpRequired': 'Enter the 6-digit code from your authenticator app.',
    'login.errorTotpInvalid': 'Code is wrong or expired. Try the new one.',
    'login.errorCredentials': 'Email or password is incorrect.',
    'login.errorUnreachable': 'Could not reach the server.',
    'login.errorGeneric': 'Could not sign in. Please try again.',

    'lang.label': 'Language',
    'lang.tr': 'Türkçe',
    'lang.en': 'English',

    'dashboard.title': 'Overview',
    'dashboard.subtitle': 'Live numbers. Anything we cannot measure yet is stated plainly below.',
    'dashboard.published': 'Published',
    'dashboard.publishedHint': 'what users see',
    'dashboard.draft': 'Draft',
    'dashboard.draftHint': 'not published',
    'dashboard.waitlist': 'Waitlist',
    'dashboard.waitlistHint': 'pre-launch signups',
    'dashboard.pushAudience': 'Push audience',
    'dashboard.pushAudienceHint': 'reachable by campaign',
    'dashboard.shareRate': 'Card share rate',
    'dashboard.shareRateNoData': 'no test completed yet',
    'dashboard.shareRatePeople': '{shared}/{completed} people',
    'dashboard.trialToPaid': 'Trial→paid',
    'dashboard.trialToPaidHint': 'billing lands in F6',
    'dashboard.soundscapes': 'Soundscapes',
    'dashboard.soundscapeCounts': '{total} records · {scheduled} scheduled',
    'dashboard.manageContent': 'Manage content',
    'dashboard.recentActivity': 'Recent activity',
    'dashboard.notMeasured': 'Not measured yet',
    'dashboard.notMeasuredBody':
      'D7 retention needs cohort analysis (A3). Trial→paid depends on the billing integration (F6).',

    'audit.empty': 'No activity yet',
    'audit.colWho': 'Who',
    'audit.colWhat': 'Action',
    'audit.colTarget': 'Target',
    'audit.colWhen': 'When',
    'audit.soundscapeCreate': 'created',
    'audit.soundscapeUpdate': 'updated',
    'audit.soundscapePublish': 'published',
    'audit.soundscapeUnpublish': 'unpublished',
    'audit.soundscapeRecipe': 'changed the sound recipe',

    'status.draft': 'Draft',
    'status.scheduled': 'Scheduled',
    'status.published': 'Published',

    'content.title': 'Soundscapes',
    'content.subtitle':
      'Drafts and scheduled records included. Publishing requires a sound recipe.',
    'content.newDraft': 'New draft',
    'content.backToList': 'Soundscapes',
    'content.empty': 'No soundscapes yet',
    'content.colTitle': 'Title',
    'content.colSlug': 'Slug',
    'content.colStatus': 'Status',
    'content.colAffinity': 'Sleep identity',
    'content.colVersion': 'Version',
    'content.colAction': 'Action',
    'content.publish': 'Publish',
    'content.unpublish': 'Unpublish',
    'content.fieldSlug': 'Slug',
    'content.fieldTitleEn': 'Title (EN)',
    'content.fieldAffinity': 'Sleep identities (comma-separated)',
    'content.placeholderSlug': 'deep-ocean-drift',
    'content.placeholderTitle': 'Deep Ocean Drift',
    'content.placeholderAffinity': 'deep-ocean, night-owl',
    'content.createSubmit': 'Create draft',
    'content.created': 'Draft created: {slug}',
    'content.metaHeading': 'Details',
    'content.metaSubmit': 'Save details',
    'content.recipeHeading': 'Sound recipe',
    'content.recipeNoPermission': 'Editing the recipe requires editor permission.',
    'content.noLayers': 'No layers — this record cannot be published. Add at least one layer.',
    'content.layerName': 'Layer name',
    'content.layerType': 'Type',
    'content.layerGain': 'Gain ({gain})',
    'content.layerRemove': 'Remove',
    'content.layerAdd': 'Add layer',
    'content.recipeSubmit': 'Save recipe',
    'content.recipeSaved': 'Recipe saved.',
    'content.errorSlugTaken': 'That slug is already taken. Try a different one.',
    'content.errorEmptyRecipe':
      'The sound recipe is empty — it cannot be published. Define the sound first.',
    'content.errorNotFound': 'Record not found. The list may be out of date.',
    'content.errorEmptyTitle': 'Title cannot be empty.',
    'content.errorInvalidSlug':
      'A slug may only contain lowercase letters, digits and hyphens (e.g. deep-ocean-drift).',
    'content.errorForbidden': 'You do not have permission for this action.',
    'content.errorBadInput': 'Invalid input. Check the slug and the title.',
    'content.errorGeneric': 'Could not save. Please try again.',
    'content.errorLayersUnreadable': 'Could not read the layers. Refresh the page and try again.',

    'users.title': 'Users',
    'users.subtitle': 'Search by email or user ID (support scenario).',
    'users.noPermission':
      'You do not have permission for this section (owner or support required).',
    'users.searchLabel': 'Search users',
    'users.searchPlaceholder': 'email or id…',
    'users.searchSubmit': 'Search',
    'users.minChars': 'Enter at least 2 characters to search.',
    'users.empty': 'No matching users.',
    'users.colEmail': 'Email',
    'users.colKind': 'Type',
    'users.colCreated': 'Created',
    'users.colId': 'ID',

    'flags.title': 'Feature Flags',
    'flags.subtitle': 'Rollout visibility — which feature is on for whom.',
    'flags.canEdit': 'As owner you can edit them.',
    'flags.readOnly': 'Only the owner can edit.',
    'flags.formHeading': 'Create / update flag',
    'flags.empty': 'No feature flags defined.',
    'flags.colKey': 'Key',
    'flags.colStatus': 'Status',
    'flags.colTargeting': 'Targeting',
    'flags.on': 'On',
    'flags.off': 'Off',
    'flags.fieldKey': 'Key (lower-kebab-case, e.g. smart-alarm)',
    'flags.fieldStatus': 'Status',
    'flags.fieldRollout': 'Rollout % (empty = everyone)',
    'flags.fieldPlatforms': 'Platforms (comma-separated, empty = all)',
    'flags.fieldMinVersion': 'Minimum version (empty = none)',
    'flags.placeholderKey': 'smart-alarm',
    'flags.placeholderRollout': 'e.g. 25',
    'flags.placeholderPlatforms': 'ios, android',
    'flags.placeholderVersion': '1.4.0',
    'flags.submit': 'Save flag',
    'flags.savedKey': '“{key}” saved.',
    'flags.rolloutAll': 'all users',
    'flags.rolloutPercent': '{percent} of users',
    'flags.rolloutPlatforms': '{platforms} only',
    'flags.rolloutMinVersion': 'version ≥ {version}',
    'flags.errorKeyInvalid':
      'Invalid key — lowercase letters, digits and hyphens only (e.g. smart-alarm).',
    'flags.errorForbidden':
      'You do not have permission for this action (only the owner edits flags).',
    'flags.errorInvalid': 'Invalid input: percentage must be 0-100, version must look like 1.4.0.',
    'flags.errorGeneric': 'Could not save. Please try again.',

    'campaign.title': 'Push Campaigns',
    'campaign.subtitle': 'Send a notification to users who have a push token.',
    'campaign.subtitleNoPermission': 'Only the owner role may send.',
    'campaign.noPermission': 'Sending campaigns requires the owner role.',
    'campaign.fieldTitle': 'Title',
    'campaign.fieldBody': 'Body',
    'campaign.fieldPlatform': 'Target',
    'campaign.platformAll': 'All push users',
    'campaign.platformIos': 'iOS only',
    'campaign.platformAndroid': 'Android only',
    'campaign.placeholderTitle': 'New weekly soundscape',
    'campaign.placeholderBody': "This week's ritual sound is live.",
    'campaign.reachNote':
      'The send reaches every user in the selected segment (except those who turned notifications off).',
    'campaign.submit': 'Send campaign',
    'campaign.submitting': 'Sending…',
    'campaign.queued':
      'Queued: {recipients} users in segment, {queued} delivery jobs enqueued. Delivery happens in the background.',
    'campaign.errorForbidden':
      'You do not have permission for this action (only the owner sends campaigns).',
    'campaign.errorInvalid':
      'Invalid input: title and body cannot be empty, platform must be ios or android.',
    'campaign.errorGeneric': 'Could not send the campaign. Please try again.',

    'security.title': 'Account security',
    'security.subtitle':
      'Two-step verification keeps your account safe even if your password leaks.',
    'security.twoStep': 'Two-step verification',
    'security.badgeEnabled': 'Enabled',
    'security.badgePending': 'Setup unfinished',
    'security.badgeOff': 'Off',
    'security.enabledBody': 'Every sign-in asks for the code from your authenticator app.',
    'security.recoveryWarning':
      'While signed in you can reset 2FA below and move it to a new device; but if you lose your authenticator app while signed out, you cannot sign in — keep the setup key somewhere safe.',
    'security.rotateHeading': 'Move to a new device / reset',
    'security.setupStart': 'Set up two-step verification',
    'security.preparing': 'Preparing…',
    'security.step1':
      'Add a new account in your authenticator app (Google Authenticator, 1Password, Aegis…).',
    'security.step2': 'Scan the code below or enter the key by hand.',
    'security.step3': 'Type the 6-digit code your app generates and confirm.',
    'security.setupKeyLabel': 'Setup key (for manual entry)',
    'security.codeLabel': '6-digit code from the app',
    'security.verifying': 'Verifying…',
    'security.enable': 'Enable',
    'security.enabledDone':
      'Two-step verification is enabled. From now on every sign-in asks for the code from your app.',
    'security.resetHint':
      'To move to a new device, reset with your password; then you can set it up again.',
    'security.resetting': 'Resetting…',
    'security.resetSubmit': 'Reset two-step verification',
    'security.resetDone':
      'Two-step verification has been reset. Refresh the page to set it up again on your new device.',
    'security.errorCodeFormat': 'The code must be 6 digits.',
    'security.errorPasswordRequired': 'Password is required.',
    'security.errorAlreadyEnabled': 'Two-step verification is already enabled on this account.',
    'security.errorAlreadyEnabledShort': 'Two-step verification is already enabled.',
    'security.errorSession': 'Your session has expired. Sign in again.',
    'security.errorRate': 'Too many attempts. Wait a minute.',
    'security.errorEnrollGeneric': 'Could not start setup. Please try again.',
    'security.errorInvalidPassword': 'Password is incorrect.',
    'security.errorResetGeneric': 'Could not reset. Please try again.',
    'security.errorCodeInvalid': 'Code is wrong or expired. Enter the new code from the app.',
    'security.errorConfirmGeneric': 'Could not verify the code. Please try again.',
  },
} as const;

export type Locale = keyof typeof dictionaries;
export type MessageKey = keyof (typeof dictionaries)['tr'];

export const locales: readonly Locale[] = ['tr', 'en'] as const;

/** Varsayılan TR: panel bugüne dek Türkçeydi, mevcut kullanıcı deneyimi korunur. */
export const defaultLocale: Locale = 'tr';

export function isLocale(value: string | undefined): value is Locale {
  return value === 'tr' || value === 'en';
}

/**
 * Sunucu bileşenleri için `useT()` eşleniği: dili bir kez bağlar, çağrı yerlerinde
 * `locale`ı tekrar tekrar geçirmeyi ortadan kaldırır. Hook DEĞİL — sunucuda güvenli.
 */
export function translator(
  locale: Locale,
): (key: MessageKey, vars?: Record<string, string | number>) => string {
  return (key, vars) => translate(locale, key, vars);
}

/** `{ad}` yer tutucularını doldurur. Eksik değer anahtarı OLDUĞU GİBİ bırakır. */
export function translate(
  locale: Locale,
  key: MessageKey,
  vars?: Record<string, string | number>,
): string {
  const raw: string = dictionaries[locale][key];
  if (!vars) return raw;
  return raw.replace(/\{(\w+)\}/g, (match, name: string) =>
    name in vars ? String(vars[name]) : match,
  );
}
