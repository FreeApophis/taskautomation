cat public/pirates.rake
#*******************************************
#
# Flexible automatic transitions for redmine
#
# (C) Thomas Bruderer, Piratenpartei Schweiz
#
# configuration is below
#
#*******************************************

namespace :pirates do
  class Rules
    attr_accessor :name, :tracker, :status, :age, :valid
    attr_accessor :conditions, :checker
    attr_accessor :changes, :action

    def initialize name, tracker, status, age_days
      @name = name
      @age = age_days
  
      @tracker = Array.new
      if tracker.kind_of?(Array)
        tracker.each do | t |
          tr = Tracker.find_by_name(t)
          @tracker << tr unless tr == nil
        end
      else
        if tracker == "*"
          @tracker = Tracker.all
        else
          @tracker << Tracker.find_by_name(tracker)
        end
      end

      @status = Array.new
      if status.kind_of?(Array)
        status.each do | s |
          st = IssueStatus.find_by_name(s)
          @status << st unless st == nil
        end
      else
        if status == "*"
          @status = IssueStatus.find(:all, :conditions => ["is_closed = false"])
        else
          @status << IssueStatus.find_by_name(status)
        end
      end


      @valid = true
      @conditions = Hash.new
      @changes = Hash.new
      @action = nil


    end

    def set_condition attribute, value
      @conditions.store(attribute, value)
    end

    def set_action delegate
      if delegate.kind_of?(Method)
        @action = delegate
      end
    end

    def set_checker delegate
      if delegate.kind_of?(Method)
        @checker = delegate
      end
    end

    def invoke_action issue, rule
      if @action != nil
        @action.call(issue, rule)
      end
    end

    def invoke_checker issue
      if @checker != nil
        return @checker.call(issue)
      end
      return true
    end

    def set_next_state status
      @changes.store(:status_id, IssueStatus.find_by_name(status).id)
    end

    def change_attribute attribute, value
      @changes.store(attribute, value)
    end

  end

  def is_not_author issue
    return issue.author_id != issue.assigned_to_id
  end

  def set_to_author issue, rule
    rule.change_attribute(:assigned_to_id, issue.author_id)
  end

  def due_date_reached issue
    if issue.due_date == nil
      return false
    end
    return issue.due_date < Date.today    
  end


  def debug_putser issue, rule
#    puts issue.inspect
    puts "Issue #{issue.id} has due date: #{issue.due_date}"
  end

#***** CONFIGURE HERE: Defining of all the rules which should be executed *****
  def self.create_rules
    result = Array.new
#***** Rule: Automatically closed after 30 days *****
    rule =  Rules.new("Automatically close after 30 days", ["Task", " Bug / Feature"], ["Done", "Won't Do"], 30)
    rule.set_next_state("Closed")

    result << rule

#***** Rule: Automatically changed from new state after 3 days *****
    rule =  Rules.new("Automatically changed from new state after 3 days", ["Task", " Bug / Feature"], "New", 3)
    rule.set_next_state("Needs Work")

    result << rule

#***** Rule: Enforce Author for State Needs Feedback, Done and Won't Do *****
    rule =  Rules.new("Automaticaclly enforce assigned-to to the author of the ticket", "*", ["Done", "Won't Do", "Needs Feedback"], 0)
    rule.set_checker(method(:is_not_author))
    rule.set_action(method(:set_to_author))

    result << rule

#***** Rule: Enforce Due date for Low Priority *****
    rule =  Rules.new("Automatically enforce due date for Low Priority after 60 days in the future", "*", "*", 0)
    rule.set_condition(:due_date, nil)
    rule.set_condition(:priority_id, IssuePriority.find_by_name("Low").id)
    rule.change_attribute(:due_date, (Date.today + 60).to_s)

    result << rule

#***** Rule: Enforce Due date for Normal Priority *****
    rule =  Rules.new("Automatically enforce due date for Normal Priority to 30 days in the future", "*", "*", 0)
    rule.set_condition(:due_date, nil)
    rule.set_condition(:priority_id, IssuePriority.find_by_name("Normal").id)
    rule.change_attribute(:due_date, (Date.today + 30).to_s)

    result << rule

#***** Rule: Enforce Due date for High Priority *****
    rule =  Rules.new("Automatically enforce due date for High Priority to 15 days in the future", "*", "*", 0)
    rule.set_condition(:due_date, nil)
    rule.set_condition(:priority_id, IssuePriority.find_by_name("High").id)
    rule.change_attribute(:due_date, (Date.today + 15).to_s)

    result << rule

#***** Rule: Enforce Due date for Urgent Priority *****
    rule =  Rules.new("Automatically enforce due date for Urgent Priority to 3 days in the future", "*", "*", 0)
    rule.set_condition(:due_date, nil)
    rule.set_condition(:priority_id, IssuePriority.find_by_name("Urgent").id)
    rule.change_attribute(:due_date, (Date.today + 3).to_s)

    result << rule

#***** Rule: Enforce Due date for High Priority *****
    rule =  Rules.new("Automatically enforce due date for Immediate Priority to 1 day in the future", "*", "*", 0)
    rule.set_condition(:due_date, nil)
    rule.set_condition(:priority_id, IssuePriority.find_by_name("Immediate").id)
    rule.change_attribute(:due_date, (Date.today + 1).to_s)

    result << rule

#***** Rule: Due day reached *****
    rule =  Rules.new("Due date reached, automatically increased by 2 days. Please handle this ticket immedialty", "*", "Needs Work", 0)
    rule.set_checker(method(:due_date_reached))
    rule.change_attribute(:due_date, (Date.today + 2).to_s)

    result << rule

#   Return all the rules
    return result
  end
#***** END CONFIGURE *****



  desc "Observes all tickets and executes actions based on rules"
  task :taskobserve => :environment do
    admin = User.find_by_id(1)
    rules = create_rules

    rules.each do | rule |
      if (rule.valid)
        Issue.find(:all, :conditions => ["status_id IN (?) and tracker_id IN (?) and updated_on < ?", rule.status, rule.tracker, (DateTime.now - rule.age)]).each do |issue|
          fulfilled = true
          rule.conditions.each { |attribute, value| fulfilled = false if (issue.send(attribute) != value) }
          fulfilled = (fulfilled and rule.invoke_checker(issue))

          #if all conditions are fulfilled
          if fulfilled
            puts "Handle Issue #{issue.id}"

            # a rule can make something more complicated, for that we call the callback which is called. 
            rule.invoke_action issue, rule

            # we now change all attributes according to the rule, this includes state changes
            if rule.changes.count > 0
              journal = Journal.new
              journal.user = admin
              journal.journalized_type = "Issue"
              journal.journalized_id = issue.id
              journal.notes = rule.name
              journal.save

              rule.changes.each do | attribute, value |
                jdetail = JournalDetail.new
                jdetail.journal_id = journal.id
                jdetail. property = "attr"
                jdetail.prop_key = attribute.to_s
                jdetail.old_value = issue.send(attribute)
                jdetail.value = value
                jdetail.save

                issue.write_attribute(attribute, value)
                issue.save
              end
            end
          end
        end
        puts "Rule '#{rule.name}' executed"
      else
        puts "Rule '#{rule.name}' is invalid and has been skipped"        
      end
    end
    puts "Observe Tasks ended"
  end
end
