# Open With Toolkit

**Periksa registrasi asosiasi file Windows, tinjau entri Open With, dan ekspor laporan — lewat toolkit PowerShell sederhana.**

Open With Toolkit adalah kumpulan skrip Windows batch dan PowerShell untuk memeriksa data registry asosiasi file. Isinya mencakup pemindaian `UserChoice` yang bersifat read-only, pemeriksaan per ekstensi, pencarian registrasi aplikasi, serta alur terkontrol untuk menghapus value Open With tertentu milik pengguna.

> **Catatan keamanan:** Perubahan registry dapat memengaruhi cara Windows membuka file. Periksa target dengan teliti. Toolkit ini tidak mengubah `UserChoice` atau value `Hash`-nya. Manager hanya mengizinkan penghapusan value per pengguna (`HKCU`) tertentu dan mencoba membuat backup registry sebelum menghapus value.

**Bahasa:** [English](README.md) · [Bahasa Indonesia](README.id.md)

## Fitur

- **Scan UserChoice** — daftar ekstensi yang memiliki key `UserChoice`, lalu ekspor hasil ke CSV dan TXT.
- **Inspect Extension** — tinjau `UserChoice`, ProgID, Open With, SupportedTypes, dan petunjuk registrasi terkait yang berhasil ditemukan.
- **Search App** — cari registrasi aplikasi, App Paths, entri uninstall, dan paket Appx pengguna saat ini pada lokasi registry yang didukung.
- **Manage value Open With tertentu** — hapus value per pengguna yang didukung setelah konfirmasi, dengan upaya ekspor backup registry dan verifikasi setelah penghapusan.

Hasil bergantung pada registrasi di instalasi Windows yang sedang digunakan. Hasil yang tidak ditemukan bukan bukti bahwa aplikasi tidak terpasang atau tidak bisa membuka suatu file.

## File yang disertakan

| File | Fungsi |
| --- | --- |
| `Manage-OpenWithChoices.bat` | Menjalankan toolkit interaktif |
| `Manage-OpenWithChoices.ps1` | Menu utama: scan, inspect, manage, dan search |
| `Read-OpenWithRegistry.bat` / `.ps1` | Pembaca registry terpisah |
| `Add-OpenWithApp.bat` / `.ps1` | Helper terpisah untuk menambahkan aplikasi ke registrasi Open With |

## Persyaratan

- Windows
- Windows PowerShell (runtime yang dituju adalah Windows PowerShell bawaan Windows)
- Akun pengguna yang memiliki akses ke lokasi registry yang ingin diperiksa

Fitur read-only biasanya tidak memerlukan hak Administrator. Hindari menjalankan toolkit sebagai Administrator kecuali kamu memahami alasan dan risikonya.

## Mulai cepat

1. Unduh atau clone repository ini.
2. Ekstrak jika mengunduh ZIP.
3. Buka folder proyek di File Explorer.
4. Klik dua kali `Manage-OpenWithChoices.bat`.

Atau jalankan dari PowerShell:

```powershell
.\Manage-OpenWithChoices.bat
```

Menu utama menyediakan:

1. **Scan UserChoice** — pemindaian read-only dan ekspor CSV/TXT.
2. **Inspect Extension** — masukkan ekstensi seperti `.php` atau `.json`.
3. **Manage Open With** — periksa entri yang tersedia dan, jika diizinkan, hapus value per pengguna yang dipilih.
4. **Search App** — cari aplikasi berdasarkan nama atau executable di sumber registry yang didukung.
5. **Exit** — keluar.

Laporan dan backup registry disimpan di folder `OpenWith-Backups` di sebelah toolkit ketika operasi terkait membuatnya.

## Keamanan dan batasan

- Toolkit ditujukan untuk pemeriksaan dan pemeliharaan terarah, bukan pembersihan massal.
- `UserChoice` dan value `Hash` diperlakukan sebagai read-only. Untuk mengganti aplikasi default, gunakan **Windows Settings → Apps → Default apps**.
- Penghapusan dibatasi pada value per pengguna (`HKCU`) yang didukung. Registrasi tingkat mesin (`HKLM`), command aplikasi, dan `UserChoice` tidak dihapus oleh manager.
- Sebelum penghapusan yang didukung, manager mencoba mengekspor key registry target. Jika ekspor gagal, penghapusan dibatalkan.
- Backup registry yang berhasil dan pemeriksaan setelah penghapusan adalah pengaman yang berguna, tetapi bukan pengganti pemahaman atas entri yang dipilih.
- Registrasi berbeda antarversi Windows dan aplikasi. Toolkit mungkin tidak menemukan semua kemungkinan jalur registrasi.
- Skrip telah diuji secara manual pada satu lingkungan Windows untuk alur yang didokumentasikan; hal ini tidak menjamin kompatibilitas pada semua konfigurasi Windows.

**Sebelum mengubah apa pun:** jalankan scan dan inspeksi read-only terlebih dahulu. Untuk tes penghapusan pertama, gunakan entri percobaan yang bisa dibuang—bukan ekstensi yang kamu andalkan.

## Output dan privasi

Laporan scan dan pencarian dapat mengungkap aplikasi yang terpasang, ekstensi file, jalur registry, dan lokasi instalasi lokal. Periksa file CSV, TXT, dan `.reg` sebelum membagikannya.

Jangan commit laporan pribadi, ekspor registry, atau output khusus komputer ke repository publik.

## Kontribusi

Laporan bug dan perbaikan yang terarah dipersilakan. Sertakan versi Windows, menu yang digunakan, pesan error lengkap, dan contoh output yang sudah disamarkan. Jangan lampirkan ekspor registry yang berisi informasi pribadi atau khusus komputer tanpa memeriksanya terlebih dahulu.

## Lisensi

Lisensi belum disertakan. Sampai lisensi ditambahkan, jangan menganggap kode ini tersedia untuk digunakan ulang, didistribusikan, atau dimodifikasi berdasarkan lisensi open-source.
