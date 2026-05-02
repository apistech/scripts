# 🛠️ apistech/scripts

Kumpulan script PowerShell untuk **maintenance & optimasi Windows** (Registry & Services), dirancang untuk kemudahan penggunaan dan kompatibilitas luas dari Windows 7 hingga Windows 11.

> **📌 Status:** Script utama `SVC_Toolkit.ps1` telah digabung (merged) menjadi **1 toolkit serbaguna** yang mencakup fungsi Maintenance Registry + Management Services.

---

## 📁 Daftar File dalam Repository

| File | Fungsi |
| :--- | :--- |
| **`SVC_Toolkit.ps1`** | **Script utama** (PowerShell). Menu interaktif untuk: <br> • Cleanup registry values (Edge/Chrome/Maintenance)<br> • Ubah StartupType services (Disabled/Manual)<br> • Hapus service pihak ketiga (Dry run / Eksekusi) |
| **`SVC_Toolkit.bat`** | Wrapper lokal. Menjalankan `SVC_Toolkit.ps1` dari folder yang sama. |
| **`SVC_Toolkit_ONLINE.bat`** | Wrapper online. Mengunduh `SVC_Toolkit.ps1` langsung dari GitHub lalu menjalankannya (selalu versi terbaru). |
| **`README.md`** | Dokumentasi ini. |

---

## 🚀 Cara Penggunaan (2 Metode)

### Metode 1: Jalankan Langsung (Lokal)
1. **Download semua file** dari repository ini ke satu folder.
2. **Klik kanan** pada `SVC_Toolkit.bat`.
3. Pilih **"Run as administrator"** (WAJIB).

### Metode 2: Selalu Versi Terbaru (Online)
1. **Download hanya** `SVC_Toolkit_ONLINE.bat` (atau clone repo).
2. **Klik kanan** pada `SVC_Toolkit_ONLINE.bat`.
3. Pilih **"Run as administrator"** (WAJIB).
4. Script akan otomatis mengunduh `SVC_Toolkit.ps1` dari GitHub, menjalankannya, lalu membersihkan file sementara.

---

## 🎮 Menu Interaktif (Setelah Script Berjalan)

#### 1️⃣ Cleanup Registry Values
- Menghapus **20+ registry values** yang sudah ditentukan untuk:
  - `Windows Maintenance` (Activation Boundary)
  - `Microsoft Edge` (10 kebijakan, seperti autofill, background mode)
  - `Google Chrome` (10 kebijakan serupa)
- **Efek:** Me-reset kebijakan browser yang mungkin telah disetel sebelumnya.

#### 2️⃣ Ubah StartupType Services
- Mengubah **200+ service** (daftar preset dari nLite + rekomendasi Windows 11) menjadi `Disabled` atau `Manual`.
- Otomatis mendeteksi versi PowerShell (fallback ke WMI untuk Windows 7).
- **Aman** – hanya memproses service yang ada dalam daftar.

#### 3️⃣ Hapus Service Pihak Ketiga
- **Dry Run (mode 1):** Hanya menampilkan service yang cocok dengan pola, **tanpa menghapus**.
- **Eksekusi (mode 2):** **Stop** dan **Hapus** service yang cocok dengan pola (Adobe, Brave, Chrome, Edge, VirtualBox, VMware, Wondershare, dll).
- **⚠️ Peringatan:** Tidak bisa di-*undo*! Gunakan Dry Run terlebih dahulu.

---

## 📋 Logging

Setiap kali script dijalankan, akan dibuat file log otomatis di **folder yang sama** dengan script.

| Format nama | Contoh | Isi |
| :--- | :--- | :--- |
| `ToolkitLog_YYYYMMDD_HHMMSS.log` | `ToolkitLog_20260502_143022.log` | Semua tindakan (berhasil, gagal, dilewati) |

---

## 🖥️ Persyaratan Sistem

| Komponen | Minimum | Rekomendasi |
| :--- | :--- | :--- |
| **OS** | Windows 7 | Windows 10/11 |
| **PowerShell** | Versi 2.0 (default Windows 7) | Versi 5.1+ (fitur lebih baik) |
| **Hak Akses** | **Administrator** (WAJIB) | Administrator |
| **Arsitektur** | 32-bit / 64-bit | 64-bit |

> **Untuk Windows 7:** Script otomatis menggunakan metode WMI fallback untuk kompatibilitas penuh.

---

## ⚙️ Kustomisasi Daftar Service (Untuk Advanced User)

Jika Anda ingin menambah/mengurangi daftar service yang diproses di **Menu 2**, edit bagian `$servicesRaw` di dalam `SVC_Toolkit.ps1`:

```powershell
$servicesRaw = @"
AxInstSV
SensrSvc
AeLookupSvc
... tambah atau hapus service di sini ...
"@
