##
# Only contains the metadata for an attachment. The URI for an attachment
# appears to be of the form
# "{JIRA::JIRAService.endpoint_url}/secure/attachment/{#id}/{#file_name}"
class JIRA::AttachmentMetadata < JIRA::NamedEntity

  # @return [String]
  add_attribute :author, 'author', :content

  # @return [String]
  add_attribute :file_name, 'filename', :content
  alias_method :filename, :file_name

  # @return [String]
  add_attribute :mime_type, 'mimetype', :content
  alias_method :content_type, :mime_type

  # @return [Number] Measured in bytes
  add_attribute :file_size, 'filesize', :to_i

  # @return [Time]
  add_attribute :create_time, 'created', :to_iso_date

  ##
  # Fetch the attachment from the server.
  def attachment
    raise NotImplementedError
  end

  # @todo I suspect that I would have to not upload
  # create_time, author
end
