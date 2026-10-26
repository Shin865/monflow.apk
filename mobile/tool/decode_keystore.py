import base64
import os
import sys

def main():
    raw = os.environ.get("KEYSTORE_BASE64", "")
    clean = "".join(raw.split()).strip('"\'')

    if not clean:
        print("::error::KEYSTORE_BASE64 is empty!", file=sys.stderr)
        sys.exit(1)

    if len(clean) < 100:
        print(f"::error::KEYSTORE_BASE64 is suspiciously short ({len(clean)} chars)! Make sure you pasted the base64-encoded string of monflow.jks, NOT the file name or password.", file=sys.stderr)
        sys.exit(1)

    # Perbaiki padding jika terpotong
    missing_padding = len(clean) % 4
    if missing_padding:
        clean += '=' * (4 - missing_padding)

    try:
        decoded = base64.b64decode(clean, validate=False)
    except Exception as e:
        print(f"::error::Failed to decode KEYSTORE_BASE64: {e}", file=sys.stderr)
        sys.exit(1)

    if len(decoded) < 500:
        print(f"::error::Decoded keystore size is only {len(decoded)} bytes. A valid Android JKS keystore is typically 2KB to 5KB.", file=sys.stderr)
        sys.exit(1)

    os.makedirs("android/app", exist_ok=True)
    with open("android/app/monflow.jks", "wb") as f:
        f.write(decoded)
    with open("android/monflow.jks", "wb") as f:
        f.write(decoded)

    print(f"Successfully decoded keystore ({len(decoded)} bytes) to android/app/monflow.jks and android/monflow.jks")

if __name__ == "__main__":
    main()
