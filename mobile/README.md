<<<<<<< Current (Your changes)
=======
## ALKHORA ESS (Flutter) – developer notes

### Base URL

Configured in `lib/src/core/config/app_config.dart`:

- `https://bms.alkhora.com`

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

- When offline, check-ins are queued in SQLite (`OfflineQueue`) and synced when back online.

Time integrity:

- Punch timestamps use a cached **NTP offset** (package `ntp`) instead of trusting the device clock directly.
- If the device is offline, the app uses the **last known NTP offset** (if available) and records metadata on the queued item.

Geofencing & anti-spoofing:

- The main punch button is **locked** when outside the configured office geofence (`AppConfig.officeLatitude/Longitude/RadiusMeters`).
- “Mock location” (GPS spoofing) attempts are blocked using `Position.isMocked` (Android-supported via `geolocator`).

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

>>>>>>> Incoming (Background Agent changes)
