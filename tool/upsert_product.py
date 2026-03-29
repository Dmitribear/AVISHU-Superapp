import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import quote, urlencode
from urllib.error import HTTPError
from urllib.request import Request, urlopen


DEFAULT_PROJECT_ID = "avishu"
DEFAULT_GOOGLE_SERVICES = Path("android/app/google-services.json")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Upsert a product document into Firestore from a JSON file."
    )
    parser.add_argument(
        "--product-file",
        required=True,
        help="Path to product JSON payload.",
    )
    parser.add_argument(
        "--project-id",
        default=DEFAULT_PROJECT_ID,
        help=f"Firebase project id. Default: {DEFAULT_PROJECT_ID}",
    )
    parser.add_argument(
        "--api-key",
        help="Firebase Web/Android API key. If omitted, read from google-services.json.",
    )
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise FileNotFoundError(f"JSON file not found: {path}")
    with path.open("r", encoding="utf-8") as fh:
        payload = json.load(fh)
    if not isinstance(payload, dict):
        raise ValueError("JSON root must be an object")
    return payload


def require_string(data: dict[str, Any], key: str) -> str:
    value = data.get(key)
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Missing required string field: {key}")
    return value.strip()


def optional_string(data: dict[str, Any], key: str, default: str = "") -> str:
    value = data.get(key)
    return value.strip() if isinstance(value, str) else default


def string_list(data: dict[str, Any], key: str) -> list[str]:
    value = data.get(key)
    if not isinstance(value, list):
        return []
    return [item.strip() for item in value if isinstance(item, str) and item.strip()]


def specifications_list(data: dict[str, Any]) -> list[dict[str, str]]:
    value = data.get("specifications")
    if not isinstance(value, list):
        return []

    result: list[dict[str, str]] = []
    for item in value:
        if not isinstance(item, dict):
            continue
        label = item.get("label")
        spec_value = item.get("value")
        if isinstance(label, str) and isinstance(spec_value, str):
            result.append({"label": label.strip(), "value": spec_value.strip()})
    return result


def normalize_image_url(url: str) -> str:
    normalized = url.strip()
    if ".webp" not in normalized.lower():
        return normalized

    origin = normalized
    if origin.startswith("https://"):
        origin = origin[len("https://") :]
    elif origin.startswith("http://"):
        origin = origin[len("http://") :]
    return f"https://wsrv.nl/?url={quote(origin, safe='')}&output=jpg"


def normalize_image_urls(urls: list[str]) -> list[str]:
    return [normalize_image_url(url) for url in urls]


def normalize_category(value: str) -> str:
    normalized = value.strip().lower()
    mapping = {
        "верхняя одежда": "outerwear",
        "кардиганы и кофты": "cardigans",
        "костюмы": "suits",
        "база": "base",
        "брюки": "trousers",
        "юбки": "skirts",
    }
    return mapping.get(normalized, normalized)


def discover_api_key() -> str:
    data = load_json(DEFAULT_GOOGLE_SERVICES)
    clients = data.get("client")
    if not isinstance(clients, list) or not clients:
        raise ValueError("No Firebase clients found in google-services.json")

    api_key_list = clients[0].get("api_key")
    if not isinstance(api_key_list, list) or not api_key_list:
        raise ValueError("No api_key section found in google-services.json")

    current_key = api_key_list[0].get("current_key")
    if not isinstance(current_key, str) or not current_key.strip():
        raise ValueError("current_key missing in google-services.json")
    return current_key.strip()


def firestore_document_url(project_id: str, document_id: str, api_key: str) -> str:
    query = urlencode({"key": api_key})
    return (
        f"https://firestore.googleapis.com/v1/projects/{project_id}"
        f"/databases/(default)/documents/products/{document_id}?{query}"
    )


def http_json(method: str, url: str, body: dict[str, Any] | None = None) -> dict[str, Any]:
    data = None
    headers = {}
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json; charset=utf-8"

    request = Request(url, data=data, headers=headers, method=method)
    try:
        with urlopen(request, timeout=30) as response:
            payload = response.read().decode("utf-8")
            return json.loads(payload) if payload else {}
    except HTTPError as error:
        payload = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {error.code}: {payload}") from error


def now_timestamp() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def to_firestore_value(value: Any) -> dict[str, Any]:
    if isinstance(value, bool):
        return {"booleanValue": value}
    if isinstance(value, int):
        return {"integerValue": str(value)}
    if isinstance(value, float):
        return {"doubleValue": value}
    if isinstance(value, str):
        return {"stringValue": value}
    if isinstance(value, list):
        return {"arrayValue": {"values": [to_firestore_value(item) for item in value]}}
    if isinstance(value, dict):
        return {
            "mapValue": {
                "fields": {key: to_firestore_value(item) for key, item in value.items()}
            }
        }
    raise TypeError(f"Unsupported Firestore value type: {type(value).__name__}")


def parse_existing_created_at(existing_doc: dict[str, Any]) -> str | None:
    fields = existing_doc.get("fields")
    if not isinstance(fields, dict):
        return None
    created_at = fields.get("createdAt")
    if not isinstance(created_at, dict):
        return None
    timestamp = created_at.get("timestampValue")
    return timestamp if isinstance(timestamp, str) and timestamp else None


def build_product_document(payload: dict[str, Any], existing_doc: dict[str, Any] | None) -> dict[str, Any]:
    price = payload.get("price")
    if not isinstance(price, (int, float)):
        raise ValueError('Field "price" must be numeric')

    default_production_days = payload.get("defaultProductionDays", 0)
    if not isinstance(default_production_days, int):
        if isinstance(default_production_days, float):
            default_production_days = int(default_production_days)
        else:
            raise ValueError('Field "defaultProductionDays" must be an integer')

    is_preorder_available = payload.get("isPreorderAvailable", False)
    if not isinstance(is_preorder_available, bool):
        raise ValueError('Field "isPreorderAvailable" must be boolean')

    created_at = parse_existing_created_at(existing_doc or {}) or now_timestamp()
    updated_at = now_timestamp()

    document_fields = {
        "id": require_string(payload, "id"),
        "name": require_string(payload, "name"),
        "slug": require_string(payload, "slug"),
        "description": require_string(payload, "description"),
        "shortDescription": require_string(payload, "shortDescription"),
        "category": normalize_category(require_string(payload, "category")),
        "material": require_string(payload, "material"),
        "silhouette": require_string(payload, "silhouette"),
        "atelierNote": optional_string(payload, "atelierNote"),
        "sections": string_list(payload, "sections"),
        "colors": string_list(payload, "colors"),
        "sizes": string_list(payload, "sizes"),
        "defaultColor": require_string(payload, "defaultColor"),
        "defaultSize": require_string(payload, "defaultSize"),
        "specifications": specifications_list(payload),
        "care": string_list(payload, "care"),
        "price": int(price) if isinstance(price, int) or float(price).is_integer() else float(price),
        "currency": optional_string(payload, "currency", "KZT"),
        "coverImage": normalize_image_url(require_string(payload, "coverImage")),
        "gallery": normalize_image_urls(string_list(payload, "gallery")),
        "isPreorderAvailable": is_preorder_available,
        "defaultProductionDays": default_production_days,
        "status": optional_string(payload, "status", "active"),
    }

    fields = {key: to_firestore_value(value) for key, value in document_fields.items()}
    fields["createdAt"] = {"timestampValue": created_at}
    fields["updatedAt"] = {"timestampValue": updated_at}
    return {"fields": fields}


def main() -> int:
    args = parse_args()
    api_key = args.api_key or discover_api_key()
    payload = load_json(Path(args.product_file))
    document_id = require_string(payload, "id")
    url = firestore_document_url(args.project_id, document_id, api_key)

    existing_doc: dict[str, Any] | None
    try:
        existing_doc = http_json("GET", url)
    except RuntimeError as error:
        if "HTTP 404" in str(error):
            existing_doc = None
        else:
            raise

    document = build_product_document(payload, existing_doc)
    response = http_json("PATCH", url, document)
    print(
        "Upserted product:",
        require_string(payload, "name"),
        f"({document_id})",
    )
    print(response.get("name", ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
