from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Dict, Any

from .config import load_config, ensure_directories
from .processor import process_data, render_summary
from .validation import ensure_non_empty, ensure_max_bytes
from .aws_interaction import upload_to_s3, persist_record


def handler(event: Dict[str, Any], context: Dict[str, Any] | None = None) -> Dict[str, Any]:
    config = load_config()
    ensure_directories(config)

    data = event.get("data")
    if data is None:
        return {"statusCode": 400, "body": {"error": "Missing 'data' field"}}

    try:
        ensure_non_empty(data, "data")
        ensure_max_bytes(data, "data", config.max_payload_bytes)
    except ValueError as exc:
        return {"statusCode": 400, "body": {"error": str(exc)}}

    processed = process_data(data)
    summary = render_summary(processed)
    timestamp = processed.processed_at.strftime("%Y%m%d%H%M%S")
    key = f"processed_{timestamp}.txt"
    record_id = f"rec_{timestamp}"

    upload_to_s3(config, key, summary)
    record_payload = {
        "id": record_id,
        "receivedAt": datetime.now(timezone.utc).isoformat(),
        "summary": summary,
        "wordCounts": processed.word_counts,
        "totalWords": processed.total_words,
        "uniqueWords": processed.unique_words,
    }
    persist_record(config, record_id, record_payload)

    return {
        "statusCode": 200,
        "body": {
            "message": f"Processed data: {summary}",
            "recordId": record_id,
            "storageKey": key,
        },
    }


def invoke_with_json(payload: str) -> str:
    event = json.loads(payload)
    response = handler(event, {})
    return json.dumps(response)
