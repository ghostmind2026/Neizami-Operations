# Neizami Mobile Bridge — Simple Formidable Contract

Baseline decision: the mobile client supports only simple Formidable forms for this phase.

## Supported field types

- `text`
- `number`
- `select` / `dropdown`
- `checkbox`

Anything else is considered unsupported by the Native Simple Form renderer and may use the explicit legacy Web fallback.

The mobile client does **not** evaluate or reproduce Formidable Lookup, Conditional Logic, Calculations, Repeaters, file uploads, signatures, custom JS, or other advanced runtime behavior in this phase.

## GET form schema

Endpoint:

```text
GET /wp-json/neizami-mobile/v1/forms/{form_key}
```

Expected data shape:

```json
{
  "form": {
    "key": "device_repair_mobile",
    "name": "وصل صيانة",
    "voice_aliases": [
      "اعملي وصل صيانة",
      "اعمل وصل",
      "استلام صيانة",
      "وصل جديد"
    ]
  },
  "submit_label": "حفظ",
  "fields": [
    {
      "key": "customer_name",
      "type": "text",
      "label": "اسم الزبون",
      "required": true,
      "default": "",
      "voice_aliases": [
        "اسم الزبون",
        "اسم العميل",
        "باسم",
        "الزبون"
      ]
    },
    {
      "key": "amount",
      "type": "number",
      "label": "المبلغ",
      "required": false,
      "default": "",
      "voice_aliases": [
        "المبلغ",
        "القيمة",
        "الحساب"
      ]
    },
    {
      "key": "payment_method",
      "type": "select",
      "label": "طريقة الدفع",
      "required": false,
      "default": "cash",
      "voice_aliases": [
        "طريقة الدفع",
        "الدفع"
      ],
      "options": [
        {"value": "cash", "label": "نقد"},
        {"value": "visa", "label": "فيزا"}
      ]
    }
  ]
}
```

`voice_aliases` are metadata only in the current phase. They are stored in the bridge contract now so the future voice-fill layer can resolve the requested form and target fields without guessing Formidable field keys.

## POST form entry

Endpoint:

```text
POST /wp-json/neizami-mobile/v1/forms/{form_key}
```

Request body:

```json
{
  "fields": {
    "customer_name": "خالد",
    "amount": "35",
    "payment_method": "cash"
  }
}
```

Expected successful response:

```json
{
  "entry_id": 12345
}
```

## Storage rule

The Mobile Bridge must create/update entries through Formidable APIs and hooks. It must not write directly to Formidable database tables.

Required path:

```text
Flutter
→ Mobile Bridge
→ Formidable create/update
→ Formidable hooks
→ LightSpeed / Approvals / Notifier / downstream Neizami hooks
```

The returned `entry_id` is the mobile confirmation that a real Formidable entry was created.

## Voice metadata scope

### Form aliases

Used later to resolve commands such as:

```text
اعملي فاتورة
اعملي وصل صيانة
اعمل سند
```

### Field aliases

Used later to resolve phrases such as:

```text
اسم الزبون
باسم
رقمو
رقم تلفونو
المبلغ
القيمة
```

Option-level aliases are intentionally deferred until the voice-fill implementation requires them.
