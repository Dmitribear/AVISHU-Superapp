import argparse
import json
from pathlib import Path
from typing import Any
from urllib.parse import quote, urlencode
from urllib.error import HTTPError
from urllib.request import Request, urlopen


DEFAULT_PROJECT_ID = "avishu"
DEFAULT_GOOGLE_SERVICES = Path("android/app/google-services.json")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Normalize Firestore product image URLs from WEBP to JPG proxy URLs."
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
    with path.open("r", encoding="utf-8") as fh:
        payload = json.load(fh)
    if not isinstance(payload, dict):
        raise ValueError("JSON root must be an object")
    return payload


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


def collection_url(project_id: str, api_key: str, page_token: str | None = None) -> str:
    query: dict[str, str] = {"key": api_key, "pageSize": "100"}
    if page_token:
        query["pageToken"] = page_token
    return (
        f"https://firestore.googleapis.com/v1/projects/{project_id}"
        f"/databases/(default)/documents/products?{urlencode(query)}"
    )


def document_url(
    project_id: str,
    document_id: str,
    api_key: str,
    field_paths: list[str] | None = None,
) -> str:
    query: list[tuple[str, str]] = [("key", api_key)]
    for field_path in field_paths or []:
        query.append(("updateMask.fieldPaths", field_path))
    return (
        f"https://firestore.googleapis.com/v1/projects/{project_id}"
        f"/databases/(default)/documents/products/{document_id}?{urlencode(query)}"
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


def string_value(field: dict[str, Any] | None) -> str:
    if not isinstance(field, dict):
        return ""
    value = field.get("stringValue")
    return value if isinstance(value, str) else ""


def array_string_values(field: dict[str, Any] | None) -> list[str]:
    if not isinstance(field, dict):
        return []
    values = field.get("arrayValue", {}).get("values", [])
    if not isinstance(values, list):
        return []
    result: list[str] = []
    for item in values:
        if isinstance(item, dict):
            value = item.get("stringValue")
            if isinstance(value, str):
                result.append(value)
    return result


def to_firestore_string_array(values: list[str]) -> dict[str, Any]:
    return {"arrayValue": {"values": [{"stringValue": value} for value in values]}}


def main() -> int:
    args = parse_args()
    api_key = args.api_key or discover_api_key()

    updated = 0
    page_token: str | None = None
    while True:
      response = http_json("GET", collection_url(args.project_id, api_key, page_token))
      documents = response.get("documents", [])
      if not isinstance(documents, list):
          documents = []

      for document in documents:
          if not isinstance(document, dict):
              continue
          name = document.get("name", "")
          if not isinstance(name, str) or "/" not in name:
              continue
          document_id = name.rsplit("/", 1)[-1]
          fields = document.get("fields", {})
          if not isinstance(fields, dict):
              continue

          cover_image = string_value(fields.get("coverImage"))
          gallery = array_string_values(fields.get("gallery"))
          normalized_cover = normalize_image_url(cover_image)
          normalized_gallery = [normalize_image_url(item) for item in gallery]

          patch_fields: dict[str, Any] = {}
          if normalized_cover != cover_image:
              patch_fields["coverImage"] = {"stringValue": normalized_cover}
          if normalized_gallery != gallery:
              patch_fields["gallery"] = to_firestore_string_array(normalized_gallery)

          if patch_fields:
              http_json(
                  "PATCH",
                  document_url(
                      args.project_id,
                      document_id,
                      api_key,
                      list(patch_fields.keys()),
                  ),
                  {"fields": patch_fields},
              )
              updated += 1
              print(f"Normalized images for: {document_id}")

      page_token = response.get("nextPageToken")
      if not isinstance(page_token, str) or not page_token:
          break

    print(f"Updated products: {updated}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
