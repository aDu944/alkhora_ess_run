## ALKHORA ESS (Flutter) – developer notes

### Base URL

Configured in `lib/src/core/config/app_config.dart`:

<<<<<<< Current (Your changes)
- `https://bms.alkhora.com`
=======
- **Flutter app source** under `mobile/` (UI + ERPNext API integration).
- Session login using **existing ERPNext users** (email/username + password).
- **Biometric unlock** (fingerprint/face) to open the app after first login.
- **Attendance check-in/out**:
  - Captures **GPS** location (lat/lng).
  - Works **offline** by queueing check-ins (SQLite) and syncing later.
  - Uses **NTP-based time** (cached offset) to reduce device-clock tampering.
  - Optional **geofence lock** + basic **mock location** blocking.
- Navigation + placeholder screens for:
  - Leave (view/apply + balance)
  - Attendance records
  - Payslips
  - Expense claims
  - Announcements
  - Profile/personal info
  - Holiday calendar
  - Document requests
  - Manager approvals (via assigned `ToDo`)
>>>>>>> Incoming (Background Agent changes)

You can override later by storing another URL in secure storage (`SecureKeys.baseUrl`).

### Authentication

- Uses ERPNext standard login:
  - `POST /api/method/login` with `usr` and `pwd` (form encoded)
  - Stores the resulting **session cookies** (PersistCookieJar)
- Validates session with:
  - `GET /api/method/frappe.auth.get_logged_user`
- Biometric unlock:
  - enabled after first login via `local_auth`
  - if device doesn’t support biometrics, app falls back to normal behavior

### Attendance (Check-in / Check-out)

Home screen is check-in/out for accessibility.

ERPNext doctypes / endpoints used:

- Find employee for logged in user:
  - `GET /api/resource/Employee`
  - filter: `user_id == logged_user`
- Read last check-in:
  - `GET /api/resource/Employee Checkin` ordered by `time desc`
- Create check-in/out:
  - `POST /api/resource/Employee Checkin`
  - fields sent:
    - `employee`, `log_type` ("IN"/"OUT"), `time`
    - tries to include `latitude`, `longitude`, `location_accuracy`, `device_id`
    - if server rejects those extra fields, it retries with standard fields only

Offline behavior:

- When offline, check-ins are queued in Hive (`OfflineQueue`) and synced when back online.

### Permissions / ERPNext configuration (recommended)

To store geolocation on check-ins, add Custom Fields to `Employee Checkin`:

- `latitude` (Float)
- `longitude` (Float)
- `location_accuracy` (Float, optional)
- `device_id` (Data, optional)

Ensure employee role permissions allow:

- Create: `Employee Checkin`
- Read own: `Employee`, `Employee Checkin`, `Attendance`, `Leave Application`, `Salary Slip` (as needed)
- Create: `Leave Application`, `Expense Claim` (as needed)

### Next modules to implement (already scaffolded in UI)

- Leave (apply + balances)
- Attendance records
- Payslips
- Expense claims
- Announcements
- Personal info updates
- Holiday calendar
- Document requests (likely needs a custom doctype/workflow)
- Manager approvals:
  - recommended to load assigned approvals via `ToDo` (`allocated_to == logged_user`)

## Admin & reporting (backend) – recommended approach

This repo currently contains the mobile app only. For:

- **CSV/PDF export** (weekly/monthly hours worked)
- **Anomaly detection** (overtime thresholds, outside-geofence punches)

Recommended implementation is an ERPNext custom app (or Server Scripts) that:

- Computes working hours by pairing `Employee Checkin` IN/OUT events per employee/day.
- Exposes a whitelisted API method for HR (or adds a report/dashboard) to export CSV/PDF.
- Flags anomalies into a doctype (e.g., `Attendance Anomaly`) and/or sends notifications to HR.

## Admin & reporting (backend) – recommended approach

This repo currently contains the mobile app only. For:

- **CSV/PDF export** (weekly/monthly hours worked)
- **Anomaly detection** (overtime thresholds, outside-geofence punches)

Recommended implementation is an ERPNext custom app (or Server Scripts) that:

- Computes working hours by pairing `Employee Checkin` IN/OUT events per employee/day.
- Exposes a whitelisted API method for HR (or adds a report/dashboard) to export CSV/PDF.
- Flags anomalies into a doctype (e.g., `Attendance Anomaly`) and/or sends notifications to HR.

