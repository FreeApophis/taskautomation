taskautomation
==============

I think Redmine and Chili are missing an important feature. Automatic transitions.

If certain criterias are met then an action should be done automatically.

As an example, it often happens that after the Resolved state, the review is not done and the task is never closed until someone cleans it up. Often it would be enough to give them a usefull timeframe to make a comment, but close it automatically when this is passed.

Here comes in Taskautomation.

It is only intended for Admins and familiar with Ruby on Rails / rake or at least Ruby because the rules are written in the script itself.
The source is the documentation, it is simple to understand and still powerfull.

Installation:

1. Copy taskautomation.rb into lib/tasks
2. Write your rules
3. Test with the rake command

go to your Chili or Redmine directory
rake RAILS_ENV=production apophis:taskobserve

4. Setup a cron task

This cron task checks every hour, this is even with active projects usually enough. You could of course only once per day.

crontab -e

Add:
0 * * * * cd /var/www/<CHILI/REDMIN/PATH>/ && /usr/bin/rake RAILS_ENV=production apophis:taskobserve

Writing rules:

I wanted to make it as simple as possible for common cases, and still flexible enough:

Simple example:

This rule is probably the most used one:

We create a new rules:
1. argument: Name of the Rule, this text will be added as a comment to the tickets when the rule is executed on a ticket:
2. argument: Lists which Workflows are selected (can be string if only 1 Worflow, or "*" if you want to match all non-closed states.)
3. argument: Tasks in which state are selected (can be string if only 1 Worflow, or "*" if you want to match all non-closed states.)
4. argument: wasnt touch for how many days?

We set an action what should happen when this criteria is met: in this case the state should be changed to "Closed"

#***** Rule: Automatically closed after 30 days *****
    rule = Rules.new("Automatically close resolved issues after 30 days", ["Task", " Bug", "Feature", "Support"], ["Resolved"], 30)
    rule.set_next_state("Closed")
    result << rule
	
More complex example:

For more complex examples you can write your own methods which you want to have executed.

In this case we set a checker method which must return a boolean value.
And we als set an action, instead of just set it to the next state.

If a task is in state Feedback we assign it to the author because he should give feedback. In the states done and won't do its their responsibility to verify the result and close the ticket.

#***** Rule: Enforce Author for State Needs Feedback, Done and Won't Do *****
    rule =  Rules.new("Automaticaclly enforce assigned-to to the author of the ticket", "*", ["Done", "Won't Do", "Needs Feedback"], 0)
    rule.set_checker(method(:is_not_author))
    rule.set_action(method(:set_to_author))

    result << rule
	
Here we see the very simple implementation. Which those two delegates you are able to execute arbitrary checks and transitions.

The check is a very simple one-liner

  def is_not_author issue
    return issue.author_id != issue.assigned_to_id
  end

And here you see how can change arbitrary attributes.
  
  def set_to_author issue, rule
    rule.change_attribute(:assigned_to_id, issue.author_id)
  end
  
I know the usability is not very good, a webinterface would be nice. If you intend to create a better way I would be interested in feedback.

Both scripts are or have been in active use, and did a good job.

Please clone and fork.
Apophis