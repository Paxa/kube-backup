require_relative '../lib/kube_backup'

gem 'minitest'

require 'minitest/autorun'
require 'yaml'

def load_sample(file)
  path = File.join(__dir__, "samples/#{file}.yaml")
  if YAML.respond_to?(:unsafe_load_file)
    YAML.unsafe_load_file(path)
  else
    YAML.load_file(path)
  end
end
