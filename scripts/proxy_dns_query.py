#!/usr/bin/env python3
"""Send a DNS query over TCP with HAProxy PROXY protocol v2 header."""

import socket
import struct
import sys

PP2_SIG = b"\r\n\r\n\0\r\nQUIT\n"


def build_pp2_v4(src_ip: str, src_port: int, dst_ip: str, dst_port: int, tenant: str | None = None) -> bytes:
    src = socket.inet_aton(src_ip)
    dst = socket.inet_aton(dst_ip)
    addr = src + dst + struct.pack("!HH", src_port, dst_port)
    tlv = b""
    if tenant:
        tid = tenant.encode()
        tlv = struct.pack("!HB", 0xE1, len(tid)) + tid
    payload = addr + tlv
    return PP2_SIG + bytes([0x21, 0x11]) + struct.pack("!H", len(payload)) + payload


def build_query(name: str, qtype: int = 1) -> bytes:
  # Minimal DNS query builder (A record default)
    labels = name.rstrip(".").split(".")
    qname = b"".join(bytes([len(p)]) + p.encode() for p in labels) + b"\0"
    return struct.pack("!HHHHHH", 0x1234, 0x0100, 1, 0, 0, 0) + qname + struct.pack("!HH", qtype, 1)


def query(host: str, port: int, name: str, qtype: int = 1, tenant: str | None = None) -> bytes:
    sock = socket.create_connection((host, port), timeout=10)
    sock.sendall(build_pp2_v4("203.0.113.50", 54321, "127.0.0.1", port, tenant))
    msg = build_query(name, qtype)
    sock.sendall(struct.pack("!H", len(msg)) + msg)
    ln = struct.unpack("!H", sock.recv(2))[0]
    data = b""
    while len(data) < ln:
        data += sock.recv(ln - len(data))
    sock.close()
    return data


def parse_answer(data: bytes) -> str:
    if len(data) < 12:
        return "empty response"
    rcode = data[3] & 0xF
    ancount = struct.unpack("!H", data[6:8])[0]
    rcodes = {0: "NOERROR", 3: "NXDOMAIN", 5: "REFUSED"}
    parts = [f"rcode={rcodes.get(rcode, rcode)}", f"answers={ancount}"]
    if ancount and len(data) > 12:
        # crude parse first A answer TTL and IP if present
        off = 12
        while data[off] != 0:
            off += 1 + data[off]
        off += 5  # null + qtype + qclass
        for _ in range(ancount):
            if data[off] & 0xC0 == 0xC0:
                off += 2
            else:
                while data[off] != 0:
                    off += 1 + data[off]
                off += 1
            rtype, rclass, ttl, rdlen = struct.unpack("!HHIH", data[off : off + 10])
            off += 10
            rdata = data[off : off + rdlen]
            off += rdlen
            if rtype == 1 and rdlen == 4:
                parts.append(f"A={socket.inet_ntoa(rdata)} ttl={ttl}")
            elif rtype == 5:
                parts.append("CNAME")
    return ", ".join(parts)


if __name__ == "__main__":
    host = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 53
    name = sys.argv[3]
    qtype = int(sys.argv[4]) if len(sys.argv) > 4 else 1
    tenant = sys.argv[5] if len(sys.argv) > 5 else None
    resp = query(host, port, name, qtype, tenant)
    print(f"{name}: {parse_answer(resp)}")
