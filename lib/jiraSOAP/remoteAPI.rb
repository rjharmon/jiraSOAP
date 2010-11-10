# Contains the API defined by Atlassian for the JIRA SOAP service. The JavaDoc
# for the SOAP API is located at http://docs.atlassian.com/software/jira/docs/api/rpc-jira-plugin/latest/com/atlassian/jira/rpc/soap/JiraSoapService.html.
#@todo exception handling
#@todo code refactoring and de-duplication
module RemoteAPI
  # XPath constant to get a node containing a response array.
  # This could be used for all responses, but is only used in cases where we
  # cannot use a more blunt XPath expression.
  RESPONSE_XPATH = '/node()[1]/node()[1]/node()[1]/node()[2]'

  # The first method to call; other methods will fail until you are logged in.
  # @param [String] user JIRA user name to login with
  # @param [String] password
  # @return [true] true if successful, otherwise an exception is thrown
  def login(user, password)
    response = invoke('soap:login') { |msg|
      msg.add 'soap:in0', user
      msg.add 'soap:in1', password
    }
    # cache now that we know it is safe to do so
    @user       = user
    @auth_token = response.document.xpath('//loginReturn').first.to_s
    true
  end

  # You only need to call this to make an explicit logout; normally, a session
  # will automatically expire after a set time (configured on the server).
  # @return [true] true if successful, otherwise false
  def logout
    response = invoke('soap:logout') { |msg|
      msg.add 'soap:in0', @auth_token
    }
    response.document.xpath('//logoutReturn').first.to_s == 'true'
  end

  # @return [[JIRA::Priority]]
  def get_priorities
    response = invoke('soap:getPriorities') { |msg|
      msg.add 'soap:in0', @auth_token
    }
    response.document.xpath("#{RESPONSE_XPATH}/getPrioritiesReturn").map {
      |frag|
      JIRA::Priority.priority_with_xml_fragment frag
    }
  end

  # @return [[JIRA::Resolution]]
  def get_resolutions
    response = invoke('soap:getResolutions') { |msg|
      msg.add 'soap:in0', @auth_token
    }
    response.document.xpath("#{RESPONSE_XPATH}/getResolutionsReturn").map {
      |frag|
      JIRA::Resolution.resolution_with_xml_fragment frag
    }
  end

  # @return [[JIRA::Field]]
  def get_custom_fields
    response = invoke('soap:getCustomFields') { |msg|
      msg.add 'soap:in0', @auth_token
    }
    response.document.xpath("#{RESPONSE_XPATH}/getCustomFieldsReturn").map {
      |frag|
      JIRA::Field.field_with_xml_fragment frag
    }
  end

  # @return [[JIRA::IssueType]]
  def get_issue_types
    response = invoke('soap:getIssueTypes') { |msg|
      msg.add 'soap:in0', @auth_token
    }
    response.document.xpath("#{RESPONSE_XPATH}/getIssueTypesReturn").map {
      |frag|
      JIRA::IssueType.issue_type_with_xml_fragment frag
    }
  end

  # @return [[JIRA::Status]]
  def get_statuses
    response = invoke('soap:getStatuses') { |msg|
      msg.add 'soap:in0', @auth_token
    }
    response.document.xpath("#{RESPONSE_XPATH}/getStatusesReturn").map {
      |frag|
      JIRA::Status.status_with_xml_fragment frag
    }
  end

  # @return [[JIRA::Scheme]]
  def get_notification_schemes
    response = invoke('soap:getNotificationSchemes') { |msg|
      msg.add 'soap:in0', @auth_token
    }
    response.document.xpath("#{RESPONSE_XPATH}/getNotificationSchemesReturn").map {
      |frag|
      JIRA::Scheme.scheme_with_xml_fragment frag
    }
  end

  # @param [String] project_key
  # @return [[JIRA::Version]]
  def get_versions_for_project(project_key)
    response = invoke('soap:getVersions') { |msg|
      msg.add 'soap:in0', @auth_token
      msg.add 'soap:in1', project_key
    }
    response.document.xpath("#{RESPONSE_XPATH}/getVersionsReturn").map {
      |frag|
      JIRA::Version.version_with_xml_fragment frag
    }
  end

  # @param [String] project_key
  # @return [JIRA::Project]
  def get_project_with_key(project_key)
    response = invoke('soap:getProjectByKey') { |msg|
      msg.add 'soap:in0', @auth_token
      msg.add 'soap:in1', project_key
    }
    frag = response.document.xpath '//getProjectByKeyReturn'
    JIRA::Project.project_with_xml_fragment frag
  end

  # @param [String] user_name
  # @return [JIRA::User]
  def get_user_with_name(user_name)
    response = invoke('soap:getUser') { |msg|
      msg.add 'soap:in0', @auth_token
      msg.add 'soap:in1', user_name
    }
    JIRA::User.user_with_xml_fragment response.document.xpath '//getUserReturn'
  end

  # Gets you the default avatar image for a project; if you want all
  # the avatars for a project, use {#get_project_avatars_for_key}.
  # @param [String] project_key
  # @return [JIRA::Avatar]
  def get_project_avatar_for_key(project_key)
    response = invoke('soap:getProjectAvatar') { |msg|
      msg.add 'soap:in0', @auth_token
      msg.add 'soap:in1', project_key
    }
    JIRA::Avatar.avatar_with_xml_fragment response.document.xpath '//getProjectAvatarReturn'
  end

  # Gets ALL avatars for a given project use this method; if you
  # just want the default avatar, use {#get_project_avatar_for_key}.
  # @param [String] project_key
  # @param [boolean] include_default_avatars
  # @return [[JIRA::Avatar]]
  def get_project_avatars_for_key(project_key, include_default_avatars = false)
    response = invoke('soap:getProjectAvatars') { |msg|
      msg.add 'soap:in0', @auth_token
      msg.add 'soap:in1', project_key
      msg.add 'soap:in2', include_default_avatars
    }
    response.document.xpath("#{RESPONSE_XPATH}/getProjectAvatarsReturn").map {
      |frag|
      JIRA::Avatar.avatar_with_xml_fragment frag
    }
  end

  # This method is the equivalent of making an advanced search from the
  # web interface.
  #
  # During my own testing, I found that HTTP requests could timeout for really
  # large requests (~2500 results). So I set a more reasonable upper limit;
  # feel free to override it, but be aware of the potential issues.
  #
  # The JIRA::Issue structure does not include any comments or attachments.
  # @param [String] jql_query JQL query as a string
  # @param [Fixnum] max_results limit on number of returned results;
  #  the value may be overridden by the server if max_results is too large
  # @return [[JIRA::Issue]]
  def get_issues_from_jql_search(jql_query, max_results = 2000)
    response = invoke('soap:getIssuesFromJqlSearch') { |msg|
      msg.add 'soap:in0', @auth_token
      msg.add 'soap:in1', jql_query
      msg.add 'soap:in2', max_results
    }
    response.document.xpath("#{RESPONSE_XPATH}/getIssuesFromJqlSearchReturn").map {
      |frag|
      JIRA::Issue.issue_with_xml_fragment frag
    }
  end

  # This method can update most, but not all, issue fields.
  #
  # Fields known to not update via this method:
  #  - status - use {#progress_workflow_action}
  #  - attachments - use {#add_base64_encoded_attachment_to_issue}
  #
  # Though JIRA::FieldValue objects have an id field, they do not expect to be
  # given id values. You must use the name of the field you wish to update.
  # @example Usage With A Normal Field
  #  summary        = JIRA::FieldValue.new
  #  summary.id     = 'summary'
  #  summary.values = ['My new summary']
  # @example Usage With A Custom Field
  #  custom_field        = JIRA::FieldValue.new
  #  custom_field.id     = 'customfield_10060'
  #  custom_field.values = ['123456']
  # @example Setting a field to be blank/nil
  #  description = JIRA::FieldValue.field_value_with_nil_values 'description'
  # @example Calling the method to update an issue
  #  jira_service_instance.update_issue 'PROJECT-1', description, custom_field
  # @param [String] issue_key
  # @param [JIRA::FieldValue] *field_values
  # @return [JIRA::Issue]
  def update_issue(issue_key, *field_values)
    response = invoke('soap:updateIssue') { |msg|
      msg.add 'soap:in0', @auth_token
      msg.add 'soap:in1', issue_key
      msg.add 'soap:in2'  do |submsg|
        field_values.each { |fv| fv.soapify_for submsg }
      end
    }
    frag = response.document.xpath '//updateIssueReturn'
    JIRA::Issue.issue_with_xml_fragment frag
  end

  # Some fields will be ignored when an issue is created.
  #  - reporter - you cannot override this value at creation
  #  - resolution
  #  - attachments
  #  - votes
  #  - status
  #  - due date - I think this is a bug in jiraSOAP or JIRA
  #  - environment - I think this is a bug in jiraSOAP or JIRA
  # @param [JIRA::Issue] issue
  # @return [JIRA::Issue]
  def create_issue_with_issue(issue)
    response = invoke('soap:createIssue') { |msg|
      msg.add 'soap:in0', @auth_token
      msg.add 'soap:in1' do |submsg|
        issue.soapify_for submsg
      end
    }
    frag = response.document.xpath '//createIssueReturn'
    JIRA::Issue.issue_with_xml_fragment frag
  end

  # @param [String] issue_key
  # @return [JIRA::Issue]
  def get_issue_with_key(issue_key)
    response = invoke('soap:getIssue') { |msg|
      msg.add 'soap:in0', @auth_token
      msg.add 'soap:in1', issue_key
    }
    frag = response.document.xpath '//getIssueReturn'
    JIRA::Issue.issue_with_xml_fragment frag
  end

  # @param [String] issue_id
  # @return [JIRA::Issue]
  def get_issue_with_id(issue_id)
    response = invoke('soap:getIssueById') { |msg|
      msg.add 'soap:in0', @auth_token
      msg.add 'soap:in1', issue_id
    }
    frag = response.document.xpath '//getIssueByIdReturn'
    JIRA::Issue.issue_with_xml_fragment frag
  end

  # @param [String] issue_key
  # @return [[JIRA::Attachment]]
  def get_attachments_for_issue_with_key(issue_key)
    response = invoke('soap:getAttachmentsFromIssue') { |msg|
      msg.add 'soap:in0', @auth_token
      msg.add 'soap:in1', issue_key
    }
    response.document.xpath("#{RESPONSE_XPATH}/getAttachmentsFromIssueReturn").map {
      |frag|
      JIRA::AttachmentMetadata.attachment_with_xml_fragment frag
    }
  end

  # New versions cannot have the archived bit set and the release date
  # field will ignore the time of day you give it and instead insert
  # the time zone offset as the time of day.
  #
  # Remember that the @release_date field is the tentative release date,
  # so its value is independant of the @released flag.
  #
  # Descriptions do not appear to be included with JIRA::Version objects
  # that SOAP API provides.
  # @param [String] project_key
  # @param [JIRA::Version] version
  # @return [JIRA::Version]
  def add_version_to_project(project_key, version)
    response = invoke('soap:addVersion') { |msg|
      msg.add 'soap:in0', @auth_token
      msg.add 'soap:in1', project_key
      msg.add 'soap:in2' do |submsg| version.soapify_for submsg end
    }
    frag = response.document.xpath '//addVersionReturn'
    JIRA::Version.version_with_xml_fragment frag
  end

  # The archive state can only be set to true for versions that have not been
  # released. However, this is not reflected by the return value of this method.
  # @param [String] project_key
  # @param [String] version_name
  # @param [boolean] state
  # @return [boolean] true if successful, otherwise an exception is thrown
  def set_archive_state_for_version_for_project(project_key, version_name, state)
    response = invoke('soap:archiveVersion') { |msg|
      msg.add 'soap:in0', @auth_token
      msg.add 'soap:in1', project_key
      msg.add 'soap:in2', version_name
      msg.add 'soap:in3', state
    }
    true
  end

  # Requires you to set at least a project name, key, and lead.
  # However, it is also a good idea to set other project properties, such as
  # the permission scheme as the default permission scheme can be too
  # restrictive in most cases.
  # @param [JIRA::Project] project
  # @return [JIRA::Project]
  def create_project_with_project(project)
    response = invoke('soap:createProjectFromObject') { |msg|
      msg.add 'soap:in0', @auth_token
      msg.add 'soap:in1' do |submsg| project.soapify_for submsg end
    }
    frag = response.document.xpath '//createProjectFromObjectReturn'
    JIRA::Project.project_with_xml_fragment frag
  end

  # @param [String] id
  # @return [JIRA::Project]
  def get_project_with_id(id)
    response = invoke('soap:getProjectById') { |msg|
      msg.add 'soap:in0', @auth_token
      msg.add 'soap:in1', id
    }
    frag = response.document.xpath '//getProjectByIdReturn'
    JIRA::Project.project_with_xml_fragment frag
  end


  # @param [String] id
  # @return [JIRA::Comment]
  def get_comment_with_id(id)
    response = invoke('soap:getComment') { |msg|
      msg.add 'soap:in0', @auth_token
      msg.add 'soap:in1', id
    }
    frag = response.document.xpath '//getCommentReturn'
    JIRA::Comment.comment_with_xml_fragment frag
  end

  # @param [String] issue_key
  # @return [[JIRA::Comment]]
  def get_comments_for_issue_with_key(issue_key)
    response = invoke('soap:getComments') { |msg|
      msg.add 'soap:in0', @auth_token
      msg.add 'soap:in1', issue_key
    }
    response.document.xpath("#{RESPONSE_XPATH}/getCommentsReturn").map {
      |frag|
      JIRA::Comment.comment_with_xml_fragment frag
    }
  end

  # @param [String] project_name
  # @return [[JIRA::IssueType]]
  def get_issue_types_for_project_with_id(project_id)
    response = invoke('soap:getIssueTypesForProject') { |msg|
      msg.add 'soap:in0', @auth_token
      msg.add 'soap:in1', project_id
    }
    response.document.xpath("#{RESPONSE_XPATH}/getIssueTypesForProjectReturn").map {
      |frag|
      JIRA::IssueType.issue_type_with_xml_fragment frag
    }
  end
  # @return [[JIRA::IssueType]]
  def get_subtask_issue_types
    response = invoke('soap:getSubTaskIssueTypes') { |msg|
      msg.add 'soap:in0', @auth_token
    }
    response.document.xpath("#{RESPONSE_XPATH}/getSubTaskIssueTypesReturn").map {
      |frag|
      JIRA::IssueType.issue_type_with_xml_fragment frag
    }
  end

  # @param [String] project_id
  # @return [[JIRA::IssueType]]
  def get_subtask_issue_types_for_project_with_id(project_id)
    response = invoke('soap:getSubTaskIssueTypesForProject') { |msg|
      msg.add 'soap:in0', @auth_token
      msg.add 'soap:in1', project_id
    }
    response.document.xpath("#{RESPONSE_XPATH}/getSubtaskIssueTypesForProjectReturn").map {
      |frag|
      JIRA::IssueType.issue_type_with_xml_fragment frag
    }
  end

  # @todo find out what this method does
  # @return [boolean] true if successful, throws an exception otherwise
  def refresh_custom_fields
    response = invoke('soap:refreshCustomFields') { |msg|
      msg.add 'soap:in0', @auth_token
    }
    true
  end

  # Retrieves favourite filters for the currently logged in user.
  # @return [[JIRA::Filter]]
  def get_favourite_filters
    response = invoke('soap:getFavouriteFilters') { |msg|
      msg.add 'soap:in0', @auth_token
    }
    response.document.xpath("#{RESPONSE_XPATH}/getFavouriteFiltersReturn").map {
      |frag|
      JIRA::Filter.filter_with_xml_fragment frag
    }
  end

  # The @build_date attribute is a Time value, but does not include a time.
  # @return [JIRA::ServerInfo]
  def get_server_info
    response = invoke('soap:getServerInfo') { |msg|
      msg.add 'soap:in0', @auth_token
    }
    frag = response.document.xpath '//getServerInfoReturn'
    JIRA::ServerInfo.server_info_with_xml_fragment frag
  end
end

#TODO: next block of useful methods
# addBase64EncodedAttachmentsToIssue
# addComment
# createProject
# createProjectRole
# createUser
# deleteProjectAvatar
# deleteUser
# editComment
# getAvailableActions
# getIssueCountForFilter
# getIssuesFromFilterWithLimit
# getIssuesFromTextSearchWithLimit
# progressWorkflowAction
# releaseVersion
# setProjectAvatar (change to different existing)
# setNewProjectAvatar (upload new and set it)
# updateProject
# progressWorkflowAction
