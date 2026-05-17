# 🛠️ apistech/scripts

Kumpulan script PowerShell untuk **maintenance & optimasi Windows** dengan fokus pada manajemen Registry dan Services. Dirancang untuk kemudahan penggunaan dan kompatibilitas luas dari **Windows 7 hingga Windows 11**.

> **📌 Status:** Toolkit terintegrasi dengan fitur Maintenance Registry + Service Management dalam satu script `SVC_Toolkit.ps1`

---

## 📁 File dalam Repository

| File | Deskripsi |
|:---|:---|
| **`SVC_Toolkit.ps1`** | **Script utama** (PowerShell). Menu interaktif dengan 3 fungsi: Cleanup Registry, Ubah StartupType Services, dan Hapus Service Pihak Ketiga. Kompatibel Windows 7–11 dengan fallback WMI untuk PS 2.0. |
| **`SVC_Toolkit.bat`** | Wrapper lokal. Menjalankan `SVC_Toolkit.ps1` dari folder yang sama dengan hak administrator. |
| **`SVC_Toolkit_ONLINE.bat`** | Wrapper online. Unduh `SVC_Toolkit.ps1` langsung dari GitHub lalu jalankan—selalu versi terbaru, tidak perlu setup awal. |

---

## 🚀 Mulai Cepat

### Opsi 1: Setup Offline (Lokal)
1. Clone atau download semua file ke satu folder
2. Klik kanan **`SVC_Toolkit.bat`**
3. Pilih **"Run as administrator"** (wajib)
4. Pilih menu → selesai ✓

### Opsi 2: Online Mode (Tanpa Setup)
1. Download hanya **`SVC_Toolkit_ONLINE.bat`**
2. Klik kanan → **"Run as administrator"**
3. Script akan unduh versi terbaru otomatis, jalankan, lalu bersihkan file sementara ✓

---

## 🎮 Menu Utama

Setelah script berjalan, pilih dari 3 fungsi utama:

### 1️⃣ Cleanup Registry Values
**Fungsi:** Hapus registry values yang sudah diset untuk browser/system policy

**Target:**
- **Windows Maintenance** – Activation Boundary
- **Microsoft Edge** – 10 kebijakan (autofill, background mode, security, dll)
- **Google Chrome** – 10 kebijakan yang sama

**Hasil:** Me-reset ke default policy browser yang telah disesuaikan

**Catatan:** Hanya menghapus value yang ada; skip otomatis untuk path/value yang tidak ditemukan

---

### 2️⃣ Ubah StartupType Services
**Fungsi:** Ubah mode startup 200+ Windows services

**Pilihan:**
- **Disabled** → Service tidak berjalan saat boot
- **Manual** → Service hanya berjalan saat dibutuhkan

**Daftar service:** Dari nLite + rekomendasi Windows 11 (synced mudah di script)

**Teknologi:**
- PowerShell 4+: `Set-Service` cmdlet
- PowerShell 2.0 (Win7): Fallback ke WMI auto-detect

**Safety:** Hanya proses service yang terdaftar; report lengkap (berhasil/skip/gagal)

---

### 3️⃣ Hapus Service Pihak Ketiga
**Fungsi:** Scan & hapus service dari aplikasi third-party (tidak bisa di-*undo*)

**Pola match:** Adobe, Brave, Chrome, Edge, VirtualBox, VMware, Wondershare, Intel services, dll

**2 Mode:**
- **Dry Run (Mode 1):** List service yang cocok, tidak menghapus → gunakan untuk preview
- **Eksekusi (Mode 2):** Stop + Delete service yang cocok → HATI-HATI ⚠️

**Workflow:**
1. Jalankan Dry Run dulu → validasi list
2. Jalankan Eksekusi jika yakin

---

## 📋 Logging

Setiap eksekusi membuat file log otomatis:

```
ToolkitLog_YYYYMMDD_HHMMSS.log
```

**Contoh:** `ToolkitLog_20260502_143022.log`

**Lokasi:** Folder yang sama dengan script

**Isi:** Semua action (berhasil ✓, skip ⊘, gagal ✗) dengan timestamp & pesan error (jika ada)

---

## 🖥️ Persyaratan Sistem

| Komponen | Minimum | Rekomendasi |
|:---|:---|:---|
| **OS** | Windows 7 | Windows 10/11 |
| **PowerShell** | 2.0* | 5.1+ |
| **Akses** | Administrator | Administrator |
| **Arch** | 32/64-bit | 64-bit |

*PS 2.0 (default Windows 7): Otomatis gunakan WMI fallback, semua fitur tetap bekerja

---

## ⚙️ Customization (Advanced User)

### Edit Daftar Registry Values
Di **Menu 1**, target registry disimpan dalam `$registryTargetsRaw` (baris 45–67).

Format:
```powershell
HKLM:\PATH\TO\KEY|ValueName
```

Contoh menambah:
```powershell
HKLM:\SOFTWARE\Policies\MyApp|PolicyKey
```

### Edit Daftar Services
Di **Menu 2**, service list ada di `$servicesRaw` (baris 122–352).

Format: satu service per baris, tanpa kutip. Mudah sync dengan nLite.

Contoh:
```
MyService
AnotherService
```

### Edit Daftar Pattern Service
Di **Menu 3**, pattern matching ada di `$patternsRaw` (baris 426–461).

Format: regex per baris. Mendukung versioning, contoh:
```
^GoogleChromeElevationService([0-9\.]+)?$
^edgeupdate([0-9\.]+)?$
```

---

## ⚠️ Penting & Safety Tips

1. **Backup:** Buat System Restore Point sebelum jalankan
2. **Test Dulu:** Menu 3 (Remove Service) → gunakan Dry Run terlebih dahulu
3. **Admin Required:** Script akan error jika tidak run as admin
4. **Read Logs:** Check log file jika ada yang fail
5. **PowerShell Policy:** Script otomatis set `Unrestricted` saat jalankan (instruksi di header)

---

## 🔗 Versi & Changelog

- **Latest:** Integrated Maintenance + Service Toolkit (v1.0)
- Kompatibel Windows 7–11
- PowerShell 2.0–5.1+ support

---

## 📝 Lisensi & Kontribusi

Script ini adalah public repository. Silakan fork, modify, atau contribute improvement melalui pull request.

---

**Punya pertanyaan?** Buka issue atau cek log file untuk debugging. Happy maintaining! 🎯
