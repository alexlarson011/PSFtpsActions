import argparse
import json
import signal
from datetime import datetime, timedelta, timezone
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID
from pyftpdlib.authorizers import DummyAuthorizer
from pyftpdlib.handlers import TLS_FTPHandler
from pyftpdlib.servers import FTPServer


def ensure_certificate(cert_dir: Path) -> tuple[Path, Path, str]:
    cert_dir.mkdir(parents=True, exist_ok=True)
    cert_path = cert_dir / "local-ftps-cert.pem"
    key_path = cert_dir / "local-ftps-key.pem"

    if cert_path.exists() and key_path.exists():
        cert = x509.load_pem_x509_certificate(cert_path.read_bytes())
    else:
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        subject = issuer = x509.Name(
            [
                x509.NameAttribute(NameOID.COUNTRY_NAME, "US"),
                x509.NameAttribute(NameOID.ORGANIZATION_NAME, "PSFtpsActions Local Test"),
                x509.NameAttribute(NameOID.COMMON_NAME, "localhost"),
            ]
        )

        cert = (
            x509.CertificateBuilder()
            .subject_name(subject)
            .issuer_name(issuer)
            .public_key(key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(datetime.now(timezone.utc) - timedelta(minutes=1))
            .not_valid_after(datetime.now(timezone.utc) + timedelta(days=7))
            .add_extension(
                x509.SubjectAlternativeName(
                    [
                        x509.DNSName("localhost"),
                        x509.DNSName("127.0.0.1"),
                    ]
                ),
                critical=False,
            )
            .sign(key, hashes.SHA256())
        )

        key_path.write_bytes(
            key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.TraditionalOpenSSL,
                encryption_algorithm=serialization.NoEncryption(),
            )
        )
        cert_path.write_bytes(cert.public_bytes(serialization.Encoding.PEM))

    digest = cert.fingerprint(hashes.SHA256()).hex()
    pairs = ":".join(digest[index : index + 2] for index in range(0, len(digest), 2))
    return cert_path, key_path, pairs


def main() -> None:
    parser = argparse.ArgumentParser(description="Start a local explicit FTPS server for PSFtpsActions tests.")
    parser.add_argument("--root", required=True)
    parser.add_argument("--ready-file", required=True)
    parser.add_argument("--cert-dir", required=True)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=0)
    parser.add_argument("--username", default="psftps")
    parser.add_argument("--password", default="psftps")
    args = parser.parse_args()

    root = Path(args.root)
    root.mkdir(parents=True, exist_ok=True)

    cert_path, key_path, fingerprint = ensure_certificate(Path(args.cert_dir))

    authorizer = DummyAuthorizer()
    authorizer.add_user(args.username, args.password, str(root), perm="elradfmwMT")

    handler = TLS_FTPHandler
    handler.authorizer = authorizer
    handler.certfile = str(cert_path)
    handler.keyfile = str(key_path)
    handler.tls_control_required = True
    handler.tls_data_required = True
    handler.passive_ports = range(30000, 30050)

    server = FTPServer((args.host, args.port), handler)
    host, port = server.socket.getsockname()

    ready_path = Path(args.ready_file)
    ready_path.parent.mkdir(parents=True, exist_ok=True)
    ready_path.write_text(
        json.dumps(
            {
                "host": host,
                "port": port,
                "username": args.username,
                "password": args.password,
                "root": str(root),
                "fingerprint": fingerprint,
            },
            indent=2,
        ),
        encoding="utf-8",
    )

    def stop_server(signum, frame):
        server.close_all()

    signal.signal(signal.SIGTERM, stop_server)
    signal.signal(signal.SIGINT, stop_server)

    server.serve_forever()


if __name__ == "__main__":
    main()
