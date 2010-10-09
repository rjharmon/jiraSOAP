require 'handsoap'
require 'logger'
require 'time'
require 'uri'

require 'jiraSOAP/url.rb'
require 'jiraSOAP/handsoap_extensions.rb'
require 'jiraSOAP/remoteEntities.rb'
require 'jiraSOAP/remoteAPI.rb'

require 'jiraSOAP/JIRAservice.rb'

#overrides and additions
require 'lib/macruby_stuff.rb' if RUBY_ENGINE == 'macruby'
