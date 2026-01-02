# Python ML Backend JSON-RPC Contract: Rust ↔ Python

**Feature**: 001-local-speech-to-text
**Date**: 2026-01-02
**Protocol**: JSON-RPC 2.0 over stdin/stdout subprocess communication

---

## Overview

The Python ML backend runs as a long-lived subprocess spawned by the Rust Tauri core. Communication uses JSON-RPC 2.0 protocol over stdin/stdout pipes.

**Process Lifecycle**:
1. Rust spawns Python process on app startup: `python3 -m ml_backend.server`
2. Python loads default language model (English)
3. Rust sends JSON-RPC requests via stdin
4. Python processes requests and sends responses via stdout
5. Python emits progress notifications for long-running operations
6. Rust kills Python process on app shutdown

**Protocol Characteristics**:
- Synchronous request/response for most operations
- Asynchronous notifications for progress updates
- One request per line (newline-delimited JSON)
- Responses match request IDs for correlation
- Notifications have no ID field

---

## JSON-RPC 2.0 Format

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "method_name",
  "params": {
    "param1": "value1",
    "param2": "value2"
  }
}
```

### Success Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "key": "value"
  }
}
```

### Error Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32600,
    "message": "Invalid request",
    "data": {
      "details": "Additional error context"
    }
  }
}
```

### Notification (No Response Expected)

```json
{
  "jsonrpc": "2.0",
  "method": "notification_name",
  "params": {
    "key": "value"
  }
}
```

---

## Methods

### `transcribe`

Transcribes audio to text using the loaded language model.

**Request**:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "transcribe",
  "params": {
    "audio_base64": "UklGRiQAAABXQVZF...",
    "language": "en",
    "sample_rate": 16000,
    "enable_vad": true
  }
}
```

**Parameters**:
- `audio_base64` (string, required): Base64-encoded audio samples (Int16 PCM)
- `language` (string, required): Language code (e.g., 'en', 'es', 'fr')
- `sample_rate` (number, required): Audio sample rate in Hz (must be 16000)
- `enable_vad` (boolean, optional): Enable voice activity detection, default: true

**Success Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "text": "Hello world this is a test",
    "confidence": 0.95,
    "duration_ms": 87,
    "word_count": 6,
    "segments": [
      {
        "text": "Hello",
        "start_time": 0,
        "end_time": 320,
        "confidence": 0.98
      },
      {
        "text": "world",
        "start_time": 320,
        "end_time": 680,
        "confidence": 0.96
      }
    ],
    "language_detected": "en"
  }
}
```

**Error Responses**:

*Invalid sample rate*:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32602,
    "message": "Invalid params",
    "data": {
      "field": "sample_rate",
      "details": "Sample rate must be 16000 Hz, got 44100"
    }
  }
}
```

*Model not loaded*:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32001,
    "message": "Model not found",
    "data": {
      "language": "es",
      "details": "Model for language 'es' not downloaded. Run download_model first."
    }
  }
}
```

*Transcription failed*:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32002,
    "message": "Transcription failed",
    "data": {
      "details": "MLX inference error: out of memory"
    }
  }
}
```

**Progress Notifications** (emitted during long transcriptions):
```json
{
  "jsonrpc": "2.0",
  "method": "transcription_progress",
  "params": {
    "request_id": 1,
    "percent": 45,
    "stage": "inference",
    "estimated_seconds_remaining": 2.3
  }
}
```

**Performance Requirements**:
- Transcription latency: <100ms for 5-second audio clips
- Memory usage: <500MB during inference
- GPU utilization: Use Metal GPU via MLX

---

### `load_model`

Loads a language model into memory.

**Request**:
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "load_model",
  "params": {
    "language": "es",
    "unload_previous": true
  }
}
```

**Parameters**:
- `language` (string, required): Language code to load
- `unload_previous` (boolean, optional): Unload currently loaded model, default: true

**Success Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "language": "es",
    "model_path": "/Users/.../models/parakeet-tdt-0.6b-es",
    "load_time_ms": 1850,
    "memory_mb": 612
  }
}
```

**Error Responses**:

*Model not found*:
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "error": {
    "code": -32001,
    "message": "Model not found",
    "data": {
      "language": "es",
      "expected_path": "/Users/.../models/parakeet-tdt-0.6b-es",
      "details": "Model files not found. Download model first."
    }
  }
}
```

*Load failed*:
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "error": {
    "code": -32003,
    "message": "Model load failed",
    "data": {
      "language": "es",
      "details": "Corrupted model weights. Checksum mismatch."
    }
  }
}
```

**Progress Notifications**:
```json
{
  "jsonrpc": "2.0",
  "method": "model_load_progress",
  "params": {
    "request_id": 2,
    "percent": 67,
    "stage": "loading_weights"
  }
}
```

---

### `unload_model`

Unloads a language model from memory to free GPU resources.

**Request**:
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "unload_model",
  "params": {
    "language": "es"
  }
}
```

**Parameters**:
- `language` (string, required): Language code to unload

**Success Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {
    "language": "es",
    "memory_freed_mb": 612
  }
}
```

**Error Responses**:

*Model not loaded*:
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "error": {
    "code": -32004,
    "message": "Model not loaded",
    "data": {
      "language": "es",
      "details": "Model is not currently loaded in memory"
    }
  }
}
```

---

### `get_loaded_models`

Returns list of currently loaded models.

**Request**:
```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "get_loaded_models",
  "params": {}
}
```

**Success Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "result": {
    "models": [
      {
        "language": "en",
        "memory_mb": 598,
        "loaded_at": "2026-01-02T10:00:00Z",
        "last_used": "2026-01-02T14:30:00Z"
      }
    ],
    "total_memory_mb": 598
  }
}
```

---

### `detect_voice_activity`

Analyzes audio for voice activity (speech vs. silence).

**Request**:
```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "method": "detect_voice_activity",
  "params": {
    "audio_base64": "UklGRiQAAABXQVZF...",
    "sample_rate": 16000,
    "threshold": 0.5
  }
}
```

**Parameters**:
- `audio_base64` (string, required): Base64-encoded audio chunk
- `sample_rate` (number, required): Must be 16000 Hz
- `threshold` (number, optional): Energy threshold (0.0 - 1.0), default: 0.5

**Success Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "result": {
    "is_speech": true,
    "speech_probability": 0.87,
    "energy_level": 0.64,
    "duration_ms": 100
  }
}
```

**Use Case**: Real-time VAD during recording to detect silence and auto-stop.

---

### `ping`

Health check to verify subprocess is responsive.

**Request**:
```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "method": "ping",
  "params": {}
}
```

**Success Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "result": {
    "status": "ok",
    "uptime_seconds": 1234,
    "memory_mb": 612
  }
}
```

---

### `shutdown`

Gracefully shuts down the Python subprocess.

**Request**:
```json
{
  "jsonrpc": "2.0",
  "id": 7,
  "method": "shutdown",
  "params": {}
}
```

**Success Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 7,
  "result": {
    "message": "Shutting down gracefully"
  }
}
```

**Side Effects**:
- Unloads all models
- Frees GPU memory
- Exits Python process (exit code 0)

---

## Notifications (Python → Rust)

### `transcription_progress`

Emitted during transcription to report progress.

**Notification**:
```json
{
  "jsonrpc": "2.0",
  "method": "transcription_progress",
  "params": {
    "request_id": 1,
    "percent": 45,
    "stage": "inference",
    "estimated_seconds_remaining": 2.3
  }
}
```

**Stages**:
- `preprocessing`: Audio feature extraction
- `inference`: Model forward pass
- `decoding`: Token-to-text decoding
- `postprocessing`: Text cleanup and formatting

---

### `model_load_progress`

Emitted during model loading to report progress.

**Notification**:
```json
{
  "jsonrpc": "2.0",
  "method": "model_load_progress",
  "params": {
    "request_id": 2,
    "percent": 67,
    "stage": "loading_weights"
  }
}
```

**Stages**:
- `loading_config`: Reading config.json
- `loading_weights`: Loading weights.safetensors
- `loading_tokenizer`: Loading tokenizer.json
- `gpu_transfer`: Transferring to Metal GPU

---

### `log`

Emitted for Python-side logging (debug, info, warning, error).

**Notification**:
```json
{
  "jsonrpc": "2.0",
  "method": "log",
  "params": {
    "level": "info",
    "message": "Model loaded successfully",
    "timestamp": "2026-01-02T14:30:00Z"
  }
}
```

**Levels**: `debug`, `info`, `warning`, `error`

---

## Error Codes

| Code | Name | Description |
|------|------|-------------|
| -32700 | Parse error | Invalid JSON received |
| -32600 | Invalid request | JSON-RPC structure invalid |
| -32601 | Method not found | Method does not exist |
| -32602 | Invalid params | Invalid method parameters |
| -32603 | Internal error | Internal JSON-RPC error |
| -32001 | Model not found | Language model not downloaded |
| -32002 | Transcription failed | ML inference error |
| -32003 | Model load failed | Failed to load model weights |
| -32004 | Model not loaded | Model not in memory |
| -32005 | Invalid audio | Audio format or encoding invalid |

---

## Communication Pattern Examples

### Example 1: Successful Transcription

**Rust → Python (Request)**:
```json
{"jsonrpc":"2.0","id":1,"method":"transcribe","params":{"audio_base64":"...","language":"en","sample_rate":16000}}
```

**Python → Rust (Progress Notification)**:
```json
{"jsonrpc":"2.0","method":"transcription_progress","params":{"request_id":1,"percent":50,"stage":"inference"}}
```

**Python → Rust (Success Response)**:
```json
{"jsonrpc":"2.0","id":1,"result":{"text":"Hello world","confidence":0.95,"duration_ms":87,"word_count":2,"segments":[]}}
```

---

### Example 2: Language Switch

**Rust → Python (Load new model)**:
```json
{"jsonrpc":"2.0","id":2,"method":"load_model","params":{"language":"es","unload_previous":true}}
```

**Python → Rust (Progress)**:
```json
{"jsonrpc":"2.0","method":"model_load_progress","params":{"request_id":2,"percent":80,"stage":"gpu_transfer"}}
```

**Python → Rust (Success)**:
```json
{"jsonrpc":"2.0","id":2,"result":{"language":"es","model_path":"...","load_time_ms":1850,"memory_mb":612}}
```

---

### Example 3: Error Handling

**Rust → Python (Invalid sample rate)**:
```json
{"jsonrpc":"2.0","id":3,"method":"transcribe","params":{"audio_base64":"...","language":"en","sample_rate":44100}}
```

**Python → Rust (Error)**:
```json
{"jsonrpc":"2.0","id":3,"error":{"code":-32602,"message":"Invalid params","data":{"field":"sample_rate","details":"Sample rate must be 16000 Hz, got 44100"}}}
```

---

## Python Server Implementation Pattern

```python
# ml-backend/src/server.py
import sys
import json
from typing import Dict, Any, Optional
from .transcriber import Transcriber
from .model_manager import ModelManager

class JSONRPCServer:
    def __init__(self):
        self.model_manager = ModelManager()
        self.transcriber = Transcriber(self.model_manager)
        self.methods = {
            'transcribe': self.handle_transcribe,
            'load_model': self.handle_load_model,
            'unload_model': self.handle_unload_model,
            'get_loaded_models': self.handle_get_loaded_models,
            'detect_voice_activity': self.handle_detect_voice_activity,
            'ping': self.handle_ping,
            'shutdown': self.handle_shutdown,
        }

    def handle_request(self, request: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        # Validate JSON-RPC structure
        if request.get('jsonrpc') != '2.0':
            return self.error_response(None, -32600, 'Invalid Request')

        method = request.get('method')
        params = request.get('params', {})
        request_id = request.get('id')

        # Dispatch to handler
        if method not in self.methods:
            return self.error_response(request_id, -32601, 'Method not found')

        try:
            result = self.methods[method](params, request_id)
            if request_id is not None:  # Don't respond to notifications
                return self.success_response(request_id, result)
        except Exception as e:
            if request_id is not None:
                return self.error_response(request_id, -32603, str(e))

        return None

    def handle_transcribe(self, params: Dict[str, Any], request_id: int) -> Dict[str, Any]:
        # Validate params
        if params.get('sample_rate') != 16000:
            raise ValueError(f"Sample rate must be 16000 Hz, got {params.get('sample_rate')}")

        # Decode audio
        import base64
        audio_bytes = base64.b64decode(params['audio_base64'])
        audio = np.frombuffer(audio_bytes, dtype=np.int16)

        # Transcribe
        result = self.transcriber.transcribe(
            audio,
            language=params['language'],
            enable_vad=params.get('enable_vad', True)
        )

        return result

    def emit_notification(self, method: str, params: Dict[str, Any]):
        """Emit a notification (no ID field)."""
        notification = {
            'jsonrpc': '2.0',
            'method': method,
            'params': params
        }
        print(json.dumps(notification), flush=True)

    def success_response(self, request_id: int, result: Any) -> Dict[str, Any]:
        return {
            'jsonrpc': '2.0',
            'id': request_id,
            'result': result
        }

    def error_response(self, request_id: Optional[int], code: int, message: str, data: Any = None) -> Dict[str, Any]:
        error = {'code': code, 'message': message}
        if data:
            error['data'] = data
        return {
            'jsonrpc': '2.0',
            'id': request_id,
            'error': error
        }

    def run(self):
        """Main event loop: read from stdin, write to stdout."""
        for line in sys.stdin:
            try:
                request = json.loads(line)
                response = self.handle_request(request)
                if response:
                    print(json.dumps(response), flush=True)
            except json.JSONDecodeError as e:
                error = self.error_response(None, -32700, f'Parse error: {e}')
                print(json.dumps(error), flush=True)

if __name__ == '__main__':
    server = JSONRPCServer()
    server.run()
```

---

## Rust Client Implementation Pattern

```rust
// src-tauri/src/python_bridge.rs
use serde::{Deserialize, Serialize};
use std::io::{BufRead, BufReader, Write};
use std::process::{Child, ChildStdin, ChildStdout, Command, Stdio};
use std::sync::atomic::{AtomicU64, Ordering};

#[derive(Serialize)]
struct JsonRpcRequest<T> {
    jsonrpc: String,
    id: u64,
    method: String,
    params: T,
}

#[derive(Deserialize)]
struct JsonRpcResponse<T> {
    jsonrpc: String,
    id: u64,
    #[serde(flatten)]
    result_or_error: ResultOrError<T>,
}

#[derive(Deserialize)]
#[serde(untagged)]
enum ResultOrError<T> {
    Result { result: T },
    Error { error: JsonRpcError },
}

#[derive(Deserialize, Debug)]
struct JsonRpcError {
    code: i32,
    message: String,
    data: Option<serde_json::Value>,
}

pub struct PythonMLBackend {
    process: Child,
    stdin: ChildStdin,
    stdout: BufReader<ChildStdout>,
    request_id: AtomicU64,
}

impl PythonMLBackend {
    pub fn spawn() -> Result<Self> {
        let mut child = Command::new("python3")
            .arg("-m")
            .arg("ml_backend.server")
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()?;

        let stdin = child.stdin.take().unwrap();
        let stdout = BufReader::new(child.stdout.take().unwrap());

        Ok(Self {
            process: child,
            stdin,
            stdout,
            request_id: AtomicU64::new(1),
        })
    }

    pub fn transcribe(&mut self, audio: Vec<i16>, language: &str) -> Result<TranscriptionResult> {
        let id = self.request_id.fetch_add(1, Ordering::SeqCst);

        let audio_base64 = base64::encode(bytemuck::cast_slice(&audio));

        let request = JsonRpcRequest {
            jsonrpc: "2.0".to_string(),
            id,
            method: "transcribe".to_string(),
            params: serde_json::json!({
                "audio_base64": audio_base64,
                "language": language,
                "sample_rate": 16000,
                "enable_vad": true
            }),
        };

        // Send request
        serde_json::to_writer(&mut self.stdin, &request)?;
        self.stdin.write_all(b"\n")?;
        self.stdin.flush()?;

        // Read response (may include notifications)
        loop {
            let mut line = String::new();
            self.stdout.read_line(&mut line)?;

            let response: serde_json::Value = serde_json::from_str(&line)?;

            // Check if notification or response
            if response.get("id").is_none() {
                // Notification - handle separately
                self.handle_notification(&response)?;
                continue;
            }

            // Response - parse and return
            let parsed: JsonRpcResponse<TranscriptionResult> = serde_json::from_value(response)?;

            match parsed.result_or_error {
                ResultOrError::Result { result } => return Ok(result),
                ResultOrError::Error { error } => {
                    return Err(anyhow!("ML backend error: {}", error.message))
                }
            }
        }
    }

    fn handle_notification(&self, notification: &serde_json::Value) -> Result<()> {
        let method = notification["method"].as_str().unwrap_or("");

        match method {
            "transcription_progress" => {
                // Emit Tauri event to frontend
                let percent = notification["params"]["percent"].as_u64().unwrap_or(0);
                // app.emit("transcription-progress", percent)?;
            }
            "log" => {
                let message = notification["params"]["message"].as_str().unwrap_or("");
                eprintln!("[Python ML] {}", message);
            }
            _ => {}
        }

        Ok(())
    }
}
```

---

**Contract Complete**: Python ML backend JSON-RPC protocol fully defined with request/response schemas, error codes, and implementation patterns.
