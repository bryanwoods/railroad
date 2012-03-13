# RailRoad - RoR diagrams generator
# http://railroad.rubyforge.org
#
# Copyright 2007-2008 - Javier Smaldone (http://www.smaldone.com.ar)
# See COPYING for more details

require 'railroad/diagram_graph'

# Root class for RailRoad diagrams
class AppDiagram

  def initialize(options)
    @options = options
    @graph = DiagramGraph.new
    @graph.show_label = @options.label

    STDERR.print "Loading application environment\n" if @options.verbose
    load_environment

    STDERR.print "Loading application classes\n" if @options.verbose
    load_classes
  end

  # Print diagram
  def print
    if @options.output
      old_stdout = STDOUT.dup
      begin
        STDOUT.reopen(@options.output)
      rescue
        STDERR.print "Error: Cannot write diagram to #{@options.output}\n\n"
        exit 2
      end
    end

    if @options.xmi
        STDERR.print "Generating XMI diagram\n" if @options.verbose
        STDOUT.print @graph.to_xmi
    else
        STDERR.print "Generating DOT graph\n" if @options.verbose
        STDOUT.print @graph.to_dot
    end

    if @options.output
      STDOUT.reopen(old_stdout)
    end
  end # print

  private

  # Prevents Rails application from writing to STDOUT
  def disable_stdout
    @old_stdout = STDOUT.dup
    STDOUT.reopen(RUBY_PLATFORM =~ /mswin/ ? "NUL" : "/dev/null")
  end

  # Restore STDOUT
  def enable_stdout
    STDOUT.reopen(@old_stdout)
  end


  # Print error when loading Rails application
  def print_error(type)
    STDERR.print "Error loading #{type}.\n  (Are you running " +
                 "#{APP_NAME} on the application's root directory?)\n\n"
  end

  # Load Rails application's environment
  def load_environment
    begin
      disable_stdout
      $:.unshift './'
      require "config/environment"
      enable_stdout
    rescue LoadError
      enable_stdout
      print_error "application environment"
      raise
    end
  end

  # Extract class name from filename
  def extract_class_name(filename)
    #filename.split('/')[2..-1].join('/').split('.').first.camelize
    # Fixed by patch from ticket #12742
    path = File.dirname(filename)
    base_file_class = File.basename(filename, ".rb").camelize
    if path == '.'
      base_file_class
    else
      rails_root = /#{Dir.pwd}/
      rails_structure = /\/?app\/(models|controllers|observers|services|views|helpers)\/?/
      namespaced_class_path = path.gsub(rails_root,'').gsub(rails_structure,'')
      # This will convert something like /Users/you/Sites/railsapp/app/models/api/modelname.rb to Api::Modelname
      # In SOME cases the namespacing/directory hierarchy does not match up which is why this is a little narsty
      # In that case we just fall back on the File.basename and cross our fingers :)
      unless namespaced_class_path.strip.blank?
        namespaced_class = ([namespaced_class_path, File.basename(filename, ".rb")].join('/')).camelize
        begin
          namespaced_class.constantize
        rescue LoadError # there is no spoon
          return base_file_class
        end
        return namespaced_class
      else
        return base_file_class
      end
    end
  end

end # class AppDiagram
