class EmployeeLeaveStatus < ActiveRecord::Base
  belongs_to :employee
   cattr_reader :per_page      
end
