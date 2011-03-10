# vim: set syntax=ruby :
# Giles Bowkett, Greg Brown, and several audience members from Giles' Ruby East presentation.
# http://gilesbowkett.blogspot.com/2007/10/use-vi-or-any-text-editor-from-within.html

require 'irb'
require 'fileutils'
require 'tempfile'
require 'shellwords'
require 'yaml'

class InteractiveEditor
  VERSION = '0.0.6'

  attr_accessor :editor

  def initialize(editor)
    @editor = editor.to_s
  end

  def edit(object, file=nil)
    object = object.instance_of?(Object) ? nil : object

    current_file = if file
      FileUtils.touch(file) unless File.exist?(file)
      File.new(file)
    else
      if @file && File.exist?(@file.path) && !object
        @file
      else
        Tempfile.new( object ? ["yobj_tempfile", ".yml"] : ["irb_tempfile", ".rb"] )
      end
    end

    if object
      File.open( current_file, 'w' ) { |f| f << object.to_yaml }
    else
      @file = current_file
      mtime = File.stat(@file.path).mtime
    end

    args = Shellwords.shellwords(@editor) #parse @editor as arguments could be complexe
    args << current_file.path
    Exec.system(*args)

    if object
      return object unless File.exists?(current_file)
      YAML::load( File.open(current_file) )
    elsif mtime < File.stat(@file.path).mtime
      execute
    end
  end

  def execute
    eval(IO.read(@file.path), TOPLEVEL_BINDING)
  end

  def self.edit(editor, self_, file=nil)
    #maybe serialise last file to disk, for recovery
    (IRB.conf[:interactive_editors] ||=
      Hash.new { |h,k| h[k] = InteractiveEditor.new(k) })[editor].edit(self_, file)
  end

  module Exec
    module Java
      def system(file, *args)
        require 'spoon'
        Process.waitpid(Spoon.spawnp(file, *args))
      rescue Errno::ECHILD => e
        raise "error exec'ing #{file}: #{e}"
      end
    end

    module MRI
      def system(file, *args)
        Kernel::system(file, *args) #or raise "error exec'ing #{file}: #{$?}"
      end
    end

    extend RUBY_PLATFORM =~ /java/ ? Java : MRI
  end

  module Editors
    {
      :vi    => nil,
      :vim   => nil,
      :emacs => nil,
      :nano  => nil,
      :mate  => 'mate -w',
      :mvim  => 'mvim -g -f -c "au VimLeave * !open -a Terminal"'
    }.each do |k,v|
      define_method(k) do |*args|
        InteractiveEditor.edit(v || k, self, *args)
      end
    end

    def ed(*args)
      if ENV['EDITOR'].to_s.size > 0
        InteractiveEditor.edit(ENV['EDITOR'], self, *args)
      else
        raise "You need to set the EDITOR environment variable first"
      end
    end
  end
end

include InteractiveEditor::Editors
