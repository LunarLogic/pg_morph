# A sample Guardfile
# More info at https://github.com/guard/guard#readme

guard :rspec, cmd: 'bundle exec rspec --color --format documentation' do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})     { |m| ["spec/lib/#{m[1]}_spec.rb", "spec/lib/#{m[1]}_integration_spec.rb"] }
  watch('spec/spec_helper.rb')  { "spec" }
end

