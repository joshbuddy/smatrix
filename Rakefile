require 'spec'
require 'spec/rake/spectask'

task :spec => 'spec:all'
namespace(:spec) do
  task :all => [:smatrix]

  Spec::Rake::SpecTask.new(:smatrix) do |t|
    t.spec_opts ||= []
    t.spec_opts << "-rubygems"
    t.spec_opts << "--options" << "spec/spec.opts"
    t.spec_files = FileList['spec/**/*_spec.rb']
  end

end

