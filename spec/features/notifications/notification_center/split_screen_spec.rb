require 'spec_helper'

describe "Split screen in the notification center", type: :feature, js: true do
  let(:global_html_title) { ::Components::HtmlTitle.new }
  shared_let(:project) { FactoryBot.create :project }
  shared_let(:work_package) { FactoryBot.create :work_package, project: project }
  shared_let(:second_work_package) { FactoryBot.create :work_package, project: project }
  shared_let(:recipient) do
    FactoryBot.create :user,
                      member_in_project: project,
                      member_with_permissions: %i[view_work_packages]
  end
  shared_let(:notification) do
    FactoryBot.create :notification,
                      recipient: recipient,
                      project: project,
                      resource: work_package,
                      journal: work_package.journals.last
  end

  shared_let(:second_notification) do
    FactoryBot.create :notification,
                      recipient: recipient,
                      project: project,
                      resource: second_work_package,
                      journal: second_work_package.journals.last
  end

  let(:center) { ::Pages::Notifications::Center.new }
  let(:split_screen) { ::Pages::Notifications::SplitScreen.new work_package }

  describe 'basic use case' do
    current_user { recipient }

    before do
      visit home_path
      center.open
    end

    it 'can switch between multiple notifications and the split screen remains open and updates accordingly' do
      center.expect_bell_count 2
      center.click_item notification

      # Opening the split screen marks the notifications as read
      split_screen.expect_open
      center.expect_work_package_item notification
      center.expect_work_package_item second_notification

      # Clicking on a another notification changes the split screen content
      center.click_item second_notification
      split_screen = ::Pages::SplitWorkPackage.new(second_work_package, project)
      split_screen.expect_open
      center.expect_work_package_item second_notification
    end

    it 'can navigate between the tabs' do
      center.expect_bell_count 2
      split_screen.expect_empty_state

      center.click_item notification
      split_screen.expect_open

      # Activity is selected as default
      split_screen.expect_tab :activity
      activity_tab = ::Components::WorkPackages::Activities.new(work_package)
      activity_tab.expect_wp_has_been_created_activity work_package

      # Navigate to the relations tab
      split_screen.switch_to_tab tab: 'relations'
      split_screen.expect_tab :relations
      relations_tab = ::Components::WorkPackages::Relations.new(work_package)
      relations_tab.expect_no_relation work_package

      # Navigate to full view and back
      wp_full = split_screen.switch_to_fullscreen
      wp_full.expect_tab :relations

      wp_full.go_back
      split_screen.expect_tab :relations

      # The split screen can be closed
      split_screen.close
      split_screen.expect_empty_state
    end

    it 'can show the correct html title while opening and closing the split view' do
      global_html_title.expect_first_segment 'Notifications'

      # The split view should be opened and html title should change
      first_title = "#{work_package.type.name}: #{work_package.subject} (##{work_package.id})"
      center.click_item notification
      global_html_title.expect_first_segment first_title

      # The split view should be closed and html title should change to the previous title
      split_screen.close
      global_html_title.expect_first_segment 'Notifications'

      # Html title should be updated with next WP data after making the current one as read
      second_title = "#{second_work_package.type.name}: #{second_work_package.subject} (##{second_work_package.id})"
      center.click_item notification
      center.mark_notification_as_read notification
      global_html_title.expect_first_segment second_title

      # After making all notifications as read, html title should show the base route
      center.mark_notification_as_read second_notification
      global_html_title.expect_first_segment 'Notifications'
    end
  end

  context 'with no unread notification' do
    current_user { recipient }

    before do
      Notification.where(recipient: recipient).update_all(read_ian: true)
      visit home_path
      center.open
    end

    it 'can switch between multiple notifications and the split screen remains open and updates accordingly' do
      center.expect_bell_count 0
      split_screen.expect_caught_up
    end
  end
end
