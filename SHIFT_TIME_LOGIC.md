# Shift Time Logic for Late Entry and Early Exit Detection

## Overview

The app determines work start and end times using a hierarchical approach to detect late entries and early exits.

## Priority Order for Shift Time Determination

### 1. **Shift Assignment (Date-Specific) - Highest Priority** ✅
   - **Source**: `Shift Assignment` doctype in ERPNext
   - **Why**: Most accurate - provides date-specific shift assignments
   - **Logic**:
     - Queries `Shift Assignment` for active assignments for the employee
     - Checks if assignment is valid for the check-in/out date
     - Fetches `shift_type` from the assignment
     - Gets `start_time` and `end_time` from the `Shift Type`
   
   **ERPNext Fields**:
   - `Shift Assignment.employee` - Employee ID
   - `Shift Assignment.shift_type` - Reference to Shift Type
   - `Shift Assignment.start_date` - Assignment start date
   - `Shift Assignment.end_date` - Assignment end date (null = ongoing)
   - `Shift Assignment.status` - Must be "Active"

### 2. **Default Shift from Employee Record** - Fallback
   - **Source**: Employee doctype in ERPNext
   - **Fields checked** (in order):
     - `Employee.default_shift`
     - `Employee.shift`
     - `Employee.shift_type`
   - **Logic**:
     - If Shift Assignment not found, checks Employee record
     - Gets the shift type name from Employee field
     - Fetches `start_time` and `end_time` from `Shift Type`

### 3. **Day-of-Week Default** - Last Resort
   - **Default Times** (if no shift configured in ERPNext):
     - **Sunday to Thursday**: 09:00 AM - 04:00 PM (7-hour shift)
     - **Saturday**: 09:00 AM - 03:00 PM (6-hour shift)
     - **Friday**: 09:00 AM - 04:00 PM (7-hour shift, same as weekdays)
   - **Used when**: No shift configuration found in ERPNext

## Late Entry Detection

**Criteria**: Check-in is considered late if it's **more than 15 minutes after** the shift start time.

**Example**:
- Shift Start: 09:00 AM
- Grace Period: 15 minutes (09:15 AM)
- Check-in at 09:14 AM → ✅ **Not Late**
- Check-in at 09:16 AM → ⚠️ **Late Entry**

**Implementation**:
```dart
final checkInMinutes = checkInTime.hour * 60 + checkInTime.minute;
final shiftStartMinutes = shiftStart.hour * 60 + shiftStart.minute;
bool isLate = checkInMinutes > (shiftStartMinutes + 15);
```

## Early Exit Detection

**Criteria**: Check-out is considered early if it's **more than 15 minutes before** the shift end time.

**Example**:
- Shift End: 04:00 PM
- Grace Period: 15 minutes (03:45 PM)
- Check-out at 03:46 PM → ✅ **Not Early**
- Check-out at 03:44 PM → ⚠️ **Early Exit**

**Implementation**:
```dart
final checkOutMinutes = checkOutTime.hour * 60 + checkOutTime.minute;
final shiftEndMinutes = shiftEnd.hour * 60 + shiftEnd.minute;
bool isEarly = checkOutMinutes < (shiftEndMinutes - 15);
```

## ERPNext Configuration Required

### 1. Shift Type Doctype
Create Shift Types with:
- **start_time**: Time field (e.g., "09:00:00")
- **end_time**: Time field (e.g., "17:00:00")
- **Example**: "Morning Shift", "Evening Shift", "Night Shift"

### 2. Shift Assignment (Optional but Recommended)
For date-specific shifts:
- Create `Shift Assignment` records
- Link to Employee
- Set `start_date` and `end_date`
- Set `status = "Active"`
- Reference a `Shift Type`

### 3. Employee Default Shift (Fallback)
If using default shift per employee:
- Set `default_shift`, `shift`, or `shift_type` field on Employee record
- Reference a `Shift Type`

## API Calls Made

### 1. Get Shift Assignment
```
GET /api/resource/Shift Assignment
Fields: ["shift_type", "start_date", "end_date"]
Filters: [
  ["employee", "=", "HR-EMP-00001"],
  ["start_date", "<=", "2026-01-08"],
  ["status", "=", "Active"]
]
Order: start_date desc
Limit: 1
```

### 2. Get Shift Type
```
GET /api/resource/Shift Type/{shift_type_name}
Fields: ["start_time", "end_time"]
```

### 3. Get Employee (for default shift)
```
GET /api/resource/Employee/{employee_id}
Fields: ["default_shift", "shift", "shift_type"]
```

## Grace Period Logic

**15-minute grace period** is applied for both late entry and early exit:
- Prevents false positives from minor clock differences
- Accounts for network delays, traffic, or brief delays
- Provides reasonable buffer for employees
- Configurable in code (currently hardcoded to 15 minutes)

## Date-Specific Logic

Shift times are determined **per date** because:
- Employees may have different shifts on different days
- Shift Assignments can change over time
- Overtime or special schedules may apply

The app caches shift times per date to avoid repeated API calls for the same date.

## Using ERPNext's Built-in Fields

If `Employee Checkin` doctype has these custom fields in ERPNext:
- `late_entry` (Check) - ERPNext calculates this automatically
- `early_exit` (Check) - ERPNext calculates this automatically

The app will **prefer** these fields over manual calculation. Manual calculation is only used as a fallback if these fields don't exist or aren't accessible.

## Example Flow

1. **Check-in at 09:15 AM on 2026-01-08**
   - App queries Shift Assignment for date 2026-01-08
   - Finds active assignment → Shift Type "Morning Shift"
   - Gets Shift Type → start_time: 09:00, end_time: 17:00
   - Checks: 09:15 > (09:05) → ✅ **Late Entry Detected**

2. **Check-out at 16:50 PM on 2026-01-08**
   - Uses cached shift times from check-in
   - Checks: 16:50 < (16:55) → ✅ **Early Exit Detected**

## Troubleshooting

### Issue: Late/Early detection not working
- **Check**: Does Shift Type exist in ERPNext?
- **Check**: Are `start_time` and `end_time` fields populated?
- **Check**: If using Shift Assignment, is it active and valid for the date?

### Issue: Default times (9 AM - 5 PM) always used
- **Check**: Employee record has shift field configured?
- **Check**: Shift Type referenced exists and is accessible?
- **Check**: Shift Assignment exists for the date?

### Issue: Wrong shift times detected
- **Check**: Multiple Shift Assignments? (App uses most recent)
- **Check**: Shift Assignment `end_date` is correct?
- **Check**: Timezone settings in ERPNext match app timezone?

