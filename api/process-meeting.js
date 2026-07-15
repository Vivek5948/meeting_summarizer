const fs = require('fs');
const formidable = require('formidable');
const FormData = require('form-data');
const axios = require('axios');

const config = {
  api: {
    bodyParser: false,
    maxDuration: 60,
  },
};

function parseForm(req) {
  const form = formidable({
    multiples: false,
    keepExtensions: true,
    maxFileSize: 25 * 1024 * 1024,
  });

  return new Promise((resolve, reject) => {
    form.parse(req, (err, fields, files) => {
      if (err) {
        reject(err);
        return;
      }
      resolve({ fields, files });
    });
  });
}

function toArray(value) {
  if (Array.isArray(value)) {
    return value.map((item) => String(item));
  }
  return [];
}

function parseGeminiJson(rawText) {
  const trimmed = String(rawText || '').trim();
  const withoutFences = trimmed
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/```$/, '')
    .trim();

  const parsed = JSON.parse(withoutFences);
  return {
    summary: String(parsed.summary || ''),
    decisions: toArray(parsed.decisions),
    actionItems: toArray(parsed.actionItems),
  };
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  if (!process.env.GROQ_API_KEY || !process.env.GEMINI_API_KEY) {
    return res.status(500).json({
      error: 'Missing GROQ_API_KEY or GEMINI_API_KEY in environment variables',
    });
  }

  try {
    const { files } = await parseForm(req);
    const uploaded = files.audio;
    const audioFile = Array.isArray(uploaded) ? uploaded[0] : uploaded;

    if (!audioFile || !audioFile.filepath) {
      return res.status(400).json({ error: 'Missing audio file. Use field name: audio' });
    }

    const groqForm = new FormData();
    groqForm.append('model', 'whisper-large-v3');
    groqForm.append('file', fs.createReadStream(audioFile.filepath), {
      filename: audioFile.originalFilename || 'meeting-audio.wav',
      contentType: audioFile.mimetype || 'audio/mpeg',
    });

    const transcriptionResponse = await axios.post(
      'https://api.groq.com/openai/v1/audio/transcriptions',
      groqForm,
      {
        headers: {
          ...groqForm.getHeaders(),
          Authorization: `Bearer ${process.env.GROQ_API_KEY}`,
        },
      },
    );

    const transcript = String(transcriptionResponse?.data?.text || '').trim();
    if (!transcript) {
      return res.status(502).json({ error: 'Transcription API returned empty transcript' });
    }

    const prompt = [
      'You are an expert meeting assistant.',
      'Summarize this meeting transcript into key decisions and action items.',
      'Return ONLY valid JSON with keys: summary, decisions, actionItems.',
      'summary must be a short paragraph.',
      'decisions must be an array of strings.',
      'actionItems must be an array of strings.',
      '',
      'Transcript:',
      transcript,
    ].join('\n');

    const geminiResponse = await axios.post(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent',
      {
        contents: [
          {
            parts: [{ text: prompt }],
          },
        ],
        generationConfig: {
          responseMimeType: 'application/json',
        },
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': process.env.GEMINI_API_KEY,
        },
      },
    );

    const rawJsonText =
      geminiResponse?.data?.candidates?.[0]?.content?.parts?.[0]?.text || '';

    const parsedSummary = parseGeminiJson(rawJsonText);

    return res.status(200).json({
      transcript,
      summary: parsedSummary.summary,
      decisions: parsedSummary.decisions,
      actionItems: parsedSummary.actionItems,
    });
  } catch (error) {
    const details = error?.response?.data || error?.message || 'Unknown error';
    return res.status(500).json({
      error: 'Failed to process meeting audio',
      details,
    });
  }
};

module.exports.config = config;
