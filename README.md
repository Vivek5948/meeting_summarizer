# Meeting Summarizer (Flutter + Firebase + Vercel)

Meeting Summarizer transcribes meeting audio and generates action-oriented summaries.

Input:

- Meeting audio files

Output:

- Transcript text
- Executive summary
- Key decisions
- Action items

This repository is now wired for deployment on Vercel:

- Flutter web frontend (static build)
- Vercel serverless backend (`/api/process-meeting`)
- Firestore persistence
- Anonymous Firebase Auth for user-scoped data

## Architecture

1. User uploads audio in Flutter web UI.
2. Frontend posts audio to `POST /api/process-meeting`.
3. Vercel function calls Groq Whisper for ASR.
4. Vercel function calls Gemini for structured summary JSON.
5. Frontend stores transcript + summary + decisions + action items in Firestore.
6. Frontend streams user-specific meeting history.

## Implemented vs Remaining (10 Steps)

1. Define product and schema
- Implemented:
  - Core fields and meeting output pipeline.
- Remaining:
  - Add optional fields like attendees, tags, and meeting duration.

2. Backend foundation
- Implemented:
  - Vercel serverless backend at `api/process-meeting.js`.
  - Health endpoint at `api/health.js`.
- Remaining:
  - Add request rate-limiting and API auth token if this is public.

3. Audio upload flow
- Implemented:
  - Frontend audio picker and multipart upload to backend.
- Remaining:
  - Optional large-file upload path via Firebase Storage.

4. ASR integration
- Implemented:
  - Groq Whisper integration in backend.
- Remaining:
  - Add provider fallback (Google/Azure/OpenAI) for reliability.

5. LLM summarization
- Implemented:
  - Gemini structured JSON summarization with strict prompt.
- Remaining:
  - Add prompt versioning and quality evaluation scripts.

6. Database schema
- Implemented:
  - Firestore save/query methods include `userId`, `status`, and content fields.
- Remaining:
  - Add migrations if you change schema for production analytics.

7. Frontend screens
- Implemented:
  - Upload + history + expandable detail view.
- Remaining:
  - Add dedicated login/settings/search pages.

8. Auth and access control
- Implemented:
  - Anonymous sign-in on startup.
  - Firestore security rules in `firestore.rules`.
- Remaining:
  - Add Google sign-in or email sign-in for real user accounts.

9. Quality and reliability
- Implemented:
  - Better startup error handling and safer data parsing.
  - Basic widget smoke test.
- Remaining:
  - Add integration tests and backend retry/circuit-breaker behavior.

10. Delivery readiness
- Implemented:
  - Deployment files for Vercel and environment template.
- Remaining:
  - Demo video and final GitHub release notes.

## Files Added for Full-Stack Setup

- `api/process-meeting.js` (serverless AI pipeline)
- `api/health.js` (health check)
- `vercel.json` (Vercel config)
- `package.json` (backend dependencies)
- `.env.example` (required secrets)
- `firestore.rules` (user data protection)
- `firestore.indexes.json` (history query index)
- `storage.rules` (optional audio storage rules)
- `scripts/vercel-build.sh` (Flutter web build command)

## Required Environment Variables on Vercel

Set these in Vercel Project Settings -> Environment Variables:

- `GROQ_API_KEY`
- `GEMINI_API_KEY`

## Deploy to Vercel (Step by Step)

1. Push this repository to GitHub.
2. In Vercel, click **Add New Project** and import the repo.
3. In project settings, add environment variables from `.env.example`.
4. Keep build command as configured in `vercel.json`:

```bash
bash scripts/vercel-build.sh
```

5. Deploy.
6. After deployment, open:

```text
https://your-project.vercel.app/api/health
```

You should receive `{ "status": "ok" }` response.

## Firebase Setup (Required)

1. Enable Firebase Authentication -> Anonymous provider.
2. Create Firestore database.
3. Deploy Firestore rules and indexes:

```bash
firebase deploy --only firestore:rules --project meeting-summariz
firebase deploy --only firestore:indexes --project meeting-summariz
```

4. (Optional) Deploy storage rules:

```bash
firebase deploy --only storage --project meeting-summariz
```

## Local Development

1. Install Flutter and Node.js.
2. Install dependencies:

```bash
flutter pub get
npm install
```

3. Run Vercel backend locally:

```bash
vercel dev
```

4. Run Flutter web pointing to local backend:

```bash
flutter run -d chrome --dart-define=BACKEND_BASE_URL=http://localhost:3000
```

## Submission Checklist

- GitHub repo with full source
- README with architecture and setup
- Working deployment URL on Vercel
- Demo video showing:
  - audio upload
  - transcript generation
  - summary + decisions + action items
  - saved history retrieval

