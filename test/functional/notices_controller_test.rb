require File.dirname(__FILE__) + '/../test_helper'

class NoticesControllerTest < ActionController::TestCase

  context "per-project keys" do
    setup do
      Setting.mail_handler_api_enabled = '0'
      Setting.mail_handler_api_key = 'off'

      @tracker = Tracker.create(:name => 'Bug')
      @project = Project.create(:name => 'Sample Project', :identifier => 'sample-project')


      @priority = IssuePriority.create!(:name => 'Normal', :position => 2, :is_default => true)
      @status = IssueStatus.create!(:name => 'New', :is_closed => false, :is_default => true, :position => 1)
      @project.trackers << @tracker
      @project.save

      @custom_field = ProjectCustomField.generate!(:name => 'Hoptoad Key', :field_format => 'string')
      Setting.plugin_redmine_hoptoad_server = {'project_key_custom_field_id' => @custom_field.id.to_s}

      @sample_error = File.read(File.dirname(__FILE__) + '/../fixtures/hoptoad_notification_v2.xml')
      @request.env["RAW_POST_DATA"] = @sample_error

    end

    context "with a matching key" do
      setup do
        @project.custom_field_values = {@custom_field.id.to_s => 'secret'}
        @project.save!
      end
      
      should "create an issue" do
        assert_difference 'Issue.count' do
          post :create
          assert assigns(:xml)
        end
      end
      
      should "use the client's tracker name" do
        post :create
        @issue = Issue.find(:first, :order => 'id DESC')
        assert_equal @tracker, @issue.tracker
      end
      
      should "use the client's priority" do
        post :create
        @issue = Issue.find(:first, :order => 'id DESC')
        assert_equal @priority, @issue.priority
      end
    end

    context "with an invalid key" do
      setup do
        @project.custom_field_values = {@custom_field.id.to_s => 'ponies'}
        @project.save!
      end

      should "reject the issue" do
        post :create
        assert_response 403
      end

      should "not save any issues" do
        assert_no_difference('Issue.count') do
          post :create
        end
      end

      should "not save any journals" do
        assert_no_difference('Journal.count') do
          post :create
        end
      end
    end

  end
  
  def test_api_v2
    t = Tracker.create(:name => 'Bug')
    p = Project.create(:name => 'Sample Project', :identifier => 'sample-project')

    priority = IssuePriority.create!(:name => 'Normal', :position => 2, :is_default => true)
    status = IssueStatus.create!(:name => 'New', :is_closed => false, :is_default => true, :position => 1)
    p.trackers << t
    p.save

    Setting.mail_handler_api_enabled = 1
    Setting.mail_handler_api_key = 'secret'

    sample_error = File.read(File.dirname(__FILE__) + '/../fixtures/hoptoad_notification_v2.xml')
    @request.env["RAW_POST_DATA"] = sample_error

    assert_difference 'Issue.count' do
      post :create
      assert assigns(:xml)
    end

    @issue = Issue.find(:first, :order => 'id DESC')

    assert_equal 'Special Error in vendor/plugins/hoptoad_notifier/lib/hoptoad_notifier.rb:136', @issue.subject
    assert_equal 'Redmine Notifier reported an Error related to source: /my_app/vendor/plugins/hoptoad_notifier/lib/hoptoad_notifier.rb#L136', @issue.description
    assert_equal t, @issue.tracker
    assert_equal p, @issue.project
    assert_equal status, @issue.status
    assert_equal priority, @issue.priority

    assert_equal 1, @issue.journals.size
    @journal = @issue.journals.first
    assert_match /Special Error/, @journal.notes, "Missing Error message"
  end

  # TODO:
  def test_api_v1
  end
end
