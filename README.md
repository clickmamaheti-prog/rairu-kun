<div align="center">

```
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    ██████╗ ███████╗██╗   ██╗ ██████╗██╗   ██╗██╗  ████████╗ ║
║    ██╔══██╗██╔════╝██║   ██║██╔════╝██║   ██║██║  ╚══██╔══╝ ║
║    ██║  ██║█████╗  ██║   ██║██║     ██║   ██║██║     ██║    ║
║    ██║  ██║██╔══╝  ╚██╗ ██╔╝██║     ██║   ██║██║     ██║    ║
║    ██████╔╝███████╗ ╚████╔╝ ╚██████╗╚██████╔╝███████╗██║    ║
║    ╚═════╝ ╚══════╝  ╚═══╝   ╚═════╝ ╚═════╝ ╚══════╝╚═╝    ║
║                                                              ║
║               ★  PREMIUM CLOUD VPS  ★                       ║
╚══════════════════════════════════════════════════════════════╝
              powered by: DevCulture ©2026 linux
```

# DevCulture Premium VPS

**Ubuntu 20.04 · Ollama AI · Multi-Port · Railway · ntfy Premium**

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new)
![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04_LTS-E95420?logo=ubuntu&logoColor=white)
![Ollama](https://img.shields.io/badge/Ollama-AI_Server-000?logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)
![Cloudflare](https://img.shields.io/badge/Cloudflare-Tunnel-F38020?logo=cloudflare&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-00e5ff)

</div>

---

## ✨ Fitur Premium

| Fitur | Keterangan |
|-------|-----------|
| 🖥 **Ubuntu 20.04 LTS** | OS premium DigitalOcean-grade |
| 🔑 **SSH Multi-Port** | 22, 80, 443, 3000, 8080, 8888, 11434 |
| 🎨 **DevCulture Banner** | Login SSH dengan banner cyan/pink premium |
| 🤖 **Ollama AI** | LLM server gratis — smollm2, phi3, llama3 |
| 🌐 **Web UI Premium** | Dashboard AI dengan tema gelap DevCulture |
| ☁️ **Cloudflare Tunnel** | Domain statis HTTPS gratis |
| 📲 **ntfy Premium** | Notifikasi bergaya profesional lengkap |
| 🔄 **Auto-Update** | Model Ollama update otomatis tiap Senin |
| 🐳 **Docker Ready** | Deploy ke Railway, Fly.io, atau VPS manapun |
| 🆓 **100% Gratis** | Railway $5/bulan credit, semua tools gratis |

---

## 🚀 Deploy ke Railway

### 1. Fork repo ini

### 2. Buat project di [railway.app](https://railway.app)
- New Project → Deploy from GitHub → pilih repo ini

### 3. Set Environment Variables

```env
NTFY_TOPIC=devculture-vps-kamu     # Ganti unik!
ROOT_PASS=PasswordKamu123          # Password SSH
AUTO_PULL_MODEL=smollm2            # Model AI default
CLOUDFLARE_TUNNEL_TOKEN=eyJ...     # Opsional: domain statis
TZ=Asia/Jakarta
```

### 4. Subscribe ntfy di HP
```
ntfy.sh/devculture-vps-kamu
```

---

## 🎨 SSH Login Banner

Saat login SSH, tampil banner premium:

```
╔══════════════════════════════════════════════════════════════╗
║   ██████╗ ███████╗██╗   ██╗ ██████╗██╗   ██╗██╗  ████████╗  ║
║   ██╔══██╗██╔════╝██║   ██║██╔════╝██║   ██║██║  ╚══██╔══╝  ║
║   ██║  ██║█████╗  ██║   ██║██║     ██║   ██║██║     ██║     ║
║   ██║  ██║██╔══╝  ╚██╗ ██╔╝██║     ██║   ██║██║     ██║     ║
║   ██████╔╝███████╗ ╚████╔╝ ╚██████╗╚██████╔╝███████╗██║     ║
║   ╚═════╝ ╚══════╝  ╚═══╝   ╚═════╝ ╚═════╝ ╚══════╝╚═╝     ║
║                                                               ║
║              ★  PREMIUM CLOUD VPS  ★                         ║
╠═══════════════════════════════════════════════════════════════╣
║  OS     │ Ubuntu 20.04 LTS                                    ║
║  RAM    │ 1024MB / 2048MB (50%)                               ║
║  Disk   │ 2.1GB/8GB (26%)                                     ║
║  Ollama │ ● Online  (AI Model Server)                         ║
║  SSH    │ bore.pub:XXXXX                                       ║
║  Web UI │ http://bore.pub:XXXXX                               ║
╚═══════════════════════════════════════════════════════════════╝
              powered by: DevCulture ©2026 linux
```

*(Warna cyan & pink gradient di terminal)*

---

## 📲 Notifikasi ntfy Premium

Semua notif bergaya profesional dengan branding DevCulture:

| Event | Notifikasi |
|-------|-----------|
| 🚀 Startup | Booting dengan info lengkap |
| ⚡ VPS Online | SSH port + URL + server stats |
| ⬇️ Download Model | Progress model AI |
| ✅ Model Siap | Info model + cara pakai |
| ☁️ Domain Live | Cloudflare Tunnel aktif |
| 📊 Status 5-menit | RAM, CPU, Disk, Models |
| 🚨 Service Crash | Alert urgent + auto-restart |
| ✅ Deploy | GitHub Actions berhasil |

---

## 🤖 Menggunakan Ollama

### Via SSH
```bash
ssh root@bore.pub -p PORT
ollama run smollm2
ollama run phi3
ollama list
```

### Via API
```bash
curl -X POST https://domain-kamu/api/chat \
  -H "Content-Type: application/json" \
  -d '{"model":"smollm2","messages":[{"role":"user","content":"Halo!"}],"stream":false}'
```

### Via Python (OpenAI SDK)
```python
from openai import OpenAI
client = OpenAI(base_url="https://domain-kamu/api", api_key="ollama")
response = client.chat.completions.create(
    model="smollm2",
    messages=[{"role":"user","content":"Halo!"}]
)
print(response.choices[0].message.content)
```

---

## 📦 Model AI Gratis

| Model | Size | RAM | Best For |
|-------|------|-----|----------|
| `smollm2` ⭐ | 270MB | ~400MB | Default, cepat |
| `tinyllama` | 637MB | ~800MB | Chat ringan |
| `phi3` ⭐ | 2.3GB | ~3GB | **Recommended** |
| `llama3.2` | 2.0GB | ~3GB | Chat premium |
| `deepseek-coder` | 776MB | ~1GB | Coding |
| `mistral` | 4.1GB | ~5GB | Kualitas tinggi |

---

## 🏗 Struktur Proyek

```
rairu-kun/
├── Dockerfile              # Ubuntu 20.04 + Ollama + bore + cloudflared
├── entrypoint.sh           # Startup + SSH + Nginx + Ollama + ntfy premium
├── devculture-banner.sh    # SSH login banner cyan/pink ANSI
├── nginx-ollama.conf       # Nginx proxy Ollama API
├── index.html              # DevCulture Ollama Web UI
├── railway.json            # Railway config
└── .github/workflows/
    └── railway-deploy.yml  # Auto-deploy CI/CD
```

---

<div align="center">

**Dibuat dengan ❤️ oleh [DevCulture](https://github.com/clickmamaheti-prog)**

*Premium VPS · AI Gratis · Tidak Perlu VPS Mahal*

⭐ **Star repo ini jika membantu!** ⭐

```
powered by: DevCulture ©2026 linux
```

</div>
