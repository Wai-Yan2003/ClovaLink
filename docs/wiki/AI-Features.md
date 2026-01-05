# AI Features

ClovaLink includes AI-powered document features that enable intelligent summarization, question answering, and semantic search across your files.

## Overview

The AI module provides:

| Feature | Description |
|---------|-------------|
| **Document Summarization** | Generate concise summaries of documents (PDF, Word, text files) |
| **Question & Answer** | Ask questions about document content and get AI-powered answers |
| **Semantic Search** | Search across documents using natural language queries |

## Supported AI Providers

ClovaLink supports multiple AI providers, allowing you to choose based on your compliance requirements, cost preferences, or existing vendor relationships.

### Cloud Providers

| Provider | Models | Notes |
|----------|--------|-------|
| **OpenAI** | GPT-4o-mini, GPT-4o | Most popular, good balance of cost/quality |
| **Anthropic** | Claude 3 Haiku, Sonnet, Opus | Strong on safety and long documents |
| **Google** | Gemini 1.5 Flash, Pro | Good for multimodal tasks |
| **Azure OpenAI** | GPT-4o-mini, GPT-4o | Enterprise-grade with Azure compliance |
| **Mistral AI** | Mistral Small, Large | European provider, GDPR-friendly |
| **Cohere** | Command-R, Command-R+ | Strong enterprise search capabilities |

### Self-Hosted / Custom

For organizations requiring complete data control, ClovaLink supports self-hosted LLM servers:

| Server | Example Endpoint |
|--------|------------------|
| **Ollama** | `http://localhost:11434/v1` |
| **vLLM** | `http://localhost:8000/v1` |
| **LocalAI** | `http://localhost:8080/v1` |
| **Text Generation Inference** | `http://localhost:8080` |

When using a self-hosted provider, configure:
- **Custom Endpoint URL**: The base URL of your LLM server
- **Model Name**: The model identifier (e.g., `llama3`, `mistral`, `codellama`)

## Configuration

### Enabling AI Features

1. Navigate to **Settings > AI Features** (Admin/SuperAdmin only)
2. Toggle **Enable AI Features**
3. Select your AI provider
4. Enter your API key (encrypted at rest)
5. Click **Save**

### Self-Hosted Configuration

When selecting "Self-Hosted / Custom":

```
AI Provider: [Self-Hosted / Custom]

Custom Endpoint URL: http://localhost:11434/v1
Model Name: llama3
```

### Role-Based Access

Control which roles can use AI features:

| Role | Default Access |
|------|----------------|
| SuperAdmin | ✅ Enabled |
| Admin | ✅ Enabled |
| Manager | ❌ Disabled |
| Employee | ❌ Disabled |

Admins can enable AI access for Manager and Employee roles in the settings.

## Usage Limits

Prevent runaway costs with configurable limits:

| Limit Type | Default | Description |
|------------|---------|-------------|
| **Monthly Token Limit** | 100,000 | Maximum tokens per month |
| **Daily Request Limit** | 100 | Maximum AI requests per day |

Usage resets automatically:
- Daily limits reset at midnight UTC
- Monthly limits reset on the 1st of each month

### Monitoring Usage

View real-time usage statistics in **Settings > AI Features > Usage History**:
- Tokens used today/this month
- Request counts
- Per-user activity log
- Success/failure rates

## Using AI Features

### Document Summarization

1. Open a file preview (PDF, Word, or text document)
2. Click the **Summarize** button (sparkles icon)
3. View the AI-generated summary

Summaries are cached per file, so subsequent requests are instant.

### Question & Answer

1. Open a file preview
2. Click the **Ask AI** button
3. Type your question (e.g., "What are the key dates mentioned?")
4. Get an AI-powered answer based on the document content

### Supported File Types

| Format | Extension | Notes |
|--------|-----------|-------|
| PDF | `.pdf` | Text extracted automatically |
| Word | `.docx` | Full text content |
| Excel | `.xlsx`, `.xls` | All sheets combined |
| PowerPoint | `.pptx` | Slide text extracted |
| Text | `.txt`, `.md`, `.json` | Direct processing |
| CSV | `.csv` | Treated as text |

## Caching

AI responses are cached to reduce API costs and improve response times:

| Cache Type | Duration | Invalidation |
|------------|----------|--------------|
| Summary | Permanent | When file is modified |
| Q&A | Session | When file is modified |

**Note**: Cached summaries are provider-agnostic. If you switch from OpenAI to Claude, existing cached summaries will still be served. Delete the file's cached summary to regenerate with the new provider.

## Maintenance Mode

Temporarily disable new AI requests while still serving cached content:

1. Go to **Settings > AI Features**
2. Enable **Maintenance Mode**
3. Customize the maintenance message
4. Users will see cached summaries but cannot make new requests

Useful for:
- API key rotation
- Provider migrations
- Cost control during budget reviews

## Security Considerations

### Data Processing Agreements

Before enabling AI features, ensure you have appropriate agreements with your AI provider:

- **OpenAI**: Enterprise agreements available for HIPAA/SOC2
- **Azure OpenAI**: Inherits Azure compliance certifications
- **Self-Hosted**: Complete data control, no external transmission

When enabling AI features, ClovaLink displays a warning reminder about data processing agreements.

### What Data is Sent

| Sent to AI Provider | NOT Sent |
|---------------------|----------|
| Document text content | File names |
| User questions | User identities |
| | Metadata |
| | Access logs |

### Audit Logging

All AI operations are logged for compliance:

```
User: john@company.com
Action: summarize
File: contract_2024.pdf
Provider: openai
Tokens: 1,247
Status: success
Timestamp: 2024-01-15T10:30:00Z
```

## Troubleshooting

### "AI features are disabled"

- Check that AI is enabled in tenant settings
- Verify your role has AI access permissions

### "API key required"

- Enter a valid API key in Settings > AI Features
- Use the "Test Connection" button to verify

### "Rate limit exceeded"

- Wait for limit reset (daily or monthly)
- Ask admin to increase limits
- Consider upgrading your AI provider plan

### "Failed to extract text"

- Ensure the file is a supported format
- Check that the PDF contains text (not just images)
- For scanned documents, OCR is not currently supported

## API Reference

### Get AI Status

```http
GET /api/ai/status
Authorization: Bearer <token>
```

### Summarize Document

```http
POST /api/ai/summarize
Authorization: Bearer <token>
Content-Type: application/json

{
  "file_id": "uuid",
  "force_refresh": false
}
```

### Ask Question

```http
POST /api/ai/answer
Authorization: Bearer <token>
Content-Type: application/json

{
  "file_id": "uuid",
  "question": "What are the payment terms?"
}
```

---

*See also: [Admin Guide](Admin-Guide) | [Security](Security) | [API Reference](API-Reference)*

