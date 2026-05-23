#!/usr/bin/env python3
import argparse
import struct


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def png_size(path: str) -> tuple[int, int]:
    with open(path, "rb") as file:
        header = file.read(24)
    if len(header) < 24 or not header.startswith(PNG_SIGNATURE):
        raise ValueError(f"{path} is not a PNG file")
    chunk_type = header[12:16]
    if chunk_type != b"IHDR":
        raise ValueError(f"{path} does not start with an IHDR chunk")
    return struct.unpack(">II", header[16:24])


def main() -> None:
    parser = argparse.ArgumentParser(description="Assert PNG dimensions without external dependencies.")
    parser.add_argument("path")
    parser.add_argument("width", type=int)
    parser.add_argument("height", type=int)
    args = parser.parse_args()

    actual = png_size(args.path)
    expected = (args.width, args.height)
    if actual != expected:
        raise SystemExit(f"{args.path}: expected {expected}, got {actual}")
    print(f"{args.path}: {actual[0]}x{actual[1]}")


if __name__ == "__main__":
    main()
