import json
import csv
import re

INPUT_FILE = "raw_data.jsonl"
OUTPUT_FILE = "clean_transactions.csv"


def normalize_amount(amount):
    """
    Normalize currency values:
    "$10.00", "10.00", 1000 -> 10.00
    """
    if amount is None:
        return None

    if isinstance(amount, int):
        return round(amount / 100.0, 2)

    if isinstance(amount, str):
        cleaned = re.sub(r"[^\d.]", "", amount)
        if cleaned == "":
            return None
        try:
            return round(float(cleaned), 2)
        except ValueError:
            return None

    return None


cleaned_rows = []

with open(INPUT_FILE, "r", encoding="utf-8") as file:
    for line in file:

        if not line.strip():
            continue

        try:
            record = json.loads(line)
        except json.JSONDecodeError:
            continue

        # -------- NAVIGATE NESTED DICTIONARIES --------
        entity = record.get("entity", {})
        payment = entity.get("payment", {})
        order = entity.get("order", {})
        payload = record.get("payload", {})

        payment_id = payment.get("id")
        order_id = order.get("id")
        amount_raw = payload.get("Amount")
        status = payload.get("status")
        flags = payload.get("flags") or []

        # -------- NORMALIZE AMOUNT --------
        amount_usd = normalize_amount(amount_raw)

        # -------- FILTERING --------
        # Remove failed transactions
        if status != "SUCCESS":
            continue

        # Remove replayed/test flags
        if "replayed" in flags:
            continue

        # Drop incomplete records
        if not payment_id or amount_usd is None:
            continue

        # -------- APPEND CLEAN ROW --------
        cleaned_rows.append({
            "payment_id": payment_id,
            "order_id": order_id,
            "amount_usd": amount_usd,
            "status": status
        })


# -------- WRITE CSV --------
with open(OUTPUT_FILE, "w", newline="", encoding="utf-8") as csvfile:
    fieldnames = ["payment_id", "order_id", "amount_usd", "status"]
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)

    writer.writeheader()
    writer.writerows(cleaned_rows)

print(f"✅ Cleaning complete. {len(cleaned_rows)} rows written to {OUTPUT_FILE}")