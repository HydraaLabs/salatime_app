"""App Store listings added for languages the app already supports.

Each entry becomes an App Store localization the first time a version is
submitted with it: name and subtitle (app info), description, keywords and
promotional text (version). Screenshots are not created: the App Store shows
the primary language screenshots for these locales.
"""

SUPPORT = 'https://salatime.net/support'
PRIVACY = 'https://salatime.net/privacy-policy'

_ES_DESCRIPTION = f"""Haz sitio a tu práctica diaria con SalaTime: horarios de oración, recordatorios del Adhan, el Corán, la Qibla y los Athkar en una sola app.

HORARIOS DE ORACIÓN PARA TU UBICACIÓN
Usa tu ubicación o elige una ciudad manualmente. Elige un método de cálculo, ajusta cada horario de oración y consulta la próxima oración de un vistazo. Personaliza los sonidos de las notificaciones y los recordatorios según tu rutina.

LEE Y ESCUCHA EL CORÁN
Lee el texto árabe con traducciones, ajusta la presentación de la lectura y usa marcadores para volver a un pasaje. El texto del Corán y las traducciones incluidas están disponibles sin conexión. Escucha recitaciones cuando tengas conexión a internet y registra los versículos que has leído.

QIBLA, ATHKAR Y CALENDARIO ISLÁMICO
Encuentra la Qibla con la brújula o el mapa, sigue los Athkar y duas diarios, consulta colecciones de hadices y el calendario de la Hégira. Localiza las mezquitas cercanas con el servicio de mapas.

TUS PREFERENCIAS, A TU RITMO
Elige un aspecto claro u oscuro y tu idioma preferido. Guarda tu progreso de lectura en el dispositivo o usa una cuenta SalaTime opcional para sincronizar las preferencias compatibles y el progreso de lectura entre dispositivos. Puedes usar las funciones principales sin crear una cuenta.

Los widgets de oración muestran información útil en tu pantalla de inicio. El acceso a la ubicación es opcional si eliges una ciudad manualmente; el permiso de notificaciones es necesario para los recordatorios. Los mapas en línea, la búsqueda de mezquitas cercanas, la reproducción de recitaciones y la sincronización de la cuenta necesitan conexión a internet.

Soporte: {SUPPORT}
Privacidad: {PRIVACY}"""

_ES = {
    'name': 'SalaTime: Horarios de Oración',
    'subtitle': 'Corán, Adhan, Qibla y Duas',
    'keywords': 'rezo,salat,namaz,azan,musulmán,islam,mezquita,hégira,ramadán,dhikr,tasbih,zakat,hadiz,brújula',
    'promotionalText': ('Reúne los horarios de oración, la lectura del Corán y los Athkar diarios. '
                        'Configura tus recordatorios, encuentra la Qibla y sigue tu progreso de lectura.'),
    'description': _ES_DESCRIPTION,
}

NEW_LOCALES = {
    'tr': {
        'name': 'SalaTime: Namaz Vakti, Kuran',
        'subtitle': 'Ezan, Kıble, Dua ve Zikir',
        'keywords': 'vakitleri,imsakiye,zikirmatik,ezan vakti,kuran-ı kerim,tesbih,cami,hicri,ramazan,islam,müslüman',
        'promotionalText': ('Namaz vakitleri, Kuran okuma ve günlük zikirler bir arada. '
                            'Hatırlatıcılarınızı ayarlayın, kıbleyi bulun ve okuma ilerlemenizi takip edin.'),
        'description': f"""SalaTime ile günlük ibadetinize yer açın: namaz vakitleri, ezan hatırlatıcıları, Kuran, kıble ve zikirler tek bir uygulamada.

KONUMUNUZA GÖRE NAMAZ VAKİTLERİ
Konumunuzu kullanın veya bir şehri elle seçin. Bir hesaplama yöntemi seçin, her namaz vaktini ayrı ayrı düzenleyin ve sonraki namazı bir bakışta görün. Bildirim seslerini ve hatırlatıcıları alışkanlıklarınıza göre ayarlayın.

KURAN OKUYUN VE DİNLEYİN
Arapça metni meallerle okuyun, okuma görünümünü ayarlayın ve bir bölüme geri dönmek için yer imlerini kullanın. Uygulamayla gelen Kuran metni ve mealler çevrimdışı kullanılabilir. İnternet bağlantınız olduğunda tilavetleri dinleyin ve okuduğunuz ayetleri kaydedin.

KIBLE, ZİKİRLER VE HİCRİ TAKVİM
Kıbleyi pusula veya harita ile bulun, günlük zikir ve duaları takip edin, hadis koleksiyonlarına göz atın ve Hicri takvime bakın. Harita hizmetiyle yakındaki camileri bulun.

TERCİHLERİNİZ, SİZİN TEMPONUZ
Açık veya koyu görünümü ve tercih ettiğiniz dili seçin. Okuma ilerlemenizi cihazınızda saklayın ya da desteklenen tercihleri ve okuma ilerlemesini cihazlar arasında eşitlemek için isteğe bağlı bir SalaTime hesabı kullanın. Ana özellikleri hesap oluşturmadan kullanabilirsiniz.

Namaz widget'ları ana ekranınızda faydalı bilgiler gösterir. Şehri elle seçtiğinizde konum erişimi isteğe bağlıdır; hatırlatıcılar için bildirim izni gerekir. Çevrimiçi haritalar, yakındaki cami aramaları, tilavet dinleme ve hesap eşitleme internet bağlantısı gerektirir.

Destek: {SUPPORT}
Gizlilik: {PRIVACY}""",
    },
    'id': {
        'name': 'SalaTime: Jadwal Sholat, Quran',
        'subtitle': 'Azan, Kiblat, Doa & Zikir',
        'keywords': 'salat,solat,adzan,waktu,muslim,islam,masjid,hijriah,ramadhan,tasbih,zakat,hadis,kalender,alquran',
        'promotionalText': ('Jadwal sholat, bacaan Al-Quran, dan zikir harian dalam satu aplikasi. '
                            'Atur pengingat, temukan arah kiblat, dan pantau kemajuan bacaan Anda.'),
        'description': f"""Luangkan waktu untuk ibadah harian Anda bersama SalaTime: jadwal sholat, pengingat azan, Al-Quran, kiblat, dan zikir dalam satu aplikasi.

JADWAL SHOLAT SESUAI LOKASI ANDA
Gunakan lokasi Anda atau pilih kota secara manual. Pilih metode perhitungan, sesuaikan setiap waktu sholat, dan lihat sholat berikutnya dengan sekilas. Atur suara notifikasi dan pengingat sesuai rutinitas Anda.

BACA DAN DENGARKAN AL-QURAN
Baca teks Arab beserta terjemahannya, sesuaikan tampilan bacaan, dan gunakan penanda untuk kembali ke suatu bagian. Teks Al-Quran dan terjemahan bawaan tersedia secara offline. Dengarkan tilawah saat terhubung ke internet dan catat ayat yang telah Anda baca.

KIBLAT, ZIKIR, DAN KALENDER HIJRIAH
Temukan arah kiblat dengan kompas atau peta, ikuti zikir dan doa harian, jelajahi kumpulan hadis, dan lihat kalender Hijriah. Temukan masjid terdekat dengan layanan peta.

PREFERENSI ANDA, SESUAI RITME ANDA
Pilih tampilan terang atau gelap dan bahasa pilihan Anda. Simpan kemajuan bacaan di perangkat Anda, atau gunakan akun SalaTime opsional untuk menyinkronkan preferensi yang didukung dan kemajuan bacaan antarperangkat. Anda dapat menggunakan fitur utama tanpa membuat akun.

Widget sholat menampilkan informasi berguna di layar utama Anda. Akses lokasi bersifat opsional jika Anda memilih kota secara manual; izin notifikasi diperlukan untuk pengingat. Peta online, pencarian masjid terdekat, streaming tilawah, dan sinkronisasi akun memerlukan koneksi internet.

Dukungan: {SUPPORT}
Privasi: {PRIVACY}""",
    },
    'ms': {
        'name': 'SalaTime: Waktu Solat, Quran',
        'subtitle': 'Azan, Kiblat, Doa & Zikir',
        'keywords': 'sholat,jadual,muslim,islam,masjid,hijrah,ramadan,tasbih,zakat,hadis,takwim,alquran,imsak,surau',
        'promotionalText': ('Waktu solat, bacaan al-Quran dan zikir harian dalam satu aplikasi. '
                            'Tetapkan peringatan, cari arah kiblat dan ikuti kemajuan bacaan anda.'),
        'description': f"""Beri ruang untuk ibadah harian anda bersama SalaTime: waktu solat, peringatan azan, al-Quran, kiblat dan zikir dalam satu aplikasi.

WAKTU SOLAT MENGIKUT LOKASI ANDA
Gunakan lokasi anda atau pilih bandar secara manual. Pilih kaedah pengiraan, laraskan setiap waktu solat dan lihat solat seterusnya dengan sekali pandang. Sesuaikan bunyi pemberitahuan dan peringatan mengikut rutin anda.

BACA DAN DENGAR AL-QURAN
Baca teks Arab bersama terjemahan, laraskan paparan bacaan dan gunakan penanda untuk kembali ke sesuatu petikan. Teks al-Quran dan terjemahan yang disertakan boleh digunakan di luar talian. Dengar bacaan al-Quran apabila ada sambungan internet dan rekod ayat yang telah anda baca.

KIBLAT, ZIKIR DAN TAKWIM HIJRAH
Cari arah kiblat menggunakan kompas atau peta, ikuti zikir dan doa harian, layari koleksi hadis dan rujuk takwim Hijrah. Cari masjid berdekatan menggunakan perkhidmatan peta.

PILIHAN ANDA, RENTAK ANDA
Pilih paparan cerah atau gelap dan bahasa pilihan anda. Simpan kemajuan bacaan pada peranti anda, atau gunakan akaun SalaTime pilihan untuk menyegerakkan tetapan yang disokong dan kemajuan bacaan merentas peranti. Anda boleh menggunakan ciri utama tanpa membuat akaun.

Widget solat memaparkan maklumat berguna pada Skrin Utama anda. Akses lokasi adalah pilihan apabila anda memilih bandar secara manual; kebenaran pemberitahuan diperlukan untuk peringatan. Peta dalam talian, carian masjid berdekatan, penstriman bacaan al-Quran dan penyegerakan akaun memerlukan sambungan internet.

Sokongan: {SUPPORT}
Privasi: {PRIVACY}""",
    },
    'es-ES': _ES,
    'es-MX': _ES,
}

# Release notes for these locales; keep them in step with WHATS_NEW for each release.
NEW_LOCALE_WHATS_NEW = {
    'tr': 'Yakındaki cami araması daha güvenilir: daha hızlı sonuçlar, harita hizmeti yoğunken korunan sonuçlar ve kendi dilinizde cami adları.',
    'id': 'Pencarian masjid terdekat lebih andal: hasil lebih cepat, tetap tersedia saat layanan peta sibuk, dan nama masjid dalam bahasa Anda.',
    'ms': 'Carian masjid berdekatan lebih dipercayai: keputusan lebih pantas, kekal tersedia apabila perkhidmatan peta sibuk, dan nama masjid dalam bahasa anda.',
    'es-ES': 'Búsqueda de mezquitas cercanas más fiable: resultados más rápidos, conservados cuando el servicio de mapas está saturado, y nombres en tu idioma.',
    'es-MX': 'Búsqueda de mezquitas cercanas más confiable: resultados más rápidos, conservados cuando el servicio de mapas está saturado, y nombres en tu idioma.',
}
