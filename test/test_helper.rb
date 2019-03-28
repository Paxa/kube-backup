require_relative '../lib/kube_backup'

gem 'minitest'

require 'minitest/autorun'
require 'yaml'

def load_sample(file)
  YAML::load_file(File.join(__dir__, "samples/#{file}.yaml"))
end
