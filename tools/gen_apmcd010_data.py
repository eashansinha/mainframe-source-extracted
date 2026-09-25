#!/usr/bin/env python3
"""Generate the synthetic (masked-style) input files for APMCD010.

Deterministic: same seed -> same bytes. Every vendor, PO and invoice is
invented; no Lowe's data. The mix deliberately exercises every match rule
(E001-E011), both discount outcomes, half-up rounding on the discount, the
cumulative-quantity rule and a receipt without an open PO line.

Usage: tools/gen_apmcd010_data.py OUTDIR
"""
import random
import sys
from decimal import Decimal, ROUND_DOWN
from pathlib import Path

RUNDATE = "20260924"
rnd = random.Random(810)


def fx(s, n):
    s = str(s)
    assert len(s) <= n, (s, n)
    return s.ljust(n)


def num(v, n, scale=0):
    d = (Decimal(v) * (10 ** scale)).to_integral_value()
    s = str(int(d)).rjust(n, "0")
    assert len(s) == n, (v, n, scale)
    return s


VENDORS = [
    ("V1000017", "NORTHWIND LUMBER SUPPLY", "A", "ACH"),
    ("V1000024", "BLUE RIDGE FASTENERS", "A", "ACH"),
    ("V1000031", "PIEDMONT PAINT CO", "A", "CHK"),
    ("V1000048", "CAROLINA APPLIANCE DIST", "A", "ACH"),
    ("V1000055", "SUMMIT TOOL WORKS", "A", "ACH"),
    ("V1000062", "HARBOR LIGHTING INC", "A", "CHK"),
    ("V1000079", "OAKMONT FLOORING", "I", "ACH"),
    ("V1000086", "GREENLEAF GARDEN SUPPLY", "H", "ACH"),
    ("V1000093", "IRONGATE PLUMBING", "A", "ACH"),
    ("V1000109", "TRISTATE ELECTRICAL", "A", "CHK"),
    ("V1000116", "COASTAL WINDOW AND DOOR", "A", "ACH"),
    ("V1000123", "MAPLE CREEK CABINETRY", "A", "ACH"),
]
ACTIVE = [v for v in VENDORS if v[2] == "A"]

po_lines = []     # (po, line, vendor, item, qty, price, status)
receipts = []     # (po, line, rcvid, date, qty)
invoices = []     # dict


def price4(lo, hi):
    return (Decimal(rnd.randint(lo * 100, hi * 100)) / 100).quantize(Decimal("0.0001"))


def ext(q, p):
    return (Decimal(q) * p).quantize(Decimal("0.01"), rounding=ROUND_DOWN)


rcv_seq = [0]


def add_receipt(po, line, qty, date="20260918"):
    rcv_seq[0] += 1
    receipts.append((po, line, f"R{rcv_seq[0]:09d}", date, qty))


# ---- normal open PO lines, fully received, clean invoices ----------------
po_no = 4500120000
inv_seq = [880000]
TERMS = ["2N10", "N30 ", "N30 ", "1N15", "N45 ", "N60 ", "2N10"]


def new_inv(vendor, po, line, qty, price, terms, date, amt=None, cur="USD", invno=None):
    if invno is None:
        inv_seq[0] += rnd.randint(1, 37)
        invno = f"INV{inv_seq[0]:09d}"
    invoices.append(dict(inv=invno, vendor=vendor, po=po, line=line, date=date,
                         terms=terms, qty=qty, price=price,
                         amt=ext(qty, price) if amt is None else amt, cur=cur))
    return invno


for i in range(34):
    v = ACTIVE[i % len(ACTIVE)][0]
    po = f"{po_no + i:010d}"
    qty = rnd.randint(4, 400)
    price = price4(3, 900)
    po_lines.append((po, 1, v, f"ITM{rnd.randint(1000000, 9999999)}", qty, price, "O"))
    add_receipt(po, 1, qty)
    # invoice dates spread so some discounts are still open and some lapsed
    day = rnd.randint(8, 23)
    inv_price = price if i % 5 else (price * Decimal("0.98")).quantize(Decimal("0.0001"))
    new_inv(v, po, 1, qty, inv_price, TERMS[i % len(TERMS)], f"202609{day:02d}")

# ---- targeted cases -------------------------------------------------------
base = po_no + 100


def po(n):
    return f"{base + n:010d}"


# half-up discount: 2% of 1234.25 = 24.685 -> 24.69 (HALF_EVEN would give 24.68)
po_lines.append((po(1), 1, "V1000017", "ITM4410021", 5, Decimal("246.8500"), "O"))
add_receipt(po(1), 1, 5)
new_inv("V1000017", po(1), 1, 5, Decimal("246.8500"), "2N10", "20260920")
# half-up discount: 1% of 3456.50 = 34.565 -> 34.57
po_lines.append((po(2), 1, "V1000055", "ITM4410022", 10, Decimal("345.6500"), "O"))
add_receipt(po(2), 1, 10)
new_inv("V1000055", po(2), 1, 10, Decimal("345.6500"), "1N15", "20260915")
# discount window: disc-date == rundate (taken) and rundate-1 (lapsed)
po_lines.append((po(3), 1, "V1000093", "ITM4410023", 12, Decimal("19.9900"), "O"))
add_receipt(po(3), 1, 12)
new_inv("V1000093", po(3), 1, 12, Decimal("19.9900"), "2N10", "20260914")
po_lines.append((po(4), 1, "V1000093", "ITM4410024", 12, Decimal("21.4900"), "O"))
add_receipt(po(4), 1, 12)
new_inv("V1000093", po(4), 1, 12, Decimal("21.4900"), "2N10", "20260913")
# E001 adjacent duplicate (same vendor + invoice no twice)
po_lines.append((po(5), 1, "V1000024", "ITM4410025", 40, Decimal("2.3700"), "O"))
add_receipt(po(5), 1, 40)
d = new_inv("V1000024", po(5), 1, 20, Decimal("2.3700"), "N30 ", "20260919")
new_inv("V1000024", po(5), 1, 20, Decimal("2.3700"), "N30 ", "20260919", invno=d)
# E002 vendor not on file
new_inv("V9999990", po(5), 1, 1, Decimal("10.0000"), "N30 ", "20260919")
# E003 inactive and payment hold
po_lines.append((po(6), 1, "V1000079", "ITM4410026", 8, Decimal("54.1000"), "O"))
add_receipt(po(6), 1, 8)
new_inv("V1000079", po(6), 1, 8, Decimal("54.1000"), "N30 ", "20260919")
po_lines.append((po(7), 1, "V1000086", "ITM4410027", 8, Decimal("14.1000"), "O"))
add_receipt(po(7), 1, 8)
new_inv("V1000086", po(7), 1, 8, Decimal("14.1000"), "N30 ", "20260919")
# E004 non-USD
po_lines.append((po(8), 1, "V1000116", "ITM4410028", 30, Decimal("88.0000"), "O"))
add_receipt(po(8), 1, 30)
new_inv("V1000116", po(8), 1, 30, Decimal("88.0000"), "N30 ", "20260919", cur="CAD")
# E005 PO line not on file
new_inv("V1000116", po(8), 2, 3, Decimal("88.0000"), "N30 ", "20260919")
# E006 PO belongs to another vendor
new_inv("V1000123", po(8), 1, 3, Decimal("88.0000"), "N30 ", "20260919")
# E007 closed and held PO lines
po_lines.append((po(9), 1, "V1000123", "ITM4410029", 6, Decimal("310.0000"), "C"))
add_receipt(po(9), 1, 6)
new_inv("V1000123", po(9), 1, 6, Decimal("310.0000"), "N30 ", "20260919")
po_lines.append((po(10), 1, "V1000123", "ITM4410030", 6, Decimal("315.0000"), "H"))
add_receipt(po(10), 1, 6)
new_inv("V1000123", po(10), 1, 6, Decimal("315.0000"), "N30 ", "20260919")
# E008 unknown terms
po_lines.append((po(11), 1, "V1000031", "ITM4410031", 25, Decimal("27.5000"), "O"))
add_receipt(po(11), 1, 25)
new_inv("V1000031", po(11), 1, 25, Decimal("27.5000"), "N90 ", "20260919")
# E009 extension error (2 cents off) and a 1-cent difference that passes
po_lines.append((po(12), 1, "V1000031", "ITM4410032", 30, Decimal("12.3456"), "O"))
add_receipt(po(12), 1, 30)
new_inv("V1000031", po(12), 1, 10, Decimal("12.3456"), "N30 ", "20260919",
        amt=ext(10, Decimal("12.3456")) + Decimal("0.02"))
new_inv("V1000031", po(12), 1, 10, Decimal("12.3456"), "N30 ", "20260919",
        amt=ext(10, Decimal("12.3456")) + Decimal("0.01"))
# E010 nothing received / over-received / cumulative on same line
po_lines.append((po(13), 1, "V1000048", "ITM4410033", 50, Decimal("499.0000"), "O"))
new_inv("V1000048", po(13), 1, 5, Decimal("499.0000"), "2N10", "20260921")
po_lines.append((po(14), 1, "V1000048", "ITM4410034", 50, Decimal("129.0000"), "O"))
add_receipt(po(14), 1, 20, "20260916")
add_receipt(po(14), 1, 10, "20260919")
new_inv("V1000048", po(14), 1, 18, Decimal("129.0000"), "N30 ", "20260920")
new_inv("V1000048", po(14), 1, 12, Decimal("129.0000"), "N30 ", "20260921")
new_inv("V1000048", po(14), 1, 1, Decimal("129.0000"), "N30 ", "20260922")
# E011 price tolerance: exactly +1% passes, +1.01% fails
po_lines.append((po(15), 1, "V1000062", "ITM4410035", 40, Decimal("75.0000"), "O"))
add_receipt(po(15), 1, 40)
new_inv("V1000062", po(15), 1, 20, Decimal("75.7500"), "N30 ", "20260919")
new_inv("V1000062", po(15), 1, 20, Decimal("75.7600"), "N30 ", "20260919")
po_lines.append((po(16), 1, "V1000109", "ITM4410036", 101, Decimal("3.3333"), "O"))
add_receipt(po(16), 1, 101)
new_inv("V1000109", po(16), 1, 100, Decimal("3.3666"), "N45 ", "20260919")
new_inv("V1000109", po(16), 1, 1, Decimal("3.3667"), "N45 ", "20260919")
# receipt for a PO line that is not open
add_receipt(po(99), 1, 7)


def main(out):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    with open(out / "APVENDOR.dat", "w") as fh:
        for vid, name, st, pm in sorted(VENDORS):
            fh.write(fx(vid, 8) + fx(name, 30) + st + pm + " " * 38 + "\n")
    with open(out / "APPOLINE.dat", "w") as fh:
        for p, ln, v, item, q, pr, st in sorted(po_lines):
            fh.write(fx(p, 10) + num(ln, 3) + fx(v, 8) + fx(item, 10) + num(q, 7)
                     + num(pr, 11, 4) + st + " " * 30 + "\n")
    with open(out / "APRCVLN.dat", "w") as fh:
        for p, ln, rid, dt, q in receipts:
            fh.write(fx(p, 10) + num(ln, 3) + fx(rid, 10) + dt + num(q, 7) + " " * 22 + "\n")
    shuffled = invoices[:]
    rnd.shuffle(shuffled)            # intake order; the JCL sorts it
    with open(out / "APINVOIC.dat", "w") as fh:
        for r in shuffled:
            fh.write(fx(r["inv"], 12) + fx(r["vendor"], 8) + fx(r["po"], 10) + num(r["line"], 3)
                     + r["date"] + fx(r["terms"], 4) + num(r["qty"], 7) + num(r["price"], 11, 4)
                     + num(r["amt"], 11, 2) + fx(r["cur"], 3) + "R01" + " " * 20 + "\n")
    (out / "SYSIN.txt").write_text(f"RUNDATE={RUNDATE}\n")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "APMC/data/baseline/APMCD010/input")
