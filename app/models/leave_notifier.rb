class LeaveNotifier < ActionMailer::Base
  def leave_details( leave, employee, link)  
      @recipients = RECIPIENT_EMAIL
      @cc = employee.office_email
      @subject = "Leave Application of #{employee.first_name} #{employee.last_name}"
      @title = "Leave Application"
      @from =  "#{employee.office_email}"
      @sent_on = sent_on=Time.now
      @body["employee"] = employee   
      @body["leave"] = leave
      @body["link"] = link
  end

  def leave_status_updated( leave, employee )
      @recipients = employee.office_email
      @cc = RECIPIENT_EMAIL
      @subject = "Applied Leave has #{leave.status}"
      @title = "Leave Application"
      @from =  'Administrator <administrator@joshsoftware.com>'
      @sent_on = sent_on=Time.now
      @body["employee"] = employee   
      @body["leave"] = leave
  end
end
