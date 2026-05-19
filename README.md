# Nexus AI — Premium RAG Agent

A production-quality, premium AI-agent application:

- **Flutter** desktop + mobile + web client with adaptive UI (NavigationRail + drawer), Material 3, custom Corporate Tech theme (Midnight Blue + Electric Cyan), streaming markdown chat, conversation history, file upload with progress, drag-and-drop, live backend telemetry, animations, and persistent dark/light theme.
- **FastAPI** backend with **LangChain + Groq** for the LLM, **HuggingFace** embeddings, **ChromaDB** vector store, and **SQLite** for conversation/document persistence. Supports streaming responses.

```
windsurf-project-2/
├── backend/                    FastAPI + LangChain + Groq + Chroma
│   ├── app/
│   │   ├── main.py             FastAPI app + CORS + lifespan
│   │   ├── config.py           Settings (.env)
│   │   ├── db.py               SQLite async models
│   │   ├── rag.py              Vector store + chunking + retrieval
│   │   ├── llm.py              Groq chat chain
│   │   ├── schemas.py          Pydantic request/response models
│   │   └── routers/
│   │       ├── documents.py    /upload, /documents, DELETE /documents/{id}
│   │       ├── chat.py         /chat, /chat/stream, /conversations
│   │       └── stats.py        /stats, /health
│   ├── requirements.txt
│   ├── .env.example
│   └── run.ps1
└── lib/                        Flutter app
    ├── main.dart
    ├── theme/                  Corporate Tech color system
    ├── widgets/                MessageBubble, ChatInputBar, HexLogo…
    ├── providers/              ChatProvider (streaming), DocumentsProvider,
    │                           ConversationsProvider, AppStatsProvider,
    │                           ThemeProvider
    ├── services/               HTTP clients for /chat, /upload,
    │                           /conversations, /stats, /health
    ├── models/                 Domain models
    └── screens/                Dashboard, Chat, Documents, Settings, AppShell
```

---

## 1. Run the backend (FastAPI + Groq RAG)

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env       # edit .env and paste your GROQ_API_KEY
.\run.ps1                          # http://localhost:8000  •  docs at /docs
```

Get a free Groq key at <https://console.groq.com/keys>.

On first request, HuggingFace will download the embedding model (~90 MB, one-time).

### Backend API

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/upload` | multipart `file` field — indexes a PDF/DOCX/TXT/MD into Chroma |
| `GET`  | `/documents` | List all indexed documents |
| `DELETE` | `/documents/{id}` | Remove document + its vectors |
| `POST` | `/chat` | `{message, conversation_id?, history?}` → grounded answer + sources |
| `POST` | `/chat/stream` | Same input, streams ndjson tokens for live typing |
| `GET`  | `/conversations` | List saved chats |
| `GET`  | `/conversations/{id}` | Full chat with messages + sources |
| `DELETE` | `/conversations/{id}` | Delete a chat |
| `GET`  | `/stats` | Documents, chunks, conversations, messages, active model |
| `GET`  | `/health` | `{status, model, groq_configured}` |

---

## 2. Run the Flutter app

Prereqs: Flutter 3.24+, the appropriate platform toolchain (Android SDK / Xcode / Windows desktop / Chrome).

```powershell
flutter pub get

# Desktop (Windows)
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8000

# Android emulator (loopback to host machine)
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000

# Physical Android device on the same Wi-Fi
flutter run -d <device_id> --dart-define=API_BASE_URL=http://<your-pc-ip>:8000

# Web
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

### Release APK

```powershell
flutter build apk --release --dart-define=API_BASE_URL=http://<your-pc-ip>:8000
# Output: build\app\outputs\flutter-apk\app-release.apk
```

### Regenerate launcher icons (after replacing `assets/icon/app_icon.png`)

```powershell
dart run flutter_launcher_icons
```

---

## 3. Features

### Dashboard
- Live stats from `/stats`: documents, knowledge chunks, conversations, backend status with pulse animation.
- Animated counters that tween in on first paint.
- Backend connectivity card shows active Groq model or "Offline" with the exact command to start the server.
- Auto-refreshes every 20 seconds.

### Chat
- **Streaming** answers token-by-token via `/chat/stream` (ndjson).
- **Conversation history sidebar** (desktop) / drawer (mobile) with new/select/delete.
- Markdown rendering, syntax-highlighted code blocks, source citation chips, copy-to-clipboard.
- Stop generation, retry on error, suggestion chips on empty state, animated empty hero.
- Conversation persistence on the server, switch between chats freely.

### Documents
- Real multipart upload to `/upload` with byte-level progress bar.
- Desktop drag-and-drop (`desktop_drop`), mobile file picker.
- File-type validation (PDF / DOCX / TXT / MD).
- "Sync with backend" button reloads the indexed library; preserves in-progress uploads.
- Per-row retry on failure, delete from server + local.

### Settings
- Agam profile, dark/light persistent theme.
- Live "AI Engine" card showing Groq model + whether the key is configured.
- Streaming on/off toggle (instantly affects new turns).
- "Clear all conversations" with confirmation.

### Theme & UX
- Corporate Tech palette: Midnight Blue (#011627) + Electric Cyan (#2EC4B6) + Cyber Lime accents.
- Adaptive layout: NavigationRail (≥800px) ↔ NavigationBar (mobile).
- Smooth bubble transitions, gradient stat cards, pulse indicators.

---

## 4. Troubleshooting

| Symptom | Fix |
|---------|-----|
| Dashboard shows "Backend Offline" | Backend not running. From `backend/` run `.\run.ps1`. |
| `503 GROQ_API_KEY is not set` | Edit `backend/.env` and paste your Groq key, then restart the server. |
| Android emulator can't reach backend | Use `http://10.0.2.2:8000` (emulator loopback to host). |
| Physical phone can't reach backend | Use your PC's LAN IP (`ipconfig`) and ensure firewall allows port 8000. |
| Upload fails with "produced no extractable text" | The PDF/DOCX is scanned/image-only. OCR is not enabled. Use a text PDF. |
| First upload takes ~30s | HuggingFace is downloading the embedding model once. Subsequent uploads are fast. |

---

## 5. Stack reference

**Backend:** FastAPI · LangChain · langchain-groq · langchain-chroma · langchain-huggingface · SQLAlchemy async · aiosqlite · pypdf · python-docx · sentence-transformers.

**Frontend:** Flutter · Provider · http · file_picker · desktop_drop · cross_file · flutter_markdown · intl · shared_preferences · uuid · flutter_launcher_icons.
