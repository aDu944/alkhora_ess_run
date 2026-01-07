# ERPNext Setup Checklist

Before the app can fully function, ensure the following are configured in ERPNext:

## Required Doctypes & Permissions

### 1. Employee Checkin ✅ (Already working)
- **Custom Fields** (if needed):
  - `latitude` (Float)
  - `longitude` (Float)  
  - `location_accuracy` (Float, optional)
  - `device_id` (Data, optional)

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


