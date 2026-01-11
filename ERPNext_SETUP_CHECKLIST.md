# ERPNext Setup Checklist

Before the app can fully function, ensure the following are configured in ERPNext:

## Required Doctypes & Permissions

### 1. Employee Checkin ✅ (Already working)
- **Custom Fields** (REQUIRED for location tracking):
  - `latitude` (Float) - Required to store check-in location coordinates
  - `longitude` (Float) - Required to store check-in location coordinates
  - `location_accuracy` (Float, optional) - GPS accuracy in meters
  - `device_id` (Data, optional) - Device identifier
  
  **Note:** The app will automatically try multiple field name variations:
  - `latitude` / `longitude` / `location_accuracy` (standard)
  - `lat` / `lng` / `accuracy` (alternative)
  - `checkin_latitude` / `checkin_longitude` / `checkin_accuracy`
  - `gps_latitude` / `gps_longitude` / `gps_accuracy`
  
  If none of these work, add custom fields with any of these names to the Employee Checkin doctype.

### 2. Leave Application
- **Permissions**: Employee role needs:
  - Read own Leave Application
  - Create Leave Application
  - Submit Leave Application (if workflow enabled)

- **Leave Types**: Ensure Leave Types are configured
- **Leave Allocation**: Employees should have Leave Allocations created

### 3. Attendance
- **Permissions**: Employee role needs:
  - Read own Attendance

- **Processing Check-ins to Attendance Records**:
  ERPNext HRMS has a background scheduler job that automatically processes `Employee Checkin` records and creates `Attendance` records. 
  
  **To enable automatic processing:**
  1. Go to ERPNext → Setup → Automation → Scheduled Job Type
  2. Find "Mark Attendance" scheduled job
  3. Ensure it's enabled and runs periodically (usually every hour or daily)
  4. Alternatively, go to HR → Tools → Mark Attendance to manually process check-ins
  
  **Manual Processing:**
  - Navigate to: HR → Tools → Mark Attendance
  - Select date range and employees
  - Click "Mark Attendance"
  - This will create Attendance records from Employee Checkin records
  
  **API Method (if needed):**
  ```python
  # Custom API endpoint to trigger attendance marking
  @frappe.whitelist()
  def mark_attendance_from_checkins(employee=None, from_date=None, to_date=None):
      from hrms.hr.doctype.employee_checkin.employee_checkin import mark_attendance
      mark_attendance(employee, from_date, to_date)
  ```
  
  **Note:** Attendance records are created based on:
  - Check-in (IN) and Check-out (OUT) pairs
  - Shift assignments
  - Working hours calculation

### 4. Salary Slip (Payslip)
- **Permissions**: Employee role needs:
  - Read own Salary Slip

- **Note**: PDF download requires print format permission or custom API method

### 5. Expense Claim
- **Permissions**: Employee role needs:
  - Read own Expense Claim
  - Create Expense Claim
  - Submit Expense Claim

- **Expense Claim Types**: Configure expense types

### 5.1. Journal Entry Account (Payments - Fast Path) ⚡
- **Permissions**: Employee role needs:
  - **Read** permission on `Journal Entry Account` doctype (for fast payments loading)
  
  **Why this is needed:**
  - The app needs to query Journal Entry Account directly to fetch employee payments quickly
  - Without this permission, the app falls back to a slower method (individual API calls per journal entry)
  - This can cause slow loading times (5-10+ seconds vs. <1 second)
  
  **How to enable:**
  1. Go to ERPNext → **Setup** → **Users and Permissions** → **Role Permissions Manager**
  2. Select the **Employee** role (or the role assigned to your employees)
  3. Search for **"Journal Entry Account"** in the doctype list
  4. Check the **Read** permission checkbox
  5. Click **Save**
  6. Alternatively, go to **Setup** → **Users and Permissions** → **Role Permission for Page and Report**
     - Select Employee role
     - Add new rule:
       - **Document Type**: Journal Entry Account
       - **Permission**: Read
       - **Apply User Permissions**: Yes (recommended for security)
  
  **Security Note:**
  - Employees will only see Journal Entry Account records where they are the party
  - The app filters by `party_type = 'Employee'` and `party = [employee_id]`
  - This is safe as employees can only see their own payment records
  - If you want additional security, you can create a custom API method that enforces these filters server-side

### 6. Announcement
- **Permissions**: Employee role needs:
  - Read Announcement

- **Configuration**: 
  - Set publish dates
  - Configure target (All, Department, Employee, etc.)

### 7. Employee (Profile)
- **Permissions**: Employee role needs:
  - Read own Employee
  - Write own Employee (for profile updates - limited fields)

- **Custom Fields for Multiple Check-in Locations** (OPTIONAL but recommended):
  - `allowed_checkin_locations` (Long Text / JSON) - Store allowed locations as JSON array
  
  **JSON Format:**
  ```json
  [
    {
      "name": "Main Office",
      "latitude": 25.2867,
      "longitude": 51.5333,
      "radius_meters": 100
    },
    {
      "name": "Home",
      "latitude": 25.2900,
      "longitude": 51.5400,
      "radius_meters": 50
    },
    {
      "name": "Tax Authority",
      "latitude": 25.2800,
      "longitude": 51.5200,
      "radius_meters": 100
    }
  ]
  ```
  
  **Alternative Custom Field Name:**
  - `custom_allowed_locations` (Long Text / JSON) - Same format as above
  
  **How it works:**
  - If `allowed_checkin_locations` or `custom_allowed_locations` is configured for an employee, 
    they can check-in from any of those locations (within the specified radius)
  - If not configured, the app uses the default office location from AppConfig (if enabled)
  - If no geofencing is configured, employees can check-in from anywhere

### 8. Holiday List
- **Permissions**: Employee role needs:
  - Read Holiday List

- **Note**: Holiday dates are in child table. May need custom API or expose child table data.

### 9. ToDo (Approvals)
- **Permissions**: Employee role needs:
  - Read own ToDo
  - Write own ToDo (to close/complete)

## Custom API Methods (Optional but Recommended)

If you want to expose child tables or complex data more efficiently:

### 1. Holiday Dates API
```python
@frappe.whitelist()
def get_holiday_dates(holiday_list):
    """Get all holiday dates for a holiday list"""
    holidays = frappe.get_all(
        'Holiday',
        filters={'parent': holiday_list},
        fields=['holiday_date', 'description', 'weekly_off'],
        order_by='holiday_date'
    )
    return holidays
```

### 2. Leave Balance API
```python
@frappe.whitelist()
def get_leave_balance(employee, leave_type, from_date=None):
    """Get current leave balance for employee"""
    from hrms.hr.doctype.leave_application.leave_application import get_leave_balance_on
    
    balance = get_leave_balance_on(
        employee, 
        leave_type, 
        from_date or today()
    )
    return balance
```

### 3. Payslip PDF Download
- Ensure print format is configured
- Or create custom method with proper permissions

## Permission Setup Guide

1. Go to **Setup → Users → Permissions → Role Permissions Manager**
2. Select **Employee** role
3. For each doctype above, ensure:
   - **Read** permission (All or "If Owner")
   - **Write** permission if user needs to create/update
   - **Submit** permission if workflow is enabled

## Testing Checklist

- [ ] Employee can check-in/out
- [ ] Employee can view leave applications
- [ ] Employee can create leave application
- [ ] Employee can view attendance records
- [ ] Employee can view payslips
- [ ] Employee can create expense claim
- [ ] Employee can view announcements
- [ ] Employee can view/update profile
- [ ] Employee can view holidays
- [ ] Employee can view approvals/todos

## Common Issues

### Issue: "Permission Denied" errors
**Solution**: Check Role Permissions Manager, ensure Employee role has required permissions

### Issue: Child tables not loading (Holiday dates)
**Solution**: Create custom API method or ensure child table data is included in API response

### Issue: PDF download fails
**Solution**: Check print format permissions or create custom download method

### Issue: Filters not working as expected
**Solution**: Verify field names match ERPNext doctype exactly (case-sensitive)

## Additional Notes

- Date fields should be in `YYYY-MM-DD` format
- Datetime fields should be ISO 8601 format
- Currency fields are Decimal/Float
- Link fields use the `name` field of the linked doctype
- Status fields may vary (check your ERPNext setup)


