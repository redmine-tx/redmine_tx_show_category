Redmine::Plugin.register :redmine_tx_show_category do
  name 'Redmine Tx Show Category plugin (시험판)'
  author 'KiHyun Kang'
  description '연관이슈에 범주를 표기해 줍니다. (부작용 있을 수 있음)'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'
end

Rails.application.config.after_initialize do

=begin  # 개 위험한 구현
  class Issue
      # reader (getter)
      define_method :subject do
        if self.category.present?
          _subject = read_attribute(:subject)
          if _subject.include?( "[#{self.category.name}]" ) then
            _subject.gsub!("[#{self.category.name}] ", "")
            _subject.gsub!("[#{self.category.name}]", "")
          end

          "[#{self.category.name}] ‎#{_subject}"
        else
          read_attribute(:subject)
        end
      end
  
      # writer (setter)
      define_method :subject= do |value|
        if value.include?( "‎" ) then
          # *로 시작하는 경우 *를 제거하고 저장
          write_attribute(:subject, value.split("‎").last)
        else
          write_attribute(:subject, value)
        end
      end
  end
=end

  module IssuesHelper
    def render_descendants_tree(issue)
      manage_relations = User.current.allowed_to?(:manage_subtasks, issue.project)
      s = +'<table class="list issues odd-even">'
      issue_list(
        issue.descendants.visible.
          preload(:status, :priority, :tracker,
                  :assigned_to).sort_by(&:lft)) do |child, level|
        css = "issue issue-#{child.id} hascontextmenu #{child.css_classes}"
        css << " idnt idnt-#{level}" if level > 0
        buttons =
          if manage_relations
            link_to(
              sprite_icon('link-break', l(:label_delete_link_to_subtask)),
              issue_path(
                {:id => child.id, :issue => {:parent_issue_id => ''},
                 :back_url => issue_path(issue.id), :no_flash => '1'}
              ),
              :method => :put,
              :data => {:confirm => l(:text_are_you_sure)},
              :title => l(:label_delete_link_to_subtask),
              :class => 'icon-only icon-link-break'
            )
          else
            "".html_safe
          end
        buttons << link_to_context_menu
        s <<
          content_tag(
            'tr',
            content_tag('td', check_box_tag("ids[]", child.id, false, :id => nil),
                        :class => 'checkbox') +
               content_tag('td',
                           link_to_issue(
                             child,
                             :project => (issue.project_id != child.project_id)),
                           :class => 'subject') +
               content_tag('td', child.category ? child.category.name : '', :class => 'category') +
               content_tag('td', h(child.status), :class => 'status') +
               content_tag('td', link_to_user(child.assigned_to), :class => 'assigned_to') +
               content_tag('td', format_date(child.start_date), :class => 'start_date') +
               content_tag('td', format_date(child.due_date), :class => 'due_date') +
               content_tag('td',
                           (if child.disabled_core_fields.include?('done_ratio')
                              ''
                            else
                              progress_bar(child.done_ratio)
                            end),
                           :class=> 'done_ratio') +
               content_tag('td', child.estimated_hours_plus, :class => 'estimated_hours_plus') +
               ( Redmine::Plugin.installed?(:redmineup_tags) ? 
                 content_tag('td', 
                   child.tags.map { |tag| 
                     content_tag('span', tag.name, class: 'tag-label-color', style: "background-color: ##{tag.color}")
                   }.join(' ').html_safe, 
                   :class => 'tag'
                 ) : '' ) +
               content_tag('td', buttons, :class => 'buttons'),
            :class => css)
      end
      s << '</table>'
      s.html_safe
    end

    def render_issue_relations(issue, relations)
      manage_relations = User.current.allowed_to?(:manage_issue_relations, issue.project)
      s = ''.html_safe
      relations.each do |relation|
        other_issue = relation.other_issue(issue)
        css = "issue issue-#{other_issue.id} hascontextmenu #{other_issue.css_classes} #{relation.css_classes_for(other_issue)}"
        buttons =
          if manage_relations
            link_to(
              sprite_icon('link-break', l(:label_relation_delete)),
              relation_path(relation, issue_id: issue.id),
              :remote => true,
              :method => :delete,
              :data => {:confirm => l(:text_are_you_sure)},
              :title => l(:label_relation_delete),
              :class => 'icon-only icon-link-break'
            )
          else
            "".html_safe
          end
        buttons << link_to_context_menu
        s <<
          content_tag(
            'tr',
            content_tag('td',
                        check_box_tag(
                          "ids[]", other_issue.id,
                          false, :id => nil),
                        :class => 'checkbox') +
               content_tag('td',
                           relation.to_s(@issue) do |other|
                             link_to_issue(
                               other,
                               :project => Setting.cross_project_issue_relations?
                             )
                           end.html_safe,
                           :class => 'subject') +
               content_tag('td', other_issue.category ? other_issue.category.name : '', :class => 'category') +
               content_tag('td', other_issue.status, :class => 'status') +
               content_tag('td', link_to_user(other_issue.assigned_to), :class => 'assigned_to') +
               content_tag('td', format_date(other_issue.start_date), :class => 'start_date') +
               content_tag('td', format_date(other_issue.due_date), :class => 'due_date') +
               content_tag('td',
                           (if other_issue.disabled_core_fields.include?('done_ratio')
                              ''
                            else
                              progress_bar(other_issue.done_ratio)
                            end),
                           :class=> 'done_ratio') +
               content_tag('td', other_issue.estimated_hours_plus, :class => 'estimated_hours_plus') +
               ( Redmine::Plugin.installed?(:redmineup_tags) ? 
                 content_tag('td', 
                   other_issue.tags.map { |tag| 
                     content_tag('span', tag.name, class: 'tag-label-color', style: "background-color: ##{tag.color}")
                   }.join(' ').html_safe, 
                   :class => 'tag'
                 ) : '' ) +
               content_tag('td', buttons, :class => 'buttons'),
            :id => "relation-#{relation.id}",
            :class => css)
      end
      content_tag('table', s, :class => 'list issues odd-even')
    end
  end
end
