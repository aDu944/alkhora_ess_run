# Processing Employee Checkin to Attendance Records in ERPNext

## Overview

In ERPNext, `Employee Checkin` records (created by the mobile app when employees check in/out) are processed into `Attendance` records. This is typically done automatically by ERPNext's background scheduler, but can also be done manually.

## Automatic Processing (Recommended)

ERPNext HRMS includes a scheduled job that automatically processes check-ins into attendance records:

1. **Enable the Scheduled Job:**
   - Go to: **ERPNext → Setup → Automation → Scheduled Job Type**
   - Find: **"Mark Attendance"** or **"Process Employee Checkin"**
   - Ensure it's enabled and set to run periodically (usually every hour or daily)
   - Save the configuration

2. **Verify Execution:**
   - Go to: **ERPNext → Setup → Automation → Scheduled Job Log**
   - Check for successful execution of the "Mark Attendance" job
   - Verify that Attendance records are being created

## Manual Processing

If automatic processing is not enabled or you need to process check-ins immediately:

1. **Via UI:**
   - Navigate to: **HR → Tools → Mark Attendance**
   - Select:
     - **Employee** (optional - leave blank for all employees)
     - **From Date** and **To Date** (date range to process)
   - Click **"Mark Attendance"** button
   - ERPNext will create Attendance records from Employee Checkin records

2. **Via Python Console:**
   ```python
   from hrms.hr.doctype.employee_checkin.employee_checkin import mark_attendance
   
   # Process for a specific employee
   mark_attendance(employee="EMP-00001", date=datetime.date.today())
   
   # Process for date range
   mark_attendance(employee="EMP-00001", 
                  from_date=datetime.date(2024, 1, 1),
                  to_date=datetime.date(2024, 1, 31))
   ```

3. **Via API (Custom Endpoint):**
   ```python
   # Add this to a custom app's api.py
   @frappe.whitelist()
   def process_attendance_from_checkins(employee=None, from_date=None, to_date=None):
       """Process Employee Checkin records into Attendance records"""
       from hrms.hr.doctype.employee_checkin.employee_checkin import mark_attendance
       from datetime import datetime
       
       if isinstance(from_date, str):
           from_date = datetime.strptime(from_date, "%Y-%m-%d").date()
       if isinstance(to_date, str):
           to_date = datetime.strptime(to_date, "%Y-%m-%d").date()
       
       mark_attendance(employee=employee, from_date=from_date, to_date=to_date)
       return {"status": "success", "message": "Attendance processed successfully"}
   ```

## How It Works

1. **Check-in Pairs:**
   - ERPNext looks for check-in (IN) and check-out (OUT) pairs for each day
   - Creates one Attendance record per day per employee

2. **Shift Assignment:**
   - If employees have shift assignments, ERPNext uses shift timing
   - Calculates working hours based on shift start/end times
   - Marks attendance as Present, Absent, or Half Day

3. **Late Entry Detection:**
   - If check-in time is after shift start time, marks `late_entry = 1`
   - Late entry threshold can be configured in Shift Type

4. **Working Hours Calculation:**
   - Calculates actual working hours from check-in to check-out
   - Stores in `working_hours` field of Attendance record

## Troubleshooting

### Check-ins Not Creating Attendance Records

1. **Check Scheduled Job:**
   - Verify "Mark Attendance" job is enabled and running
   - Check Scheduled Job Log for errors

2. **Verify Check-in Records:**
   - Go to: **HR → Employee Checkin**
   - Verify check-ins are being created with correct `log_type` (IN/OUT)
   - Ensure `employee` field is correctly linked

3. **Check Shift Assignment:**
   - Go to: **HR → Shift Assignment**
   - Verify employees have active shift assignments
   - Check shift start/end times

4. **Manual Process:**
   - Try manually processing via **HR → Tools → Mark Attendance**
   - Check for error messages in the console

### Attendance Records Not Showing in App

1. **Check Permissions:**
   - Ensure Employee role has "Read" permission on Attendance doctype
   - Verify `docstatus = 1` (submitted) attendance records are visible

2. **Check Date Range:**
   - Attendance page shows current month by default
   - Verify attendance records exist for the current month

3. **Check API Access:**
   - Verify API user has permission to read Attendance records
   - Test API endpoint: `GET /api/resource/Attendance`

## Best Practices

1. **Enable Automatic Processing:**
   - Always enable the scheduled job for automatic attendance marking
   - Set it to run daily or every few hours

2. **Monitor Job Execution:**
   - Regularly check Scheduled Job Log for failures
   - Set up email notifications for job failures

3. **Process Historical Data:**
   - After enabling automatic processing, manually process historical check-ins
   - Use date range selector to process past months

4. **Verify Accuracy:**
   - Periodically review Attendance records against Employee Checkin records
   - Ensure working hours are calculated correctly
   - Check for missing attendance records

