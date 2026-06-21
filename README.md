# onetwopunch

Fast port discovery with unicornscan, deep enumeration with nmap. Run them together so you get the speed of a stateless scanner and the detail of a full-featured one.

Revamped by **Th3Gr1ff**, based on the original work by **superkojiman**.

---

## How it works

1. Unicornscan blasts all 65535 ports at high speed using stateless SYN or UDP probes.
2. The open ports it finds are handed off to nmap for service version detection and any other enumeration you configure.
3. Results are saved per-host under `~/.onetwopunch/` in both XML and greppable formats.

Previous scan results are automatically backed up with a timestamp before each new run, so you never overwrite old data.

---

## What changed from the original

The original onetwopunch was written for an older unicornscan build. This revamp targets the current release at [robertelee78/unicornscan](https://github.com/robertelee78/unicornscan) and includes the following changes:

- The `-l <logfile>` flag was removed from modern unicornscan. Output is now captured from stdout via `tee` (bash) or `subprocess.Popen` (Python).
- The legacy all-ports shorthand `:a` is replaced with the explicit range `:1-65535`.
- The `-I` flag is added to enable immediate/streaming output so ports appear as they are discovered.
- A `-r` rate option is exposed as a CLI parameter (default 1000 pps) instead of being hardcoded.
- Both `unicornscan` and `us` binary names are detected automatically.
- Port parsing is hardened against minor output format variation.
- Blank lines and comments in the targets file are skipped.

---

## Files

| File | Description |
|---|---|
| `onetwopunch.sh` | Bash implementation |
| `onetwopunch.py` | Python 3 implementation, no external dependencies |

Both files are functionally identical. Use whichever fits your environment.

---

## Requirements

- Linux, run as root
- [nmap](https://nmap.org/)
- [unicornscan](https://github.com/robertelee78/unicornscan) (v0.4.52 or newer, binary must be `unicornscan` or `us` in PATH)
- Python 3.7+ (Python version only)

---

## Usage

### Bash

```bash
chmod +x onetwopunch.sh
sudo ./onetwopunch.sh -t targets.txt [-p tcp/udp/all] [-i interface] [-r rate] [-n "nmap options"]
```

### Python

```bash
sudo python3 onetwopunch.py -t targets.txt [-p tcp/udp/all] [-i interface] [-r rate] [-n "nmap options"]
```

### Options

| Flag | Description | Default |
|---|---|---|
| `-t` | File containing target IPs, one per line | Required |
| `-p` | Protocol: `tcp`, `udp`, or `all` | `tcp` |
| `-i` | Network interface | `eth0` |
| `-r` | Unicornscan packets-per-second rate | `1000` |
| `-n` | Nmap options passed directly to nmap | `-sV` |
| `-h` | Show help | |

---

## Targets file

One IP address or CIDR range per line. Lines starting with `#` and blank lines are ignored.

```
# internal hosts
192.168.1.10
192.168.1.20
10.0.0.0/24
```

---

## Examples

TCP scan with service detection:

```bash
sudo ./onetwopunch.sh -t targets.txt -p tcp -i eth0
```

Full scan (TCP + UDP) at a higher rate with OS detection:

```bash
sudo ./onetwopunch.sh -t targets.txt -p all -i eth0 -r 5000 -n "-sV -O"
```

Python version, aggressive scan on a specific interface:

```bash
sudo python3 onetwopunch.py -t targets.txt -p all -i ens3 -r 2000 -n "-A"
```

---

## Output

Results are written to `~/.onetwopunch/`:

```
~/.onetwopunch/
    ndir/
        <ip>-tcp.xml        nmap XML output
        <ip>-tcp.grep       nmap greppable output
        <ip>-tcp-nmap.txt   nmap console output (Python version)
        <ip>-udp.xml
        <ip>-udp.grep
        <ip>-udp-nmap.txt
    udir/
        <ip>-tcp.txt        raw unicornscan output
        <ip>-udp.txt
    backup/
        ndir-<timestamp>/   previous ndir backed up before each run
        udir-<timestamp>/   previous udir backed up before each run
```

---

## Credits

Original onetwopunch by [superkojiman](https://github.com/superkojiman)  
Revamped for modern unicornscan by [Th3Gr1ff](https://github.com/Th3Gr1ff)
