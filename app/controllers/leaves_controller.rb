class LeavesController < ApplicationController  
  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
layout "vendor/plugins/employee_management/app/views/layouts/home.html.erb"

  def index       
    if session[:rolename] == "admin" and session[:department] == "Admin"      
      @emp_leaves = Leave.find(:all, :conditions =>['status =?',"Pending" ])      
    elsif session[:rolename] == "admin" and session[:department] != "Admin"
      @emp_leaves = Leave.find(:all, :conditions =>['status =?',"Pending" ])   
      @leaves = Leave.paginate(:all, :conditions =>['employee_id =?', params[:id] ], :page => params[:page], :per_page => 10 )
      @employee_leave_status = EmployeeLeaveStatus.find(:first, :conditions =>["employee_id = ? and year = ?",params[:id],Time.now.strftime("%Y").to_i])
    elsif session[:rolename] != "admin"
      @leaves = Leave.paginate(:all, :conditions =>['employee_id =?', params[:id] ], :page => params[:page], :per_page => 10 )
      @employee_leave_status = EmployeeLeaveStatus.find(:first, :conditions =>["employee_id = ? and year = ?",params[:id],Time.now.strftime("%Y").to_i])
    end    
  end
  
  def new
    @leave = Leave.new        
#@employee = Employee.find( session[:user_id] )
    @employee = Employee.find(12) 
  end
  
  def show
    @leave = Leave.find(params[:id])
  end
  
  def create       
   @leave = Leave.new(params[:leave])
   @employee = Employee.find( session[:user_id] )
   @leave.status = "Pending"   
   @leave.date = Time.now.strftime("%m/%d/%Y")
  
     if @leave.save
       @link = url_for :controller => 'leaves', :action => 'edit', :id => @leave.id
       Notifier.deliver_leave_details( @leave, @employee, @link )
       emp_lev_status = EmployeeLeaveStatus.find_by_employee_id_and_year( @employee.id, Time.now.strftime("%Y").to_i )
       if emp_lev_status.remain_privilege <  @leave.no_of_days  and  @leave.type_of_leave == "privilege" 
        flash[:notice] = " Leave has been successfully applied and your #{@leave.no_of_days - emp_lev_status.remain_privilege } day's are Without pay "
        redirect_to( :action => 'index', :id=>session[:user_id])
       else
        flash[:notice] = 'Leave has been successfully applied.'
        redirect_to( :action => 'index', :id=>session[:user_id])
       end            
     else      
      @employee.contact = params[:leave][:contact_no]
      @employee.address = params[:leave][:address]
      render :action => 'new'
     end
  end
  
  def edit        
    @leave = Leave.find(params[:id])
    @employee = Employee.find( session[:user_id] )
  end
  
  def update
    @leave = Leave.find(params[:id])        
    @employee = Employee.find( session[:user_id] )
    if @leave.update_attributes(params[:leave])
      if session[:rolename] == "admin" and session[:department] == "Admin"
        @leave.status = params[:status]
        @leave.save        
        Notifier.deliver_leave_status_updated( @leave, @leave.employee )
        if @leave.status == "Approved" or @leave.status == "Rejected"
          update_employee_leave_status( @leave )
        end
      else
        @link = url_for :controller => 'leaves', :action => 'edit', :id => @leave.id
        Notifier.deliver_leave_details( @leave, @employee, @link )
      end
      emp_lev_status = EmployeeLeaveStatus.find_by_employee_id_and_year( @employee.id, Time.now.strftime("%Y").to_i )
      if emp_lev_status.remain_privilege <  @leave.no_of_days  and  @leave.type_of_leave == "privilege" and session[:rolename] != "admin"
        flash[:notice] = " Leave has been successfully updated and your #{@leave.no_of_days - emp_lev_status.remain_privilege } day's are Without pay "
        redirect_to( :action => 'index', :id=>session[:user_id])
      else
        flash[:notice] = 'Leave has been successfully updated.'
        redirect_to :action => 'index',   :id=>session[:user_id]
      end
    else
      render :action => 'edit'
    end
  end
  
  def destroy
    @leave = Leave.find(params[:id])
    @leave.destroy
    flash[:notice] = 'Leave was successfully deleted.'
    redirect_to :action => 'index', :id=>session[:user_id]
  end
  
  def print
    @leave = Leave.find(params[:id])
    render :layout => false
  end
  
  def update_employee_leave_status( leave )    
    @employee_leave_status = EmployeeLeaveStatus.find_by_employee_id(leave.employee_id)
    if leave.type_of_leave == "privilege"
      @employee_leave_status.remain_privilege = @employee_leave_status.total_privilege - leave.no_of_days
    elsif leave.type_of_leave == "casual"
      @employee_leave_status.remain_casual = @employee_leave_status.total_casual - leave.no_of_days
    elsif leave.type_of_leave == "sick"
      @employee_leave_status.remain_sick = @employee_leave_status.total_sick - leave.no_of_days
    end                
     @employee_leave_status.save
  end
   
  def emp_leave_status    
    if params[:status_year]
      @employee_leave_status = EmployeeLeaveStatus.paginate( :all, :conditions =>["year = ?", params[:status_year].to_i] , :page => params[:page], :per_page => 10)
      session[:current_year] = params[:status_year]
    else
      session[:current_year] = Time.now.strftime("%Y")
      @employee_leave_status = EmployeeLeaveStatus.paginate( :all, :conditions =>["year = ?", Time.now.strftime("%Y").to_i] , :page => params[:page], :per_page => 10)
    end
     if request.xhr? 
      render :update do |page|        
        page.replace_html 'change_year', :partial =>'emp_leave_status', :locals => { :employee_leave_status => @employee_leave_status }
      end
    end  
  end
    
  def edit_emp_leave_status
    @employee_leave_status = EmployeeLeaveStatus.find( params[:id] )
    session[:emp_leave_id] = @employee_leave_status.employee_id    
  end
  
  def change_year
    invalid_year = 0
    if params[:status_year]
      @employee_leave_status = EmployeeLeaveStatus.find(:first, :conditions =>["employee_id = ? and year = ?",  session[:emp_leave_id], params[:status_year] ] )
      if @employee_leave_status.blank?     
          invalid_year = 1
          #~ @employee_leave_status = EmployeeLeaveStatus.new
          #~ @employee_leave_status.employee_id = session[:emp_leave_id]
          #~ @employee_leave_status.year = params[:status_year]
          #~ @employee_leave_status.save
         @employee_leave_status = EmployeeLeaveStatus.find(:first, :conditions =>["employee_id = ? and year = ?",  session[:emp_leave_id], Time.now.strftime("%Y").to_i ] )         
       end
       session[:current_year] = @employee_leave_status.year.to_s
    end
    if request.xhr? 
      render :update do |page|
        flash[:notice] = "Selected year's leaves are not available." if invalid_year == 1
        page.replace_html 'change_year', :partial =>'edit_emp_leave_status', :locals => { :employee_leave_status => @employee_leave_status }
      end
    end    
  end
  
  def update_emp_leave_status
    @employee_leave_status = EmployeeLeaveStatus.find( params[:id] )      
    @employee_leave_status = EmployeeLeaveStatus.find( :first, :conditions => ["employee_id =? and year = ? ", @employee_leave_status.employee_id,session[:current_year].to_i ] )
    @employee_leave_status.year = params[:status_year]
    if @employee_leave_status.update_attributes(params[:employee_leave_status])
      flash[:notice] = 'Employee Leave status was successfully updated.'
      redirect_to :action => 'emp_leave_status'
    else
      render :action=> "edit_emp_leave_status"
    end
  end
  
  def delete_emp_leave_status
    @employee_leave_status = EmployeeLeaveStatus.find( params[:id] )
    @employee_leave_status.destroy
    flash[:notice] = 'Employee Leave Status was successfully deleted.'
    redirect_to :action => 'emp_leave_status'
  end
  
  def leave_details
    @employee = Employee.find( params[:id] )
    @leaves = Leave.find(:all, :conditions =>['employee_id =? and status =?', params[:id], "Approved" ], :order =>"date DESC")
  end  
 
end